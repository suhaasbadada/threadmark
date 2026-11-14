import Foundation
import Testing
@testable import CompanionKit

/// Counts every native boundary and can replace registration after precheck,
/// immediately before the actual bound CLI is allowed to admit human SQL.
private actor ComparisonPeer: CoreService {
    let adapter: ProcessService
    var replacement: String?
    var unbound = 0, sourceCalls = 0, rejected = 0, delivered = 0
    init(_ adapter: ProcessService) { self.adapter = adapter }
    func arm(root: String) { replacement = root }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        switch operation {
        case .context, .contexts, .searchHumanContext: unbound += 1; throw ServiceError.invalid
        case .query, .queryBound, .queryTermsBound, .index, .indexBound, .prepareContext, .prepareContextBound, .prepareContextTermsBound:
            sourceCalls += 1; throw ServiceError.invalid
        case .compareHumanContextBound(let request):
            if let root = replacement {
                replacement = nil
                let b = request.binding
                _ = try await adapter.perform(.removeProject(b.project, b.root, b.rootIdentity, b.incarnation))
                _ = try await adapter.perform(.addProject(b.project, root, ["a.rs"]))
                _ = try await adapter.perform(.writeContext(b.project, request.contextID, "note", "Synthetic replacement B private", update: false))
            }
            do { let reply = try await adapter.perform(operation); delivered += 1; return reply }
            catch { rejected += 1; throw error }
        default: return try await adapter.perform(operation)
        }
    }
}

