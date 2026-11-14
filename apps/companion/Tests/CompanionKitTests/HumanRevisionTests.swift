import Foundation
import Testing
@testable import CompanionKit

private func syntheticHumanHistory(_ count: Int = 1) -> ContextHistory {
    ContextHistory(project: "alpha", id: "memo", producer: "human-authored", authority: .string("human-declared"),
        history: (0..<count).map { ContextRevision(revision: $0 + 1, kind: "note", text: "Synthetic revision \($0 + 1)", retired: false) })
}

/// Holds a write even after cancellation to exercise the model's join fence.
private actor HumanRevisionCore: CoreService {
    let project = Project(id: "alpha", root: "/synthetic/alpha", sources: [], rootIdentity: .string("r1"), incarnation: String(repeating: "a", count: 32))
    var count = 1
    var hold = false
    var failHistory = false
    var omitAppend = false
    var didStart = false
    var started: CheckedContinuation<Void, Never>?
    var releaseWrite: CheckedContinuation<Void, Never>?
    var events: [String] = []
    func prepareHold() { hold = true; didStart = false }
    func failRead() { failHistory = true }
    func acknowledgeWithoutAppend() { omitAppend = true }
    func waitForWrite() async {
        if didStart { return }
        await withCheckedContinuation { started = $0 }
    }
    func release() { releaseWrite?.resume(); releaseWrite = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        switch operation {
        case .project: events.append("project"); return .project(project)
        case .contexts: return .contexts(ContextList(project: "alpha", contexts: []))
        case .context:
            if failHistory { throw ServiceError.failed }
            return .context(syntheticHumanHistory(count))
        case .updateContextRevisionBound(let binding, _, _), .retireContextRevisionBound(let binding):
            try binding.validate()
            guard binding.revision == count else { throw ServiceError.failed }
            events.append("begin"); didStart = true; started?.resume(); started = nil
            if hold { hold = false; await withCheckedContinuation { releaseWrite = $0 } }
            if !omitAppend { count += 1 }
            events.append("commit"); return .acknowledged
        default: throw ServiceError.unavailable // A legacy fallback must fail, never simulate success.
        }
    }
}

@Suite("Native human revision capture and lifetime")
struct HumanRevisionTests {
    @Test func malformedOrLegacyHistoryCannotBecomeCASMetadata() throws {
        let project = Project(id: "alpha", root: "/synthetic/alpha", sources: [], rootIdentity: .string("r1"), incarnation: String(repeating: "a", count: 32))
        for count in [0, 33] {
            #expect(throws: ServiceError.invalid) { try HumanContextRevisionBinding(project: project, history: syntheticHumanHistory(count)) }
        }
        let missing = Project(id: project.id, root: project.root, sources: [], rootIdentity: project.root_identity)
        #expect(throws: ServiceError.invalid) { try HumanContextRevisionBinding(project: missing, history: syntheticHumanHistory()) }
        let malformed = ContextHistory(project: "alpha", id: "memo", producer: "human-authored", authority: .null,
            history: [ContextRevision(revision: 2, kind: "note", text: "Synthetic skipped revision", retired: false)])
        #expect(throws: ServiceError.invalid) { try HumanContextRevisionBinding(project: project, history: malformed) }
    }
    @Test(arguments: [false, true]) @MainActor
    func cancelJoinsLateCASBeforeSuccessorAndNeverAdoptsItsHistory(retire: Bool) async throws {
        let service = HumanRevisionCore()
        let selected = CompanionModel(service: service, configured: true)
        selected.select("alpha"); await selected.waitForOperation()
        selected.openContext("memo"); await selected.waitForOperation()
        selected.editPreparation(query: "q", original: "Synthetic unsaved request")
        let base = try #require(selected.humanContextRevisionBinding("memo")), editor = selected.contextEditorRevision
        await service.prepareHold()
        if retire { selected.retireContext("memo") }
        else { selected.writeContext(id: "memo", kind: "note", text: "Synthetic unsaved editor", update: true, expected: base) }
        await service.waitForWrite()
        selected.cancel()
        #expect(selected.history?.history.count == 1 && selected.contextEditorRevision == editor)
        selected.openContext("memo")
        let before = await service.events
        #expect(before.last == "begin")
        await service.release(); await selected.waitForOperation()
        let events = await service.events
        // Canceled writer's namespace-only uncertainty probe runs after commit;
        // only then may the successor perform its two history-scope probes.
        #expect(events.suffix(4) == ["commit", "project", "project", "project"])
        #expect(selected.history?.history.count == 2 && selected.originalDraft == "Synthetic unsaved request")
        #expect(selected.contextEditorRevision == editor && base.revision == 1)
        await selected.shutdown()
    }
    @Test @MainActor func postCommitReadFailureRemainsUncertainAndKeepsCapturedHistory() async throws {
        let service = HumanRevisionCore()
        let selected = CompanionModel(service: service, configured: true)
        selected.select("alpha"); await selected.waitForOperation()
        selected.openContext("memo"); await selected.waitForOperation()
        let base = try #require(selected.humanContextRevisionBinding("memo"))
        await service.failRead()
        selected.writeContext(id: "memo", kind: "note", text: "Synthetic saved but unread", update: true, expected: base)
        await selected.waitForOperation()
        #expect(await service.count == 2)
        #expect(selected.lastError == .mutationUncertain && selected.history?.history.count == 1)
        await selected.shutdown()
    }
    @Test @MainActor func receiptWithoutAdvancedHistoryCannotBecomeConfirmedSuccess() async throws {
        let service = HumanRevisionCore()
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        await service.acknowledgeWithoutAppend()
        model.retireContext("memo"); await model.waitForOperation()
        #expect(model.lastError == .mutationUncertain && model.history?.history.count == 1)
        await model.shutdown()
    }
}

