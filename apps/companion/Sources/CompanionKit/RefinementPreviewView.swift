import SwiftUI

@MainActor
public struct RefinementPreviewView: View {
    @ObservedObject private var model: CompanionModel
    private let settings: ProviderSettings
    public init(model: CompanionModel, settings: ProviderSettings) { self.model = model; self.settings = settings }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Optional Refine · retained engine review").font(.headline)
            Text("Uses the original and evidence query above. Select and explicitly enable a local profile in Connections first. Remote inference is unsupported even for saved profiles.")
            Text("Generated prose is unverified. Review intent, negations and permissions. Explicit engine approval returns only an in-memory value; no copy, send or host admission. Refine retrieval is independent of Source Query/Context mode.").font(.caption)
            Picker("Refine retrieval mode", selection: Binding(get: { model.refinementRetrievalMode }, set: model.setRefinementRetrievalMode)) {
                ForEach(SourceRetrievalMode.allCases, id: \.self) { mode in Text(mode.label).tag(mode) }
            }.accessibilityIdentifier("refine-retrieval-mode")
            Text(model.refinementRetrievalMode.explanation).font(.caption)
            Text("Changing mode cancels pending/preparing/idle Refine and requires fresh inspection and consent, even when changed back. At most 8 source lines and 8192 serialized selection bytes; lexical evidence is not semantic understanding.").font(.caption)
            HStack {
                Button("Inspect data for Refine…") { model.requestRefinement(settings: settings) }
                    .disabled(!model.canPrepareContext)
                    .accessibilityIdentifier("refine-inspect")
                Button("Cancel / dismiss Refine", action: model.cancelRefinement)
                    .accessibilityIdentifier("refine-dismiss")
            }
            if let preview = model.refinementPreview {
                Text("\(preview.state) · snapshot \(preview.snapshot)").textSelection(.enabled)
                Text("Original · unchanged").font(.headline)
                Text(verbatim: preview.original).textSelection(.enabled)
                Text("Proposed · not applied").font(.headline)
                Text(verbatim: preview.proposed).textSelection(.enabled)
                ForEach(Array(preview.material_questions.enumerated()), id: \.offset) { _, question in
                    Text(verbatim: "Material question: " + question).textSelection(.enabled)
                }
                Text("Finite compatibility preview only · approval not requested · delivery not attempted. Cancel preserves the original and human-note editor/history.").font(.caption)
            }
            if model.retainedReviewVisible { RetainedEngineReviewView(model: model, review: model.retainedReview) }
        }
        .sheet(item: Binding(get: { model.pendingRefinement }, set: { if $0 == nil && model.pendingRefinement != nil { model.cancelRefinement() } })) { consent in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Allow this one local inference request?").font(.headline)
                    Text("Profile: \(consent.profile.id) · model: \(consent.profile.model) · locality: local")
                    Text("Exact destination: \(consent.profile.endpoint)").textSelection(.enabled)
                    Text(RefinementConsent.disclosure)
                    Text("Project: \(consent.project.id) · root: \(consent.project.root)").textSelection(.enabled)
                    Text("Root identity: \(consent.project.root_identity?.description ?? "unavailable") · incarnation: \(consent.project.incarnation ?? "unavailable")").textSelection(.enabled)
                    Text("Snapshot: \(consent.project.snapshot?.description ?? "unavailable")").textSelection(.enabled)
                    Text(verbatim: "Query: " + consent.query).textSelection(.enabled)
                    Text("Refine retrieval: \(consent.retrievalMode.label)").font(.headline)
                    Text(consent.retrievalMode.explanation).font(.caption)
                    Text("Exact original sent").font(.headline)
                    Text(verbatim: consent.original).textSelection(.enabled)
                    Text("Exact selected SOURCE evidence · untrusted quotations, not human policy").font(.headline)
                    Text(consent.reviewCoverage)
                    if consent.selection.results.isEmpty { Text("No matching source evidence; no project expertise is implied.") }
                    ForEach(Array(consent.selection.results.enumerated()), id: \.offset) { _, evidence in
                        Text("\(evidence.path):\(evidence.line) · \(evidence.producer) · \(evidence.currentness) · hash \(evidence.source_hash)").font(.caption).textSelection(.enabled)
                        Text(verbatim: evidence.text).textSelection(.enabled)
                        Text("Coverage: \(evidence.coverage.description)").font(.caption)
                    }
                    HStack {
                        Button("Cancel", action: model.cancelRefinement).keyboardShortcut(.defaultAction)
                        Button("Confirm one local inference call") { model.confirmRetainedRefinement(consent, settings: settings) }
                            .accessibilityIdentifier("refine-confirm")
                    }
                }.padding()
            }.frame(width: 620, height: 620)
        }
    }
}

