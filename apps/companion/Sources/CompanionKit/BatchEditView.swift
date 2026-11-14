import SwiftUI

/// Occasional Context management, not a task feed. No appearance/selection I/O.
public struct BatchEditView: View {
    @ObservedObject private var model: CompanionModel
    public init(model: CompanionModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session-only atomic note batch · \(model.stagedBatch.count)/8").font(.headline)
            Text("Staged project: \(model.batchProjectID ?? "None") · exact captured registration, not another project with the same ID.")
            Text("2–8 different existing IDs in one project. Human-authored context, not observed truth, permission, semantic resolution or source changes. Staging and Review do no I/O. Nothing is retained across app restart.").font(.caption)
            Text(model.batchStatus).textSelection(.enabled)
            if model.batchOutcomeUnknown {
                Text("Prior batch persisted outcome unknown — never assume rollback. No automatic retry. Explicitly reload each target history and restage from a fresh Edit base before a new review.")
            }
            ForEach(model.pendingBatchReview?.entries ?? model.stagedBatch) { entry in
                VStack(alignment: .leading) {
                    Text("\(entry.operation.uppercased()) · \(entry.id) · expected revision \(entry.expectedRevision) · \(entry.kind)")
                    Text(entry.text).textSelection(.enabled)
                    if entry.operation == "retire" {
                        DisclosureGroup("Captured retained human history (not Forget)") {
                            ForEach(entry.capturedHistory.history, id: \.revision) { revision in
                                Text("Revision \(revision.revision) · \(revision.kind) · \(revision.retired ? "retired" : "active")")
                                Text(revision.text).textSelection(.enabled)
                            }
                        }
                    }
                    Button("Remove staged \(entry.id)") { model.removeBatchEntry(entry.id) }
                }
            }
            Text("To edit a staged update, explicitly load its history, Edit the loaded revision, change your editor, and Stage again. This replaces only copied intent; no automatic history rebase.").font(.caption)
            HStack {
                Button("Review exact staged batch", action: model.reviewBatch).disabled(!model.canReviewBatch)
                Button("Clear staged plan", action: model.clearBatchPlan).disabled(model.stagedBatch.isEmpty)
            }
            if let review = model.pendingBatchReview {
                Text("Frozen local review · \(review.entries.count) actions. Apply appends all or none using the captured revisions. Retire keeps history. Cancel keeps every draft and staged entry.")
                HStack {
                    Button("Cancel batch review", action: model.cancelBatchReview).keyboardShortcut(.cancelAction)
                    Button("Apply reviewed atomic batch") { model.applyBatch(review) }.disabled(model.busy)
                }
            }
        }.accessibilityElement(children: .contain)
    }
}
