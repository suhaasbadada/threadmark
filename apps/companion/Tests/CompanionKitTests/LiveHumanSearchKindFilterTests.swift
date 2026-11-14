import Foundation
import Testing
@testable import CompanionKit

private actor FilterPeer: CoreService {
    let adapter: ProcessService
    var root: String?
    var failSearch = false
    var holdSearch = false, didStart = false
    var held: CheckedContinuation<Void, Never>?, started: CheckedContinuation<Void, Never>?
    var delivered = 0, rejected = 0, fallback = 0
    init(_ adapter: ProcessService) { self.adapter = adapter }
    func arm(_ root: String) { self.root = root }
    func fail(_ value: Bool) { failSearch = value }
    func hold() { holdSearch = true; didStart = false }
    func waitForSearch() async { if !didStart { await withCheckedContinuation { started = $0 } } }
    func release() { held?.resume(); held = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        switch operation {
        case .searchHumanContext, .searchHumanContextBound:
            fallback += 1; throw ServiceError.invalid
        case .searchHumanContextKindsBound(let request):
            if holdSearch {
                holdSearch = false; didStart = true; started?.resume(); started = nil
                await withCheckedContinuation { held = $0 }
            }
            if failSearch { throw ServiceError.failed }
            if let root {
                self.root = nil
                let b = request.binding
                _ = try await adapter.perform(.removeProject(b.project, b.root, b.rootIdentity, b.incarnation))
                _ = try await adapter.perform(.addProject(b.project, root, []))
                _ = try await adapter.perform(.writeContext(b.project, "memo", "note", "Synthetic B private needle", update: false))
                do { let reply = try await adapter.perform(operation); delivered += 1; return reply }
                catch { if error as? ServiceError == .failed { rejected += 1 }; throw error }
            }
            return try await adapter.perform(operation)
        default: return try await adapter.perform(operation)
        }
    }
}

@Suite("Actual CLI kind filtered human search")
struct LiveHumanSearchKindFilterTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil, "Requires rebuilt CLI"), arguments: [false, true])
    @MainActor func ae05ReplacementAfterNativePrecheckNoBOrFallback(differentRoot: Bool) async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "filter-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, []))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic A needle", update: false))
        let peer = FilterPeer(adapter)
        let selected = CompanionModel(service: peer, configured: true)
        selected.select("alpha"); await selected.waitForOperation(); selected.openContext("memo"); await selected.waitForOperation()
        selected.setHumanSearchKindFilter(["note"])
        let other = fixture.root.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
        await peer.arm(differentRoot ? other.path : fixture.root.path)
        selected.searchHumanContext("needle"); await selected.waitForOperation()
        #expect(await peer.rejected == 1)
        #expect(await peer.delivered == 0)
        #expect(await peer.fallback == 0)
        #expect(selected.project == nil && selected.history == nil && selected.humanSearch == nil && selected.lastError == .namespaceChanged)
        await selected.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil, "Requires rebuilt CLI"))
    @MainActor func ae01AE02AE06ActualFilterLifecycleAndCASPreservation() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "filter-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        for n in 0..<12 { _ = try await adapter.perform(.writeContext("alpha", "a\(n)", "pitfall", "needle needle needle", update: false)) }
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic needle", update: false))
        let peer = FilterPeer(adapter)
        let model = CompanionModel(service: peer, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        let base = try #require(model.humanContextRevisionBinding("memo")), editor = model.contextEditorRevision
        model.editPreparation(query: "q", original: "Synthetic original draft")
        _ = try await adapter.perform(.writeContext("alpha", "memo", "decision", "Synthetic needle", update: true))
        model.writeContext(id: "memo", kind: "note", text: "Synthetic unsaved editor", update: true, expected: base); await model.waitForOperation()
        #expect(model.lastError == .contextConflict)
        model.setHumanSearchKindFilter(["note"]); model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch?.matched_entries == 0 && model.lastError == .contextConflict)
        model.setHumanSearchKindFilter(["decision"]); model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch?.results.first?.revision == 2 && model.humanSearchSelectedKinds == ["decision"])
        #expect(model.lastError == .contextConflict && model.status == ServiceError.contextConflict.localizedDescription)
        #expect(model.history?.history.count == 1 && model.humanContextRevisionBinding("memo") == base)
        #expect(model.contextEditorRevision == editor && model.originalDraft == "Synthetic original draft")
        await peer.fail(true)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch == nil && model.lastError == .contextConflict)
        #expect(model.history?.history.count == 1 && model.humanContextRevisionBinding("memo") == base)
        #expect(model.contextEditorRevision == editor && model.originalDraft == "Synthetic original draft")
        await peer.fail(false); await peer.hold()
        model.searchHumanContext("needle"); await peer.waitForSearch()
        model.setHumanSearchKindFilter(["decision", "note"])
        #expect(model.humanSearch == nil && model.lastError == .contextConflict)
        await peer.release(); await model.waitForOperation()
        #expect(model.humanSearch == nil && model.lastError == .contextConflict)
        #expect(model.history?.history.count == 1 && model.humanContextRevisionBinding("memo") == base)
        #expect(model.contextEditorRevision == editor && model.originalDraft == "Synthetic original draft")
        // Source policy/root absence is not human read authority.
        _ = try await adapter.perform(.setSources("alpha", []))
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("a.rs"))
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch?.results.first?.id == "memo")
        _ = try await adapter.perform(.retireContext("alpha", "memo"))
        model.searchHumanContext("needle"); await model.waitForOperation(); #expect(model.humanSearch?.matched_entries == 0)
        _ = try await adapter.perform(.writeContext("alpha", "memo", "decision", "Synthetic needle", update: true))
        model.searchHumanContext("needle"); await model.waitForOperation(); #expect(model.humanSearch?.results.first?.revision == 4)
        let p = try #require(model.project), b = try HumanContextReadBinding(project: p)
        _ = try await adapter.perform(.forgetContext("alpha", "memo", b.root, b.rootIdentity, b.incarnation, 4))
        model.searchHumanContext("needle"); await model.waitForOperation(); #expect(model.humanSearch?.matched_entries == 0)
        await #expect(throws: (any Error).self) { try await adapter.perform(.writeContext("alpha", "memo", "note", "needle", update: false)) }
        // Turning opt-in off retains the default old route and no filter metadata.
        let defaultModel = CompanionModel(service: adapter, configured: true)
        defaultModel.select("alpha"); await defaultModel.waitForOperation()
        defaultModel.setHumanSearchKindFilter(nil); defaultModel.searchHumanContext("needle"); await defaultModel.waitForOperation()
        #expect(defaultModel.humanSearch?.results.count == 8 && defaultModel.humanSearchSelectedKinds == nil)
        #expect(await peer.fallback == 0)
        await defaultModel.shutdown()
        await model.shutdown()
    }
}
