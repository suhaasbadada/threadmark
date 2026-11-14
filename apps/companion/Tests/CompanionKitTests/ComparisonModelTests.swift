import Foundation
import Testing
@testable import CompanionKit

private actor ComparisonCore: CoreService {
    var project = comparisonProject
    var calls = 0, comparisons = 0, sources = 0
    var failure: ServiceError?
    var wrongPair = false
    var forgotten = false
    var hold = false
    var started = false
    var startWait: CheckedContinuation<Void, Never>?
    var releaseWait: CheckedContinuation<Void, Never>?
    var events: [String] = []
    func arm(_ failure: ServiceError? = nil, hold: Bool = false) { self.failure = failure; self.hold = hold; started = false }
    func replace() { project = Project(id: "alpha", root: "/synthetic/B", sources: [], rootIdentity: .string("r2"), incarnation: String(repeating: "b", count: 32)) }
    func returnWrongPair() { wrongPair = true }
    func waitForCompare() async { if !started { await withCheckedContinuation { startWait = $0 } } }
    func release() { releaseWait?.resume(); releaseWait = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        calls += 1
        switch operation {
        case .project: events.append("project"); return .project(project)
        case .contextsBound: return .contexts(ContextList(project: "alpha", contexts: []))
        case .contextBound(_, let id):
            events.append("history")
            if forgotten { throw ServiceError.failed }
            return .context(comparisonHistory(id: id))
        case .forgetContext(_, _, _, _, _, let revision):
            events.append("forget"); forgotten = true
            return .forgotten(ForgottenContext(project: "alpha", id: "memo", forgotten: true, removed_revisions: revision, retention_limits: ForgottenContext.retentionLimits))
        case .forgottenContextsBound:
            return .forgottenContexts(ForgottenContexts(project: "alpha", forgotten: forgotten ? [.init(id: "memo")] : []))
        case .updateContextRevisionBound:
            events.append("mutation"); throw ServiceError.timedOut
        case .compareHumanContextBound(let request):
            comparisons += 1; events.append("begin"); started = true; startWait?.resume(); startWait = nil
            if hold { hold = false; await withCheckedContinuation { releaseWait = $0 } }
            events.append("end")
            if let failure { throw failure }
            if wrongPair {
                let other = try HumanComparisonRequest(project: project, history: comparisonHistory(["Synthetic wrong", "Synthetic other"]), from: 1, to: 2)
                return .humanComparison(try HumanComparison.decode(comparisonFrame(other), request: other))
            }
            return .humanComparison(try HumanComparison.decode(comparisonFrame(request), request: request))
        default: sources += 1; throw ServiceError.invalid
        }
    }
}

