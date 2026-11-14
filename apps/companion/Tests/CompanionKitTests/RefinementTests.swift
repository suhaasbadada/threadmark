import Foundation
import Testing
@testable import CompanionKit

func refinementSettings(_ endpoint: String = "http://127.0.0.1:12345/v1/chat/completions") throws -> ProviderSettings {
    var settings = ProviderSettings()
    try settings.configure(ProviderProfile(id: "synthetic-local", endpoint: endpoint, model: "synthetic-model", locality: .local))
    settings.enabled = true
    return settings
}
private func syntheticConsent() throws -> RefinementConsent {
    let project = Project(id: "alpha", root: "/synthetic/alpha", sources: ["a.rs"],
        snapshot: .string(String(repeating: "a", count: 64)), rootIdentity: .string("r1"), incarnation: String(repeating: "b", count: 32))
    let settings = try refinementSettings()
    let selection = QueryReport(project: project.id, snapshot: project.snapshot, currentness: "current-at-read",
        coverage: .string("lexical-lines-only; no semantic coverage"), results: [])
    return RefinementConsent(id: UUID(), project: project, query: "synthetic", original: "Do NOT deploy e\u{301} 👋", settings: settings,
        profile: try settings.selectedProfile(), selection: selection, generation: 0, scopeRevision: 0)
}
private func previewPayload(_ consent: RefinementConsent) -> [String: Any] {
    ["project": consent.project.id, "root": consent.project.root, "root_identity": consent.project.root_identity!.description,
     "incarnation": consent.project.incarnation!, "snapshot": consent.project.snapshot!.description, "query": consent.query,
     "original": consent.original, "proposed": consent.original + "\nSynthetic proposal", "changed": true,
     "mode": "refinement-preview", "state": consent.selection.results.isEmpty ? "needs-input" : "ready-for-review", "material_questions": [String](),
     "coverage": consent.selection.coverage.description, "approval": "not-requested", "delivery": "not-attempted",
     "provider": ["profile": consent.profile.id, "model": consent.profile.model, "endpoint": consent.profile.endpoint,
                  "locality": "local", "data_scope": "request-and-selected-evidence", "max_calls": 1,
                  "max_tokens": 1024, "deadline_seconds": 30, "output_byte_budget": 8192]]
}

private actor RefinementCore: CoreService {
    let seed: RefinementConsent
    var held: CheckedContinuation<Void, Never>?
    var began: CheckedContinuation<Void, Never>?
    var didBegin = false
    var hold = false
    var mode = "valid"
    var calls = 0
    init() throws { seed = try syntheticConsent() }
    func configure(_ mode: String, hold: Bool = false) { self.mode = mode; self.hold = hold }
    func waitForCall() async { if didBegin { return }; await withCheckedContinuation { began = $0 } }
    func release() { held?.resume(); held = nil }
    func count() -> Int { calls }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        switch operation {
        case .project: return .project(seed.project)
        case .contextsBound: return .contexts(ContextList(project: "alpha", contexts: []))
        case .contextBound: return .context(ContextHistory(project: "alpha", id: "memo", producer: "human-authored", authority: .string("human-declared"), history: [ContextRevision(revision: 1, kind: "note", text: "Synthetic retained history", retired: false)]))
        case .query, .queryBound: return .query(seed.selection)
        case .refinePreview(let consent):
            calls += 1; didBegin = true; began?.resume(); began = nil
            if hold { await withCheckedContinuation { held = $0 } } // Deliberately ignores task cancellation.
            if mode == "unknown" { return .acknowledged }
            if mode == "error" { throw ServiceError.failed }
            var payload = previewPayload(consent)
            if mode == "wrong-original" { payload["original"] = "Changed original" }
            return .refinementPreview(try JSONDecoder().decode(RefinementPreview.self, from: JSONSerialization.data(withJSONObject: payload)))
        default: throw ServiceError.unavailable
        }
    }
}

