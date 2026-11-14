import Foundation
import Testing
@testable import CompanionKit

func batchHistory(_ id: String) -> ContextHistory {
    ContextHistory(project: "alpha", id: id, producer: "human-authored",
        authority: .string("context-not-authorization-or-observed-truth"),
        history: [ContextRevision(revision: 1, kind: "note", text: "Synthetic \(id)", retired: false)])
}
func batchPlan(_ count: Int = 2) throws -> BatchPlan {
    BatchPlan(binding: try HumanContextReadBinding(project: inspectionScope), entries: (0..<count).map {
        let id = "n\($0)"
        return BatchEntry(id: id, operation: $0 == 0 ? "update" : "retire", expectedRevision: 1,
            kind: "note", text: $0 == 0 ? "Copied draft" : "Synthetic \(id)", capturedHistory: batchHistory(id), historyGeneration: 1)
    })
}
func batchBytes(_ plan: BatchPlan) throws -> Data {
    var data = try JSONSerialization.data(withJSONObject: ["version": "human-context-batch-edit-v1", "project": plan.binding.project,
        "count": plan.entries.count, "actions": plan.entries.sorted { $0.id < $1.id }.map {
            ["id": $0.id, "operation": $0.operation, "old_revision": $0.expectedRevision, "new_revision": $0.expectedRevision + 1] as [String: Any]
        }], options: [.sortedKeys])
    data.append(10); return data
}

private actor BatchCore: CoreService {
    var calls = 0
    var executions: [BatchExecution] = []
    var hold = false
    var holdHistory = false
    var active = false
    var overtook = false
    var failure = false
    var entered: CheckedContinuation<Void, Never>?
    var release: CheckedContinuation<Void, Never>?
    func pause() { hold = true }
    func pauseHistory() { holdHistory = true }
    func fail() { failure = true }
    func wait() async { if active { return }; await withCheckedContinuation { entered = $0 } }
    func finish() { hold = false; holdHistory = false; release?.resume(); release = nil }
    func perform(_ op: CompanionKit.Operation) async throws -> Reply {
        calls += 1; if active { overtook = true }
        switch op {
        case .project: return .project(inspectionScope)
        case .contextsBound: return .contexts(ContextList(project: "alpha", contexts: []))
        case .contextBound(_, let id):
            if holdHistory {
                active = true; entered?.resume(); entered = nil
                await withCheckedContinuation { release = $0 }; active = false
            }
            return .context(batchHistory(id))
        case .editContextBatchBound(let execution):
            executions.append(execution)
            if hold {
                active = true; entered?.resume(); entered = nil
                await withCheckedContinuation { release = $0 }; active = false
            }
            let plan = try execution.claim() // Deliberately delay claim past cancellation.
            if failure { throw ServiceError.failed }
            return .batchReceipt(try BatchReceipt.decode(batchBytes(plan), plan: plan))
        default: throw ServiceError.invalid
        }
    }
}

