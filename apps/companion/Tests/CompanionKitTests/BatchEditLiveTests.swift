import Foundation
import Testing
@testable import CompanionKit

private actor BatchRaceCore: CoreService {
    let service: ProcessService
    let mode: String
    var writes = 0
    var fallbacks = 0
    var committed = false
    var entered: CheckedContinuation<Void, Never>?
    var release: CheckedContinuation<Void, Never>?
    init(_ service: ProcessService, _ mode: String) { self.service = service; self.mode = mode }
    func wait() async { if committed { return }; await withCheckedContinuation { entered = $0 } }
    func finish() { release?.resume(); release = nil }
    func perform(_ op: CompanionKit.Operation) async throws -> Reply {
        if case .contextsBound = op, committed, mode == "refresh-fails" { throw ServiceError.failed }
        if case .writeContext = op { fallbacks += 1 }
        if case .updateContextRevisionBound = op { fallbacks += 1 }
        if case .retireContextRevisionBound = op { fallbacks += 1 }
        let reply = try await service.perform(op)
        guard case .editContextBatchBound = op else { return reply }
        writes += 1; committed = true
        switch mode {
        case "lost": throw ServiceError.failed
        case "cancel":
            entered?.resume(); entered = nil
            await withCheckedContinuation { release = $0 }
        case "rebind":
            guard case .project(let p) = try await service.perform(.project("alpha")),
                  case .string(let identity) = p.root_identity, let nonce = p.incarnation else { throw ServiceError.invalid }
            _ = try await service.perform(.removeProject(p.id, p.root, identity, nonce))
            _ = try await service.perform(.addProject(p.id, p.root, p.sources))
            _ = try await service.perform(.writeContext("alpha", "n0", "note", "Replacement B", update: false))
        default: break
        }
        return reply
    }
}

