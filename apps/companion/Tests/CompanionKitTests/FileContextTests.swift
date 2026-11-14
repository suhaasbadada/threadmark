// AN-A1–A4, A6. Synthetic frames/services only; no provider or host.
import Foundation
import Testing
@testable import CompanionKit

func fileContextBytes(_ r: FileContextRequest, stale: Bool = false, empty: Bool = false) throws -> Data {
    let ranked = r.mode == .rankedTerms
    let query = try FileQueryRequest(project: r.project, query: r.query, mode: r.mode, selectedPaths: r.selectedPaths)
    let source = try #require(JSONSerialization.jsonObject(with: fileQueryBytes(query, stale: stale)) as? [String: Any])
    var rows = try #require(source["results"] as? [[String: Any]])
    for i in rows.indices { rows[i]["id"] = "source-\(i)"; rows[i].removeValue(forKey: "matched_terms"); rows[i].removeValue(forKey: "occurrences") }
    if empty { rows = [] }
    let needsInput = stale || empty
    var coverage = try #require(source["coverage"] as? String)
    if ranked { coverage = "ranked-terms; " + coverage + "; selection=" + (try #require(source["selection"] as? String)) }
    if stale { coverage += "; source context stale or unindexed" }
    let o: [String: Any] = ["format": "threadmark-file-scoped-context", "version": 1, "project": r.project.id,
        "snapshot": stale ? NSNull() : (r.project.snapshot?.description ?? NSNull()),
        "selected_paths": r.selectedPaths, "retrieval_mode": r.wireMode, "coverage": coverage,
        "selection": source["selection"]!, "truncated": false, "matching_anchors": needsInput ? 0 : 1,
        "scanned_anchors": 1, "evidence": rows, "mode": "context-only", "state": needsInput ? "needs-input" : "ready-for-review",
        "original": r.original, "proposed": needsInput ? r.original : r.original + FileContextDocument.quotedHeader + "Synthetic quoted data",
        "changed": !needsInput, "provider": "not-invoked", "approval": "not-requested", "delivery": "not-attempted",
        "limitations": FileContextDocument.limitations]
    var data = try JSONSerialization.data(withJSONObject: o, options: [.sortedKeys, .withoutEscapingSlashes]); data.append(10); return data
}

private actor FileContextCore: CoreService {
    var scope = fileQueryScope
    var calls = 0, preparations = 0, defaults = 0, queries = 0, providers = 0
    var captures: [FileContextRequest] = []
    var fullScopes: [Project] = []
    var failure: ServiceError?, forged = false
    var hold = false, active = false, overtook = false
    var batchHold = false
    var executions: [BatchExecution] = []
    var entered: CheckedContinuation<Void, Never>?, release: CheckedContinuation<Void, Never>?
    func pause() { hold = true }
    func pauseBatch() { batchHold = true }
    func fail(_ e: ServiceError?) { failure = e }
    func forge() { forged = true }
    func wait() async { if active { return }; await withCheckedContinuation { entered = $0 } }
    func finish() { release?.resume(); release = nil }
    private func suspend() async {
        active = true; entered?.resume(); entered = nil
        await withCheckedContinuation { release = $0 }; active = false
    }
    func perform(_ op: CompanionKit.Operation) async throws -> Reply {
        calls += 1; if active { overtook = true }
        switch op {
        case .project(let id):
            if id == "beta" { return .project(Project(id: id, root: "/synthetic/beta", sources: ["b.rs"], snapshot: scope.snapshot, rootIdentity: .string("beta"), incarnation: String(repeating: "c", count: 32))) }
            return .project(scope)
        case .contextsBound(let b): return .contexts(ContextList(project: b.project, contexts: []))
        case .contextBound(_, let id): return .context(batchHistory(id))
        case .prepareContextFilesBound(let r):
            preparations += 1; captures.append(r)
            if hold { hold = false; await suspend() }
            if let failure { throw failure }
            let d = try FileContextDocument.decode(fileContextBytes(r), request: r)
            if forged {
                var p = d.preview; p.coverage = "forged"
                return .fileContext(FileContextDocument(preview: p, selectedPaths: d.selectedPaths, evidence: d.evidence,
                    matchingAnchors: d.matchingAnchors, scannedAnchors: d.scannedAnchors, truncated: d.truncated, bytes: d.bytes))
            }
            return .fileContext(d)
        case .prepareContextBound(let p, _, let original), .prepareContextTermsBound(let p, _, let original):
            defaults += 1; fullScopes.append(p)
            var preview = ContextPreview(project: p.id, snapshot: p.snapshot, mode: "context-only", state: "ready-for-review",
                original: original, proposed: original + FileContextDocument.quotedHeader + "Default", changed: true,
                approval: "not-requested", delivery: "not-attempted", provider: "not-invoked")
            if case .prepareContextTermsBound = op { preview.retrieval_mode = "ranked-terms"; preview.coverage = "ranked-terms; synthetic" }
            return .preview(preview)
        case .queryBound(let p, _), .queryTermsBound(let p, _):
            queries += 1; fullScopes.append(p)
            if case .queryTermsBound = op { return .query(QueryReport(project: p.id, snapshot: p.snapshot, currentness: "current-at-read",
                coverage: .string("indexed-source-lines-only; any-term literal text matches; no semantic/symbol coverage"), results: [], truncated: false,
                selection: "distinct-matched-terms-desc,total-nonoverlap-occurrences-desc,path-line-asc", terms: ["center"])) }
            return .query(QueryReport(project: p.id, snapshot: p.snapshot, currentness: "current-at-read", coverage: .string("lexical"), results: []))
        case .queryFilesBound(let r): return .filteredQuery(try FilteredQuery.decode(fileQueryBytes(r), request: r))
        case .indexBound: return .indexed(IndexReport(project: scope.id, snapshot: scope.snapshot!, files: 2, anchors: 2, coverage: .string("lexical"), empty: false))
        case .editContextBatchBound(let execution):
            executions.append(execution)
            if batchHold { batchHold = false; await suspend() }
            _ = try execution.claim(); throw ServiceError.failed
        case .refinePreview: providers += 1; throw ServiceError.invalid
        default: throw ServiceError.invalid
        }
    }
}

@Suite("Explicit mounted file-scoped Context")
struct FileContextTests {
    @MainActor private func model(_ core: FileContextCore) async -> CompanionModel {
        let m = CompanionModel(service: core, configured: true)
        m.select("alpha"); await m.waitForOperation(); m.openContext("n0"); await m.waitForOperation()
        m.editPreparation(query: "center", original: "Do NOT change permissions. é e\u{301} \"quotes\"\\\r\n\n")
        return m
    }
    @Test(arguments: [SourceRetrievalMode.literal, .rankedTerms])
    @MainActor func inertIndependentChoicesDefaultEmptyAndRefine(mode: SourceRetrievalMode) async throws {
        let c = FileContextCore(), m = await model(c)
        m.setSourceRetrievalMode(mode); m.setQueryFileFilter([])
        m.prepareContext(); await m.waitForOperation()
        #expect(await c.defaults == 1)
        #expect(await c.fullScopes.last?.sources == fileQueryScope.sources)
        let calls = await c.calls, base = m.humanContextRevisionBinding("n0"), editor = m.contextEditorRevision, original = m.originalDraft
        m.setContextFileFilter([]); m.setInspectionRadius(0)
        #expect(!m.canPrepareContext && m.canInspectRefinement)
        m.prepareContext(); await m.waitForOperation()
        #expect(await c.calls == calls && m.preview == nil)
        m.setContextFileFilter(["a.rs", "z.rs"])
        #expect(m.contextFileFilter == ["z.rs", "a.rs"])
        m.setContextFileFilter(["outside.rs"])
        #expect(m.contextFileFilter == ["z.rs", "a.rs"])
        m.setContextFileFilter(["z.rs"])
        #expect(await c.calls == calls && m.queryFileFilter == [] && m.canPrepareContext)
        m.prepareContext(); await m.waitForOperation()
        #expect(m.contextSelectedPaths == ["z.rs"] && m.preview?.original.utf8.elementsEqual(original.utf8) == true)
        #expect(m.evidence == nil && !m.canInspectSource(inspectionAnchor()))
        #expect(await c.captures.last?.project.sources == fileQueryScope.sources)
        #expect(m.humanContextRevisionBinding("n0") == base && m.contextEditorRevision == editor)
        var settings = ProviderSettings()
        settings.profiles = [ProviderProfile(id: "synthetic", endpoint: "http://127.0.0.1:9/v1/chat/completions", model: "synthetic", locality: .local)]
        settings.selectedProfileID = "synthetic"; settings.enabled = true
        m.setContextFileFilter([]); m.setRefinementRetrievalMode(mode)
        m.requestRefinement(settings: settings); await m.waitForOperation()
        let consent = try #require(m.pendingRefinement)
        #expect(consent.project.sources == fileQueryScope.sources && consent.retrievalMode == mode)
        #expect(await c.providers == 0)
        #expect(await c.preparations == 1)
        await m.shutdown()
    }

    @Test(arguments: ["subset", "query", "original", "query-subset", "query-text", "mode", "radius", "settings", "policy", "selection", "build", "incremental", "forget", "source-forget", "cancel", "config", "quit", "invalid"])
    @MainActor func ignoringACannotPublishAfterBOrOvertake(change: String) async throws {
        let c = FileContextCore(), m = await model(c)
        let original = m.originalDraft, editor = m.contextEditorRevision, base = m.humanContextRevisionBinding("n0")
        m.setContextFileFilter(["z.rs"]); await c.pause(); m.prepareContext(); await c.wait()
        switch change {
        case "subset": m.setContextFileFilter(["a.rs"]); m.prepareContext()
        case "query": m.editPreparation(query: "center λ", original: original); m.prepareContext()
        case "original": m.editPreparation(query: "center", original: "Exact B\r\n"); m.prepareContext()
        case "query-subset": m.setQueryFileFilter([])
        case "query-text": m.sourceQueryChanged()
        case "mode": m.setSourceRetrievalMode(.rankedTerms); m.prepareContext()
        case "radius": m.setInspectionRadius(1)
        case "settings": m.setRefinementRetrievalMode(.rankedTerms)
        case "policy": m.stageSources(["a.rs"])
        case "selection": m.select("beta")
        case "build": m.build()
        case "incremental": m.buildIncrementally()
        case "forget": m.requestForget()
        case "source-forget": m.requestSourceForget("z.rs")
        case "config": m.configure(executable: URL(fileURLWithPath: "/absent"), dataDirectory: URL(fileURLWithPath: "/absent-store"))
        case "quit": m.quit()
        case "invalid": m.editPreparation(query: "bad\0", original: original); m.prepareContext()
        default: m.cancel()
        }
        #expect(m.preview == nil)
        #expect(await c.preparations == 1)
        #expect(await !c.overtook)
        await c.finish(); await m.waitForOperation()
        #expect(await !c.overtook)
        if ["subset", "query", "original", "mode"].contains(change) {
            #expect(await c.preparations == 2)
            #expect(m.contextSelectedPaths == (change == "subset" ? ["a.rs"] : ["z.rs"]))
            #expect(m.preview?.original.utf8.elementsEqual(m.originalDraft.utf8) == true)
        } else { #expect(m.preview == nil) }
        if !["selection", "config"].contains(change) {
            #expect(m.history != nil && m.contextEditorRevision == editor && m.humanContextRevisionBinding("n0") == base)
            #expect(m.originalDraft == (change == "original" ? "Exact B\r\n" : original))
        }
        if change == "selection" { #expect(m.project?.id == "beta") }
        if change == "incremental" {
            let calls = await c.calls
            m.prepareContext(); await m.waitForOperation()
            #expect(m.lastError == .mutationUncertain)
            #expect(await c.calls == calls)
        }
        #expect(await c.providers == 0)
        await m.shutdown()
    }

    @Test(arguments: [ServiceError.failed, .invalid, .outputLimit, .timedOut, .scopeMismatch, .namespaceChanged])
    @MainActor func wholeFailuresDiscardOldPreviewNoDiagnosticsOrFallback(error: ServiceError) async throws {
        let c = FileContextCore(), m = await model(c)
        m.writeContext(id: "n0", kind: "note", text: "unsaved", update: true) // Missing captured base: conflict.
        let base = m.humanContextRevisionBinding("n0"), editor = m.contextEditorRevision, original = m.originalDraft
        m.setContextFileFilter(["z.rs"]); m.prepareContext(); await m.waitForOperation()
        #expect(m.preview != nil && m.lastError == .contextConflict)
        let calls = await c.calls
        await c.fail(error); m.prepareContext(); await m.waitForOperation()
        #expect(await c.calls == calls + 1)
        #expect(await c.defaults == 0)
        #expect(m.preview == nil && m.contextSelectedPaths == nil)
        if error == .namespaceChanged { #expect(m.project == nil && m.history == nil && m.originalDraft.isEmpty) }
        else {
            #expect(m.lastError == .contextConflict && m.humanContextRevisionBinding("n0") == base)
            #expect(m.contextEditorRevision == editor && m.originalDraft == original && m.history != nil)
        }
        await m.shutdown()
    }
    @Test @MainActor func typedForgeryReparsedAtAdoption() async throws {
        let c = FileContextCore(), m = await model(c)
        await c.forge(); m.setContextFileFilter(["z.rs"]); m.prepareContext(); await m.waitForOperation()
        #expect(m.preview == nil && m.lastError == .invalid)
        await m.shutdown()
    }
    @Test @MainActor func localInvalidEmptyAndPolicyChangesKeepCASConflictWithoutIO() async throws {
        let c = FileContextCore(), m = await model(c)
        m.writeContext(id: "n0", kind: "note", text: "unsaved", update: true)
        let base = m.humanContextRevisionBinding("n0"), editor = m.contextEditorRevision
        let calls = await c.calls
        m.setContextFileFilter(["z.rs"]); m.editPreparation(query: "bad\0", original: "unsent")
        m.prepareContext(); await m.waitForOperation()
        #expect(m.lastError == .contextConflict && m.status.contains(ServiceError.contextConflict.localizedDescription))
        m.setContextFileFilter([]); m.prepareContext(); await m.waitForOperation()
        #expect(m.lastError == .contextConflict && m.status.contains("Select at least one"))
        m.stageSources(["a.rs"])
        #expect(m.lastError == .contextConflict && m.status.contains(ServiceError.contextConflict.localizedDescription))
        #expect(m.humanContextRevisionBinding("n0") == base && m.contextEditorRevision == editor && m.originalDraft == "unsent")
        #expect(await c.calls == calls)
        await m.shutdown()
    }
    @Test(arguments: [false, true])
    @MainActor func batchReviewRevokedAndDispatchedUnknownJoined(dispatched: Bool) async throws {
        let c = FileContextCore(), m = await model(c)
        m.stageBatchUpdate(id: "n0", kind: "note", text: "copied unsaved draft", expected: m.humanContextRevisionBinding("n0"))
        m.openContext("n1"); await m.waitForOperation(); m.stageBatchRetire()
        m.setContextFileFilter(["z.rs"]); m.reviewBatch()
        let review = try #require(m.pendingBatchReview), base = m.humanContextRevisionBinding("n1"), editor = m.contextEditorRevision
        if dispatched { await c.pauseBatch(); m.applyBatch(review); await c.wait() }
        m.prepareContext()
        #expect(m.pendingBatchReview == nil)
        if dispatched {
            #expect(m.batchOutcomeUnknown)
            #expect(await c.preparations == 0)
            let execution = try #require(await c.executions.first)
            #expect(throws: (any Error).self) { try execution.claim() }
            await c.finish()
        } else { m.applyBatch(review) }
        await m.waitForOperation()
        #expect(m.preview != nil && m.stagedBatch.count == 2 && m.batchReceipt == nil)
        #expect(m.batchOutcomeUnknown == dispatched)
        if dispatched { #expect(m.batchStatus.contains("unknown")) }
        #expect(await !c.overtook)
        #expect(m.humanContextRevisionBinding("n1") == base && m.contextEditorRevision == editor)
        await m.shutdown()
    }
}

@Suite("Closed AM native frame")
struct FileContextDecoderTests {
    @Test(arguments: [SourceRetrievalMode.literal, .rankedTerms])
    func closedShapeExactOriginalAndWholeLFBudget(mode: SourceRetrievalMode) throws {
        let original = "Do NOT change permissions. é e\u{301} \"quoted\"\\\r\n\n"
        let r = try FileContextRequest(project: fileQueryScope, query: "center", original: original, mode: mode, selectedPaths: ["z.rs"])
        let data = try fileContextBytes(r), good = String(decoding: data, as: UTF8.self)
        let parsed = try FileContextDocument.decode(data, request: r)
        #expect(parsed.preview.original.utf8.elementsEqual(original.utf8))
        for bytes in [try fileContextBytes(r, stale: true), try fileContextBytes(r, empty: true)] {
            let needsInput = try FileContextDocument.decode(bytes, request: r)
            #expect(needsInput.preview.state == "needs-input" && !needsInput.preview.changed)
            #expect(needsInput.preview.proposed.utf8.elementsEqual(original.utf8))
        }
        let hostile: [String] = [String(good.dropLast()), good + "{}", String(good.dropLast(3)),
            "{\"version\":1," + String(good.dropFirst()), "{\"vers\\u0069on\":1," + String(good.dropFirst()),
            "{\"extra\":null," + String(good.dropFirst()), good.replacingOccurrences(of: "\"version\":1", with: "\"version\":1.0"),
            good.replacingOccurrences(of: "\"version\":1", with: "\"version\":true"),
            good.replacingOccurrences(of: "\"line\":3", with: "\"line\":3,\"l\\u0069ne\":3"),
            good.replacingOccurrences(of: "\"line\":3", with: "\"line\":3e0"),
            good.replacingOccurrences(of: "\"text\":\"center λ\"", with: "\"text\":\"absent\"")]
        for frame in hostile { #expect(throws: (any Error).self) { try FileContextDocument.decode(Data(frame.utf8), request: r) } }
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let headers: [(String, Any)] = [("version", "1"), ("snapshot", "bad"), ("project", "beta"),
            ("selected_paths", ["a.rs"]), ("selected_paths", ["z.rs", "z.rs"]), ("retrieval_mode", "wrong"),
            ("coverage", "semantic"), ("selection", "wrong"), ("matching_anchors", true), ("matching_anchors", 0),
            ("scanned_anchors", 0), ("scanned_anchors", 4097), ("truncated", true), ("truncated", 0),
            ("original", original.precomposedStringWithCanonicalMapping), ("original", original.trimmingCharacters(in: .whitespacesAndNewlines)),
            ("original", original + "\0"), ("proposed", original), ("changed", false), ("state", "needs-input"),
            ("provider", "invoked"), ("approval", "requested"), ("delivery", "sent"), ("mode", "refine"), ("limitations", "wrong")]
        for (key, value) in headers {
            var bad = object; bad[key] = value
            var bytes = try JSONSerialization.data(withJSONObject: bad); bytes.append(10)
            #expect(throws: (any Error).self) { try FileContextDocument.decode(bytes, request: r) }
        }
        for key in object.keys {
            var missing = object; missing.removeValue(forKey: key)
            var bytes = try JSONSerialization.data(withJSONObject: missing); bytes.append(10)
            #expect(throws: (any Error).self) { try FileContextDocument.decode(bytes, request: r) }
        }
        let rows = try #require(object["evidence"] as? [[String: Any]])
        let changes: [(String, Any)] = [("extra", true), ("matched_terms", 1), ("occurrences", 1), ("id", "source-1"),
            ("project", "beta"), ("path", "a.rs"), ("path", "outside.rs"), ("line", true), ("line", 0), ("line", 4097),
            ("line", 1.5), ("source_hash", String(repeating: "X", count: 64)), ("producer", "not a producer"),
            ("kind", "human"), ("currentness", "stale-or-unindexed"), ("coverage", "semantic"),
            ("text", "center\0"), ("text", "center\nλ"), ("text", String(repeating: "x", count: 1025))]
        for (key, value) in changes {
            var bad = object, row = rows[0]; row[key] = value; bad["evidence"] = [row]
            var bytes = try JSONSerialization.data(withJSONObject: bad); bytes.append(10)
            #expect(throws: (any Error).self) { try FileContextDocument.decode(bytes, request: r) }
        }
        var duplicate = object, second = rows[0]; second["id"] = "source-1"
        duplicate["evidence"] = [rows[0], second]; duplicate["matching_anchors"] = 2; duplicate["scanned_anchors"] = 2
        var duplicateBytes = try JSONSerialization.data(withJSONObject: duplicate); duplicateBytes.append(10)
        #expect(throws: (any Error).self) { try FileContextDocument.decode(duplicateBytes, request: r) }
        let exact = Data((String(repeating: " ", count: 8192 - data.count) + good).utf8)
        #expect(exact.count == 8192)
        _ = try FileContextDocument.decode(exact, request: r)
        #expect(throws: (any Error).self) { try FileContextDocument.decode(Data([32]) + exact, request: r) }
    }
    @Test func pureRequestAdmissionAndCanonicalFullCapture() throws {
        let originals = ["", "a\0b", String(repeating: "é", count: 2049)]
        for original in originals { #expect(throws: (any Error).self) { try FileContextRequest(project: fileQueryScope, query: "center", original: original, mode: .literal, selectedPaths: ["z.rs"]) } }
        for paths in [[], ["z.rs", "z.rs"], ["outside.rs"], Array(repeating: "z.rs", count: 65)] {
            #expect(throws: (any Error).self) { try FileContextRequest(project: fileQueryScope, query: "center", original: "original", mode: .literal, selectedPaths: paths) }
        }
        let r = try FileContextRequest(project: fileQueryScope, query: "center", original: String(repeating: "é", count: 2048), mode: .literal, selectedPaths: ["a.rs", "z.rs"])
        #expect(r.selectedPaths == fileQueryScope.sources && r.project == fileQueryScope && r.original.utf8.count == 4096)
        let legacy = Project(id: fileQueryScope.id, root: fileQueryScope.root, sources: fileQueryScope.sources)
        #expect(throws: (any Error).self) { try FileContextRequest(project: legacy, query: "center", original: "o", mode: .literal, selectedPaths: ["z.rs"]) }
        #expect(throws: (any Error).self) { try FileContextRequest(project: fileQueryScope, query: "center\n", original: "o", mode: .rankedTerms, selectedPaths: ["z.rs"]) }
    }
    @Test(arguments: [SourceRetrievalMode.literal, .rankedTerms])
    func truncationCanonicalSubsetAndStaleStateConsistency(mode: SourceRetrievalMode) throws {
        let r = try FileContextRequest(project: fileQueryScope, query: "center", original: "exact", mode: mode, selectedPaths: ["a.rs", "z.rs"])
        let good = try fileContextBytes(r)
        var o = try #require(JSONSerialization.jsonObject(with: good) as? [String: Any])
        o["matching_anchors"] = 2; o["scanned_anchors"] = 2; o["truncated"] = true
        let oldCoverage = try #require(o["coverage"] as? String)
        if mode == .literal { o["coverage"] = oldCoverage + "; bounded selection omits additional matches" }
        else { o["coverage"] = oldCoverage.replacingOccurrences(of: "; selection=", with: "; bounded selection omits additional matches; selection=") }
        var data = try JSONSerialization.data(withJSONObject: o); data.append(10)
        let d = try FileContextDocument.decode(data, request: r)
        #expect(d.truncated && d.matchingAnchors == 2 && d.evidence.count == 1)
        var wrongOrder = o; wrongOrder["selected_paths"] = ["a.rs", "z.rs"]
        var reversed = try JSONSerialization.data(withJSONObject: wrongOrder); reversed.append(10)
        #expect(throws: (any Error).self) { try FileContextDocument.decode(reversed, request: r) }
        let stale = try #require(JSONSerialization.jsonObject(with: fileContextBytes(r, stale: true)) as? [String: Any])
        let changes: [(String, Any)] = [("state", "ready-for-review"), ("changed", true), ("proposed", "replacement"),
            ("matching_anchors", 1), ("truncated", true), ("evidence", o["evidence"]!)]
        for (key, value) in changes {
            var invalid = stale; invalid[key] = value
            var bytes = try JSONSerialization.data(withJSONObject: invalid); bytes.append(10)
            #expect(throws: (any Error).self) { try FileContextDocument.decode(bytes, request: r) }
        }
    }
}
