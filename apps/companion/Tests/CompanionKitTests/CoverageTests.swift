// TM-01–04/07/10; AD-A1–A5; AF-A1–A5; partial P2/P3 acceptance only.
import Foundation
import Testing
@testable import CompanionKit

func coverageBytes(_ request: CoverageRequest) throws -> Data {
    let p = request.project, exists = p.snapshot != nil && p.snapshot != .null
    guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
    let files: [[String: Any]] = p.sources.map { path in
        ["path": path, "baseline_exists": exists, "stored_anchor_record_count": exists ? 1 : 0,
         "current_metadata": ["byte_count": 10, "line_count": 1, "hash": inspectionHash],
         "baseline_matches": exists, "status": exists ? "current" : "unindexed"]
    }
    let snapshot: Any
    if case .string(let hash) = p.snapshot { snapshot = hash } else { snapshot = NSNull() }
    var data = try JSONSerialization.data(withJSONObject: ["format": "threadmark-coverage-report", "version": 1,
        "project": p.id, "root_identity": identity, "incarnation": token, "baseline_snapshot": snapshot,
        "coverage": "lexical-only", "semantic_completeness": "not-assessed", "review_scope": "explicit-approved-files-only",
        "files": files, "summary": ["approved_file_count": files.count, "readable_file_count": files.count,
            "unavailable_file_count": 0, "matching_file_count": exists ? files.count : 0,
            "stored_anchor_record_count": exists ? files.count : 0, "project_snapshot_current": exists,
            "needs_build": !exists, "needs_readability_review": false]], options: [.sortedKeys, .withoutEscapingSlashes])
    data.append(10); return data
}

private actor CoverageCore: CoreService {
    var requests: [CoverageRequest] = []
    var reads = 0
    var failure: ServiceError?
    var delayed = false
    var delayedQuery = false
    var active = false
    var overtook = false
    var entered: CheckedContinuation<Void, Never>?
    var release: CheckedContinuation<Void, Never>?
    func hold() { delayed = true }
    func holdQuery() { delayedQuery = true }
    func waitUntilEntered() async { if active { return }; await withCheckedContinuation { entered = $0 } }
    func finish() { delayed = false; release?.resume(); release = nil }
    func setFailure(_ error: ServiceError) { failure = error }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        if active { overtook = true }
        switch operation {
        case .project: reads += 1; return .project(inspectionScope)
        case .contextsBound: return .contexts(ContextList(project: "alpha", contexts: []))
        case .contextBound:
            return .context(ContextHistory(project: "alpha", id: "memo", producer: "human-authored", authority: .string("context-not-authorization-or-observed-truth"),
                history: [ContextRevision(revision: 1, kind: "note", text: "human history", retired: false)]))
        case .queryBound:
            if delayedQuery {
                delayedQuery = false; active = true; entered?.resume(); entered = nil
                await withCheckedContinuation { release = $0 }; active = false
            }
            return .query(QueryReport(project: "alpha", snapshot: inspectionScope.snapshot, currentness: "current-at-read", coverage: .string("lexical"), results: [inspectionAnchor()]))
        case .indexBound:
            return .indexed(IndexReport(project: "alpha", snapshot: inspectionScope.snapshot!, files: 1, anchors: 1, coverage: .string("lexical"), empty: false))
        case .coverageBound(let request):
            requests.append(request); active = true; entered?.resume(); entered = nil
            if delayed { await withCheckedContinuation { release = $0 } }
            active = false
            if let failure { throw failure }
            return .coverage(try CoverageDocument.decode(coverageBytes(request), request: request))
        default: throw ServiceError.invalid
        }
    }
}