@Suite("Actual CLI native atomic note batch")
struct BatchEditLiveTests {
    @MainActor private func staged(_ service: any CoreService, count: Int = 2) async throws -> CompanionModel {
        let m = CompanionModel(service: service, configured: true)
        m.select("alpha"); await m.waitForOperation()
        for n in 0..<count {
            let id = "n\(n)"
            m.openContext(id); await m.waitForOperation()
            if n % 2 == 0 {
                m.stageBatchUpdate(id: id, kind: "decision", text: "Synthetic replacement \(n)", expected: m.humanContextRevisionBinding(id))
            } else { m.stageBatchRetire() }
        }
        return m
    }
    private func setup(count: Int = 2) async throws -> (ApprovedWatchFixture, ProcessService) {
        let (f, s) = try await CoverageLiveTests().setup(["a.rs"])
        for n in 0..<count { _ = try await s.perform(.writeContext("alpha", "n\(n)", "note", "Synthetic old \(n)", update: false)) }
        return (f, s)
    }
    private func history(_ s: ProcessService, _ id: String) async throws -> ContextHistory {
        guard case .context(let h) = try await s.perform(.context("alpha", id)) else { throw ServiceError.invalid }; return h
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func sourcePolicyAndMissingSourceAreIndependentHumanMutation() async throws {
        let (f, s) = try await setup(); defer { f.remove() }
        let m = try await staged(s), p = try #require(m.project)
        guard case .string(let identity) = p.root_identity, let nonce = p.incarnation else { throw ServiceError.invalid }
        _ = try await s.perform(.setSourcesBound(p.id, p.root, identity, nonce, p.sources, []))
        try FileManager.default.removeItem(at: f.root.appendingPathComponent("a.rs")) // Synthetic unavailable source only.
        m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview)); await m.waitForOperation()
        #expect(m.batchReceipt?.count == 2 && m.project == p)
        #expect(try await history(s, "n0").history.count == 2)
        await m.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil), arguments: [2, 3, 4, 5, 6, 7, 8])
    @MainActor func explicitMixedBatchReopenAndPreservation(count: Int) async throws {
        let (f, s) = try await setup(count: count); defer { f.remove() }
        _ = try await s.perform(.index("alpha"))
        let source = try Data(contentsOf: f.root.appendingPathComponent("a.rs"))
        let m = try await staged(s, count: count)
        let old = try #require(m.project), base = m.humanContextRevisionBinding("n\(count - 1)"), editor = m.contextEditorRevision
        m.editPreparation(query: "center", original: "Unsent original")
        let database = s.dataDirectory!.appendingPathComponent("knowledge.sqlite"), bytes = try Data(contentsOf: database)
        m.reviewBatch(); m.cancelBatchReview()
        #expect(try Data(contentsOf: database) == bytes)
        #expect(m.stagedBatch.count == count)
        m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview)); await m.waitForOperation()
        #expect(m.batchReceipt?.count == count && m.stagedBatch.isEmpty)
        #expect(m.project == old && m.contextEditorRevision == editor && m.humanContextRevisionBinding("n\(count - 1)") == base)
        #expect(m.originalDraft == "Unsent original")
        let reopened = ProcessService(executable: s.executable, dataDirectory: s.dataDirectory)
        for n in 0..<count {
            let h = try await history(reopened, "n\(n)")
            #expect(h.history.count == 2 && h.history.last?.retired == (n % 2 != 0))
        }
        guard case .query(let q) = try await reopened.perform(.query("alpha", "center")) else { throw ServiceError.invalid }
        #expect(q.results.count == 1 && q.currentness == "current-at-read")
        #expect(try Data(contentsOf: f.root.appendingPathComponent("a.rs")) == source)
        await m.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil), arguments: ["peer", "forget"])
    @MainActor func anyPeerConflictOrForgetRejectsWholeBatch(change: String) async throws {
        let (f, s) = try await setup(); defer { f.remove() }
        let m = try await staged(s)
        let base = m.humanContextRevisionBinding("n1"), editor = m.contextEditorRevision
        if change == "peer" {
            _ = try await s.perform(.writeContext("alpha", "n1", "note", "Peer newer", update: true))
            m.writeContext(id: "n1", kind: "note", text: "Unsent stale editor", update: true, expected: base)
            await m.waitForOperation()
            #expect(m.lastError == .contextConflict)
        }
        else {
            let p = try #require(m.project)
            guard case .string(let identity) = p.root_identity, let nonce = p.incarnation else { throw ServiceError.invalid }
            _ = try await s.perform(.forgetContext("alpha", "n1", p.root, identity, nonce, 1))
        }
        m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview)); await m.waitForOperation()
        #expect(m.batchReceipt == nil && m.stagedBatch.count == 2 && !m.canReviewBatch)
        #expect(m.contextEditorRevision == editor && m.humanContextRevisionBinding("n1") == base)
        if change == "peer" { #expect(m.lastError == .contextConflict) }
        let unchanged = try await history(s, "n0")
        #expect(unchanged.history.count == 1 && unchanged.history[0].text == "Synthetic old 0")
        if change == "peer" { #expect(try await history(s, "n1").history.count == 2) }
        else { await #expect(throws: (any Error).self) { try await history(s, "n1") } }
        await m.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil), arguments: ["lost", "cancel", "rebind", "refresh-fails"])
    @MainActor func actualCommitLostReceiptCancelReplacementAndRefreshFailure(mode: String) async throws {
        let (f, s) = try await setup(); defer { f.remove() }
        let race = BatchRaceCore(s, mode), m = try await staged(race)
        let old = m.project, base = m.humanContextRevisionBinding("n1")
        m.reviewBatch(); m.applyBatch(try #require(m.pendingBatchReview))
        if mode == "cancel" { await race.wait(); m.cancel(); await race.finish() }
        await m.waitForOperation()
        #expect(await race.writes == 1)
        #expect(await race.fallbacks == 0)
        #expect(m.project == old && m.humanContextRevisionBinding("n1") == base)
        #expect(m.history?.history.last?.text == "Synthetic old 1")
        if mode == "refresh-fails" {
            #expect(m.batchReceipt?.count == 2 && m.stagedBatch.isEmpty && m.batchStatus.contains("saved"))
            #expect(m.batchStatus.contains("refresh failed"))
        } else {
            #expect(m.batchReceipt == nil && m.stagedBatch.count == 2 && m.batchStatus.contains("unknown") && !m.canReviewBatch)
        }
        if mode != "rebind" { #expect(try await history(s, "n0").history.count == 2) }
        await m.shutdown()
    }
}