@Suite("Owned explicit comparison lifecycle")
struct ComparisonModelTests {
    @Test @MainActor func onlyExplicitCompareDoesIOAndPreservesConflictAndDraftBase() async throws {
        let core = ComparisonCore()
        let selected = CompanionModel(service: core, configured: true)
        selected.select("alpha"); await selected.waitForOperation()
        selected.openContext("memo"); await selected.waitForOperation()
        selected.editPreparation(query: "q", original: "Synthetic original draft")
        let base = try #require(selected.humanContextRevisionBinding("memo")), editor = selected.contextEditorRevision
        selected.writeContext(id: "memo", kind: "note", text: "Synthetic unsaved draft", update: true)
        #expect(selected.lastError == .contextConflict)
        let calls = await core.calls
        selected.openHumanComparison(); selected.chooseHumanComparison(from: 2, to: 1)
        #expect(!selected.canCompareHumanContext)
        selected.compareHumanContext()
        selected.chooseHumanComparison(from: 1, to: 99)
        #expect(selected.comparisonTo == 1)
        selected.chooseHumanComparison(from: 1, to: 2)
        #expect(await core.calls == calls)
        selected.compareHumanContext(); await selected.waitForOperation()
        #expect(await core.comparisons == 1)
        #expect(await core.sources == 0)
        #expect(selected.humanComparison?.removed == "old\r\n")
        #expect(selected.lastError == .contextConflict && selected.status == ServiceError.contextConflict.localizedDescription)
        #expect(selected.humanContextRevisionBinding("memo") == base && selected.contextEditorRevision == editor)
        #expect(selected.originalDraft == "Synthetic original draft" && selected.history?.history.count == 2)
        selected.cancelHumanComparison()
        #expect(selected.humanComparison == nil && selected.history?.history.count == 2)
        #expect(selected.humanContextRevisionBinding("memo") == base && selected.contextEditorRevision == editor)
        await selected.shutdown()
    }
    @Test(arguments: [ServiceError.failed, .timedOut, .invalid]) @MainActor
    func sameNamespaceFailuresRetainHumanState(failure: ServiceError) async throws {
        let core = ComparisonCore()
        let selected = CompanionModel(service: core, configured: true)
        selected.select("alpha"); await selected.waitForOperation(); selected.openContext("memo"); await selected.waitForOperation()
        selected.editPreparation(query: "q", original: "Synthetic request")
        let base = try #require(selected.humanContextRevisionBinding("memo")), editor = selected.contextEditorRevision
        selected.writeContext(id: "memo", kind: "note", text: "Synthetic draft", update: true)
        await core.arm(failure)
        selected.openHumanComparison(); selected.compareHumanContext(); await selected.waitForOperation()
        #expect(selected.humanComparison == nil && selected.comparisonStatus == failure.localizedDescription)
        #expect(selected.history?.history.count == 2 && selected.humanContextRevisionBinding("memo") == base)
        #expect(selected.lastError == .contextConflict && selected.contextEditorRevision == editor && selected.originalDraft == "Synthetic request")
        await selected.shutdown()
    }
    @Test(arguments: ["cancel", "choice", "history", "note", "config", "quit", "successor", "forget", "mutation"]) @MainActor
    func staleCallbacksAreDroppedAndSuccessorsJoin(action: String) async throws {
        let core = ComparisonCore()
        let model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "q", original: "Synthetic original")
        let base = model.humanContextRevisionBinding("memo"), editor = model.contextEditorRevision
        await core.arm(hold: true)
        model.openHumanComparison(); model.compareHumanContext(); await core.waitForCompare()
        switch action {
        case "cancel": model.cancelHumanComparison()
        case "choice": model.chooseHumanComparison(from: 1, to: 1)
        case "history": model.openContext("memo")
        case "note": model.openContext("other")
        case "config": model.configure(executable: URL(fileURLWithPath: "/synthetic/unavailable"), dataDirectory: URL(fileURLWithPath: "/synthetic/store"))
        case "quit": model.quit()
        case "forget":
            model.cancelHumanComparison(); model.requestForget()
            model.confirmForget(try #require(model.pendingForget))
        case "mutation":
            model.writeContext(id: "memo", kind: "note", text: "Synthetic saved draft", update: true, expected: base)
        default: model.compareHumanContext()
        }
        #expect(await core.events.last == "begin") // no successor service before predecessor join
        await core.release(); await model.waitForOperation()
        if action == "successor" { #expect(await core.comparisons == 2 && model.humanComparison != nil) }
        else { #expect(model.humanComparison == nil) }
        if ["cancel", "choice", "history", "successor", "quit", "mutation"].contains(action) {
            #expect(model.history?.history.count == 2 && model.humanContextRevisionBinding("memo") == base)
            #expect(model.contextEditorRevision == editor && model.originalDraft == "Synthetic original")
        }
        if action == "note" { #expect(model.history?.id == "other") }
        if action == "history" || action == "note" { #expect(!model.humanComparisonVisible) }
        if action == "forget" {
            #expect(model.history == nil && model.humanComparison == nil && !model.forgetRequiresRefresh)
            #expect(await core.events.contains("forget"))
            #expect(model.originalDraft == "Synthetic original")
        }
        if action == "mutation" { #expect(model.lastError == .mutationUncertain && model.humanComparison == nil) }
        await model.shutdown()
    }
    @Test @MainActor func typedValidResponseForAnotherCapturedTextPairIsRejectedAtAdoption() async throws {
        let core = ComparisonCore()
        let selected = CompanionModel(service: core, configured: true)
        selected.select("alpha"); await selected.waitForOperation(); selected.openContext("memo"); await selected.waitForOperation()
        let base = selected.humanContextRevisionBinding("memo")
        await core.returnWrongPair()
        selected.openHumanComparison(); selected.compareHumanContext(); await selected.waitForOperation()
        #expect(selected.humanComparison == nil && selected.comparisonStatus == ServiceError.invalid.localizedDescription)
        #expect(selected.history?.history.count == 2 && selected.humanContextRevisionBinding("memo") == base)
        await selected.shutdown()
    }
    @Test @MainActor func authoritativeReplacementClearsOldNamespace() async throws {
        let core = ComparisonCore()
        let model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "q", original: "Synthetic original")
        await core.replace()
        model.openHumanComparison(); model.compareHumanContext(); await model.waitForOperation()
        #expect(model.lastError == .namespaceChanged && model.project == nil && model.history == nil)
        #expect(model.originalDraft.isEmpty && model.humanComparison == nil && !model.humanComparisonVisible)
        #expect(await core.comparisons == 0)
        await model.shutdown()
    }
}
