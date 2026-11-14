// Unit Y: TM-01–04/07/10; partial P2-A1/A3/A5/A6, P3-A4. Synthetic only.
import Foundation
import Testing
@testable import CompanionKit

private actor MarkerReadPeer: CoreService {
    let adapter: ProcessService
    var armed: String?
    var root = ""
    var rejected = 0, delivered = 0, unbound = 0, commits = 0
    var holdDomain: String?
    var heldReply: Reply?
    var pending: CheckedContinuation<Reply, any Error>?
    var observer: CheckedContinuation<Void, Never>?
    init(_ adapter: ProcessService) { self.adapter = adapter }
    func arm(_ domain: String, root: String) { armed = domain; self.root = root }
    func hold(_ domain: String) { holdDomain = domain }
    func waitForHeldRead() async { if heldReply == nil { await withCheckedContinuation { observer = $0 } } }
    func release() { if let heldReply { pending?.resume(returning: heldReply) }; pending = nil; heldReply = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        let domain: String, binding: HumanContextReadBinding
        switch operation {
        case .forgottenContexts, .forgottenSources: unbound += 1; throw ServiceError.invalid
        case .forgottenContextsBound(let b): domain = "context"; binding = b
        case .forgottenSourcesBound(let b): domain = "source"; binding = b
        default:
            let reply = try await adapter.perform(operation)
            if case .forgetContext = operation { commits += 1 }
            if case .forgetSource = operation { commits += 1 }
            return reply
        }
        let replacing = armed == domain
        if replacing {
            armed = nil
            _ = try await adapter.perform(.removeProject(binding.project, binding.root, binding.rootIdentity, binding.incarnation))
            _ = try await adapter.perform(.addProject(binding.project, root, ["b-private.rs"]))
            guard case .project(let p) = try await adapter.perform(.project(binding.project)),
                  case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
            _ = try await adapter.perform(.writeContext(p.id, "b-private-id", "note", "Synthetic B", update: false))
            _ = try await adapter.perform(.forgetContext(p.id, "b-private-id", p.root, identity, token, 1))
            _ = try await adapter.perform(.forgetSource(p.id, "b-private.rs", p.root, identity, token, p.sources))
        }
        do {
            let reply = try await adapter.perform(operation)
            if replacing { delivered += 1 }
            if holdDomain == domain {
                holdDomain = nil; heldReply = reply; observer?.resume(); observer = nil
                return try await withCheckedThrowingContinuation { pending = $0 }
            }
            return reply
        } catch {
            if replacing, error as? ServiceError == .failed { rejected += 1 }
            throw error
        }
    }
}

private actor MarkerReadFake: CoreService {
    var project: Project
    var mode = "valid", calls = 0, reads = 0, unbound = 0
    var pending: CheckedContinuation<Reply, any Error>?
    var observer: CheckedContinuation<Void, Never>?
    var started = false
    init(legacy: Bool = false, root: String = "/synthetic/alpha", identity: String = "r1") {
        project = Project(id: "alpha", root: root, sources: ["a.rs"], rootIdentity: .string(identity), incarnation: legacy ? nil : "0123456789abcdef0123456789abcdef")
    }
    func replaceMetadata(root: String, identity: String) { project = Project(id: project.id, root: root, sources: project.sources, rootIdentity: .string(identity), incarnation: project.incarnation) }
    func setMode(_ value: String) { mode = value }
    func waitForRead() async { if !started { await withCheckedContinuation { observer = $0 } } }
    func release() { pending?.resume(returning: .forgottenContexts(ForgottenContexts(project: "alpha", forgotten: []))); pending = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        calls += 1
        switch operation {
        case .project: return .project(project)
        case .contextsBound(let b):
            return .contexts(ContextList(project: b.project, contexts: [.init(id: "memo", revision: 1, kind: "note", retired: false, producer: "human-authored", authority: .string("human-declared"))]))
        case .contextBound(let b, let id):
            return .context(ContextHistory(project: b.project, id: id, producer: "human-authored", authority: .string("human-declared"), history: [.init(revision: 1, kind: "note", text: "Synthetic retained history", retired: false)]))
        case .forgottenContexts, .forgottenSources: unbound += 1; throw ServiceError.invalid
        case .forgottenContextsBound(let b), .forgottenSourcesBound(let b):
            try b.validate(); reads += 1; started = true; observer?.resume(); observer = nil
            if mode == "hold" { return try await withCheckedThrowingContinuation { pending = $0 } }
            if mode == "fail" { throw ServiceError.failed }
            if case .forgottenSourcesBound = operation { return .forgottenSources(ForgottenSources(project: b.project, forgotten: [])) }
            return .forgottenContexts(ForgottenContexts(project: b.project, forgotten: []))
        default: throw ServiceError.invalid
        }
    }
}

