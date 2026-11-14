// TM-01–04/07/10; Z-A1–A5, P2-A1/A3/A4/A6, P3-A3/A4/A5/A6.
import Foundation
import Testing
@testable import CompanionKit

let inspectionHash = String(repeating: "a", count: 64)
let inspectionScope = Project(id: "alpha", root: "/synthetic/inspection", sources: ["a.rs"],
    snapshot: .string(inspectionHash), rootIdentity: .string("root-identity"), incarnation: String(repeating: "b", count: 32))

func inspectionAnchor(_ line: Int = 3, text: String = "center λ") -> Evidence {
    Evidence(project: "alpha", path: "a.rs", line: line, text: text, source_hash: inspectionHash,
             producer: "lexical-v1", kind: "observed-source-line", currentness: "current-at-read", coverage: .string("lexical"))
}
func inspectionBytes(_ request: SourceInspectionRequest) throws -> Data {
    let a = request.anchor, p = request.project
    let first = max(1, a.line - request.radius), last = min(5, a.line + request.radius)
    let lines: [[String: Any]] = (first...last).map { line in
        ["line": line, "text": line == a.line ? a.text : (line == 2 ? "" : "neighbor λ"),
         "is_anchor": line == a.line, "kind": line == a.line ? "indexed-anchor" : "observed-source-text"]
    }
    guard case .string(let identity) = p.root_identity, case .string(let snapshot) = p.snapshot else { throw ServiceError.invalid }
    var data = try JSONSerialization.data(withJSONObject: ["format": "threadmark-source-anchor-inspection", "version": 1,
        "project": p.id, "root_identity": identity, "incarnation": p.incarnation!, "snapshot": snapshot,
        "path": a.path, "source_hash": a.source_hash, "producer": a.producer,
        "anchor_line": a.line, "radius": request.radius, "currentness": "current-at-read", "lines": lines], options: [.sortedKeys, .withoutEscapingSlashes])
    data.append(10); return data
}

private actor InspectionCore: CoreService {
    var scope = inspectionScope
    var requests: [SourceInspectionRequest] = []
    var failure: ServiceError?
    var delayed = false
    var entered: CheckedContinuation<Void, Never>?
    var release: CheckedContinuation<Void, Never>?
    var active = false
    var successorOvertook = false
    var inspections = 0
    var projectReads = 0
    func hold() { delayed = true }
    func waitUntilEntered() async { if active { return }; await withCheckedContinuation { entered = $0 } }
    func finish() { release?.resume(); release = nil }
    func setFailure(_ value: ServiceError) { failure = value }
    func replaceScope(_ value: Project) { scope = value }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        switch operation {
        case .project: projectReads += 1; return .project(scope)
        case .contextsBound: return .contexts(ContextList(project: "alpha", contexts: []))
        case .contextBound:
            return .context(ContextHistory(project: "alpha", id: "memo", producer: "human-authored", authority: .string("human"),
                history: [ContextRevision(revision: 1, kind: "note", text: "human history", retired: false)]))
        case .queryBound, .queryTermsBound:
            if active { successorOvertook = true }
            return .query(QueryReport(project: "alpha", snapshot: scope.snapshot, currentness: "current-at-read",
                                      coverage: .string("lexical"), results: [inspectionAnchor(), inspectionAnchor(4, text: "center two")]))
        case .indexBound:
            if active { successorOvertook = true }
            return .indexed(IndexReport(project: "alpha", snapshot: .string(inspectionHash), files: 1,
                                        anchors: 2, coverage: .string("lexical"), empty: false))
        case .inspectSourceAnchorBound(let request):
            requests.append(request); inspections += 1; active = true
            entered?.resume(); entered = nil
            if delayed { await withCheckedContinuation { release = $0 } }
            active = false
            if let failure { throw failure }
            guard (try? HumanContextReadBinding(project: scope)) == (try? HumanContextReadBinding(project: request.project)) else { throw ServiceError.namespaceChanged }
            guard ProjectExportDocument.exact(scope, request.project) else { throw ServiceError.readRequiresRefresh }
            return .sourceInspection(try SourceInspectionDocument.decode(inspectionBytes(request), request: request))
        default: throw ServiceError.invalid
        }
    }
}

