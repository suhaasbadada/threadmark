// TM-01–04/07/10; P2-A1/A6, P3-A4, P4-A2. Synthetic actual CLI/SQLite.
import Foundation
import Testing
@testable import CompanionKit

/// Mutate AFTER the model's Project A precheck, BEFORE the actual bound CLI
/// source query. Core's private before_sources test separately proves traversal
/// was never reached; this verifies native argv reaches that enforcement path.
private actor SourceReadPeer: CoreService {
    let adapter: ProcessService
    let replacementRoot: String
    let change: String
    let interceptBuild: Bool
    var boundCalls = 0
    var rejected = false
    var providerCalls = 0
    var capturedSnapshot: JSONValue?
    var unboundBuilds = 0
    init(_ adapter: ProcessService, replacementRoot: String, change: String, interceptBuild: Bool = false) {
        self.adapter = adapter; self.replacementRoot = replacementRoot; self.change = change; self.interceptBuild = interceptBuild
    }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        if case .refinePreview = operation { providerCalls += 1; throw ServiceError.invalid }
        let captured: Project?
        var build = false
        switch operation {
        case .queryBound(let p, _), .prepareContextBound(let p, _, _),
             .queryTermsBound(let p, _), .prepareContextTermsBound(let p, _, _): captured = p
        case .indexBound(let id, let root, let identity, let sources, let token):
            build = true
            captured = interceptBuild ? Project(id: id, root: root, sources: sources, rootIdentity: .string(identity), incarnation: token) : nil
        case .index(let id):
            build = true; unboundBuilds += 1
            if !interceptBuild { return try await adapter.perform(operation) }
            guard case .project(let p) = try await adapter.perform(.project(id)) else { throw ServiceError.invalid }
            captured = p
        default: captured = nil
        }
        if let p = captured, boundCalls == 0 {
            capturedSnapshot = p.snapshot
            boundCalls += 1
            if change == "policy" { _ = try await adapter.perform(.setSources(p.id, [])) }
            else if change == "snapshot" {
                try Data("// synthetic changed SQL snapshot\n".utf8).write(to: URL(fileURLWithPath: p.root).appendingPathComponent("a.rs"))
                if !build { _ = try await adapter.perform(.index(p.id)) }
            } else {
                guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
                _ = try await adapter.perform(.removeProject(p.id, p.root, identity, token))
                _ = try await adapter.perform(.addProject(p.id, change == "same-root" ? p.root : replacementRoot, p.sources))
                if !build { _ = try await adapter.perform(.index(p.id)) }
            }
            do { return try await adapter.perform(operation) }
            catch { rejected = true; throw error }
        }
        return try await adapter.perform(operation)
    }
}

private actor LegacySourceCore: CoreService {
    var sourceReads = 0
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        switch operation {
        case .project(let id): return .project(Project(id: id, root: "/synthetic/legacy", sources: ["a.rs"], rootIdentity: .string("r1")))
        case .contexts(let id): return .contexts(ContextList(project: id, contexts: []))
        case .query, .queryBound, .prepareContext, .prepareContextBound, .refinePreview, .index, .indexBound:
            sourceReads += 1; throw ServiceError.invalid
        default: throw ServiceError.unavailable
        }
    }
}

