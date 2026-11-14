// AH-A1–A5; TM-01–04/07/10, partial P2/P3 only. Synthetic fixtures.
import Foundation
import Testing
@testable import CompanionKit

func incrementalBytes(_ request: IncrementalBuildRequest) throws -> Data {
    let p = request.project, baseline = p.snapshot != nil && p.snapshot != .null
    let snapshot: String
    if case .string(let h) = p.snapshot { snapshot = h } else { snapshot = inspectionHash }
    var o: [String: Any] = ["format": "threadmark-incremental-lexical-index", "version": 1,
        "project": p.id, "baseline_snapshot": NSNull(), "snapshot": snapshot,
        "coverage": "lexical-lines-only; no semantic coverage", "files": p.sources.count,
        "anchors": p.sources.count, "reused_files": baseline ? p.sources.count : 0,
        "reindexed_files": baseline ? 0 : p.sources.count, "reused_anchors": baseline ? p.sources.count : 0,
        "written_anchors": baseline ? 0 : p.sources.count, "deleted_anchors": 0,
        "snapshot_updated": !baseline, "persistent_writes": !baseline, "empty": p.sources.isEmpty]
    if case .string(let h) = p.snapshot { o["baseline_snapshot"] = h }
    var data = try JSONSerialization.data(withJSONObject: o, options: [.sortedKeys, .withoutEscapingSlashes])
    data.append(10); return data
}

private actor IncrementalCore: CoreService {
    var current = inspectionScope
    var calls: [String] = []
    var requests: [IncrementalBuildRequest] = []
    var failure = false
    var replacement: Project?
    var holdBuild = false
    var holdQuery = false
    var active = false
    var overtook = false
    var entered: CheckedContinuation<Void, Never>?
    var release: CheckedContinuation<Void, Never>?
    func hold(query: Bool = false) { if query { holdQuery = true } else { holdBuild = true } }
    func waitUntilEntered() async { if active { return }; await withCheckedContinuation { entered = $0 } }
    func finish() { holdBuild = false; holdQuery = false; release?.resume(); release = nil }
    func fail() { failure = true }
    func replace(_ p: Project) { replacement = p }
    private func delay() async {
        active = true; entered?.resume(); entered = nil
        await withCheckedContinuation { release = $0 }; active = false
    }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        if active { overtook = true }
        switch operation {
        case .project: calls.append("project"); return .project(current)
        case .contextsBound: calls.append("human-bound"); return .contexts(ContextList(project: "alpha", contexts: []))
        case .contextBound:
            return .context(ContextHistory(project: "alpha", id: "memo", producer: "human-authored",
                authority: .string("context-not-authorization-or-observed-truth"),
                history: [ContextRevision(revision: 1, kind: "note", text: "human history", retired: false)]))
        case .queryBound:
            calls.append("query"); if holdQuery { await delay() }
            return .query(QueryReport(project: "alpha", snapshot: current.snapshot, currentness: "current-at-read",
                                      coverage: .string("lexical"), results: [inspectionAnchor()]))
        case .indexBound:
            calls.append("full")
            return .indexed(IndexReport(project: "alpha", snapshot: current.snapshot!, files: 1, anchors: 1, coverage: .string("lexical"), empty: false))
        case .indexIncrementalBound(let request):
            calls.append("incremental"); requests.append(request)
            if holdBuild { await delay() } // Deliberately ignores cancellation.
            if failure { throw ServiceError.failed }
            let report = try IncrementalBuildReport.decode(incrementalBytes(request), request: request)
            if let replacement { current = replacement }
            return .incrementalBuild(report)
        default: throw ServiceError.contextConflict
        }
    }
}

