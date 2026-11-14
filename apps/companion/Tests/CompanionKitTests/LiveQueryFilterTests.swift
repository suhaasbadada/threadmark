import Foundation
import Testing
@testable import CompanionKit

@Suite("Actual CLI native file-scoped Query")
struct LiveQueryFilterTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: [SourceRetrievalMode.literal, .rankedTerms])
    @MainActor func twoFullListsEarlyUnselectedAndInspect(mode: SourceRetrievalMode) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let files = (0..<63).map { String(format: "a%02d.rs", $0) } + ["z.rs"]
        for path in files { try Data((path == "z.rs" ? "first\n\ncenter λ\nlast\n" : "center center center λ\n").utf8).write(to: fixture.root.appendingPathComponent(path)) }
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "query-store"))
        _ = try await service.perform(.addProject("alpha", fixture.root.path, files))
        _ = try await service.perform(.index("alpha"))
        _ = try await service.perform(.writeContext("alpha", "memo", "note", "human history", update: false))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "unsent original")
        model.setSourceRetrievalMode(mode); model.setQueryFileFilter(files.reversed())
        model.query("center"); await model.waitForOperation()
        #expect(model.evidence?.results.count == 8 && model.querySelectedPaths == files)
        model.setQueryFileFilter(["z.rs"]); model.query("center"); await model.waitForOperation()
        let a = try #require(model.evidence?.results.first), p = try #require(model.project)
        #expect(a.path == "z.rs" && model.evidence?.results.count == 1)
        #expect(model.canInspectSource(a))
        model.inspectSource(a); await model.waitForOperation()
        #expect(model.sourceInspection?.path == "z.rs")
        #expect(model.history?.history.last?.text == "human history" && model.originalDraft == "unsent original")
        let captured = try FileQueryRequest(project: p, query: "center", mode: mode, selectedPaths: ["z.rs"])
        // Unselected approved edits and unsafe sources stale the entire snapshot.
        let unselected = fixture.root.appendingPathComponent(files[0])
        try Data("changed unselected\n".utf8).write(to: unselected)
        model.query("center"); await model.waitForOperation()
        #expect(model.evidence?.currentness == "stale-or-unindexed" && model.evidence?.results.isEmpty == true)
        try FileManager.default.removeItem(at: unselected)
        try FileManager.default.createSymbolicLink(atPath: unselected.path, withDestinationPath: "z.rs")
        model.query("center"); await model.waitForOperation()
        #expect(model.evidence?.currentness == "stale-or-unindexed" && model.evidence?.results.isEmpty == true)
        try FileManager.default.removeItem(at: unselected)
        try Data("center center center λ\n".utf8).write(to: unselected)
        guard case .string(let identity) = p.root_identity, let nonce = p.incarnation else { throw ServiceError.invalid }
        _ = try await service.perform(.forgetSource(p.id, "z.rs", p.root, identity, nonce, p.sources))
        await #expect(throws: (any Error).self) { try await service.perform(.queryFilesBound(captured)) }
        guard case .project(let fresh) = try await service.perform(.project(p.id)) else { throw ServiceError.invalid }
        #expect(throws: (any Error).self) { try FileQueryRequest(project: fresh, query: "center", mode: mode, selectedPaths: ["z.rs"]) }
        _ = try await service.perform(.index(p.id))
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent("z.rs")) == Data("first\n\ncenter λ\nlast\n".utf8))
        guard case .context(let history) = try await service.perform(.context(p.id, "memo")) else { throw ServiceError.invalid }
        #expect(history.history.last?.text == "human history")
        model.query("center"); await model.waitForOperation()
        #expect(model.evidence == nil && !model.canInspectSource(a))
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: ["root", "identity", "nonce", "policy", "snapshot"])
    func actualDispatchRejectsCapturedPeerChanges(field: String) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        try Data("center A\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
        try Data("center B must not appear\n".utf8).write(to: fixture.root.appendingPathComponent("b.rs"))
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "race-store"))
        _ = try await service.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await service.perform(.index("alpha"))
        guard case .project(let p) = try await service.perform(.project("alpha")), case .string(let identity) = p.root_identity,
              let nonce = p.incarnation else { throw ServiceError.invalid }
        let request = try FileQueryRequest(project: p, query: "center", mode: .literal, selectedPaths: ["a.rs"])
        switch field {
        case "policy": _ = try await service.perform(.setSources("alpha", ["b.rs"]))
        case "snapshot":
            try Data("center B changed\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
            _ = try await service.perform(.index("alpha"))
        default:
            _ = try await service.perform(.removeProject("alpha", p.root, identity, nonce))
            var root = fixture.root
            if field == "root" || field == "identity" {
                root = fixture.root.appendingPathComponent("replacement")
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
                try Data("center B replacement\n".utf8).write(to: root.appendingPathComponent("a.rs"))
            }
            _ = try await service.perform(.addProject("alpha", root.path, ["a.rs"]))
            _ = try await service.perform(.index("alpha"))
        }
        await #expect(throws: (any Error).self) { try await service.perform(.queryFilesBound(request)) }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_QUERY_FILTER_FIXTURE_BINARY"] != nil),
          arguments: [SourceRetrievalMode.literal, .rankedTerms])
    func exact145ArgvCanonicalTwoListsEOFAndHostileOutput(mode: SourceRetrievalMode) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_QUERY_FILTER_FIXTURE_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let paths = ["a.rs"] + (1..<64).map { "f\($0).rs" }
        let p = Project(id: "alpha", root: inspectionScope.root, sources: paths, snapshot: inspectionScope.snapshot,
            rootIdentity: inspectionScope.root_identity, incarnation: inspectionScope.incarnation)
        let r = try FileQueryRequest(project: p, query: "center", mode: mode, selectedPaths: paths.reversed())
        let data = try fileQueryBytes(r), response = fixture.root.appendingPathComponent("response.json")
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: fixture.root)
        try data.write(to: response)
        guard case .filteredQuery(let report) = try await service.perform(.queryFilesBound(r)) else { throw ServiceError.invalid }
        #expect(report.selectedPaths == paths)
        let good = String(decoding: data, as: UTF8.self)
        let hostile: [String] = ["{\"version\":1," + String(good.dropFirst()), String(good.dropLast(2)), good + "{}",
            good.replacingOccurrences(of: "\"path\":\"a.rs\"", with: "\"path\":\"outside.rs\""), String(repeating: " ", count: 8193)]
        for frame in hostile {
            try Data(frame.utf8).write(to: response)
            await #expect(throws: (any Error).self) { try await service.perform(.queryFilesBound(r)) }
        }
    }
}