@MainActor
private struct RetainedEngineReviewView: View {
    @ObservedObject var model: CompanionModel
    @ObservedObject var review: RetainedReviewController
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stateLabel).font(.headline).accessibilityIdentifier("retained-review-state")
            if let consent = review.consent {
                Text("Project: \(consent.project.id) · \(consent.retrievalMode.label) · snapshot \(consent.project.snapshot?.description ?? "none")").font(.caption)
                Text(consent.retrievalMode.explanation).font(.caption)
                Text("Coverage at preparation: \(consent.reviewCoverage)").font(.caption)
            }
            if case .approvedValue(let value) = review.state {
                ReviewTextDiffView(comparison: ReviewTextDiff(original: review.original, proposed: value.text),
                    proposedLabel: "Approved engine value · \(value.delivery) · \(value.choice)")
            } else if let proposed = review.proposed {
                ReviewTextDiffView(comparison: ReviewTextDiff(original: review.original, proposed: proposed))
            } else {
                Text("Original · unchanged").font(.headline)
                Text(verbatim: model.originalDraft).textSelection(.enabled)
            }
            ForEach(Array(review.questions.enumerated()), id: \.offset) { _, question in
                Text(verbatim: "Material question: " + question).textSelection(.enabled)
            }
            if let challenge = review.challenge {
                if let editable = review.editable {
                    RetainedProseEditor(model: model, review: review, challenge: challenge, editable: editable)
                        .id("\(challenge.revision):\(challenge.digest)")
                }
                Button("Use original") { model.useRetainedOriginal(challenge) }
                    .disabled(!model.retainedActionsAvailable)
                    .accessibilityIdentifier("retained-use-original")
            }
            Button("Cancel retained review", action: model.cancelRefinement)
            Text("Edits cannot clear material questions. Both choices are revalidated by the retained Rust engine. Values stay in memory; no clipboard, host draft, Send or execution. Closing Manage retains this bounded session; Quit cancels and joins it. Native accessibility and live-model quality are not certified.").font(.caption)
        }
    }
    private var stateLabel: String {
        switch review.state {
        case .idle, .preparing: return "Preparing retained review"
        case .needsInput: return "Needs input — prepared use blocked"
        case .ready: return "Ready for explicit review — not delivered"
        case .reviewRequired: return "Review required — inspect current content and questions"
        case .failed: return "Failed — no automatic fallback; explicit original only if still available"
        case .canceled: return "Canceled — nothing delivered"
        case .approvedValue: return "Engine approved value — delivery not attempted"
        }
    }
}

private typealias ReviewViewState<Value> = SwiftUI.State<Value>

@MainActor
private struct RetainedProseEditor: View {
    @ObservedObject var model: CompanionModel
    @ObservedObject var review: RetainedReviewController
    let challenge: RetainedReviewChallenge
    let editable: RetainedReviewEditable
    @ReviewViewState private var objective: String
    @ReviewViewState private var expectations: String
    init(model: CompanionModel, review: RetainedReviewController, challenge: RetainedReviewChallenge, editable: RetainedReviewEditable) {
        self.model = model; self.review = review; self.challenge = challenge; self.editable = editable
        _objective = ReviewViewState(initialValue: editable.objective)
        _expectations = ReviewViewState(initialValue: editable.output_expectations)
    }
    var body: some View {
        VStack(alignment: .leading) {
            Text("Comparison above shows the last engine preview. Unsaved fields appear in that comparison only after Edit; changing them does not approve or deliver anything.").font(.caption)
            TextField("Editable objective", text: $objective)
            TextField("Editable output expectations", text: $expectations)
            HStack {
                Button("Edit") { model.editRetainedReview(challenge, objective: objective, outputExpectations: expectations) }
                    .disabled(!model.retainedActionsAvailable)
                    .accessibilityIdentifier("retained-edit")
                Button("Use prepared") { model.useRetainedPrepared(challenge) }
                    .disabled(!model.retainedActionsAvailable || !review.questions.isEmpty || review.state == .needsInput ||
                        review.consent?.selection.results.isEmpty != false ||
                        !objective.utf8.elementsEqual(editable.objective.utf8) || !expectations.utf8.elementsEqual(editable.output_expectations.utf8))
                    .accessibilityIdentifier("retained-use-prepared")
            }
        }
    }
}