@Suite("Explicit native incremental lexical Build")
struct IncrementalBuildTests {
    @Test @MainActor func explicitOnlyAndOldFullRouteAndHumanPreservation() async throws {
        let core = IncrementalCore(), model = CompanionModel(service: core, configured: true)
        #expect(await core.calls.isEmpty)
        model.select("alpha"); await model.waitForOperation()
        model.showManagement(); model.closeManagement(); model.setInspectionRadius(1)
        model.setHumanSearchKindFilter(["note"])
        #expect(await core.requests.isEmpty)
        #expect(model.automaticRefreshConsent == nil && model.paused)
        model.build(); await model.waitForOperation()
        #expect(await core.calls.contains("full"))
        #expect(await core.requests.isEmpty)
        model.openContext("memo"); await model.waitForOperation()
        model.openHumanComparison(); model.editPreparation(query: "center", original: "unsent original")
        let base = model.humanContextRevisionBinding("memo"), editor = model.contextEditorRevision
        model.writeContext(id: "memo", kind: "note", text: "draft", update: true)
        #expect(model.lastError == .contextConflict)
        let before = await core.calls.count
        model.buildIncrementally(); await model.waitForOperation()
        let r = try #require(model.incrementalBuildReport)
        #expect(!r.persistentWrites && !r.snapshotUpdated && r.reusedFiles == 1)
        #expect(await Array(core.calls.dropFirst(before)) == ["incremental", "project"])
        #expect(model.history?.history.last?.text == "human history" && model.contextEditorRevision == editor)
        #expect(model.originalDraft == "unsent original" && model.humanContextRevisionBinding("memo") == base)
        #expect(model.humanComparisonVisible && model.lastError == .contextConflict)
        #expect(model.evidence == nil && model.automaticRefreshConsent == nil && model.paused)
        await model.shutdown()
    }

    @Test(arguments: ["cancel", "policy", "config", "quit", "forget", "source-forget", "selection"])
    @MainActor func lateIgnoringResultCannotPublish(fence: String) async throws {
        let core = IncrementalCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "unsent")
        await core.hold(); model.buildIncrementally(); await core.waitUntilEntered()
        switch fence {
        case "policy": model.stageSources([])
        case "config": model.configure(executable: URL(fileURLWithPath: "/missing/core"), dataDirectory: URL(fileURLWithPath: "/missing/store"))
        case "quit": model.quit()
        case "forget": model.requestForget()
        case "source-forget": model.requestSourceForget("a.rs")
        case "selection": model.select(nil)
        default: model.cancel()
        }
        #expect(model.incrementalBuildReport == nil)
        await core.finish(); await model.waitForOperation()
        #expect(model.incrementalBuildReport == nil)
        #expect(await core.requests.count == 1)
        #expect(await !core.calls.contains("full"))
        if ["cancel", "forget", "source-forget"].contains(fence) {
            #expect(model.sourceRequiresRefresh && model.status.contains("outcome unknown"))
            #expect(model.originalDraft == "unsent" && model.history?.history.last?.text == "human history")
        }
        await model.shutdown()
    }

    @Test @MainActor func predecessorJoinAndExplicitSuccessorJoinBeforeDispatch() async throws {
        let core = IncrementalCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        await core.hold(query: true); model.query("center"); await core.waitUntilEntered()
        model.buildIncrementally()
        #expect(await core.requests.isEmpty)
        await core.finish(); await model.waitForOperation()
        #expect(await !core.overtook)
        #expect(await core.requests.count == 1)
        await core.hold(); model.buildIncrementally(); await core.waitUntilEntered()
        model.buildIncrementally()
        #expect(await core.requests.count == 2)
        await core.finish(); await model.waitForOperation()
        #expect(await !core.overtook)
        #expect(await core.requests.count == 3)
        #expect(model.incrementalBuildReport != nil && !model.sourceRequiresRefresh)
        await model.shutdown()
    }

    @Test @MainActor func canceledWhileJoiningPredecessorNeverStartsMutation() async throws {
        let core = IncrementalCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        await core.hold(query: true); model.query("center"); await core.waitUntilEntered()
        model.buildIncrementally(); model.cancel()
        await core.finish(); await model.waitForOperation()
        #expect(await core.requests.isEmpty)
        #expect(!model.sourceRequiresRefresh && model.incrementalBuildReport == nil)
        await model.shutdown()
    }

    @Test(arguments: ["failure", "snapshot", "policy", "nonce", "root"])
    @MainActor func unknownOutcomeNeverAdoptsOrRetriesOrFallsBack(change: String) async throws {
        let core = IncrementalCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        let p = try #require(model.project)
        if change == "failure" { await core.fail() }
        else {
            await core.replace(Project(id: p.id, root: change == "root" ? "/replacement" : p.root,
                sources: change == "policy" ? [] : p.sources,
                snapshot: change == "snapshot" ? .string(String(repeating: "b", count: 64)) : p.snapshot,
                rootIdentity: p.root_identity, incarnation: change == "nonce" ? String(repeating: "c", count: 32) : p.incarnation))
        }
        let before = await core.calls.count
        model.buildIncrementally(); await model.waitForOperation()
        #expect(model.incrementalBuildReport == nil && model.project == p && model.sourceRequiresRefresh)
        #expect(model.lastError == .mutationUncertain)
        #expect(await Array(core.calls.dropFirst(before)) == (change == "failure" ? ["incremental"] : ["incremental", "project"]))
        await model.shutdown()
    }
}

