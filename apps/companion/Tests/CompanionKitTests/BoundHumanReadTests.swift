// TM-01–04/07/10; partial P2-A1/A3/A6, P3-A4. Synthetic local CLI only.
import Foundation
import Testing
@testable import CompanionKit

/// Replaces registration precisely at bound dispatch, after model metadata
/// prechecks. The actual CLI must reject, not return B for UI to discard.
private actor HumanReadPeer: CoreService {
    let adapter: ProcessService
    var replacementRoot: String?
    var armed: String?
    var rejected = 0
    var delivered = 0
    var unbound = 0
    init(_ adapter: ProcessService) { self.adapter = adapter }
    func arm(_ kind: String, root: String) { armed = kind; replacementRoot = root }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        let kind: String
        let binding: HumanContextReadBinding
        switch operation {
        case .contexts, .context, .searchHumanContext:
            unbound += 1; throw ServiceError.invalid
        case .contextsBound(let b): kind = "list"; binding = b
        case .contextBound(let b, _): kind = "history"; binding = b
        case .searchHumanContextBound(let b, _): kind = "search"; binding = b
        default: return try await adapter.perform(operation)
        }
        let replacing = armed == kind
        if replacing {
            armed = nil
            _ = try await adapter.perform(.removeProject(binding.project, binding.root, binding.rootIdentity, binding.incarnation))
            _ = try await adapter.perform(.addProject(binding.project, replacementRoot!, ["a.rs"]))
            _ = try await adapter.perform(.writeContext(binding.project, "memo", "note", "Synthetic namespace B needle", update: false))
        }
        do {
            let reply = try await adapter.perform(operation)
            if replacing { delivered += 1 }
            return reply
        } catch {
            if replacing, error as? ServiceError == .failed { rejected += 1 }
            throw error
        }
    }
}

private actor HumanReadFailureCore: CoreService {
    let project: Project
    var calls = 0
    var reads = 0
    var unbound = 0
    var failReads = false
    init(legacy: Bool = false) {
        project = Project(id: "alpha", root: "/synthetic/alpha", sources: [], rootIdentity: .string("r1"), incarnation: legacy ? nil : String(repeating: "a", count: 32))
    }
    func fail() { failReads = true }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        calls += 1
        switch operation {
        case .project: return .project(project)
        case .contexts, .context, .searchHumanContext:
            unbound += 1; throw ServiceError.invalid
        case .contextsBound(let b):
            reads += 1; try b.validate()
            if failReads { throw ServiceError.failed }
            return .contexts(ContextList(project: b.project, contexts: []))
        case .contextBound(let b, let id):
            reads += 1; try b.validate()
            if failReads { throw ServiceError.failed }
            return .context(ContextHistory(project: b.project, id: id, producer: "human-authored", authority: .string("human-declared"), history: [ContextRevision(revision: 1, kind: "note", text: "Synthetic retained history", retired: false)]))
        default: throw ServiceError.invalid
        }
    }
}

