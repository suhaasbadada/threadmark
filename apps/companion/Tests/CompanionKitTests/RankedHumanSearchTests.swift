import Foundation
import Testing
@testable import CompanionKit

let apProject = Project(id: "alpha", root: "/synthetic/ranked", sources: [], rootIdentity: .string("r1"), incarnation: String(repeating: "a", count: 32))
func apRequest(_ query: String = "  ÉCHO \"quoted\" ÉCHO  ", kinds: [String] = InputPolicy.contextKinds.sorted()) throws -> RankedHumanSearchRequest {
    try RankedHumanSearchRequest(binding: HumanContextReadBinding(project: apProject), query: query, kinds: kinds)
}
func apPayload(_ request: RankedHumanSearchRequest, text: String = "ÉCHO \"quoted\"") -> [String: Any] {
    ["version": "human-search-ranked-v1", "project": request.binding.project,
     "root_identity": request.binding.rootIdentity, "incarnation": request.binding.incarnation,
     "selected_kinds": request.kinds, "terms": request.terms, "producer": "human-authored",
     "status": "active-latest-at-read", "authority": "context-not-authorization-or-observed-truth",
     "coverage": RankedHumanSearch.coverageLabel, "selection": RankedHumanSearch.selectionLabel,
     "limitations": RankedHumanSearch.limitationsLabel,
     "matched_entries": 1, "omitted_entries": 0, "truncated": false,
     "results": [["id": "memo", "revision": 1, "kind": request.kinds[0], "text": text,
                  "producer": "human-authored", "status": "active", "matched_terms": request.terms, "occurrences": request.terms.count]]]
}
func apFrame(_ payload: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes]) + Data([10])
}
func apBadFrames(_ r: RankedHumanSearchRequest) throws -> [Data] {
    let payload = apPayload(r), valid = try apFrame(payload), text = String(decoding: valid, as: UTF8.self)
    var bad = [Data(valid.dropLast()), Data(valid.prefix(64)), valid + valid, Data(repeating: 120, count: 8193)]
    for (key, value): (String, Any) in [("version", "human-search-kind-filter-v1"), ("project", "beta"), ("root_identity", "other"), ("incarnation", String(repeating: "b", count: 32)), ("selected_kinds", ["note"]), ("terms", ["other"]), ("producer", "observed"), ("status", "active"), ("authority", "permission"), ("coverage", "all"), ("selection", "semantic"), ("limitations", "none"), ("matched_entries", true), ("matched_entries", 4097), ("matched_entries", 0), ("omitted_entries", 1), ("truncated", true), ("truncated", 0), ("extra", "data")] {
        var p = payload; p[key] = value; bad.append(try apFrame(p))
    }
    for key in payload.keys { var p = payload; p.removeValue(forKey: key); bad.append(try apFrame(p)) }
    for (key, value): (String, Any) in [("id", "../bad"), ("revision", 0), ("revision", 33), ("revision", true), ("kind", "unknown"), ("text", ""), ("text", "x\0"), ("text", String(repeating: "x", count: 4097)), ("text", "unmatched"), ("matched_terms", Array(r.terms.reversed())), ("matched_terms", [r.terms[0]]), ("occurrences", true), ("occurrences", 3), ("occurrences", -1), ("extra", 1), ("producer", "source"), ("status", "retired")] {
        var p = payload, rows = payload["results"] as! [[String: Any]]; rows[0][key] = value; p["results"] = rows; bad.append(try apFrame(p))
    }
    for (key, replacement) in [("version", "\"version\":\"human-search-ranked-v1\",\"ver\\u0073ion\":"), ("kind", "\"kind\":\"note\",\"kind\":"), ("occurrences", "\"occurrences\":2,\"occurr\\u0065nces\":")] {
        bad.append(Data(text.replacingOccurrences(of: "\"\(key)\":", with: replacement).utf8))
    }
    for number in ["1.0", "1e0", "-1", "01", "9999999999999999999999999999999999999", "null"] {
        bad.append(Data(text.replacingOccurrences(of: "\"matched_entries\":1", with: "\"matched_entries\":\(number)").utf8))
    }
    var duplicate = payload; duplicate["results"] = Array(repeating: (payload["results"] as! [[String: Any]])[0], count: 2); duplicate["matched_entries"] = 2
    bad.append(try apFrame(duplicate))
    return bad
}

