import Foundation
import Testing
@testable import CompanionKit

@Suite("Actual CLI native explicit coverage")
struct CoverageLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_COVERAGE_FIXTURE_BINARY"] != nil), arguments: [true, false])
    func closed64ArgvEOFAndHostileWholeResponses(baseline: Bool) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_COVERAGE_FIXTURE_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let p = Project(id: "alpha", root: inspectionScope.root, sources: ["a.rs"] + (1..<64).map { "f\($0).rs" },
            snapshot: baseline ? inspectionScope.snapshot : nil, rootIdentity: inspectionScope.root_identity, incarnation: inspectionScope.incarnation)
        let request = try CoverageRequest(project: p), data = try coverageBytes(request)
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: fixture.root)
        let response = fixture.root.appendingPathComponent("response.json")
        try data.write(to: response)
        guard case .coverage(let valid) = try await service.perform(.coverageBound(request)) else { throw ServiceError.invalid }
        #expect(valid.files.count == 64)
        let text = try #require(String(data: data, encoding: .utf8))
        for bad in ["{\"version\":1," + text.dropFirst(), text + "{}", String(text.dropLast(2)),
                    text.replacingOccurrences(of: "\"path\":\"f1.rs\"", with: "\"path\":\"a.rs\""),
                    text.replacingOccurrences(of: "lexical-only", with: "semantic-complete"), String(repeating: " ", count: 65537)] {
            try Data(bad.utf8).write(to: response)
            await #expect(throws: (any Error).self) { try await service.perform(.coverageBound(request)) }
        }
    }
    func setup(_ paths: [String]) async throws -> (ApprovedWatchFixture, ProcessService) {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture()
        for path in paths { try Data("fn center() {}\n".utf8).write(to: fixture.root.appendingPathComponent(path)) }
        let service = ProcessService(executable: URL(fileURLWithPath: binary),
            dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "coverage-store"))
        _ = try await service.perform(.addProject("alpha", fixture.root.path, paths))
        return (fixture, service)
    }
    func project(_ service: ProcessService) async throws -> Project {
        guard case .project(let p) = try await service.perform(.project("alpha")) else { throw ServiceError.invalid }; return p
    }
    func report(_ service: ProcessService, _ p: Project) async throws -> CoverageDocument {
        guard case .coverage(let d) = try await service.perform(.coverageBound(CoverageRequest(project: p))) else { throw ServiceError.invalid }; return d
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func full64UnindexedExplicitBuildRecaptureAndPreservation() async throws {
        let (fixture, service) = try await setup((0..<64).map { "f\($0).rs" }); defer { fixture.remove() }
        _ = try await service.perform(.writeContext("alpha", "memo", "note", "Synthetic human history", update: false))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "unsent original")
        #expect(model.coverageReport == nil && model.canInspectCoverage)
        let p = try #require(model.project), editor = model.contextEditorRevision
        model.inspectCoverage(); await model.waitForOperation()
        let first = try #require(model.coverageReport)
        #expect(first.files.count == 64 && first.files.allSatisfy { $0.status == "unindexed" && $0.storedAnchorRecords == 0 })
        #expect(first.needsBuild == true && !first.projectSnapshotCurrent && first.baselineSnapshot == nil)
        #expect(model.project == p && model.evidence == nil && !model.canInspectSource(inspectionAnchor()))
        model.build(); await model.waitForOperation()
        #expect(model.coverageReport == nil && model.project?.snapshot != p.snapshot)
        await #expect(throws: (any Error).self) { try await report(service, p) }
        model.inspectCoverage(); await model.waitForOperation()
        let current = try #require(model.coverageReport)
        #expect(current.projectSnapshotCurrent && current.matchingFiles == 64 && current.needsBuild == false)
        #expect(current.files.allSatisfy { $0.status == "current" && $0.observedHash != nil })
        #expect(model.history?.history.last?.text == "Synthetic human history" && model.originalDraft == "unsent original")
        #expect(model.contextEditorRevision == editor)
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    func mixedChangedMissingUnsafeEmptyAndRecovery() async throws {
        let paths = ["changed.rs", "current.rs", "empty.rs", "missing.rs", "unsafe.rs", "zero.rs"]
        let (fixture, service) = try await setup(paths); defer { fixture.remove() }
        try Data().write(to: fixture.root.appendingPathComponent("empty.rs"))
        try Data("  \n\n".utf8).write(to: fixture.root.appendingPathComponent("zero.rs"))
        let unbuilt = try await report(service, project(service))
        #expect(unbuilt.files[2].status == "readable-empty" && !unbuilt.files[2].baselineExists)
        _ = try await service.perform(.index("alpha"))
        let p = try await project(service)
        let before = try await report(service, p)
        #expect(before.projectSnapshotCurrent && before.files[2].status == "readable-empty")
        #expect(before.files[5].storedAnchorRecords == 0 && before.files[5].status == "current")
        // Data.write without .atomic keeps the same file identity.
        try Data("fn changed() {}\n".utf8).write(to: fixture.root.appendingPathComponent("changed.rs"))
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("missing.rs"))
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("unsafe.rs"))
        try FileManager.default.createSymbolicLink(atPath: fixture.root.appendingPathComponent("unsafe.rs").path, withDestinationPath: "current.rs")
        let database = service.dataDirectory!.appendingPathComponent("knowledge.sqlite")
        let db = try Data(contentsOf: database), entries = try FileManager.default.contentsOfDirectory(atPath: service.dataDirectory!.path).sorted()
        let mixed = try await report(service, p)
        #expect(!mixed.projectSnapshotCurrent && mixed.needsBuild == true && mixed.needsReadabilityReview)
        #expect(mixed.files.map(\.status) == ["changed", "current", "readable-empty", "unavailable-or-unsafe", "unavailable-or-unsafe", "current"])
        #expect(mixed.files[3].observedHash == nil && mixed.files[4].observedHash == nil)
        #expect(try Data(contentsOf: database) == db)
        #expect(try FileManager.default.contentsOfDirectory(atPath: service.dataDirectory!.path).sorted() == entries)
        try Data("fn center() {}\n".utf8).write(to: fixture.root.appendingPathComponent("changed.rs"))
        let unknown = try await report(service, p)
        #expect(unknown.needsBuild == nil && !unknown.projectSnapshotCurrent)
        try Data("fn center() {}\n".utf8).write(to: fixture.root.appendingPathComponent("current.rs"), options: .atomic)
        let replaced = try await report(service, p)
        #expect(replaced.files[1].status == "replaced" && replaced.files[1].observedHash == before.files[1].observedHash)
        #expect(replaced.needsBuild == true && !replaced.projectSnapshotCurrent)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: ["snapshot", "policy", "nonce", "root"])
    @MainActor func oldCaptureRefusesWithoutBMetadataOrDiagnostics(change: String) async throws {
        let (fixture, service) = try await setup(["a.rs"]); defer { fixture.remove() }
        _ = try await service.perform(.index("alpha"))
        _ = try await service.perform(.writeContext("alpha", "memo", "note", "Synthetic history", update: false))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original")
        model.query("center"); await model.waitForOperation()
        let p = try #require(model.project), query = model.evidence, editor = model.contextEditorRevision
        switch change {
        case "snapshot":
            try Data("fn replacement() {}\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
            _ = try await service.perform(.index("alpha"))
        case "policy": _ = try await service.perform(.setSources("alpha", []))
        default:
            guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
            _ = try await service.perform(.removeProject(p.id, p.root, identity, token))
            let other = fixture.root.appendingPathComponent("other")
            try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
            try Data("B private source\n".utf8).write(to: other.appendingPathComponent("a.rs"))
            _ = try await service.perform(.addProject("alpha", change == "root" ? other.path : p.root, p.sources))
        }
        model.inspectCoverage(); await model.waitForOperation()
        #expect(model.coverageReport == nil && !model.canInspectCoverage)
        #expect(model.project == p && model.evidence == query && model.history?.history.last?.text == "Synthetic history")
        #expect(model.originalDraft == "original" && model.contextEditorRevision == editor)
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    func forgetOmissionsSourceNotesAndEmptyPolicy() async throws {
        let (fixture, service) = try await setup(["a.rs", "b.rs"]); defer { fixture.remove() }
        _ = try await service.perform(.index("alpha"))
        _ = try await service.perform(.writeContext("alpha", "memo", "note", "Synthetic history", update: false))
        let p = try await project(service)
        guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
        _ = try await service.perform(.forgetSource(p.id, "a.rs", p.root, identity, token, p.sources))
        _ = try await service.perform(.index("alpha"))
        await #expect(throws: (any Error).self) { try await report(service, p) }
        let current = try await project(service), d = try await report(service, current)
        #expect(d.files.map(\.path) == ["b.rs"] && d.projectSnapshotCurrent)
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent("a.rs")) == Data("fn center() {}\n".utf8))
        guard case .context(let history) = try await service.perform(.contextBound(HumanContextReadBinding(project: current), "memo")) else { throw ServiceError.invalid }
        #expect(history.history.last?.text == "Synthetic history")
        _ = try await service.perform(.setSources("alpha", []))
        let empty = try await report(service, project(service))
        #expect(empty.files.isEmpty && empty.needsBuild == true && !empty.projectSnapshotCurrent)
        _ = try await service.perform(.index("alpha"))
        let builtEmpty = try await report(service, project(service))
        #expect(builtEmpty.files.isEmpty && builtEmpty.projectSnapshotCurrent && builtEmpty.needsBuild == false)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil), arguments: [UInt8(0), UInt8(255)])
    @MainActor func repairedADLineBudgetFailsWholeNativeAdoption(suffix: UInt8) async throws {
        let (fixture, service) = try await setup(["a.rs"]); defer { fixture.remove() }
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        let database = service.dataDirectory!.appendingPathComponent("knowledge.sqlite"), before = try Data(contentsOf: database)
        var bytes = Data(repeating: 10, count: 4096); bytes.append(suffix)
        try bytes.write(to: fixture.root.appendingPathComponent("a.rs"))
        model.inspectCoverage(); await model.waitForOperation()
        #expect(model.coverageReport == nil && !model.canInspectCoverage && model.project?.snapshot == nil)
        #expect(try Data(contentsOf: database) == before)
        model.select("alpha"); await model.waitForOperation()
        bytes = Data(repeating: 10, count: 4095); bytes.append(suffix)
        try bytes.write(to: fixture.root.appendingPathComponent("a.rs"))
        model.inspectCoverage(); await model.waitForOperation()
        #expect(model.coverageReport?.files.first?.status == "unavailable-or-unsafe")
        #expect(model.coverageReport?.needsBuild == true) // No baseline, not a missing-file diagnosis.
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/sqlite3")))
    @MainActor func WALHeaderRefusalPreservesDatabaseAndDirectory() async throws {
        let (fixture, service) = try await setup(["a.rs"]); defer { fixture.remove() }
        _ = try await service.perform(.index("alpha"))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        let p = model.project, database = service.dataDirectory!.appendingPathComponent("knowledge.sqlite")
        let sqlite = Process(), output = Pipe()
        sqlite.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        sqlite.arguments = [database.path, "PRAGMA journal_mode=WAL;"]
        sqlite.standardOutput = output; sqlite.standardError = FileHandle.nullDevice
        try sqlite.run(); sqlite.waitUntilExit()
        #expect(sqlite.terminationStatus == 0)
        #expect(String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) == "wal\n")
        let before = try Data(contentsOf: database), entries = try FileManager.default.contentsOfDirectory(atPath: service.dataDirectory!.path).sorted()
        #expect(before[18] == 2 && before[19] == 2)
        model.inspectCoverage(); await model.waitForOperation()
        #expect(model.coverageReport == nil && model.project == p && !model.canInspectCoverage)
        #expect(try Data(contentsOf: database) == before)
        #expect(try FileManager.default.contentsOfDirectory(atPath: service.dataDirectory!.path).sorted() == entries)
        await model.shutdown()
    }
}
