import Foundation
import Testing
@testable import CompanionKit

func setRequest(_ anchors: [Evidence] = [inspectionAnchor(), inspectionAnchor(4, text: "center two")],
                project: Project = inspectionScope, radius: Int = 2) throws -> SourceInspectionSetRequest {
    try SourceInspectionSetRequest(project: project, anchors: anchors, radius: radius, query: "center",
        mode: .literal, selectedPaths: nil, readID: UUID())
}
func setBytes(_ request: SourceInspectionSetRequest) throws -> Data {
    var windows: [[String: Any]] = []
    for a in request.anchors {
        let single = try SourceInspectionRequest(project: request.project, anchor: a, radius: request.radius)
        var record = try #require(JSONSerialization.jsonObject(with: inspectionBytes(single)) as? [String: Any])
        for key in ["format", "version", "project", "root_identity", "incarnation", "snapshot", "radius", "currentness"] { record.removeValue(forKey: key) }
        windows.append(record)
    }
    let p = request.project
    guard case .string(let identity) = p.root_identity, case .string(let snapshot) = p.snapshot else { throw ServiceError.invalid }
    let object: [String: Any] = ["format": "threadmark-source-inspection-set", "version": 1,
        "project": p.id, "root_identity": identity, "incarnation": p.incarnation!,
        "snapshot": snapshot, "radius": request.radius, "currentness": "current-at-read", "inspections": windows]
    var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    data.append(10); return data
}

private actor SetCore: CoreService {
    var calls = 0
    var setReads = 0
    var singleReads = 0
    var metadataReads = 0
    var failure: ServiceError?
    var forged = false
    var batchFails = false
    var batchSaved = false
    var failSavedRefresh = false
    var delayed = false
    var active = false
    var overtook = false
    var entered: CheckedContinuation<Void, Never>?
    var release: CheckedContinuation<Void, Never>?
    var requests: [SourceInspectionSetRequest] = []
    func hold() { delayed = true }
    func waitEntered() async { if active { return }; await withCheckedContinuation { entered = $0 } }
    func finish() { release?.resume(); release = nil; delayed = false }
    func fail(_ error: ServiceError) { failure = error }
    func forge() { forged = true }
    func batchFailure(_ value: Bool) { batchFails = value }
    func savedRefreshFailure() { failSavedRefresh = true }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        calls += 1
        if active { overtook = true }
        switch operation {
        case .project: metadataReads += 1; return .project(inspectionScope)
        case .contextsBound:
            if batchSaved && failSavedRefresh { throw ServiceError.failed }
            return .contexts(ContextList(project: "alpha", contexts: []))
        case .contextBound(_, let id):
            return .context(ContextHistory(project: "alpha", id: id, producer: "human-authored", authority: .string("context-not-authorization-or-observed-truth"),
                history: [ContextRevision(revision: 1, kind: "note", text: "human history", retired: false)]))
        case .editContextBatchBound(let execution):
            let plan = try execution.claim()
            if batchFails { throw ServiceError.failed }
            batchSaved = true
            return .batchReceipt(try BatchReceipt.decode(batchBytes(plan), plan: plan))
        case .queryBound, .queryTermsBound:
            return .query(QueryReport(project: "alpha", snapshot: inspectionScope.snapshot, currentness: "current-at-read",
                coverage: .string("lexical"), results: [inspectionAnchor(), inspectionAnchor(4, text: "center two")]))
        case .indexBound:
            return .indexed(IndexReport(project: "alpha", snapshot: .string(inspectionHash), files: 1, anchors: 2, coverage: .string("lexical"), empty: false))
        case .inspectSourceAnchorBound(let r):
            singleReads += 1
            return .sourceInspection(try SourceInspectionDocument.decode(inspectionBytes(r), request: r))
        case .inspectSourceSetBound(let r):
            setReads += 1; requests.append(r); active = true; entered?.resume(); entered = nil
            if delayed { await withCheckedContinuation { release = $0 } }
            active = false
            if let failure { throw failure }
            let d = try SourceInspectionSetDocument.decode(setBytes(r), request: r)
            if forged { return .sourceInspectionSet(SourceInspectionSetDocument(project: d.project, radius: d.radius, windows: [], bytes: d.bytes)) }
            return .sourceInspectionSet(d)
        default: throw ServiceError.invalid
        }
    }
}