@Suite("Actual CLI native saved revision comparison")
struct ComparisonLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil)) @MainActor
    func CASConflictComparisonNeverRebasesDraftAndExplicitFreshEditRecovers() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "comparison-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "head\né\r\ntail", update: false))
        let peer = ComparisonPeer(adapter), model = CompanionModel(service: adapter, configured: true)
        // Exercise normal model, not an unbound convenience read, for editor capture.
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "q", original: "Synthetic unrelated original")
        let base = try #require(model.humanContextRevisionBinding("memo")), editor = model.contextEditorRevision
        let draft = "Synthetic unsaved editor" // UI owns this string; comparison never receives it.
        _ = try await adapter.perform(.updateContextRevisionBound(base, "decision", "head\ne\u{301}\ntail\n"))
        model.writeContext(id: "memo", kind: "note", text: draft, update: true, expected: base); await model.waitForOperation()
        #expect(model.lastError == .contextConflict && model.history?.history.count == 1)
        model.openHumanComparison(); model.compareHumanContext(); await model.waitForOperation()
        #expect(model.humanComparison?.textChanged == false && model.lastError == .contextConflict)
        #expect(model.status == ServiceError.contextConflict.localizedDescription)
        #expect(model.humanContextRevisionBinding("memo") == base && model.contextEditorRevision == editor)
        model.openContext("memo"); await model.waitForOperation() // explicit fresh history, not editor rebase
        #expect(model.history?.history.count == 2 && base.revision == 1 && draft == "Synthetic unsaved editor")
        model.openHumanComparison(); model.chooseHumanComparison(from: 1, to: 2); model.compareHumanContext(); await model.waitForOperation()
        let compared = try #require(model.humanComparison)
        #expect(compared.textChanged && compared.kindChanged && !compared.retirementChanged)
        #expect((compared.prefix + compared.added + compared.suffix).utf8.elementsEqual("head\ne\u{301}\ntail\n".utf8))
        #expect(model.originalDraft == "Synthetic unrelated original" && model.contextEditorRevision == editor && base.revision == 1)
        model.writeContext(id: "memo", kind: "note", text: draft, update: true, expected: base); await model.waitForOperation()
        #expect(model.lastError == .contextConflict)
        let fresh = try #require(model.humanContextRevisionBinding("memo")) // explicit Edit-equivalent capture
        model.writeContext(id: "memo", kind: "decision", text: "head\ne\u{301}\ntail\n", update: true, expected: fresh); await model.waitForOperation()
        #expect(model.history?.history.count == 3 && model.humanComparison == nil)
        model.retireContext("memo"); await model.waitForOperation()
        #expect(model.history?.history.last?.retired == true)
        let retired = try #require(model.humanContextRevisionBinding("memo"))
        model.writeContext(id: "memo", kind: "decision", text: "head\ne\u{301}\ntail\n", update: true, expected: retired); await model.waitForOperation()
        #expect(model.history?.history.count == 5 && model.history?.history.last?.retired == false)
        let history = try #require(model.history), project = try #require(model.project)
        for (a, b) in [(2, 3), (3, 4), (4, 5), (5, 5)] {
            let request = try HumanComparisonRequest(project: project, history: history, from: a, to: b)
            guard case .humanComparison(let value) = try await peer.perform(.compareHumanContextBound(request)) else { throw ServiceError.invalid }
            #expect(!value.textChanged && !value.kindChanged)
            #expect(value.retirementChanged == ((a == 3 && b == 4) || (a == 4 && b == 5)))
        }
        #expect(await peer.unbound == 0)
        await model.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil), arguments: [false, true]) @MainActor
    func actualAdmissionRejectsSameIDReplacementAfterPrecheck(differentRoot: Bool) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let other = fixture.root.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
        try Data("Synthetic source".utf8).write(to: other.appendingPathComponent("a.rs"))
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "comparison-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic A context", update: false))
        let peer = ComparisonPeer(adapter)
        let selected = CompanionModel(service: peer, configured: true)
        selected.select("alpha"); await selected.waitForOperation(); selected.openContext("memo"); await selected.waitForOperation()
        selected.editPreparation(query: "q", original: "Synthetic A draft")
        let nonce = selected.project?.incarnation
        await peer.arm(root: differentRoot ? other.path : fixture.root.path)
        selected.openHumanComparison(); selected.compareHumanContext(); await selected.waitForOperation()
        #expect(await peer.rejected == 1)
        #expect(await peer.delivered == 0)
        #expect(await peer.unbound == 0)
        #expect(selected.lastError == .namespaceChanged && selected.humanComparison == nil && selected.history == nil)
        #expect(selected.project == nil && selected.originalDraft.isEmpty)
        guard case .project(let replacement) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        #expect(replacement.incarnation != nonce)
        await selected.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil)) @MainActor
    func sourceForgetPolicySnapshotAndMissingRootDoNotAffectHumanReadButContextForgetDoes() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let root = fixture.root.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try Data("Synthetic source".utf8).write(to: root.appendingPathComponent("a.rs"))
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "comparison-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", root.path, ["a.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic context", update: false))
        let peer = ComparisonPeer(adapter), model = CompanionModel(service: peer, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "q", original: "Synthetic original")
        let base = try #require(model.humanContextRevisionBinding("memo")), editor = model.contextEditorRevision
        model.openHumanComparison(); model.compareHumanContext(); await model.waitForOperation()
        #expect(model.humanComparison != nil)
        model.inspectForgottenSources(); await model.waitForOperation()
        model.requestSourceForget("a.rs")
        model.confirmSourceForget(try #require(model.pendingSourceForget)); await model.waitForOperation()
        #expect(model.humanComparison != nil && model.humanContextRevisionBinding("memo") == base)
        #expect(model.contextEditorRevision == editor && model.originalDraft == "Synthetic original")
        _ = try await adapter.perform(.index("alpha")) // peer changes snapshot with zero approved sources
        try FileManager.default.removeItem(at: root)
        model.compareHumanContext(); await model.waitForOperation()
        #expect(model.humanComparison != nil && model.history?.history.count == 1)
        #expect(await peer.sourceCalls == 0)
        #expect(await peer.unbound == 0)
        model.requestForget(); model.confirmForget(try #require(model.pendingForget)); await model.waitForOperation()
        #expect(model.humanComparison == nil && model.history == nil)
        // An old real binding also cannot resurrect a forgotten note.
        let registered = Project(id: base.project, root: base.root, sources: [], rootIdentity: .string(base.rootIdentity), incarnation: base.incarnation)
        let oldRequest = try HumanComparisonRequest(project: registered, history: comparisonHistory(["Synthetic context"]), from: 1, to: 1)
        await #expect(throws: ServiceError.failed) { try await adapter.perform(.compareHumanContextBound(oldRequest)) }
        await #expect(throws: ServiceError.failed) { try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic context", update: false)) }
        await model.shutdown()
    }
}