@Suite("Closed incremental lexical receipt")
struct IncrementalBuildDecoderTests {
    @Test func hostileWholeCountsSnapshotNoopAndNewline() throws {
        let request = try IncrementalBuildRequest(project: inspectionScope), data = try incrementalBytes(request)
        _ = try IncrementalBuildReport.decode(data, request: request)
        let text = String(decoding: data, as: UTF8.self)
        for bad in ["{\"version\":1," + text.dropFirst(), "{\"vers\\u0069on\":1," + text.dropFirst(),
                    text + "{}", String(text.dropLast(2)), String(text.dropLast()),
                    text.replacingOccurrences(of: "lexical-lines-only; no semantic coverage", with: "semantic"),
                    text.replacingOccurrences(of: "\"files\":1", with: "\"files\":true"),
                    text.replacingOccurrences(of: "\"version\":1", with: "\"version\":1.0"),
                    text.replacingOccurrences(of: "\"files\":1", with: "\"files\":18446744073709551616"),
                    "{\"extra\":0," + text.dropFirst()] {
            #expect(throws: (any Error).self) { try IncrementalBuildReport.decode(Data(bad.utf8), request: request) }
        }
        let original = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for (key, value) in [("files", 0 as Any), ("anchors", 2 as Any), ("reused_files", 0 as Any),
                             ("reindexed_files", 1 as Any), ("reused_anchors", 0 as Any), ("written_anchors", 1 as Any),
                             ("deleted_anchors", 1 as Any), ("snapshot_updated", true as Any), ("persistent_writes", true as Any),
                             ("empty", true as Any), ("project", "wrong" as Any), ("baseline_snapshot", NSNull() as Any),
                             ("snapshot", String(repeating: "b", count: 64) as Any)] {
            var o = original; o[key] = value
            var bad = try JSONSerialization.data(withJSONObject: o); bad.append(10)
            #expect(throws: (any Error).self) { try IncrementalBuildReport.decode(bad, request: request) }
        }
        var exact = Data(data.dropLast()); exact.append(Data(repeating: 32, count: 65536 - data.count)); exact.append(10)
        #expect(exact.count == 65536)
        _ = try IncrementalBuildReport.decode(exact, request: request)
        exact.insert(32, at: exact.count - 1)
        #expect(throws: (any Error).self) { try IncrementalBuildReport.decode(exact, request: request) }
    }
    @Test func noneEmptyAndNewSnapshotAllowedButOnlyExactRegistrationAdopted() throws {
        let p = Project(id: inspectionScope.id, root: inspectionScope.root, sources: [],
                        rootIdentity: inspectionScope.root_identity, incarnation: inspectionScope.incarnation)
        let request = try IncrementalBuildRequest(project: p)
        let r = try IncrementalBuildReport.decode(incrementalBytes(request), request: request)
        #expect(r.empty && r.snapshotUpdated && r.persistentWrites && r.reusedFiles == 0)
        let fresh = Project(id: p.id, root: p.root, sources: [], snapshot: .string(r.snapshot), rootIdentity: p.root_identity, incarnation: p.incarnation)
        try r.validateAdoption(fresh, request: request)
        #expect(throws: (any Error).self) { try r.validateAdoption(p, request: request) }
    }
}