@Suite("Explicit native source inspection")
struct SourceInspectionTests {
    @Test(arguments: [SourceRetrievalMode.literal, .rankedTerms])
    @MainActor func explicitOnlyAndEveryResultMembership(mode: SourceRetrievalMode) async throws {
        let core = InspectionCore()
        let subject = CompanionModel(service: core, configured: true)
        subject.select("alpha"); await subject.waitForOperation()
        subject.openContext("memo"); await subject.waitForOperation()
        subject.editPreparation(query: "center", original: "unsent original")
        subject.setSourceRetrievalMode(mode); subject.query("center"); await subject.waitForOperation()
        subject.setInspectionRadius(3)
        let metadataReads = await core.projectReads
        #expect(await core.inspections == 0)
        #expect(!subject.canInspectSource(inspectionAnchor(1, text: "invented")))
        subject.inspectSource(inspectionAnchor(1, text: "invented"))
        #expect(await core.inspections == 0)
        for anchor in try #require(subject.evidence).results {
            #expect(subject.canInspectSource(anchor))
            subject.inspectSource(anchor); await subject.waitForOperation()
            let document = try #require(subject.sourceInspection)
            #expect(document.lines.first?.number == max(1, anchor.line - 3))
            #expect(document.lines.first(where: \.isAnchor)?.text == anchor.text)
            #expect(document.lines.contains(where: { $0.number == 2 && $0.text.isEmpty }))
        }
        #expect(await core.inspections == 2)
        #expect(await core.projectReads == metadataReads)
        #expect(subject.history?.history.last?.text == "human history" && subject.originalDraft == "unsent original")
        #expect(subject.automaticRefreshConsent == nil)
        subject.setInspectionRadius(0)
        let calls = await core.inspections
        #expect(subject.sourceInspection == nil && calls == 2)
        subject.inspectSource(inspectionAnchor()); await subject.waitForOperation()
        #expect(subject.sourceInspection?.lines.count == 1)
        subject.sourceQueryChanged()
        #expect(!subject.canInspectSource(inspectionAnchor()))
        await subject.shutdown()
    }

    @Test(arguments: [ServiceError.failed, .invalid, .unavailable, .outputLimit])
    @MainActor func failurePreservesHumanAndQueryButRequiresExplicitFreshQuery(error: ServiceError) async throws {
        let core = InspectionCore()
        let subject = CompanionModel(service: core, configured: true)
        subject.select("alpha"); await subject.waitForOperation()
        subject.openContext("memo"); await subject.waitForOperation()
        subject.editPreparation(query: "center", original: "original")
        subject.query("center"); await subject.waitForOperation()
        let editor = subject.contextEditorRevision, query = subject.evidence
        let metadataReads = await core.projectReads
        await core.setFailure(error)
        subject.inspectSource(inspectionAnchor()); await subject.waitForOperation()
        #expect(subject.sourceInspection == nil && subject.evidence == query)
        #expect(subject.history?.history.last?.text == "human history" && subject.originalDraft == "original")
        #expect(subject.contextEditorRevision == editor && !subject.canInspectSource(inspectionAnchor()))
        #expect(await core.projectReads == metadataReads)
        await subject.shutdown()
    }

    @Test(arguments: ["cancel", "query", "radius", "settings", "policy", "selection", "quit", "build", "config", "query-change"])
    @MainActor func lateOutputCannotAdoptAndSuccessorsJoin(action: String) async throws {
        let core = InspectionCore()
        let model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original")
        model.query("center"); await model.waitForOperation()
        let query = model.evidence, editor = model.contextEditorRevision
        await core.hold()
        model.inspectSource(inspectionAnchor()); await core.waitUntilEntered()
        switch action {
        case "query": model.query("second")
        case "query-change": model.sourceQueryChanged()
        case "radius": model.setInspectionRadius(0)
        case "settings": model.refinementSettingsChanged(ProviderSettings())
        case "policy": model.stageSources([])
        case "selection": model.select(nil)
        case "build": model.build()
        case "config": model.configure(executable: URL(fileURLWithPath: "/synthetic/new-cli"), dataDirectory: URL(fileURLWithPath: "/synthetic/new-store"))
        case "quit": model.quit()
        default: model.cancel()
        }
        await core.finish(); await model.waitForOperation()
        let overtook = await core.successorOvertook
        #expect(model.sourceInspection == nil && !overtook)
        if ["cancel", "radius", "settings", "quit", "query-change"].contains(action) {
            #expect(model.history?.history.last?.text == "human history" && model.evidence == query)
            #expect(model.originalDraft == "original" && model.contextEditorRevision == editor)
        }
        if action != "query" { #expect(!model.canInspectSource(inspectionAnchor())) }
        await model.shutdown()
    }

    @Test(arguments: ["nonce", "root", "snapshot", "policy"])
    @MainActor func authoritativeMetadataReplacementDoesNotAdopt(change: String) async throws {
        let core = InspectionCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original")
        model.query("center"); await model.waitForOperation()
        await core.hold(); model.inspectSource(inspectionAnchor()); await core.waitUntilEntered()
        let p = inspectionScope
        await core.replaceScope(Project(id: p.id, root: change == "root" ? "/synthetic/other" : p.root,
            sources: change == "policy" ? [] : p.sources, snapshot: change == "snapshot" ? .string(String(repeating: "c", count: 64)) : p.snapshot,
            rootIdentity: p.root_identity, incarnation: change == "nonce" ? String(repeating: "c", count: 32) : p.incarnation))
        await core.finish(); await model.waitForOperation()
        #expect(model.sourceInspection == nil && model.sourceRequiresRefresh)
        if change == "nonce" || change == "root" { #expect(model.project == nil && model.history == nil && model.originalDraft.isEmpty) }
        else { #expect(model.history != nil && model.originalDraft == "original") }
        await model.shutdown()
    }

    @Test(arguments: 0...3)
    func strictWindowAndWholeDocument(radius: Int) throws {
        let request = try SourceInspectionRequest(project: inspectionScope, anchor: inspectionAnchor(), radius: radius)
        let data = try inspectionBytes(request)
        let result = try SourceInspectionDocument.decode(data, request: request)
        #expect(result.lines.filter(\.isAnchor).count == 1)
        var o = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["project", "root_identity", "incarnation", "snapshot", "path", "source_hash", "producer", "currentness", "format"] {
            var bad = o; bad[key] = "/not-authorized"
            #expect(throws: (any Error).self) { try SourceInspectionDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
        }
        for key in ["radius", "anchor_line", "version"] {
            for value: Any in [true, -1, 1.5, "1", 1e30] {
                var bad = o; bad[key] = value
                #expect(throws: (any Error).self) { try SourceInspectionDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
            }
        }
        let text = try #require(String(data: data, encoding: .utf8))
        for bad in ["{\"version\":1," + text.dropFirst(), "{\"vers\\u0069on\":1," + text.dropFirst(),
                    text.replacingOccurrences(of: "\"is_anchor\":", with: "\"kind\":\"indexed-anchor\",\"is_anchor\":"),
                    String(text.dropLast(2)), text + "{}"] {
            #expect(throws: (any Error).self) { try SourceInspectionDocument.decode(Data(bad.utf8), request: request) }
        }
        o["unknown"] = true
        #expect(throws: (any Error).self) { try SourceInspectionDocument.decode(JSONSerialization.data(withJSONObject: o), request: request) }
        let lines = try #require((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["lines"] as? [[String: Any]])
        for mutation in ["center", "gap", "kind", "duplicate", "count", "newline", "type", "overflow"] {
            var bad = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]), rows = lines
            let center = try #require(rows.firstIndex(where: { $0["is_anchor"] as? Bool == true }))
            switch mutation {
            case "center": rows[center]["text"] = "wrong center"
            case "gap": rows[0]["line"] = 4000
            case "kind": rows[center]["kind"] = "observed-source-text"
            case "duplicate": rows.append(rows[center])
            case "count": rows = []
            case "newline": rows[center]["text"] = "line\nbreak"
            case "type": rows[center]["is_anchor"] = 1
            default: rows[center]["line"] = 1e100
            }
            bad["lines"] = rows
            #expect(throws: (any Error).self) { try SourceInspectionDocument.decode(JSONSerialization.data(withJSONObject: bad), request: request) }
        }
        var padded = data; padded.append(Data(repeating: 32, count: 8192 - padded.count))
        #expect(throws: ServiceError.outputLimit) { try SourceInspectionDocument.decode(padded, request: request) }
        padded.removeLast(); padded.append(10)
        #expect(try SourceInspectionDocument.decode(padded, request: request).lines.count == result.lines.count)
    }
}