actor APRankedCore: CoreService {
    let scope: Project
    init(scope: Project = apProject) { self.scope = scope }
    var calls = 0, oldSearches = 0, filtered = 0
    var requests: [RankedHumanSearchRequest] = []
    var hold = false, didStart = false, fail = false, forged = false, active = false, overtook = false
    var readError: ServiceError?
    var held: CheckedContinuation<Void, Never>?, started: CheckedContinuation<Void, Never>?
    func arm() { hold = true; didStart = false }
    func failing(_ value: Bool) { fail = value }
    func error(_ value: ServiceError) { readError = value }
    func forge() { forged = true }
    func wait() async { if !didStart { await withCheckedContinuation { started = $0 } } }
    func release() { held?.resume(); held = nil }
    private func pauseIfArmed() async {
        didStart = true; started?.resume(); started = nil
        if hold { hold = false; active = true; await withCheckedContinuation { held = $0 }; active = false }
    }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        calls += 1
        if active { overtook = true }
        switch operation {
        case .project: return .project(scope)
        case .contextsBound: return .contexts(ContextList(project: "alpha", contexts: []))
        case .contextBound(_, let id):
            return .context(ContextHistory(project: "alpha", id: id, producer: "human-authored", authority: .string("context-not-authorization-or-observed-truth"), history: [ContextRevision(revision: 1, kind: "note", text: "Synthetic human history", retired: false)]))
        case .searchHumanContextTermsBound(let request):
            requests.append(request); await pauseIfArmed()
            if fail { throw ServiceError.failed }
            if let readError { throw readError }
            let bytes = try apFrame(apPayload(request, text: request.query))
            let result = try RankedHumanSearch.decode(bytes, request: request)
            if forged {
                var p = apPayload(request, text: request.query)
                var rows = p["results"] as! [[String: Any]]; rows[0]["id"] = "forged"; p["results"] = rows
                return .rankedHumanSearch(RankedHumanSearch(document: try RankedHumanSearch.decode(apFrame(p), request: request).document, bytes: bytes))
            }
            return .rankedHumanSearch(result)
        case .prepareContextFilesBound(let request):
            await pauseIfArmed()
            return .fileContext(try FileContextDocument.decode(fileContextBytes(request), request: request))
        case .searchHumanContextBound: oldSearches += 1; await pauseIfArmed(); throw ServiceError.failed
        case .searchHumanContextKindsBound: filtered += 1; await pauseIfArmed(); throw ServiceError.failed
        case .editContextBatchBound(let execution): _ = try execution.claim(); throw ServiceError.failed
        default: throw ServiceError.unavailable
        }
    }
}

