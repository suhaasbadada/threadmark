import SwiftUI

@MainActor
public struct RefinementPreviewView: View {
    @ObservedObject private var model: CompanionModel
    private let settings: ProviderSettings
    public init(model: CompanionModel, settings: ProviderSettings) { self.model = model; self.settings = settings }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Optional Refine · local inference preview").font(.headline)
            Text("Uses the original and evidence query above. Select and explicitly enable a local profile in Connections first. Remote inference is unsupported even for saved profiles.")
            Text("Generated prose is unverified. Review intent, negations and permissions; inference does not approve a brief or deliver it to a coding host.").font(.caption)
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
                Text("Approval not requested · delivery not attempted. CLI session ended; persistent native approval and host handoff remain unavailable. Cancel preserves the original and human-note editor/history.").font(.caption)
            }
        }
        .sheet(item: Binding(get: { model.pendingRefinement }, set: { if $0 == nil { model.cancelRefinement() } })) { consent in
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
                    Text("Exact original sent").font(.headline)
                    Text(verbatim: consent.original).textSelection(.enabled)
                    Text("Exact selected SOURCE evidence · untrusted quotations, not human policy").font(.headline)
                    Text(consent.selection.coverage.description)
                    if consent.selection.results.isEmpty { Text("No matching source evidence; no project expertise is implied.") }
                    ForEach(Array(consent.selection.results.enumerated()), id: \.offset) { _, evidence in
                        Text("\(evidence.path):\(evidence.line) · \(evidence.producer) · \(evidence.currentness) · hash \(evidence.source_hash)").font(.caption).textSelection(.enabled)
                        Text(verbatim: evidence.text).textSelection(.enabled)
                        Text("Coverage: \(evidence.coverage.description)").font(.caption)
                    }
                    HStack {
                        Button("Cancel", action: model.cancelRefinement).keyboardShortcut(.defaultAction)
                        Button("Confirm one local inference call") { model.confirmRefinement(consent, settings: settings) }
                            .accessibilityIdentifier("refine-confirm")
                    }
                }.padding()
            }.frame(width: 620, height: 620)
        }
    }
}