@Suite("Native explicit atomic note batch")
struct BatchEditTests {
    @MainActor private func prepare(_ core: BatchCore) async -> CompanionModel {
        let m = CompanionModel(service: core, configured: true)
        m.select("alpha"); await m.waitForOperation()
        m.openContext("n0"); await m.waitForOperation()
        m.stageBatchUpdate(id: "n0", kind: "note", text: "Copied draft", expected: m.humanContextRevisionBinding("n0"))
        m.openContext("n1"); await m.waitForOperation(); m.stageBatchRetire()
        return m
    }
    @Test @MainActor func zeroIOReviewCancelAndExplicitApplyPreserveEditorAndConflict() async throws {
        let core = BatchCore(), m = await prepare(core)
        m.editPreparation(query: "center", original: "Unsent original")
        m.writeContext(id: "n1", kind: "note", text: "draft", update: true) // Missing base: local conflict.
        let base = m.humanContextRevisionBinding("n1"), editor = m.contextEditorRevision
        let calls = await core.calls
        m.stageBatchRetire(); m.reviewBatch()
        let stale = try #require(m.pendingBatchReview)
        m.cancelBatchReview(); m.applyBatch(stale)
        #expect(await core.calls == calls)
        #expect(await core.executions.isEmpty)
        #expect(m.stagedBatch.count == 2 && m.history?.id == "n1" && m.originalDraft == "Unsent original")
        m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview)); await m.waitForOperation()
        #expect(m.batchReceipt?.count == 2 && m.stagedBatch.isEmpty)
        #expect(m.humanContextRevisionBinding("n1") == base && m.contextEditorRevision == editor)
        #expect(m.lastError == .contextConflict && m.originalDraft == "Unsent original")
        let execution = try #require(await core.executions.first)
        #expect(throws: (any Error).self) { try execution.claim() }
        await m.shutdown()
    }
    @Test(arguments: ["cancel", "quit", "config", "selection", "edit", "remove", "review", "restage"])
    @MainActor func delayedPreclaimRevocationAndNoLatePublication(fence: String) async throws {
        let core = BatchCore(), m = await prepare(core)
        await core.pause(); m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview)); await core.wait()
        switch fence {
        case "quit": m.quit()
        case "config": m.configure(executable: URL(fileURLWithPath: "/missing/core"), dataDirectory: URL(fileURLWithPath: "/missing/store"))
        case "selection": m.select(nil)
        case "edit": m.contextEditorChanged()
        case "remove": m.removeBatchEntry("n0")
        case "review": m.cancelBatchReview()
        case "restage": m.stageBatchRetire()
        default: m.cancel()
        }
        let execution = try #require(await core.executions.first)
        #expect(throws: (any Error).self) { try execution.claim() }
        await core.finish(); await m.waitForOperation()
        #expect(m.batchReceipt == nil && !m.stagedBatch.isEmpty)
        #expect(m.batchStatus.contains("unknown") && !m.canReviewBatch)
        #expect(m.batchOutcomeUnknown)
        if ["cancel", "edit", "review", "remove"].contains(fence) { #expect(m.history?.id == "n1") }
        await m.shutdown()
    }
    @Test @MainActor func successorJoinsAndCanceledQueuedAttemptNeverClaims() async throws {
        let core = BatchCore(), m = await prepare(core)
        await core.pause(); m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview)); await core.wait()
        m.cancel(); m.openContext("n0") // Explicit successor must join ignoring worker.
        #expect(await core.executions.count == 1)
        await core.finish(); await m.waitForOperation()
        #expect(await !core.overtook)
        #expect(m.history?.id == "n0" && !m.canReviewBatch)
        // Fresh histories and deliberate re-staging, never an automatic retry/rebase.
        m.stageBatchUpdate(id: "n0", kind: "note", text: "new intent", expected: m.humanContextRevisionBinding("n0"))
        m.openContext("n1"); await m.waitForOperation(); m.stageBatchRetire()
        #expect(m.canReviewBatch)
        m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview)); m.cancel()
        await m.waitForOperation()
        #expect(await core.executions.count == 1) // Canceled before owned task dispatch.
        #expect(m.canReviewBatch)
        await m.shutdown()
    }
    @Test @MainActor func unknownFailureRetainsIntentAndRequiresFreshHistories() async throws {
        let core = BatchCore(), m = await prepare(core)
        await core.fail(); m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview)); await m.waitForOperation()
        #expect(m.stagedBatch.count == 2 && m.batchStatus.contains("unknown") && !m.canReviewBatch)
        m.reviewBatch(); #expect(m.pendingBatchReview == nil)
        m.stageBatchRetire(); #expect(!m.canReviewBatch)
        #expect(m.batchOutcomeUnknown)
        m.clearBatchPlan()
        #expect(m.stagedBatch.isEmpty && m.batchOutcomeUnknown && m.batchStatus.contains("unknown"))
        await m.shutdown()
    }
    @Test @MainActor func ignoringReadPredecessorJoinedBeforeApplyAndQueuedCancelHasNoEffect() async throws {
        let core = BatchCore(), m = await prepare(core)
        await core.pauseHistory(); m.openContext("n0"); await core.wait(); m.cancel()
        m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview)); m.cancel()
        #expect(await core.executions.isEmpty)
        await core.finish(); await m.waitForOperation()
        #expect(await !core.overtook)
        #expect(await core.executions.isEmpty)
        #expect(m.canReviewBatch && !m.batchStatus.contains("unknown"))
        m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview)); await m.waitForOperation()
        #expect(m.batchReceipt?.count == 2)
        await m.shutdown()
    }
    @Test func oneUseAndClosedReceiptAndEncodedBudgets() throws {
        let plan = try batchPlan(), valid = try batchBytes(plan)
        #expect(try BatchReceipt.decode(valid, plan: plan).count == 2)
        let execution = BatchExecution(plan); _ = try execution.claim()
        #expect(throws: (any Error).self) { try execution.claim() }
        let revoked = BatchExecution(plan); revoked.revoke()
        #expect(throws: (any Error).self) { try revoked.claim() }
        let text = String(decoding: valid, as: UTF8.self)
        for bad in [text + "{}", String(text.dropLast()), "{\"count\":2," + text.dropFirst(),
                    text.replacingOccurrences(of: "\"count\":2", with: "\"count\":2.0"),
                    text.replacingOccurrences(of: "\"count\":2", with: "\"count\":true"),
                    text.replacingOccurrences(of: "\"count\":2", with: "\"count\":200000000000000000000000000000"),
                    text.replacingOccurrences(of: "\"n1\"", with: "\"n0\""),
                    text.replacingOccurrences(of: "\"retire\"", with: "\"update\""),
                    text.replacingOccurrences(of: "\"old_revision\":1", with: "\"old_revision\":2"),
                    text.replacingOccurrences(of: "\"new_revision\":2", with: "\"new_revision\":3"),
                    text.replacingOccurrences(of: "\"alpha\"", with: "\"beta\""),
                    text.replacingOccurrences(of: "\"id\":\"n0\"", with: "\"id\":\"n0\",\"\\u0069d\":\"n0\""),
                    "{\"extra\":1," + text.dropFirst(), "{}\n"] {
            #expect(throws: (any Error).self) { try BatchReceipt.decode(Data(bad.utf8), plan: plan) }
        }
        var exact = valid; exact.insert(contentsOf: repeatElement(UInt8(32), count: 8192 - valid.count), at: 0)
        #expect(try BatchReceipt.decode(exact, plan: plan).count == 2)
        exact.insert(32, at: 0)
        #expect(throws: (any Error).self) { try BatchReceipt.decode(exact, plan: plan) }
        #expect(throws: (any Error).self) { try batchPlan(1).encoded() }
        #expect(throws: (any Error).self) { try batchPlan(9).encoded() }
        #expect(try batchPlan(8).encoded().count < 65536)
        let eight = try batchPlan(8)
        func withText(_ text: String) -> BatchPlan {
            BatchPlan(binding: eight.binding, entries: eight.entries.map {
                BatchEntry(id: $0.id, operation: "update", expectedRevision: 1, kind: "note", text: text,
                           capturedHistory: $0.capturedHistory, historyGeneration: 1)
            })
        }
        #expect(try withText(String(repeating: "📝", count: 1024)).encoded().count <= 65536)
        #expect(throws: (any Error).self) { try withText(String(repeating: "📝", count: 1025)).encoded() }
        #expect(throws: (any Error).self) { try withText(String(repeating: "\u{1}", count: 4096)).encoded() }
        #expect(throws: (any Error).self) { try withText("bad\0text").encoded() }
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_BATCH_FIXTURE_BINARY"] != nil))
    func processClaimsOnceExactArgvJSONStdinAndWholeFrame() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_BATCH_FIXTURE_BINARY"])
        let f = try ApprovedWatchFixture(); defer { f.remove() }
        let initial = try batchPlan(8)
        let plan = BatchPlan(binding: initial.binding, entries: initial.entries.map {
            BatchEntry(id: $0.id, operation: "update", expectedRevision: 1, kind: "note",
                text: String(repeating: "x", count: 4096), capturedHistory: $0.capturedHistory, historyGeneration: 1)
        })
        let bytes = try batchBytes(plan)
        #expect(try plan.encoded().count > 32768)
        try plan.encoded().write(to: f.root.appendingPathComponent("request.json"))
        try bytes.write(to: f.root.appendingPathComponent("response.json"))
        let s = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: f.root)
        let execution = BatchExecution(plan)
        guard case .batchReceipt(let receipt) = try await s.perform(.editContextBatchBound(execution)) else { throw ServiceError.invalid }
        #expect(receipt.count == 8)
        await #expect(throws: (any Error).self) { try await s.perform(.editContextBatchBound(execution)) }
        for bad in [Data("{}\n".utf8), Data(bytes.dropLast()), Data(repeating: 32, count: 8193)] {
            try bad.write(to: f.root.appendingPathComponent("response.json"))
            await #expect(throws: (any Error).self) { try await s.perform(.editContextBatchBound(BatchExecution(plan))) }
        }
    }
}
