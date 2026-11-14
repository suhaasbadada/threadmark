import Foundation
import Testing
@testable import CompanionKit

/// Synthetic second local process replaces the registration after the search read.
private actor SearchReplacementPeer: CoreService {
    let adapter: ProcessService
    var armed = false
    init(_ adapter: ProcessService) { self.adapter = adapter }
    func arm() { armed = true }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        let reply = try await adapter.perform(operation)
        if case .searchHumanContext(let id, _) = operation, armed {
            armed = false
            guard case .project(let p) = try await adapter.perform(.project(id)),
                  case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
            _ = try await adapter.perform(.removeProject(id, p.root, identity, token))
            _ = try await adapter.perform(.addProject(id, p.root, p.sources))
            _ = try await adapter.perform(.writeContext(id, "memo", "note", "Synthetic replacement needle", update: false))
        }
        return reply
    }
}

@Suite("Actual rebuilt CLI native human search")
struct LiveHumanSearchTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil,
                  "Explicitly set THREADMARK_CORE_TEST_BINARY to rebuilt CLI; synthetic data only"))
    @MainActor func addSearchEditRetireForgetAndPeerReplacement() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let source = try Data(contentsOf: fixture.root.appendingPathComponent("a.rs"))
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "human-search-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        let otherRoot = fixture.root.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: otherRoot, withIntermediateDirectories: false)
        try source.write(to: otherRoot.appendingPathComponent("a.rs"))
        _ = try await adapter.perform(.addProject("alpha-other", otherRoot.path, ["a.rs"]))
        _ = try await adapter.perform(.writeContext("alpha-other", "memo", "constraint", "Synthetic other-project needle", update: false))
        _ = try await adapter.perform(.index("alpha"))
        guard case .project(let before) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        let model = CompanionModel(service: adapter, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.writeContext(id: "memo", kind: "note", text: "Synthetic first needle", update: false)
        await model.waitForOperation()
        model.editPreparation(query: "source", original: "Synthetic unrelated unsaved original")
        let editorRevision = model.contextEditorRevision
        // Human search must not need approved source content, even if unreadable.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fixture.root.appendingPathComponent("a.rs").path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fixture.root.appendingPathComponent("a.rs").path) }
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch?.results.map(\.text) == ["Synthetic first needle"])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fixture.root.appendingPathComponent("a.rs").path)
        #expect(model.humanSearch?.incarnation == before.incarnation)
        #expect(model.originalDraft == "Synthetic unrelated unsaved original" && model.contextEditorRevision == editorRevision)
        model.inspectHumanSearchEntry("memo"); await model.waitForOperation()
        #expect(model.history?.history.last?.text == "Synthetic first needle")
        #expect(model.contextEditorRevision == editorRevision)
        model.writeContext(id: "memo", kind: "decision", text: "Synthetic revised needle", update: true, expected: model.humanContextRevisionBinding("memo"))
        #expect(model.humanSearch == nil)
        await model.waitForOperation()
        model.searchHumanContext("first"); await model.waitForOperation()
        #expect(model.humanSearch?.matched_entries == 0)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch?.results.first?.revision == 2 && model.humanSearch?.results.first?.kind == "decision")
        model.inspectHumanSearchEntry("memo"); await model.waitForOperation()
        model.retireContext("memo"); #expect(model.humanSearch == nil); await model.waitForOperation()
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch?.matched_entries == 0)
        // New entry, then native bound Forget: every revision is excluded on subsequent read/reopen.
        model.writeContext(id: "forget-me", kind: "pitfall", text: "Synthetic forget needle", update: false)
        await model.waitForOperation()
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch?.results.map(\.id) == ["forget-me"])
        model.inspectHumanSearchEntry("forget-me"); await model.waitForOperation()
        model.requestForget(); model.confirmForget(try #require(model.pendingForget)); await model.waitForOperation()
        #expect(model.humanSearch == nil)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch?.matched_entries == 0 && model.originalDraft == "Synthetic unrelated unsaved original")
        let reopened = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        guard case .humanContextSearch(let afterForget) = try await reopened.perform(.searchHumanContext("alpha", "needle")),
              case .humanContextSearch(let other) = try await reopened.perform(.searchHumanContext("alpha-other", "needle")),
              case .project(let after) = try await reopened.perform(.project("alpha")) else { throw ServiceError.invalid }
        #expect(afterForget.results.isEmpty && other.results.map(\.text) == ["Synthetic other-project needle"])
        #expect(after.snapshot == before.snapshot && after.sources == before.sources && after.incarnation == before.incarnation)
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent("a.rs")) == source)
        await model.shutdown()

        let peer = SearchReplacementPeer(adapter)
        let captured = CompanionModel(service: peer, configured: true)
        captured.select("alpha"); await captured.waitForOperation()
        let oldToken = captured.project?.incarnation
        await peer.arm(); captured.searchHumanContext("needle"); await captured.waitForOperation()
        #expect(captured.humanSearch == nil && captured.project == nil && captured.lastError == .namespaceChanged)
        guard case .humanContextSearch(let replacement) = try await adapter.perform(.searchHumanContext("alpha", "needle")) else { throw ServiceError.invalid }
        #expect(replacement.incarnation != oldToken && replacement.results.map(\.text) == ["Synthetic replacement needle"])
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent("a.rs")) == source)
        await captured.shutdown()
    }
}