@Suite("AR coherent native selected Query inspection")
struct SourceInspectionSetTests {
    @Test(arguments: [SourceRetrievalMode.literal, .rankedTerms])
    @MainActor func ar01MemoryOnlyAndReadIdentity(mode: SourceRetrievalMode) async throws {
        let core = SetCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.setSourceRetrievalMode(mode); model.query("center"); await model.waitForOperation()
        let old = try #require(model.sourceInspectionRows.first), count = await core.calls
        #expect(!model.canInspectSelectedSources)
        model.stageSourceRow(old, selected: true)
        #expect(!model.canInspectSelectedSources)
        model.inspectSelectedSources()
        model.selectAllSourceRows(); model.setInspectionRadius(3)
        #expect(model.canInspectSelectedSources)
        model.stageSourceRow(old, selected: false); model.clearStagedSourceRows()
        #expect(await core.calls == count)
        model.query("center"); await model.waitForOperation()
        // Same coordinate AND exact same text is a different rendered read.
        model.stageSourceRow(old, selected: true)
        #expect(model.stagedSourceRows.isEmpty && !model.canStageSourceRow(old))
        let row = try #require(model.sourceInspectionRows.first)
        model.inspectSource(row.anchor); await model.waitForOperation()
        #expect(await core.singleReads == 1)
        #expect(await core.setReads == 0)
        #expect(model.canStageSourceRow(row))
        await model.shutdown()
    }