@Suite("Registration-bound native suppression reads")
struct BoundMarkerReadTests {
    @Test @MainActor func legacyBothInspectionsHaveNoIOOrFallbackAndExplainUpgrade() async {
        let service = MarkerReadFake(legacy: true)
        let model = CompanionModel(service: service, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation()
        let calls = await service.calls
        model.inspectForgottenContexts(); await model.waitForOperation()
        #expect(model.lastError == .humanReadRequiresRefresh && model.status.contains("--confirm-legacy-workers-stopped"))
        model.inspectForgottenSources(); await model.waitForOperation()
        #expect(model.lastError == .sourceInspectionUnavailable && model.status.contains("--to-version 4"))
        #expect(await service.calls == calls)
        #expect(await service.reads == 0)
        #expect(await service.unbound == 0)
        await model.shutdown()
    }

    @Test(arguments: ["context", "source"], [false, true])
    @MainActor func readFailureAndCancelKeepHistoryEditorBaseAndOriginal(domain: String, cancel: Bool) async throws {
        let service = MarkerReadFake()
        let model = CompanionModel(service: service, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "needle", original: "Synthetic unsaved original")
        let text = model.history?.history.first?.text, base = model.humanContextRevisionBinding("memo"), editor = model.contextEditorRevision
        await service.setMode(cancel ? "hold" : "fail")
        if domain == "source" { model.inspectForgottenSources() } else { model.inspectForgottenContexts() }
        if cancel { await service.waitForRead(); model.cancel(); await service.release() }
        await model.waitForOperation()
        #expect(model.history?.history.first?.text == text && model.humanContextRevisionBinding("memo") == base && model.contextEditorRevision == editor)
        #expect(model.originalDraft == "Synthetic unsaved original" && model.project != nil)
        #expect(model.sourceMarkers == nil && model.forgottenMarkers == nil && !model.status.contains("markers verified"))
        #expect(await service.unbound == 0)
        #expect(await service.reads == 1)
        await model.shutdown()
    }

    @Test(arguments: ["context", "source"], ["root", "identity"])
    @MainActor func markerInspectionPrechecksCompareExactUnicodeBytesWithoutDispatch(domain: String, field: String) async {
        let service = MarkerReadFake(root: "/synthetic/é", identity: "identity-é")
        let model = CompanionModel(service: service, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "needle", original: "Synthetic unsaved original")
        let base = model.humanContextRevisionBinding("memo"), editor = model.contextEditorRevision
        await service.replaceMetadata(root: field == "root" ? "/synthetic/e\u{301}" : "/synthetic/é", identity: field == "identity" ? "identity-e\u{301}" : "identity-é")
        if domain == "source" { model.inspectForgottenSources() } else { model.inspectForgottenContexts() }
        await model.waitForOperation()
        #expect(await service.reads == 0)
        #expect(await service.unbound == 0)
        #expect(model.history?.history.first?.text == "Synthetic retained history" && model.humanContextRevisionBinding("memo") == base)
        #expect(model.contextEditorRevision == editor && model.originalDraft == "Synthetic unsaved original")
        #expect(model.sourceMarkers == nil && model.forgottenMarkers == nil)
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil, "Requires explicitly rebuilt CLI"),
          arguments: ["context", "source", "context-followup", "source-followup"], [false, true])
    @MainActor func replacementAtMarkerDispatchAfterPrecheckRejectsWithoutBMetadata(kind: String, differentRoot: Bool) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let other = fixture.root.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
        for root in [fixture.root, other] {
            try Data("Synthetic source".utf8).write(to: root.appendingPathComponent("a.rs"))
            try Data("Synthetic B source".utf8).write(to: root.appendingPathComponent("b-private.rs"))
        }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "bound-marker-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic namespace A", update: false))
        let peer = MarkerReadPeer(adapter), model = CompanionModel(service: peer, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "needle", original: "Synthetic unsaved original")
        if kind == "source-followup" { model.inspectForgottenSources(); await model.waitForOperation() }
        let base = model.humanContextRevisionBinding("memo"), editor = model.contextEditorRevision
        await peer.arm(kind.hasPrefix("context") ? "context" : "source", root: differentRoot ? other.path : fixture.root.path)
        switch kind {
        case "context": model.inspectForgottenContexts()
        case "source": model.inspectForgottenSources()
        case "context-followup": model.requestForget(); model.confirmForget(try #require(model.pendingForget))
        default: model.requestSourceForget("a.rs"); model.confirmSourceForget(try #require(model.pendingSourceForget))
        }
        await model.waitForOperation()
        #expect(await peer.rejected == 1)
        #expect(await peer.delivered == 0)
        #expect(await peer.unbound == 0)
        #expect(model.sourceMarkers == nil && model.forgottenMarkers == nil && model.project != nil)
        #expect(model.originalDraft == "Synthetic unsaved original")
        if kind == "context-followup" {
            #expect(model.forgetRequiresRefresh && model.lastError == .forgetUncertain && model.history == nil)
            #expect(model.status.contains("may already be removed"))
            #expect(await peer.commits == 1)
        } else {
            #expect(model.history?.history.first?.text == "Synthetic namespace A" && model.contextEditorRevision == editor && model.humanContextRevisionBinding("memo") == base)
            if kind == "source-followup" {
                #expect(model.sourceRequiresRefresh && model.lastError == .sourceForgetUncertain && model.status.contains("may already be revoked"))
                #expect(await peer.commits == 1)
            }
        }
        // B really has markers, but none were delivered by the cached read.
        guard case .forgottenContexts(let ids) = try await adapter.perform(.forgottenContexts("alpha")),
              case .forgottenSources(let paths) = try await adapter.perform(.forgottenSources("alpha")) else { throw ServiceError.invalid }
        #expect(ids.forgotten.map(\.id) == ["b-private-id"] && paths.forgotten.map(\.path) == ["b-private.rs"])
        await model.shutdown()
    }

    @Test(arguments: ["context", "source"])
    @MainActor func realCliPolicyOnlyChangeAndMissingSourceDoNotInvalidateMarkerBinding(domain: String) async throws {
        guard let binary = ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] else { return }
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "marker-policy-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        guard case .project(let p) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        let binding = try HumanContextReadBinding(project: p)
        _ = try await adapter.perform(.setSources("alpha", []))
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("a.rs"))
        let operation: CompanionKit.Operation = domain == "source" ? .forgottenSourcesBound(binding) : .forgottenContextsBound(binding)
        _ = try await adapter.perform(operation)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil, "Requires explicitly rebuilt CLI"), arguments: ["context", "source"])
    @MainActor func canceledPostCommitMarkerReadNeverClaimsRollbackOrAdoptsLateProof(domain: String) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "marker-cancel-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic retained history", update: false))
        let peer = MarkerReadPeer(adapter), model = CompanionModel(service: peer, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "needle", original: "Synthetic unsaved original")
        if domain == "source" { model.inspectForgottenSources(); await model.waitForOperation() }
        let editor = model.contextEditorRevision, base = model.humanContextRevisionBinding("memo")
        await peer.hold(domain)
        if domain == "source" { model.requestSourceForget("a.rs"); model.confirmSourceForget(try #require(model.pendingSourceForget)) }
        else { model.requestForget(); model.confirmForget(try #require(model.pendingForget)) }
        await peer.waitForHeldRead()
        #expect(await peer.commits == 1) // The operation already committed in the real CLI.
        model.cancel(); await peer.release(); await model.waitForOperation()
        #expect(model.forgottenMarkers == nil && model.sourceMarkers == nil && !model.status.contains("suppression confirmed"))
        #expect(model.originalDraft == "Synthetic unsaved original" && model.status.contains("Requires Refresh"))
        if domain == "source" {
            #expect(model.sourceRequiresRefresh && model.history?.history.first?.text == "Synthetic retained history")
            #expect(model.contextEditorRevision == editor && model.humanContextRevisionBinding("memo") == base)
        } else { #expect(model.forgetRequiresRefresh && model.history == nil && model.contextEditorRevision == editor + 1) }
        #expect(await peer.unbound == 0)
        await model.shutdown()
    }

    @Test(arguments: ["markers", "source-markers"])
    func exactBoundArgvEmptyStdinAndStrictDecoding(prefix: String) async throws {
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("opencode/bound-marker-fixture-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let b = try HumanContextReadBinding(project: Project(id: "alpha", root: "/synthetic/alpha", sources: [], rootIdentity: .string("r1"), incarnation: "0123456789abcdef0123456789abcdef"))
        let operation: CompanionKit.Operation = prefix == "markers" ? .forgottenContextsBound(b) : .forgottenSourcesBound(b)
        for mode in ["valid", "project", "bad", "duplicate", "order", "content", "extra", "over", "large"] {
            let directory = root.appendingPathComponent("bound-" + prefix + "-" + mode)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let adapter = ProcessService(executable: package.appendingPathComponent(".build/debug/CompanionTestProcess"), dataDirectory: directory)
            if mode == "valid" { _ = try await adapter.perform(operation) }
            else { await #expect(throws: (any Error).self) { try await adapter.perform(operation) } }
        }
    }
}