@Suite("Native refinement consent and strict preview")
struct RefinementTests {
    @Test func slashHeavyValidPreviewKeepsRustEnvelopeBudget() throws {
        let consent = try syntheticConsent()
        var payload = previewPayload(consent)
        let proposed = String(repeating: "/", count: 6000)
        payload["proposed"] = proposed
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.withoutEscapingSlashes])
        #expect(data.count + 1 <= 8192)
        let preview = try JSONDecoder().decode(RefinementPreview.self, from: data)
        #expect(try JSONEncoder().encode(preview).count + 1 > 8192) // Old, incompatible slash escaping.
        #expect(try RefinementPreview.decode(data, consent: consent).proposed == proposed)
        #expect(throws: (any Error).self) { try RefinementPreview.decode(data + Data(repeating: 32, count: 8193), consent: consent) }
    }

    @Test func closedSchemaIdentityOriginalQuestionsAndDuplicateKeys() throws {
        let consent = try syntheticConsent(), valid = previewPayload(consent)
        let data = try JSONSerialization.data(withJSONObject: valid)
        _ = try RefinementPreview.decode(data, consent: consent)
        for key in valid.keys {
            var bad = valid; bad.removeValue(forKey: key)
            #expect(throws: (any Error).self) { try RefinementPreview.decode(JSONSerialization.data(withJSONObject: bad), consent: consent) }
        }
        for (key, value): (String, Any) in [
            ("project", "other"), ("root", "/other"), ("root_identity", "other"), ("incarnation", String(repeating: "c", count: 32)),
            ("snapshot", String(repeating: "d", count: 64)), ("query", "other"), ("mode", "context-only"),
            ("state", "approved"), ("original", "Do NOT deploy é 👋"), ("changed", false),
            ("approval", "approved"), ("delivery", "copied"), ("coverage", "complete"),
            ("material_questions", [String(repeating: "q", count: 1025)]), ("proposed", ""), ("unknown", true)
        ] {
            var bad = valid; bad[key] = value
            #expect(throws: (any Error).self) { try RefinementPreview.decode(JSONSerialization.data(withJSONObject: bad), consent: consent) }
        }
        let provider = try #require(valid["provider"] as? [String: Any])
        for (key, value): (String, Any) in [("profile", "other"), ("model", "other"), ("endpoint", "http://127.0.0.1:1/v1"), ("locality", "remote"), ("data_scope", "whole-project"), ("max_calls", 2), ("max_tokens", 1025), ("deadline_seconds", 31), ("output_byte_budget", 8193), ("extra", true)] {
            var badProvider = provider; badProvider[key] = value
            var bad = valid; bad["provider"] = badProvider
            #expect(throws: (any Error).self) { try RefinementPreview.decode(JSONSerialization.data(withJSONObject: bad), consent: consent) }
        }
        var questions = valid; questions["state"] = "needs-input"; questions["material_questions"] = ["Synthetic material question?"]
        #expect(try RefinementPreview.decode(JSONSerialization.data(withJSONObject: questions), consent: consent).state == "needs-input")
        let text = String(decoding: data, as: UTF8.self)
        for duplicate in ["\"state\":\"ready-for-review\",", "\"\\u0073tate\":\"ready-for-review\","] {
            let bad = Data(("{" + duplicate + text.dropFirst()).utf8)
            #expect(throws: (any Error).self) { try RefinementPreview.decode(bad, consent: consent) }
        }
        #expect(throws: (any Error).self) { try RefinementPreview.decode(Data(repeating: 32, count: 8193), consent: consent) }
    }

    @Test @MainActor func lateUnknownAndFailedRepliesCannotReplaceDraftOrHistory() async throws {
        for mode in ["valid", "unknown", "error", "wrong-original"] {
            let core = try RefinementCore(), settings = try refinementSettings()
            let model = CompanionModel(service: core, configured: true)
            model.select("alpha"); await model.waitForOperation()
            model.openContext("memo"); await model.waitForOperation()
            let historyText = model.history?.history.first?.text, editorRevision = model.contextEditorRevision
            let original = "Do NOT deploy e\u{301} 👋"
            model.editPreparation(query: "synthetic", original: original)
            model.requestRefinement(settings: settings); await model.waitForOperation()
            let consent = try #require(model.pendingRefinement)
            #expect(await core.count() == 0)
            await core.configure(mode, hold: true)
            model.confirmRefinement(consent, settings: settings)
            await core.waitForCall()
            if mode == "valid" { model.cancelRefinement() }
            await core.release(); await model.waitForOperation()
            #expect(model.refinementPreview == nil && model.originalDraft.utf8.elementsEqual(original.utf8))
            #expect(model.history?.history.first?.text == historyText && model.contextEditorRevision == editorRevision)
            await model.shutdown()
        }
    }

    @Test @MainActor func editsProfileChangesAndCancellationInvalidateConsent() async throws {
        for change in ["original", "query", "profile", "policy", "cancel", "configuration", "project"] {
            let core = try RefinementCore(), settings = try refinementSettings()
            let model = CompanionModel(service: core, configured: true)
            model.select("alpha"); await model.waitForOperation()
            model.editPreparation(query: "synthetic", original: "Do not deploy")
            model.requestRefinement(settings: settings); await model.waitForOperation()
            let consent = try #require(model.pendingRefinement)
            var current = settings
            switch change {
            case "original": model.editPreparation(query: "synthetic", original: "Do NOT delete")
            case "query": model.editPreparation(query: "other", original: model.originalDraft)
            case "profile": current.profiles[0].model = "other"
            case "policy": model.stageSources([])
            case "configuration": model.configure(executable: URL(fileURLWithPath: "/synthetic/cli"), dataDirectory: URL(fileURLWithPath: "/synthetic/store"))
            case "project": model.select(nil)
            default: model.cancelRefinement()
            }
            model.confirmRefinement(consent, settings: current); await model.waitForOperation()
            #expect(await core.count() == 0 && model.pendingRefinement == nil && model.refinementPreview == nil)
            await model.shutdown()
        }
    }
}