@Suite("AP ranked human-note search")
struct RankedHumanSearchTests {
    @Test func ap02LimitsUnicodeByteIdentity() throws {
        #expect(try apRequest().terms == ["écho", "\"quoted\""])
        #expect(try apRequest("ΟΣ ΟΣ İ é e\u{301}").terms == ["ος", "i\u{307}", "é", "e\u{301}"])
        for q in ["", " ", "x\n", String(repeating: "x", count: 65), (1...9).map(String.init).joined(separator: " "), String(repeating: "x ", count: 129)] {
            #expect(throws: (any Error).self) { try apRequest(q) }
        }
        for kinds in [[], ["note", "note"], ["unknown"]] { #expect(throws: (any Error).self) { try apRequest(kinds: kinds) } }
    }
    @Test func ap03WholeFrameAndForgedProjection() throws {
        let r = try apRequest(), bytes = try apFrame(apPayload(r)), result = try RankedHumanSearch.decode(bytes, request: r)
        try result.validate(request: r, scope: apProject)
        for frame in try apBadFrames(r) { #expect(throws: (any Error).self) { try RankedHumanSearch.decode(frame, request: r) } }
        let exact = Data(bytes.dropLast()) + Data(repeating: 32, count: 8192 - bytes.count) + Data([10])
        #expect(exact.count == 8192); _ = try RankedHumanSearch.decode(exact, request: r)
        #expect(throws: (any Error).self) { try RankedHumanSearch.decode(exact + Data([10]), request: r) }
        let forged = RankedHumanSearch(document: result.document, bytes: Data("{}\n".utf8))
        #expect(throws: (any Error).self) { try forged.validate(request: r, scope: apProject) }
        // Canonically equivalent strings are NOT byte-identical matches.
        let combining = try apRequest("é", kinds: ["note"])
        #expect(throws: (any Error).self) { try RankedHumanSearch.decode(apFrame(apPayload(combining, text: "e\u{301}")), request: combining) }
        let overlap = try apRequest("aa a", kinds: ["note"])
        var p = apPayload(overlap, text: "aaaa"); var rows = p["results"] as! [[String: Any]]; rows[0]["occurrences"] = 6; p["results"] = rows
        _ = try RankedHumanSearch.decode(apFrame(p), request: overlap)
        var sorted = apPayload(overlap, text: "aaaa")
        var sortedRows = sorted["results"] as! [[String: Any]]
        sortedRows[0]["id"] = "a"; sortedRows[0]["occurrences"] = 6
        var second = sortedRows[0]; second["id"] = "b"; sortedRows.append(second)
        sorted["results"] = sortedRows; sorted["matched_entries"] = 2
        _ = try RankedHumanSearch.decode(apFrame(sorted), request: overlap)
        sorted["results"] = Array(sortedRows.reversed())
        #expect(throws: (any Error).self) { try RankedHumanSearch.decode(apFrame(sorted), request: overlap) }
        let excluded = try apRequest(kinds: ["note"])
        var unselected = apPayload(excluded); var entries = unselected["results"] as! [[String: Any]]; entries[0]["kind"] = "decision"; unselected["results"] = entries
        #expect(throws: (any Error).self) { try RankedHumanSearch.decode(apFrame(unselected), request: excluded) }
    }
    @Test @MainActor func ap01ZeroIOAndOldRoutes() async throws {
        let core = APRankedCore(), model = CompanionModel(service: APRankedCore(), configured: true)
        _ = HumanContextSearchView(model: model)
        let selected = CompanionModel(service: core, configured: true)
        #expect(selected.humanSearchMode == .literal)
        selected.setHumanSearchMode(.rankedAnyTerms); selected.setHumanSearchKindFilter(["note"]); selected.humanSearchQueryChanged()
        #expect(await core.calls == 0)
        selected.select("alpha"); await selected.waitForOperation()
        let calls = await core.calls
        selected.setHumanSearchKindFilter([]); #expect(!selected.canSearchHumanNotes("needle"))
        selected.searchHumanContext("needle"); await selected.waitForOperation(); #expect(await core.calls == calls)
        selected.setHumanSearchKindFilter(nil); selected.searchHumanContext("needle"); await selected.waitForOperation()
        #expect(await core.requests.first?.kinds == InputPolicy.contextKinds.sorted())
        #expect(selected.rankedHumanSearch != nil && selected.humanSearch == nil)
        selected.setHumanSearchMode(.literal); selected.searchHumanContext("needle"); await selected.waitForOperation()
        #expect(await core.oldSearches == 1)
        selected.setHumanSearchKindFilter(["note"]); selected.searchHumanContext("needle"); await selected.waitForOperation()
        #expect(await core.filtered == 1)
        await selected.shutdown(); await model.shutdown()
    }
    @Test @MainActor func ap04IgnoringCancelJoinsBeforeSuccessorAndPreservesHistory() async throws {
        let core = APRankedCore(), model = CompanionModel(service: APRankedCore(), configured: true)
        let selected = CompanionModel(service: core, configured: true)
        selected.select("alpha"); await selected.waitForOperation(); selected.openContext("memo"); await selected.waitForOperation()
        selected.editPreparation(query: "source", original: "Synthetic original unsaved")
        let base = try #require(selected.humanContextRevisionBinding("memo")), editor = selected.contextEditorRevision
        selected.setHumanSearchMode(.rankedAnyTerms); await core.arm()
        selected.searchHumanContext("first"); await core.wait()
        selected.humanSearchQueryChanged(); selected.setHumanSearchKindFilter(["decision"])
        let calls = await core.calls
        selected.searchHumanContext("second"); #expect(await core.calls == calls)
        await core.release(); await selected.waitForOperation()
        #expect(await !core.overtook)
        #expect(await core.requests.map(\.query) == ["first", "second"])
        #expect(selected.rankedHumanSearch?.document.terms == ["second"])
        #expect(selected.history?.id == "memo" && selected.humanContextRevisionBinding("memo") == base)
        #expect(selected.originalDraft == "Synthetic original unsaved" && selected.contextEditorRevision == editor)
        let adopted = try #require(selected.rankedHumanSearch)
        let before = await core.calls
        selected.inspectHumanSearchEntry("forged"); #expect(await core.calls == before)
        selected.inspectRankedHumanSearchEntry("forged", result: adopted); #expect(await core.calls == before)
        selected.searchHumanContext("second"); await selected.waitForOperation()
        let current = try #require(selected.rankedHumanSearch), after = await core.calls
        selected.inspectRankedHumanSearchEntry("memo", result: adopted); #expect(await core.calls == after)
        selected.inspectRankedHumanSearchEntry("memo", result: current); await selected.waitForOperation(); #expect(await core.calls > after)
        await core.failing(true); selected.searchHumanContext("second"); await selected.waitForOperation()
        #expect(selected.rankedHumanSearch == nil && selected.history?.id == "memo")
        await core.failing(false); await core.forge(); selected.searchHumanContext("second"); await selected.waitForOperation()
        #expect(selected.rankedHumanSearch == nil && selected.history?.id == "memo")
        let forgedCalls = await core.calls; selected.inspectHumanSearchEntry("forged"); #expect(await core.calls == forgedCalls)
        await selected.shutdown(); await model.shutdown()
    }
    @Test(arguments: ["mode", "kinds", "query", "policy", "configuration", "selection", "cancel", "quit", "build", "forget", "sourceForget"])
    @MainActor func ap04Lifecycle(action: String) async {
        let core = APRankedCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.setHumanSearchMode(.rankedAnyTerms); await core.arm(); model.searchHumanContext("first"); await core.wait()
        switch action {
        case "mode": model.setHumanSearchMode(.literal)
        case "kinds": model.setHumanSearchKindFilter(["note"])
        case "query": model.humanSearchQueryChanged()
        case "policy": model.stageSources(["../unsafe.rs"])
        case "configuration": model.configure(executable: URL(fileURLWithPath: "/synthetic/absent"), dataDirectory: URL(fileURLWithPath: "/synthetic/store"))
        case "selection": model.select(nil)
        case "cancel": model.cancel()
        case "quit": model.quit()
        case "build": model.build()
        case "forget": model.requestForget()
        default: model.requestSourceForget("a.rs")
        }
        await core.release(); await model.waitForOperation()
        #expect(model.rankedHumanSearch == nil)
        if ["mode", "kinds", "query", "policy", "cancel", "build", "forget", "sourceForget"].contains(action) { #expect(model.history?.id == "memo") }
        await model.shutdown()
    }
    @Test @MainActor func ap04AJReviewRevokedAndUnknownOutcomeSurvivesReadonlySuccess() async throws {
        let core = APRankedCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.stageBatchUpdate(id: "memo", kind: "note", text: "Synthetic unsaved", expected: model.humanContextRevisionBinding("memo"))
        model.openContext("other"); await model.waitForOperation(); model.stageBatchRetire()
        model.reviewBatch(); let old = try #require(model.pendingBatchReview)
        let calls = await core.calls
        model.setHumanSearchMode(.rankedAnyTerms); model.applyBatch(old)
        #expect(model.pendingBatchReview == nil)
        #expect(await core.calls == calls)
        model.reviewBatch(); model.applyBatch(try #require(model.pendingBatchReview)); await model.waitForOperation()
        #expect(model.batchOutcomeUnknown && model.batchStatus.contains("unknown"))
        let intent = model.stagedBatch.count, warning = model.batchStatus
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.rankedHumanSearch != nil && model.batchOutcomeUnknown)
        #expect(model.stagedBatch.count == intent && model.batchStatus == warning && !model.canReviewBatch)
        await model.shutdown()
    }
    @Test(arguments: ["ranked-notes", "file-context"]) @MainActor
    func integratedContextAndNoteSuccessorsJoinAndKeepIndependentScopes(predecessor: String) async throws {
        let core = APRankedCore(scope: fileQueryScope), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "Exact unsent original\r\n")
        model.writeContext(id: "memo", kind: "note", text: "Unsaved draft", update: true)
        let base = try #require(model.humanContextRevisionBinding("memo")), editor = model.contextEditorRevision
        model.setHumanSearchMode(.rankedAnyTerms)
        model.setQueryFileFilter([]); model.setContextFileFilter(["z.rs"])
        await core.arm()
        if predecessor == "ranked-notes" { model.searchHumanContext("first") }
        else { model.prepareContext() }
        await core.wait()
        let calls = await core.calls
        if predecessor == "ranked-notes" {
            model.setContextFileFilter(["a.rs"]); model.prepareContext()
        } else {
            model.cancel(); model.searchHumanContext("second")
        }
        #expect(await core.calls == calls)
        await core.release(); await model.waitForOperation()
        #expect(await !core.overtook)
        #expect(model.queryFileFilter == [] && model.humanSearchMode == .rankedAnyTerms)
        #expect(model.history?.id == "memo" && model.humanContextRevisionBinding("memo") == base)
        #expect(model.contextEditorRevision == editor && model.lastError == .contextConflict)
        #expect(model.originalDraft == "Exact unsent original\r\n")
        if predecessor == "ranked-notes" {
            #expect(model.rankedHumanSearch == nil && model.contextSelectedPaths == ["a.rs"])
            #expect(model.preview?.original == model.originalDraft)
        } else {
            #expect(model.preview == nil && model.contextFileFilter == ["z.rs"])
            #expect(model.rankedHumanSearch?.document.terms == ["second"])
        }
        await model.shutdown()
    }
    @Test(arguments: [false, true]) @MainActor
    func ap04ModeChangeCancelsOldLiteralAndAEPreservingCAS(filtered: Bool) async throws {
        let core = APRankedCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        let base = try #require(model.humanContextRevisionBinding("memo"))
        model.editPreparation(query: "source", original: "Synthetic exact unsaved original")
        model.writeContext(id: "memo", kind: "note", text: "Synthetic unsaved editor", update: true)
        #expect(model.lastError == .contextConflict)
        if filtered { model.setHumanSearchKindFilter(["note"]) }
        await core.arm(); model.searchHumanContext("literal"); await core.wait()
        model.setHumanSearchMode(.rankedAnyTerms)
        #expect(model.history?.id == "memo" && model.humanContextRevisionBinding("memo") == base && model.lastError == .contextConflict)
        model.searchHumanContext("ranked"); await core.release(); await model.waitForOperation()
        #expect(await !core.overtook)
        #expect(model.rankedHumanSearch?.document.terms == ["ranked"] && model.lastError == .contextConflict)
        #expect(model.history?.id == "memo" && model.humanContextRevisionBinding("memo") == base)
        #expect(model.originalDraft == "Synthetic exact unsaved original")
        await model.shutdown()
    }
    @Test(arguments: [ServiceError.failed, .timedOut, .canceled, .outputLimit, .invalid]) @MainActor
    func ap04SameNamespaceFailuresPreserveHumanState(error: ServiceError) async throws {
        let core = APRankedCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        let base = try #require(model.humanContextRevisionBinding("memo")), editor = model.contextEditorRevision
        model.editPreparation(query: "source", original: "Synthetic original bytes 📝")
        model.writeContext(id: "memo", kind: "note", text: "Synthetic unsaved", update: true)
        model.setHumanSearchMode(.rankedAnyTerms); await core.error(error)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.rankedHumanSearch == nil && model.history?.id == "memo" && model.lastError == .contextConflict)
        #expect(model.humanContextRevisionBinding("memo") == base && model.contextEditorRevision == editor)
        #expect(model.originalDraft == "Synthetic original bytes 📝")
        await model.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_RANKED_HUMAN_FIXTURE_BINARY"] != nil))
    func ap05CArgvEOFAndHostileFrames() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_RANKED_HUMAN_FIXTURE_BINARY"])
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: fixture.root)
        let request = try apRequest(), valid = try apFrame(apPayload(request)), file = fixture.root.appendingPathComponent("response.json")
        try valid.write(to: file)
        guard case .rankedHumanSearch(let result) = try await adapter.perform(.searchHumanContextTermsBound(request)) else { throw ServiceError.invalid }
        #expect(result.document.terms == request.terms)
        for bytes in try apBadFrames(request) {
            try bytes.write(to: file)
            await #expect(throws: (any Error).self) { try await adapter.perform(.searchHumanContextTermsBound(request)) }
        }
        let exact = Data(valid.dropLast()) + Data(repeating: 32, count: 8192 - valid.count) + Data([10])
        try exact.write(to: file); _ = try await adapter.perform(.searchHumanContextTermsBound(request))
    }
}