    @Test(arguments: 0...3)
    @MainActor func ar02SingleOperationAndWholeAdoption(radius: Int) async throws {
        let core = SetCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "unsent original")
        model.query("center"); await model.waitForOperation()
        let editor = model.contextEditorRevision, reads = await core.metadataReads
        model.selectAllSourceRows(); model.setInspectionRadius(radius)
        model.inspectSelectedSources(); await model.waitForOperation()
        let result = try #require(model.sourceInspectionSet)
        #expect(result.windows.count == 2 && result.radius == radius)
        #expect(result.windows.allSatisfy { $0.lines.filter(\.isAnchor).count == 1 })
        #expect(await core.setReads == 1)
        #expect(await core.singleReads == 0)
        #expect(await core.metadataReads == reads)
        #expect(model.originalDraft == "unsent original" && model.history?.history.last?.text == "human history")
        #expect(model.contextEditorRevision == editor && model.canInspectSelectedSources)
        model.clearStagedSourceRows()
        #expect(model.sourceInspectionSet == nil)
        await model.shutdown()
    }

    @Test(arguments: [ServiceError.failed, .invalid, .unavailable, .outputLimit, .canceled])
    @MainActor func ar04FailurePreservesButRevokes(error: ServiceError) async throws {
        let core = SetCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original")
        model.query("center"); await model.waitForOperation()
        let query = model.evidence, editor = model.contextEditorRevision, old = try #require(model.sourceInspectionRows.first)
        model.selectAllSourceRows(); await core.fail(error)
        model.inspectSelectedSources(); await model.waitForOperation()
        #expect(model.sourceInspectionSet == nil && model.evidence == query)
        #expect(model.history != nil && model.originalDraft == "original" && model.contextEditorRevision == editor)
        #expect(!model.canStageSourceRow(old) && !model.canInspectSelectedSources && !model.canInspectSource(old.anchor))
        model.selectAllSourceRows(); model.inspectSelectedSources()
        #expect(await core.setReads == 1)
        await model.shutdown()
    }

    @Test(arguments: ["cancel", "query", "radius", "settings", "policy", "selection", "quit", "build", "incremental", "config", "query-change", "filter", "mode", "remove", "clear", "forget", "source-forget"])
    @MainActor func ar04IgnoringCancelJoinsSuccessor(action: String) async throws {
        let core = SetCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original")
        model.query("center"); await model.waitForOperation()
        let old = try #require(model.sourceInspectionRows.first)
        model.selectAllSourceRows(); await core.hold()
        model.inspectSelectedSources(); await core.waitEntered()
        switch action {
        case "query": model.query("new")
        case "radius": model.setInspectionRadius(0)
        case "settings": model.refinementSettingsChanged(ProviderSettings())
        case "policy": model.stageSources([])
        case "selection": model.select(nil)
        case "quit": model.quit()
        case "build": model.build()
        case "incremental": model.buildIncrementally()
        case "config": model.configure(executable: URL(fileURLWithPath: "/synthetic/other-cli"), dataDirectory: URL(fileURLWithPath: "/synthetic/other-store"))
        case "query-change": model.sourceQueryChanged()
        case "filter": model.setQueryFileFilter(["a.rs"])
        case "mode": model.setSourceRetrievalMode(.rankedTerms)
        case "remove": model.stageSourceRow(old, selected: false)
        case "clear": model.clearStagedSourceRows()
        case "forget": model.requestForget()
        case "source-forget": model.requestSourceForget("a.rs")
        default: model.cancel()
        }
        await core.finish(); await model.waitForOperation()
        #expect(model.sourceInspectionSet == nil)
        #expect(await core.overtook == false)
        if action != "query" { #expect(!model.canStageSourceRow(old)) }
        if ["cancel", "radius", "settings", "query-change", "remove", "clear", "quit"].contains(action) {
            #expect(model.history != nil && model.originalDraft == "original")
        }
        await model.shutdown()
    }

    @Test @MainActor func ar03ForgedTypedFrameCannotPublish() async throws {
        let core = SetCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.query("center"); await model.waitForOperation()
        model.selectAllSourceRows(); await core.forge(); model.inspectSelectedSources(); await model.waitForOperation()
        #expect(model.sourceInspectionSet == nil && !model.canInspectSelectedSources)
        await model.shutdown()
    }

    @Test(arguments: [false, true])
    @MainActor func ar04AJReviewRevocationUnknownAndSavedRefresh(unknown: Bool) async throws {
        let core = SetCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("n0"); await model.waitForOperation()
        model.stageBatchUpdate(id: "n0", kind: "note", text: "copied draft", expected: model.humanContextRevisionBinding("n0"))
        model.openContext("n1"); await model.waitForOperation(); model.stageBatchRetire()
        model.editPreparation(query: "center", original: "original")
        model.query("center"); await model.waitForOperation()
        model.reviewBatch()
        #expect(model.pendingBatchReview != nil)
        let calls = await core.calls
        model.selectAllSourceRows()
        #expect(model.pendingBatchReview == nil)
        #expect(await core.calls == calls)
        model.reviewBatch()
        let review = try #require(model.pendingBatchReview)
        await core.batchFailure(unknown); await core.savedRefreshFailure()
        model.applyBatch(review); await model.waitForOperation()
        #expect(model.batchOutcomeUnknown == unknown)
        if !unknown {
            #expect(model.batchReceipt?.count == 2 && model.batchStatus.contains("saved"))
        }
        model.query("center"); await model.waitForOperation()
        // Local old Edit base mismatch sets a conflict without any service call.
        model.writeContext(id: "n1", kind: "note", text: "unsaved editor", update: true)
        #expect(model.lastError == .contextConflict)
        let base = model.humanContextRevisionBinding("n1"), editor = model.contextEditorRevision
        model.selectAllSourceRows(); model.inspectSelectedSources(); await model.waitForOperation()
        #expect(model.sourceInspectionSet != nil && model.batchOutcomeUnknown == unknown)
        #expect(model.lastError == .contextConflict && model.humanContextRevisionBinding("n1") == base)
        #expect(model.contextEditorRevision == editor && model.history?.id == "n1" && model.originalDraft == "original")
        if unknown { #expect(model.stagedBatch.count == 2 && !model.canReviewBatch) }
        else { #expect(model.batchReceipt?.count == 2) }
        await model.shutdown()
    }

    @Test func ar02AdmissionAndCanonicalFullPolicy() throws {
        let p = Project(id: "alpha", root: inspectionScope.root, sources: ["z.rs", "a.rs"], snapshot: inspectionScope.snapshot,
            rootIdentity: inspectionScope.root_identity, incarnation: inspectionScope.incarnation)
        let z = Evidence(project: "alpha", path: "z.rs", line: 2, text: "center", source_hash: inspectionHash,
            producer: "lexical-v1", kind: "observed-source-line", currentness: "current-at-read", coverage: .string("lexical"))
        let r = try setRequest([inspectionAnchor(), z], project: p)
        #expect(r.anchors.first?.path == "z.rs" && r.project.sources == p.sources)
        let input = try #require(JSONSerialization.jsonObject(with: r.encoded()) as? [String: Any])
        #expect(Set(input.keys) == ["version", "anchors"])
        for rows in [[], [z], [z, z], Array(repeating: z, count: 9)] {
            #expect(throws: (any Error).self) { try setRequest(rows, project: p) }
        }
        for radius in [-1, 4] { #expect(throws: (any Error).self) { try setRequest(radius: radius) } }
    }

    @Test(arguments: 0...3)
    func ar03StrictFrames(radius: Int) throws {
        let request = try setRequest(radius: radius), data = try setBytes(request)
        let document = try SourceInspectionSetDocument.decode(data, request: request)
        try document.validate(request: request)
        let o = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["format", "project", "root_identity", "incarnation", "snapshot", "currentness", "extra"] {
            var bad = o; bad[key] = "forged"
            #expect(throws: (any Error).self) { try SourceInspectionSetDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
        }
        let hostile: [Any] = [true, -1, 1.5, "1", 1e100, NSNull()]
        for key in ["radius", "version"] {
            for value in hostile {
                var bad = o; bad[key] = value
                #expect(throws: (any Error).self) { try SourceInspectionSetDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
            }
        }
        let windows = try #require(o["inspections"] as? [[String: Any]])
        for key in ["path", "source_hash", "producer", "anchor_line", "extra"] {
            var bad = o, records = windows; records[1][key] = "forged"; bad["inspections"] = records
            #expect(throws: (any Error).self) { try SourceInspectionSetDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
        }
        for mutation in ["count", "order", "duplicate", "center", "gap", "kind", "anchor", "line-type", "text-type", "line-extra", "text-overflow", "newline", "nul", "empty", "partial"] {
            var bad = o, records = windows
            var lines = try #require(records[1]["lines"] as? [[String: Any]])
            let center = try #require(lines.firstIndex { $0["is_anchor"] as? Bool == true })
            switch mutation {
            case "count": records.removeLast()
            case "order": records.reverse()
            case "duplicate": records[1] = records[0]
            case "center": lines[center]["text"] = "fabricated"
            case "gap": lines[0]["line"] = 4000
            case "kind": lines[center]["kind"] = "observed-source-text"
            case "anchor": lines[center]["is_anchor"] = false
            case "line-type": lines[center]["line"] = true
            case "text-type": lines[center]["text"] = 7
            case "line-extra": lines[center]["extra"] = true
            case "text-overflow": lines[center]["text"] = String(repeating: "x", count: 1025)
            case "newline": lines[center]["text"] = "center\nforged"
            case "nul": lines[center]["text"] = "center\0forged"
            case "empty": lines = []
            default: lines.remove(at: center)
            }
            if !["count", "order", "duplicate"].contains(mutation) { records[1]["lines"] = lines }
            bad["inspections"] = records
            #expect(throws: (any Error).self) { try SourceInspectionSetDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
        }
        let text = try #require(String(data: data, encoding: .utf8))
        for bad in ["{\"version\":1," + text.dropFirst(), "{\"vers\\u0069on\":1," + text.dropFirst(),
                    text.replacingOccurrences(of: "\"is_anchor\":", with: "\"kind\":\"indexed-anchor\",\"is_anchor\":"),
                    text.replacingOccurrences(of: "\"line\":3", with: "\"line\":3e0"), String(text.dropLast(2)), text + "{}"] {
            #expect(throws: (any Error).self) { try SourceInspectionSetDocument.decode(Data(bad.utf8), request: request) }
        }
        var exact = data; exact.append(Data(repeating: 32, count: 8191 - exact.count)); exact.append(10)
        #expect(try SourceInspectionSetDocument.decode(exact, request: request).windows.count == 2)
        exact.append(10)
        #expect(throws: ServiceError.outputLimit) { try SourceInspectionSetDocument.decode(exact, request: request) }
    }
}
