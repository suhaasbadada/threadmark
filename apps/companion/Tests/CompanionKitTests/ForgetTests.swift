// TM-01–04/07/10; partial P2-A3/A5, P3-A4. Synthetic, no GUI or user data.
import Foundation
import Testing
@testable import CompanionKit

private let syntheticIncarnation = "0123456789abcdef0123456789abcdef"
private actor ForgetCore: CoreService {
    var revision = 2
    var mode = "valid"
    var calls = 0
    var forgetCalls = 0
    var deleted = false
    var projectReadsAfterForget = 0
    var hold = false
    var waiter: CheckedContinuation<Void, Never>?
    var pending: CheckedContinuation<Reply, any Error>?
    var indexStarted = false
    var holdIndex = false
    var indexWaiter: CheckedContinuation<Void, Never>?
    var indexPending: CheckedContinuation<Reply, any Error>?
    var events: [String] = []
    func waitUntilIndex() async {
        if indexStarted { return }
        await withCheckedContinuation { indexWaiter = $0 }
    }
    func releaseIndex() {
        events.append("index-finished")
        indexPending?.resume(returning: .indexed(IndexReport(project: "alpha", snapshot: .string("s1"), files: 1, anchors: 1, coverage: .string("lexical"), empty: false)))
        indexPending = nil
    }
    func setMode(_ value: String) { mode = value }
    func edit() { revision += 1 }
    func holdReceipt() { hold = true }
    func holdNextIndex() { holdIndex = true }
    func waitUntilForget() async {
        if forgetCalls > 0 { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func release() { pending?.resume(returning: receipt()); pending = nil }
    func receipt() -> Reply {
        .forgotten(ForgottenContext(project: mode == "project" ? "beta" : "alpha",
            id: mode == "id" ? "other" : "memo", forgotten: mode != "false",
            removed_revisions: mode == "count" ? 1 : 2,
            retention_limits: mode == "limits" ? "erased forever" : ForgottenContext.retentionLimits))
    }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        calls += 1
        switch operation {
        case .indexBound:
            if holdIndex {
                holdIndex = false
                events.append("index-started"); indexStarted = true; indexWaiter?.resume(); indexWaiter = nil
                return try await withCheckedThrowingContinuation { indexPending = $0 }
            }
            return .indexed(IndexReport(project: "alpha", snapshot: .string("s1"), files: 1, anchors: 1, coverage: .string("lexical"), empty: false))
        case .project(let id):
            if forgetCalls > 0 { projectReadsAfterForget += 1 }
            let replace = mode == "replace-before" && projectReadsAfterForget == 1 ||
                mode == "replace-after" && projectReadsAfterForget == 2
            return .project(Project(id: id, root: "/synthetic/alpha", sources: ["a.rs"], rootIdentity: .string("r1"),
                incarnation: mode == "legacy" ? nil : (replace ? String(repeating: "f", count: 32) : syntheticIncarnation)))
        case .contextsBound(let b):
            let id = b.project
            let entries = deleted && mode != "still-present" ? [] : [ContextEntry(id: "memo", revision: revision,
                kind: "note", retired: false, producer: "human-authored", authority: .string("human-declared"))]
            return .contexts(ContextList(project: id, contexts: entries))
        case .contextBound(let b, let context):
            let id = b.project
            return .context(ContextHistory(project: id, id: context, producer: "human-authored", authority: .string("human-declared"),
                history: (1...revision).map { ContextRevision(revision: $0, kind: "note", text: "Synthetic human revision \($0)", retired: false) }))
        case .forgottenContextsBound(let binding):
            try binding.validate()
            let id = binding.project
            if mode == "followup-failure" { throw ServiceError.failed }
            return .forgottenContexts(ForgottenContexts(project: mode == "marker-project" ? "beta" : id,
                forgotten: mode == "marker-missing" ? [] : [.init(id: mode == "marker-invalid" ? "../bad" : "memo")]))
        case .forgetContext(let id, let context, let root, let identity, let token, let expected):
            events.append("forget-started")
            forgetCalls += 1; waiter?.resume(); waiter = nil
            guard id == "alpha", context == "memo", root == "/synthetic/alpha", identity == "r1",
                  token == syntheticIncarnation, expected == revision else { throw ServiceError.scopeMismatch }
            deleted = true
            if hold { return try await withCheckedThrowingContinuation { pending = $0 } }
            if mode == "ack" { return .acknowledged }
            if mode == "failure" { throw ServiceError.failed }
            return receipt()
        default: throw ServiceError.unavailable
        }
    }
}

@Suite("Native human Forget exact approval")
@MainActor struct ForgetTests {
    private func loaded(_ service: ForgetCore) async -> CompanionModel {
        let model = CompanionModel(service: service, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "synthetic", original: "Unrelated original request")
        // Loading history after a request edit is intentional: request edits invalidate prior approvals.
        model.openContext("memo"); await model.waitForOperation()
        return model
    }
    @Test func promptCancelHasNoOperationsOrEditorDraftLoss() async throws {
        let service = ForgetCore(), model = await loaded(service)
        let calls = await service.calls, editor = model.contextEditorRevision
        model.requestForget(); let prompt = try #require(model.pendingForget)
        #expect(prompt.revision == 2 && prompt.contextID == "memo")
        model.cancelForget(); model.confirmForget(prompt)
        #expect(await service.calls == calls)
        #expect(model.contextEditorRevision == editor && model.history != nil)
        #expect(model.originalDraft == "Unrelated original request")
    }
    @Test func confirmedSingleUseClearsOnlyHumanEditorAndProvesSuppression() async throws {
        let service = ForgetCore(), model = await loaded(service)
        model.requestForget(); let prompt = try #require(model.pendingForget)
        model.confirmForget(prompt); model.confirmForget(prompt)
        #expect(model.history == nil && model.contexts.isEmpty && model.forgottenMarkers == nil)
        #expect(model.contextEditorRevision == 2 && model.originalDraft == "Unrelated original request")
        await model.waitForOperation()
        #expect(await service.forgetCalls == 1)
        #expect(model.lastError == nil && !model.forgetRequiresRefresh)
        #expect(model.forgottenMarkers?.forgotten.map(\.id) == ["memo"])
        #expect(model.status.contains("suppression confirmed"))
    }
    @Test(arguments: ["editor", "request", "context", "project", "config", "sources", "refresh", "build", "cancel", "pause", "removal", "quit"])
    func stalePromptCannotDispatch(event: String) async throws {
        let service = ForgetCore(), model = await loaded(service)
        model.requestForget(); let prompt = try #require(model.pendingForget)
        switch event {
        case "editor": model.contextEditorChanged()
        case "request": model.editPreparation(query: "new", original: "unchanged")
        case "context": model.openContext("other")
        case "project": model.select("beta")
        case "config": model.configure(executable: URL(fileURLWithPath: "/synthetic/no-core"), dataDirectory: URL(fileURLWithPath: "/synthetic/no-store"))
        case "sources": model.stageSources([])
        case "refresh": model.refreshSelected()
        case "build": model.build()
        case "cancel": model.cancel()
        case "pause": model.togglePause()
        case "removal": model.requestRemoval()
        default: model.quit()
        }
        model.confirmForget(prompt); await model.waitForOperation()
        #expect(await service.forgetCalls == 0)
        #expect(model.contextEditorRevision == (["project", "config", "refresh"].contains(event) ? 2 : 1) && model.pendingForget == nil)
    }
    @Test(arguments: ["ack", "project", "id", "false", "count", "limits", "still-present", "marker-missing", "marker-project", "marker-invalid", "replace-before", "replace-after", "followup-failure", "failure"])
    func receiptAndAuthoritativeFollowupRequired(mode: String) async throws {
        let service = ForgetCore(), model = await loaded(service)
        await service.setMode(mode)
        model.requestForget(); model.confirmForget(try #require(model.pendingForget)); await model.waitForOperation()
        #expect(await service.forgetCalls == 1)
        #expect(model.lastError == .forgetUncertain && model.forgetRequiresRefresh)
        #expect(model.history == nil && model.contexts.isEmpty && model.forgottenMarkers == nil && model.preview == nil)
        #expect(model.originalDraft == "Unrelated original request" && model.status.contains("Requires Refresh"))
    }
    @Test func externalEditRejectsCapturedRevisionWithoutClaimingRollback() async throws {
        let service = ForgetCore(), model = await loaded(service)
        model.requestForget(); let prompt = try #require(model.pendingForget)
        await service.edit(); model.confirmForget(prompt); await model.waitForOperation()
        #expect(!(await service.deleted) && model.lastError == .forgetUncertain)
    }
    @Test func forgetPreemptsAutomaticWorkButJoinsItsTeardownBeforeDeletion() async throws {
        let service = ForgetCore(), driver = ManualRefreshDriver()
        let model = CompanionModel(service: service, configured: true, refreshDriver: driver)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        await service.holdNextIndex()
        model.enableAutomaticRefresh(try #require(model.automaticRefreshProposal))
        driver.fire(); await service.waitUntilIndex()
        model.requestForget(); let prompt = try #require(model.pendingForget)
        #expect(model.history != nil && !driver.active)
        model.confirmForget(prompt)
        #expect(await service.forgetCalls == 0)
        await service.releaseIndex(); await model.waitForOperation()
        #expect(await service.events == ["index-started", "index-finished", "forget-started"])
        #expect(model.lastError == nil && model.indexReport == nil && model.forgottenMarkers != nil)
        #expect(!driver.active && model.automaticRefreshConsent == nil)
    }
    @Test(arguments: [false, true]) func delayedCommittedReceiptAfterCancelOrScopeChangeIsNotApplied(switchProject: Bool) async throws {
        let service = ForgetCore(), model = await loaded(service)
        await service.holdReceipt()
        model.requestForget(); model.confirmForget(try #require(model.pendingForget))
        await service.waitUntilForget()
        if switchProject { model.select("beta") } else { model.cancel() }
        await service.release(); await model.waitForOperation()
        #expect(model.forgottenMarkers == nil && !model.status.contains("suppression confirmed"))
        #expect(await service.forgetCalls == 1)
        if !switchProject { #expect(model.forgetRequiresRefresh && model.status.contains("Requires Refresh")) }
    }
    @Test func legacyOnlyOffersExplicitUpgradeGuidance() async throws {
        let service = ForgetCore(); await service.setMode("legacy")
        let model = await loaded(service)
        model.refreshSelected(); await model.waitForOperation()
        #expect(!model.canForgetContext && model.status.contains("--confirm-legacy-workers-stopped"))
        model.requestForget(); #expect(model.pendingForget == nil)
        #expect(await service.forgetCalls == 0)
    }
    @Test func markerValidationRejectsBadIDsOrderDuplicatesAndCapacity() throws {
        for ids in [["../bad"], ["b", "a"], ["a", "a"], (0...4096).map { String(format: "id%04d", $0) }] {
            let markers = ForgottenContexts(project: "alpha", forgotten: ids.map { .init(id: $0) })
            #expect(throws: ServiceError.invalid) { try markers.validate(project: "alpha") }
        }
    }
}