@Suite("Explicit native coverage")
struct CoverageTests {
    @Test @MainActor func explicitCoverageCancelsAndJoinsAnOlderQuery() async throws {
        let core = CoverageCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        await core.holdQuery(); model.query("center"); await core.waitUntilEntered()
        #expect(model.canInspectCoverage)
        model.inspectCoverage()
        #expect(await core.requests.isEmpty)
        await core.finish(); await model.waitForOperation()
        #expect(await !core.overtook)
        #expect(model.evidence == nil && model.coverageReport != nil)
        #expect(await core.requests.count == 1)
        await model.shutdown()
    }
    @Test(arguments: ["success", "error", "cancel"])
    @MainActor func humanCASConflictAndEditorBaseAreNotRebased(action: String) async throws {
        let core = CoverageCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.query("center"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original")
        let base = try #require(model.humanContextRevisionBinding("memo")), editor = model.contextEditorRevision, query = model.evidence
        model.writeContext(id: "memo", kind: "note", text: "unsaved draft", update: true)
        #expect(model.lastError == .contextConflict)
        if action == "error" { await core.setFailure(.failed) }
        if action == "cancel" { await core.hold() }
        model.inspectCoverage()
        if action == "cancel" { await core.waitUntilEntered(); model.cancel(); await core.finish() }
        await model.waitForOperation()
        #expect(model.lastError == .contextConflict && model.humanContextRevisionBinding("memo") == base)
        #expect(model.contextEditorRevision == editor && model.history?.history.last?.text == "human history")
        #expect(model.originalDraft == "original" && model.evidence == query)
        await model.shutdown()
    }
    @Test @MainActor func typedAuthoritativeNamespaceErrorUsesExistingClearing() async throws {
        let core = CoverageCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original")
        await core.setFailure(.namespaceChanged)
        model.inspectCoverage(); await model.waitForOperation()
        #expect(model.project == nil && model.history == nil && model.originalDraft.isEmpty)
        #expect(model.sourceRequiresRefresh && model.coverageReport == nil)
        await model.shutdown()
    }
    @Test @MainActor func noIOUntilButtonAndNoSourceEligibility() async throws {
        let core = CoverageCore()
        let model = CompanionModel(service: core)
        #expect(!model.canInspectCoverage)
        model.inspectCoverage(); #expect(await core.requests.isEmpty)
        #expect(await core.reads == 0)
        let subject = CompanionModel(service: core, configured: true)
        subject.select("alpha"); await subject.waitForOperation()
        subject.openContext("memo"); await subject.waitForOperation()
        subject.editPreparation(query: "center", original: "original")
        subject.setInspectionRadius(3)
        #expect(await core.requests.isEmpty)
        let reads = await core.reads, editor = subject.contextEditorRevision
        subject.inspectCoverage(); await subject.waitForOperation()
        #expect(subject.coverageReport?.projectSnapshotCurrent == true)
        #expect(subject.evidence == nil && !subject.canInspectSource(inspectionAnchor()))
        #expect(subject.history?.history.last?.text == "human history" && subject.originalDraft == "original")
        #expect(subject.contextEditorRevision == editor && subject.automaticRefreshConsent == nil)
        #expect(await core.reads == reads)
        let captured = try #require(await core.requests.first)
        #expect(ProjectExportDocument.exact(captured.project, inspectionScope))
        subject.stageSources([])
        #expect(subject.coverageReport == nil && !subject.canInspectCoverage)
        #expect(await core.requests.count == 1)
        await subject.shutdown(); await model.shutdown()
    }

    @Test(arguments: [ServiceError.failed, .invalid, .unavailable, .outputLimit, .canceled])
    @MainActor func unknownFailurePreservesQueryHumanAndRequiresMetadata(error: ServiceError) async throws {
        let core = CoverageCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original")
        model.query("center"); await model.waitForOperation()
        let query = model.evidence, editor = model.contextEditorRevision, reads = await core.reads
        await core.setFailure(error)
        model.inspectCoverage(); await model.waitForOperation()
        #expect(model.coverageReport == nil && model.evidence == query && !model.canInspectCoverage)
        #expect(!model.canInspectSource(inspectionAnchor()))
        #expect(model.project == inspectionScope && model.contextEditorRevision == editor)
        #expect(model.history?.history.last?.text == "human history" && model.originalDraft == "original")
        #expect(await core.reads == reads)
        model.inspectCoverage(); #expect(await core.requests.count == 1)
        await model.shutdown()
    }

    @Test(arguments: ["cancel", "query", "query-change", "settings", "config", "policy", "selection", "build", "quit", "successor", "forget", "source-forget"])
    @MainActor func cancelJoinAndLatePublication(action: String) async throws {
        let core = CoverageCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original")
        model.query("center"); await model.waitForOperation()
        let query = model.evidence, editor = model.contextEditorRevision
        await core.hold(); model.inspectCoverage(); await core.waitUntilEntered()
        switch action {
        case "query": model.query("next")
        case "query-change": model.sourceQueryChanged()
        case "settings": model.refinementSettingsChanged(ProviderSettings())
        case "config": model.configure(executable: URL(fileURLWithPath: "/synthetic/other"), dataDirectory: URL(fileURLWithPath: "/synthetic/store"))
        case "policy": model.stageSources([])
        case "selection": model.select(nil)
        case "build": model.build()
        case "quit": model.quit()
        case "successor": model.inspectCoverage()
        case "forget": model.requestForget()
        case "source-forget": model.requestSourceForget("a.rs")
        default: model.cancel()
        }
        await core.finish(); await model.waitForOperation()
        #expect(await !core.overtook)
        let count = await core.requests.count
        if action == "successor" { #expect(model.coverageReport != nil && count == 2) }
        else { #expect(model.coverageReport == nil) }
        if ["cancel", "settings", "quit", "query-change"].contains(action) {
            #expect(model.evidence == query && model.history?.history.last?.text == "human history")
            #expect(model.originalDraft == "original" && model.contextEditorRevision == editor)
        }
        await model.shutdown()
    }

    @Test func closedWholeDocumentAndCrossFields() throws {
        let request = try CoverageRequest(project: inspectionScope), data = try coverageBytes(request)
        let valid = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(try CoverageDocument.decode(data, request: request).projectSnapshotCurrent)
        for key in ["project", "root_identity", "incarnation", "baseline_snapshot", "coverage", "semantic_completeness", "review_scope", "format"] {
            var bad = valid; bad[key] = "wrong"
            #expect(throws: (any Error).self) { try CoverageDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
        }
        let summary = try #require(valid["summary"] as? [String: Any])
        for key in summary.keys {
            for value: Any in [NSNull(), "1", -1, 1.5, 1e30, true, false, 64] {
                if (summary[key] as? NSObject) == (value as? NSObject) { continue }
                var bad = valid, s = summary; s[key] = value; bad["summary"] = s
                #expect(throws: (any Error).self) { try CoverageDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
            }
        }
        let files = try #require(valid["files"] as? [[String: Any]])
        for key in files[0].keys {
            for value: Any in [NSNull(), "wrong", -1, 1e30, true, false, 4097] {
                if (files[0][key] as? NSObject) == (value as? NSObject) { continue }
                var bad = valid, rows = files; rows[0][key] = value; bad["files"] = rows
                #expect(throws: (any Error).self) { try CoverageDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
            }
        }
        let text = try #require(String(data: data, encoding: .utf8))
        for bad in ["{\"version\":1," + text.dropFirst(), "{\"vers\\u0069on\":1," + text.dropFirst(),
                    text.replacingOccurrences(of: "\"byte_count\":", with: "\"hash\":\"bad\",\"byte_count\":"),
                    text.replacingOccurrences(of: "\"version\":1", with: "\"version\":true"),
                    String(text.dropLast(2)), text + "{}", "{\"extra\":1," + text.dropFirst()] {
            #expect(throws: (any Error).self) { try CoverageDocument.decode(Data(bad.utf8), request: request) }
        }
        var padded = data; padded.append(Data(repeating: 32, count: 65536 - padded.count))
        #expect(throws: ServiceError.outputLimit) { try CoverageDocument.decode(padded, request: request) }
        padded.removeLast(); padded.append(10)
        #expect(try CoverageDocument.decode(padded, request: request).files.count == 1)
    }
    @Test func fileOrderNullabilityAndFalseCurrentness() throws {
        let p = Project(id: inspectionScope.id, root: inspectionScope.root, sources: ["a.rs", "b.rs"],
            snapshot: inspectionScope.snapshot, rootIdentity: inspectionScope.root_identity, incarnation: inspectionScope.incarnation)
        let request = try CoverageRequest(project: p), data = try coverageBytes(request)
        let valid = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rows = try #require(valid["files"] as? [[String: Any]])
        for mutation in ["order", "duplicate", "short", "extra", "unknown-status", "null-current", "changed-matches", "changed-no-baseline", "hash", "zero-counts", "metadata-extra", "false-current"] {
            var bad = valid, files = rows
            switch mutation {
            case "order": files.reverse()
            case "duplicate": files[1] = files[0]
            case "short": files.removeLast()
            case "extra": files.append(files[0])
            case "unknown-status": files[0]["status"] = "ready"
            case "null-current": files[0]["current_metadata"] = NSNull()
            case "changed-matches": files[0]["status"] = "changed"
            case "changed-no-baseline": files[0]["baseline_exists"] = false; files[0]["status"] = "changed"
            case "hash": files[0]["current_metadata"] = ["byte_count": 10, "line_count": 1, "hash": String(repeating: "G", count: 64)]
            case "zero-counts": files[0]["current_metadata"] = ["byte_count": 0, "line_count": 1, "hash": inspectionHash]
            case "metadata-extra": files[0]["current_metadata"] = ["byte_count": 10, "line_count": 1, "hash": inspectionHash, "text": "not allowed"]
            default:
                files[0]["status"] = "unavailable-or-unsafe"; files[0]["current_metadata"] = NSNull(); files[0]["baseline_matches"] = false
            }
            bad["files"] = files
            #expect(throws: (any Error).self) { try CoverageDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
        }
        // A fully cross-field-consistent claimed baseline is still forbidden when
        // the exact captured registration had explicit none.
        let none = Project(id: p.id, root: p.root, sources: p.sources, rootIdentity: p.root_identity, incarnation: p.incarnation)
        #expect(throws: (any Error).self) { try CoverageDocument.decode(data, request: CoverageRequest(project: none)) }
        let empty = Project(id: p.id, root: p.root, sources: [], rootIdentity: p.root_identity, incarnation: p.incarnation)
        let emptyRequest = try CoverageRequest(project: empty)
        #expect(try CoverageDocument.decode(coverageBytes(emptyRequest), request: emptyRequest).needsBuild == true)
    }
}