@Suite("Registration-bound native human reads")
struct BoundHumanReadTests {
    @Test @MainActor func legacySelectionIsMetadataOnlyAndTargetedReadsHaveNoIO() async {
        let service = HumanReadFailureCore(legacy: true)
        let model = CompanionModel(service: service, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation()
        #expect(await service.calls == 1)
        #expect(await service.reads == 0)
        model.openContext("memo"); await model.waitForOperation()
        #expect(model.lastError == .humanReadRequiresRefresh)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(await service.calls == 1)
        #expect(await service.reads == 0)
        #expect(await service.unbound == 0)
        #expect(model.history == nil && model.humanSearch == nil)
        await model.shutdown()
    }
    @Test @MainActor func sameNamespaceReadAndRefreshFailuresKeepEditorBaseAndHistory() async throws {
        let service = HumanReadFailureCore()
        let model = CompanionModel(service: service, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "q", original: "Synthetic unsaved original")
        let base = try #require(model.humanContextRevisionBinding("memo")), editor = model.contextEditorRevision
        await service.fail()
        model.openContext("memo"); await model.waitForOperation()
        #expect(model.lastError == .failed && model.history?.history.count == 1)
        model.refreshSelected(); await model.waitForOperation()
        #expect(model.lastError == .failed && model.history?.history.count == 1)
        #expect(model.humanContextRevisionBinding("memo") == base && model.contextEditorRevision == editor)
        #expect(model.originalDraft == "Synthetic unsaved original" && model.project != nil)
        #expect(await service.unbound == 0)
        await model.shutdown()
    }
    @Test func exactBytesAndLegacyValidation() throws {
        let token = String(repeating: "a", count: 32)
        let a = Project(id: "alpha", root: "/synthetic/é", sources: [], rootIdentity: .string("é"), incarnation: token)
        let b = Project(id: "alpha", root: "/synthetic/e\u{301}", sources: ["a.rs"], rootIdentity: .string("e\u{301}"), incarnation: token)
        #expect(a.root == b.root) // Swift equality alone is insufficient.
        #expect(try HumanContextReadBinding(project: a) != HumanContextReadBinding(project: b))
        #expect(throws: ServiceError.invalid) { try HumanContextReadBinding(project: Project(id: "alpha", root: a.root, sources: [], rootIdentity: a.root_identity)) }
        #expect(throws: ServiceError.invalid) { try HumanContextReadBinding(project: Project(id: "alpha", root: a.root, sources: [], rootIdentity: .number(1), incarnation: token)) }
        let changedPolicy = Project(id: a.id, root: a.root, sources: ["missing.rs"], snapshot: .string("different"), rootIdentity: a.root_identity, incarnation: token)
        #expect(try HumanContextReadBinding(project: a) == HumanContextReadBinding(project: changedPolicy))
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil,
                  "Requires explicitly rebuilt CLI"), arguments: ["list", "history", "search", "mutation-list", "mutation-history"], [false, true])
    @MainActor func replacementAtDispatchRejectedByCore(kind: String, differentRoot: Bool) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let other = fixture.root.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
        try Data("Synthetic source".utf8).write(to: other.appendingPathComponent("a.rs"))
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "bound-human-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic namespace A needle", update: false))
        let peer = HumanReadPeer(adapter)
        let model = CompanionModel(service: peer, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        #expect(model.history?.history.last?.text == "Synthetic namespace A needle")
        let oldToken = try #require(model.project?.incarnation)
        await peer.arm(kind.replacingOccurrences(of: "mutation-", with: ""), root: differentRoot ? other.path : fixture.root.path)
        switch kind {
        case "list": model.refreshSelected()
        case "history": model.openContext("memo")
        case "search": model.searchHumanContext("needle")
        default: model.writeContext(id: "memo", kind: "note", text: "Synthetic fresh CAS", update: true, expected: model.humanContextRevisionBinding("memo"))
        }
        await model.waitForOperation()
        #expect(await peer.rejected == 1)
        #expect(await peer.delivered == 0)
        #expect(await peer.unbound == 0)
        #expect(model.project == nil && model.history == nil && model.humanSearch == nil && model.lastError == .namespaceChanged)
        guard case .project(let current) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        #expect(current.incarnation != oldToken)
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil,
                  "Requires explicitly rebuilt CLI"))
    @MainActor func policyOnlyChangeDoesNotBindHumanHistoryToSourceFiles() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "human-policy-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        let peer = HumanReadPeer(adapter)
        let model = CompanionModel(service: peer, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation()
        model.writeContext(id: "memo", kind: "note", text: "Synthetic first needle", update: false); await model.waitForOperation()
        #expect(model.history?.history.count == 1)
        let base = try #require(model.humanContextRevisionBinding("memo"))
        _ = try await adapter.perform(.setSources("alpha", []))
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("a.rs"))
        model.openContext("memo"); await model.waitForOperation()
        #expect(model.history?.history.count == 1 && model.humanContextRevisionBinding("memo") == base)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch?.results.map(\.id) == ["memo"])
        #expect(model.history?.history.count == 1)
        model.writeContext(id: "memo", kind: "decision", text: "Synthetic next needle", update: true, expected: base); await model.waitForOperation()
        #expect(model.history?.history.count == 2 && model.lastError == nil)
        model.retireContext("memo"); await model.waitForOperation()
        #expect(model.history?.history.last?.retired == true)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch?.results.isEmpty == true)
        model.refreshSelected(); await model.waitForOperation()
        #expect(model.contexts.first?.revision == 3)
        model.openContext("memo"); await model.waitForOperation()
        model.requestForget()
        model.confirmForget(try #require(model.pendingForget)); await model.waitForOperation()
        #expect(model.lastError == nil && model.contexts.isEmpty && !model.forgetRequiresRefresh)
        #expect(model.forgottenMarkers?.forgotten.map(\.id) == ["memo"])
        #expect(await peer.unbound == 0)
        await model.shutdown()
    }
}