@Suite("Cached native source reads bind before core traversal")
struct BoundSourceReadTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: ["same-root", "different-root", "policy"])
    @MainActor func manualBuildCannotPublishIntoReplacementRegistration(change: String) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let other = fixture.root.appendingPathComponent("replacement")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
        try Data("// synthetic replacement not authorized by old Build\n".utf8).write(to: other.appendingPathComponent("a.rs"))
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary),
            dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "bound-build-store"))
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic retained human history", update: false))
        let peer = SourceReadPeer(adapter, replacementRoot: other.path, change: change, interceptBuild: true)
        let model = CompanionModel(service: peer, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "synthetic", original: "Synthetic original; do NOT send")
        let editor = model.contextEditorRevision
        model.build(); await model.waitForOperation()
        let calls = await peer.boundCalls, unbound = await peer.unboundBuilds, rejected = await peer.rejected
        #expect(calls == 1 && unbound == 0 && rejected)
        #expect(model.indexReport == nil && model.sourceRequiresRefresh)
        guard case .project(let current) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        #expect(current.snapshot == nil) // Old unbound Build would index replacement B.
        if change == "policy" {
            #expect(model.lastError == .readRequiresRefresh && model.project != nil)
            #expect(model.originalDraft == "Synthetic original; do NOT send")
            #expect(model.contextEditorRevision == editor && model.history?.history.last?.text == "Synthetic retained human history")
        } else {
            #expect(model.lastError == .namespaceChanged && model.project == nil && model.originalDraft.isEmpty)
        }
        await model.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil), arguments: ["same-root", "policy", "snapshot"])
    @MainActor func automaticPostIndexQueryBindsActualFreshSnapshot(change: String) async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "automatic-bound-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.index("alpha"))
        let peer = SourceReadPeer(adapter, replacementRoot: fixture.root.path, change: change)
        let driver = ManualRefreshDriver()
        let model = CompanionModel(service: peer, configured: true, refreshDriver: driver)
        model.select("alpha"); await model.waitForOperation()
        let oldSnapshot = model.project?.snapshot
        model.editPreparation(query: "synthetic", original: "Synthetic automatic unsaved original")
        model.enableAutomaticRefresh(try #require(model.automaticRefreshProposal))
        try Data("// synthetic changed BEFORE authorized automatic index\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
        driver.fire(); await model.waitForOperation()
        let snapshot = await peer.capturedSnapshot, calls = await peer.boundCalls, rejected = await peer.rejected
        #expect(snapshot != nil && snapshot != oldSnapshot && calls == 1 && rejected)
        #expect(model.automaticRefreshConsent == nil && !driver.active && !model.busy && model.indexReport == nil)
        if change == "same-root" { #expect(model.project == nil && model.lastError == .namespaceChanged) }
        else { #expect(model.sourceRequiresRefresh && model.lastError == .readRequiresRefresh && model.originalDraft == "Synthetic automatic unsaved original") }
        await model.shutdown()
    }
    @Test(arguments: ["query", "context", "refine", "build"])
    @MainActor func legacyScopeRequiresRefreshWithoutUnboundFallback(operation: String) async throws {
        let service = LegacySourceCore()
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.editPreparation(query: "synthetic", original: "Synthetic legacy unsaved original")
        switch operation {
        case "query": model.query("synthetic")
        case "context": model.prepareContext()
        case "build": model.build()
        default: model.requestRefinement(settings: try refinementSettings())
        }
        await model.waitForOperation()
        #expect(await service.sourceReads == 0)
        #expect(model.lastError == .readRequiresRefresh && model.sourceRequiresRefresh)
        #expect(model.originalDraft == "Synthetic legacy unsaved original" && model.project != nil)
        #expect(model.automaticRefreshProposal == nil && model.pendingRefinement == nil)
        await model.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: ["query", "context", "refine", "ranked-query", "ranked-context"], ["same-root", "different-root", "policy", "snapshot"])
    @MainActor func actualCLIRejectsReplacementBetweenPrecheckAndSelection(operation: String, change: String) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let other = fixture.root.appendingPathComponent("replacement")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
        try Data("// synthetic B content must never appear\n".utf8).write(to: other.appendingPathComponent("a.rs"))
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "bound-read-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.index("alpha"))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic retained human history", update: false))
        let peer = SourceReadPeer(adapter, replacementRoot: other.path, change: change)
        let model = CompanionModel(service: peer, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "synthetic", original: "Synthetic unsaved original; do not send")
        let editor = model.contextEditorRevision
        if operation.hasPrefix("ranked-") { model.setSourceRetrievalMode(.rankedTerms) }
        switch operation {
        case "query", "ranked-query": model.query("synthetic")
        case "context", "ranked-context": model.prepareContext()
        default: model.requestRefinement(settings: try refinementSettings())
        }
        await model.waitForOperation()
        let calls = await peer.boundCalls, rejected = await peer.rejected, providers = await peer.providerCalls
        #expect(calls == 1 && rejected && providers == 0)
        #expect(model.evidence == nil && model.preview == nil && model.pendingRefinement == nil && model.refinementPreview == nil)
        if change == "policy" || change == "snapshot" {
            #expect(model.lastError == .readRequiresRefresh && model.sourceRequiresRefresh)
            #expect(model.originalDraft == "Synthetic unsaved original; do not send")
            #expect(model.contextEditorRevision == editor && model.history?.history.last?.text == "Synthetic retained human history")
            #expect(!model.canPrepareContext)
        } else {
            #expect(model.lastError == .namespaceChanged && model.project == nil)
            #expect(model.originalDraft.isEmpty && model.contextEditorRevision != editor && model.history == nil)
        }
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func actualSourceEditAndUnindexedContextDoNotBecomeNamespaceMismatch() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "unindexed-store")
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await service.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.editPreparation(query: "synthetic", original: "Synthetic preserve intent")
        model.prepareContext(); await model.waitForOperation()
        #expect(model.preview?.state == "needs-input" && model.lastError == nil)
        model.build(); await model.waitForOperation()
        try Data("// synthetic edited after index\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
        model.query("synthetic"); await model.waitForOperation()
        #expect(model.evidence?.currentness == "stale-or-unindexed" && model.evidence?.results.isEmpty == true)
        #expect(model.lastError == nil && !model.sourceRequiresRefresh && model.originalDraft == "Synthetic preserve intent")
        await model.shutdown()
    }
}