@Suite("Actual CLI native human CAS peers")
struct LiveHumanRevisionTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    func twoActualCLIWritersCompeteForOneCapturedRevision() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "store")
        let first = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        let second = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await first.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await first.perform(.writeContext("alpha", "memo", "note", "Synthetic initial", update: false))
        guard case .project(let project) = try await first.perform(.project("alpha")),
              case .context(let history) = try await first.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        let base = try HumanContextRevisionBinding(project: project, history: history)
        let update = Task { () -> Bool in
            do { _ = try await first.perform(.updateContextRevisionBound(base, "decision", "Synthetic winning update")); return true }
            catch { return false }
        }
        let retire = Task { () -> Bool in
            do { _ = try await second.perform(.retireContextRevisionBound(base)); return true }
            catch { return false }
        }
        let updated = await update.value, retired = await retire.value
        #expect(updated != retired)
        guard case .context(let actual) = try await second.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(actual.history.count == 2 && actual.history.last?.retired == retired)
        #expect(actual.history.last?.text == (updated ? "Synthetic winning update" : "Synthetic initial"))
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: ["update", "retire", "forget"], [false, true]) @MainActor
    func peerMutationAfterCaptureNeverOverwrites(peerAction: String, retire: Bool) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        let peer = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic first", update: false))
        let model = CompanionModel(service: adapter, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "q", original: "Synthetic unrelated unsaved request")
        let base = try #require(model.humanContextRevisionBinding("memo")), editor = model.contextEditorRevision
        switch peerAction {
        case "update": _ = try await peer.perform(.updateContextRevisionBound(base, "decision", "Synthetic peer wins"))
        case "retire": _ = try await peer.perform(.retireContextRevisionBound(base))
        default: _ = try await peer.perform(.forgetContext(base.project, base.contextID, base.root, base.rootIdentity, base.incarnation, base.revision))
        }
        if retire { model.retireContext("memo") }
        else { model.writeContext(id: "memo", kind: "constraint", text: "Synthetic unsaved draft", update: true, expected: base) }
        await model.waitForOperation()
        #expect(model.lastError == .contextConflict && model.history?.history.count == 1)
        #expect(model.contextEditorRevision == editor && model.originalDraft == "Synthetic unrelated unsaved request")
        if peerAction == "forget" {
            await #expect(throws: ServiceError.failed) { try await peer.perform(.context("alpha", "memo")) }
            await #expect(throws: ServiceError.failed) { try await peer.perform(.writeContext("alpha", "memo", "note", "Synthetic no resurrection", update: false)) }
        } else {
            guard case .context(let actual) = try await peer.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
            #expect(actual.history.count == 2 && actual.history.last?.retired == (peerAction == "retire"))
            #expect(actual.history.last?.text == (peerAction == "update" ? "Synthetic peer wins" : "Synthetic first"))
        }
        await model.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil)) @MainActor
    func freshCASOnceRestartSourcePolicyRebuildAndRevisionLimit() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        let model = CompanionModel(service: adapter, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.writeContext(id: "memo", kind: "note", text: "Synthetic first", update: false); await model.waitForOperation()
        let base = try #require(model.humanContextRevisionBinding("memo"))
        _ = try await adapter.perform(.setSources("alpha", []))
        model.writeContext(id: "memo", kind: "decision", text: "Synthetic second", update: true, expected: base)
        await model.waitForOperation()
        #expect(model.lastError == nil && model.history?.history.count == 2)
        await #expect(throws: ServiceError.failed) { try await adapter.perform(.retireContextRevisionBound(base)) }
        let fresh = try #require(model.humanContextRevisionBinding("memo"))
        model.retireContext("memo"); await model.waitForOperation()
        #expect(model.history?.history.count == 3 && model.history?.history.last?.retired == true)
        await model.shutdown()
        let reopened = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await reopened.perform(.index("alpha"))
        guard case .project(let project) = try await reopened.perform(.project("alpha")),
              case .context(let history) = try await reopened.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(history.history.count == 3 && history.history.last?.text == "Synthetic second")
        await #expect(throws: ServiceError.failed) { try await reopened.perform(.updateContextRevisionBound(fresh, "note", "Synthetic stale")) }
        // Real guarded updates, each using exactly the history just inspected.
        for _ in 3..<32 {
            guard case .context(let current) = try await reopened.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
            _ = try await reopened.perform(.updateContextRevisionBound(try HumanContextRevisionBinding(project: project, history: current), "note", "Synthetic bounded history"))
        }
        guard case .context(let full) = try await reopened.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        let limit = try HumanContextRevisionBinding(project: project, history: full)
        #expect(limit.revision == 32)
        await #expect(throws: ServiceError.failed) { try await reopened.perform(.retireContextRevisionBound(limit)) }
        await #expect(throws: ServiceError.failed) { try await reopened.perform(.updateContextRevisionBound(limit, "note", "Synthetic over limit")) }
        guard case .context(let unchanged) = try await reopened.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(unchanged.history.count == 32 && unchanged.history.last?.retired == false)
    }
}
