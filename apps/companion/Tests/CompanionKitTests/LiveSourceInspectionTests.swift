import Foundation
import Testing
@testable import CompanionKit

@Suite("Actual CLI native query to explicit inspection")
struct LiveSourceInspectionTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/sqlite3")))
    @MainActor func nativeWALRejectionDoesNotRunWritableMetadataDiagnostics() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        try Data("fn center() {}\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "wal-store")
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await service.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await service.perform(.index("alpha"))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.query("center"); await model.waitForOperation()
        let query = try #require(model.evidence), anchor = try #require(query.results.first)
        let database = store.appendingPathComponent("knowledge.sqlite")
        // Finite synthetic SQLite setup only, never a product path or real store.
        let sqlite = Process(), output = Pipe()
        sqlite.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        sqlite.arguments = [database.path, "PRAGMA journal_mode=WAL;"]
        sqlite.standardOutput = output; sqlite.standardError = FileHandle.nullDevice
        try sqlite.run(); sqlite.waitUntilExit()
        #expect(sqlite.terminationStatus == 0)
        #expect(String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) == "wal\n")
        let before = try Data(contentsOf: database), entries = try FileManager.default.contentsOfDirectory(atPath: store.path).sorted()
        #expect(before[18] == 2 && before[19] == 2)
        model.inspectSource(anchor); await model.waitForOperation()
        #expect(model.sourceInspection == nil && model.evidence == query && !model.canInspectSource(anchor))
        #expect(try Data(contentsOf: database) == before)
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.path).sorted() == entries)
        await model.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    func actualTransportRejectsEveryForgedBindingAndExactSelectedText() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        try Data("first\n\nfn center() {}\nlast\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
        let service = ProcessService(executable: URL(fileURLWithPath: binary),
            dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "binding-store"))
        _ = try await service.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await service.perform(.index("alpha"))
        guard case .project(let p) = try await service.perform(.project("alpha")),
              case .query(let q) = try await service.perform(.queryBound(p, "center")) else { throw ServiceError.invalid }
        let a = try #require(q.results.first)
        for field in ["root", "identity", "nonce", "snapshot", "policy", "hash", "line", "text", "producer"] {
            let scope = Project(id: p.id, root: field == "root" ? fixture.root.path + "/wrong" : p.root,
                sources: field == "policy" ? ["a.rs", "b.rs"] : p.sources,
                snapshot: field == "snapshot" ? .string(inspectionHash) : p.snapshot,
                rootIdentity: field == "identity" ? .string("wrong-root-identity") : p.root_identity,
                incarnation: field == "nonce" ? String(repeating: "c", count: 32) : p.incarnation)
            let anchor = Evidence(project: a.project, path: a.path, line: field == "line" ? 1 : a.line,
                text: field == "text" ? "B content must not appear" : a.text,
                source_hash: field == "hash" ? inspectionHash : a.source_hash,
                producer: field == "producer" ? "wrong-producer" : a.producer,
                kind: a.kind, currentness: a.currentness, coverage: a.coverage)
            let request = try SourceInspectionRequest(project: scope, anchor: anchor, radius: 2)
            await #expect(throws: (any Error).self) { try await service.perform(.inspectSourceAnchorBound(request)) }
        }
        for absent in ["nonce", "snapshot", "identity"] {
            let legacy = Project(id: p.id, root: p.root, sources: p.sources,
                snapshot: absent == "snapshot" ? nil : p.snapshot,
                rootIdentity: absent == "identity" ? nil : p.root_identity,
                incarnation: absent == "nonce" ? nil : p.incarnation)
            #expect(throws: (any Error).self) { try SourceInspectionRequest(project: legacy, anchor: a, radius: 2) }
        }
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: [SourceRetrievalMode.literal, .rankedTerms], 0...3)
    @MainActor func fullPolicyUnicodeBlankAndWholeWindows(mode: SourceRetrievalMode, radius: Int) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let sources = (0..<64).map { "f\($0).rs" }
        let source = "first λ\n\nfn center_one() {\n    center_two(); // é \\\"\n}\n"
        for path in sources { try Data(source.utf8).write(to: fixture.root.appendingPathComponent(path)) }
        let service = ProcessService(executable: URL(fileURLWithPath: binary),
            dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "inspection-store"))
        _ = try await service.perform(.addProject("alpha", fixture.root.path, sources))
        _ = try await service.perform(.index("alpha"))
        _ = try await service.perform(.writeContext("alpha", "memo", "note", "Synthetic saved human history", update: false))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "Synthetic unsent original")
        model.setSourceRetrievalMode(mode); model.query("center"); await model.waitForOperation()
        let query = try #require(model.evidence), editor = model.contextEditorRevision
        #expect(query.results.count == 8 && model.sourceInspection == nil)
        model.setInspectionRadius(radius)
        for anchor in query.results {
            #expect(model.canInspectSource(anchor))
            model.inspectSource(anchor); await model.waitForOperation()
            let document = try #require(model.sourceInspection)
            let lines = source.split(separator: "\n", omittingEmptySubsequences: false).dropLast()
            let first = max(1, anchor.line - radius), last = min(lines.count, anchor.line + radius)
            #expect(document.lines.map(\.number) == Array(first...last))
            #expect(document.lines.map(\.text) == Array(lines[(first - 1)..<last]).map(String.init))
            #expect(document.lines.first(where: \.isAnchor)?.text == anchor.text)
            #expect(document.producer == anchor.producer && document.sourceHash == anchor.source_hash)
        }
        #expect(model.evidence == query && model.history?.history.last?.text == "Synthetic saved human history")
        #expect(model.originalDraft == "Synthetic unsent original" && model.contextEditorRevision == editor)
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent(sources[0])) == Data(source.utf8))
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: ["source", "snapshot", "policy", "same-root", "other-root", "forget", "failed-build"])
    @MainActor func actualRevocationMutationReplacementAndRecovery(change: String) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let url = fixture.root.appendingPathComponent("a.rs"), source = "first\n\nfn center() {}\nlast\n"
        try Data(source.utf8).write(to: url)
        let service = ProcessService(executable: URL(fileURLWithPath: binary),
            dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "inspection-store"))
        _ = try await service.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await service.perform(.index("alpha"))
        _ = try await service.perform(.writeContext("alpha", "memo", "note", "Synthetic human history", update: false))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "unsent original")
        model.query("center"); await model.waitForOperation()
        let p = try #require(model.project), query = try #require(model.evidence), anchor = try #require(query.results.first)
        let request = try SourceInspectionRequest(project: p, anchor: anchor, radius: 2)
        let editor = model.contextEditorRevision
        switch change {
        case "same-root", "other-root":
            let other = fixture.root.appendingPathComponent("replacement")
            try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
            try Data("fn center_B_MUST_NOT_APPEAR() {}\n".utf8).write(to: other.appendingPathComponent("a.rs"))
            guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
            _ = try await service.perform(.removeProject(p.id, p.root, identity, token))
            _ = try await service.perform(.addProject(p.id, change == "same-root" ? p.root : other.path, p.sources))
            _ = try await service.perform(.index(p.id))
        case "policy": _ = try await service.perform(.setSources(p.id, []))
        case "forget":
            guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
            _ = try await service.perform(.forgetSource(p.id, "a.rs", p.root, identity, token, p.sources))
            // Omitted-source rebuild must not resurrect the old indexed anchor.
            _ = try await service.perform(.index(p.id))
        case "failed-build":
            try FileManager.default.removeItem(at: url)
            await #expect(throws: (any Error).self) { try await service.perform(.index(p.id)) }
        default:
            try Data("first\n\nfn center_CHANGED() {}\nlast\n".utf8).write(to: url)
            if change == "snapshot" { _ = try await service.perform(.index(p.id)) }
        }
        await #expect(throws: (any Error).self) { try await service.perform(.inspectSourceAnchorBound(request)) }
        model.inspectSource(anchor); await model.waitForOperation()
        #expect(model.sourceInspection == nil && !model.canInspectSource(anchor))
        // CLI's failure is opaque. Do not use the normal writable metadata
        // opener for classification; no replacement is adopted or inspected.
        #expect(model.history?.history.last?.text == "Synthetic human history" && model.originalDraft == "unsent original")
        #expect(model.contextEditorRevision == editor && model.evidence == query && model.project == p)
        if change == "source" || change == "failed-build" {
            try Data(source.utf8).write(to: url)
            if change == "failed-build" { model.build(); await model.waitForOperation() }
            model.query("center"); await model.waitForOperation()
            model.inspectSource(try #require(model.evidence?.results.first)); await model.waitForOperation()
            #expect(model.sourceInspection != nil)
        }
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_SOURCE_INSPECTION_FIXTURE_BINARY"] != nil))
    func hostileProcessResponseAndFullPolicyArgv() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_SOURCE_INSPECTION_FIXTURE_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let files = ["a.rs"] + (1..<64).map { "f\($0).rs" }
        let p = Project(id: "alpha", root: inspectionScope.root, sources: files, snapshot: inspectionScope.snapshot,
                        rootIdentity: inspectionScope.root_identity, incarnation: inspectionScope.incarnation)
        let request = try SourceInspectionRequest(project: p, anchor: inspectionAnchor(), radius: 2)
        let data = try inspectionBytes(request)
        let response = fixture.root.appendingPathComponent("response.json")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: fixture.root)
        try data.write(to: response)
        guard case .sourceInspection(let document) = try await adapter.perform(.inspectSourceAnchorBound(request)) else { throw ServiceError.invalid }
        #expect(document.lines.count == 5)
        let text = try #require(String(data: data, encoding: .utf8))
        for bad in [text.replacingOccurrences(of: "center λ", with: "B content"), "{\"version\":1," + text.dropFirst(), String(text.dropLast(2)), text + "{}", String(repeating: " ", count: 8193)] {
            try Data(bad.utf8).write(to: response)
            await #expect(throws: (any Error).self) { try await adapter.perform(.inspectSourceAnchorBound(request)) }
        }
    }
}
