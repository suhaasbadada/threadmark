import SwiftUI

/// Mounted in management Context/history; never reads on appearance or selection.
@MainActor
public struct HumanComparisonView: View {
    @ObservedObject private var model: CompanionModel
    public init(model: CompanionModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Compare saved revisions…", action: model.openHumanComparison)
                .disabled(model.busy || model.humanComparisonRevisions.isEmpty)
                .accessibilityIdentifier("human-comparison-open")
            if model.humanComparisonVisible {
                Text("Same-note saved revision review").font(.headline)
                Text("Human-authored context, not observed source truth or authorization. Logical-line common prefix/suffix review, not a minimal or semantic diff, conflict detection or conflict resolution. No draft changes or automatic retry.")
                Picker("FROM saved revision", selection: Binding(get: { model.comparisonFrom }, set: { model.chooseHumanComparison(from: $0, to: model.comparisonTo) })) {
                    ForEach(model.humanComparisonRevisions, id: \.revision) { entry in
                        Text("\(entry.revision) · \(entry.kind) · \(entry.retired ? "retired" : "active")").tag(entry.revision)
                    }
                }.accessibilityIdentifier("human-comparison-from")
                Picker("TO saved revision", selection: Binding(get: { model.comparisonTo }, set: { model.chooseHumanComparison(from: model.comparisonFrom, to: $0) })) {
                    ForEach(model.humanComparisonRevisions, id: \.revision) { entry in
                        Text("\(entry.revision) · \(entry.kind) · \(entry.retired ? "retired" : "active")").tag(entry.revision)
                    }
                }.accessibilityIdentifier("human-comparison-to")
                HStack {
                    Button("Compare", action: model.compareHumanContext).disabled(!model.canCompareHumanContext || model.busy)
                        .accessibilityLabel("Compare chosen saved human revisions")
                        .accessibilityIdentifier("human-comparison-read")
                    Button("Cancel comparison (keep editor)", action: model.cancelHumanComparison)
                        .accessibilityIdentifier("human-comparison-cancel")
                }
                Text(model.comparisonStatus).textSelection(.enabled)
                if model.lastError == .contextConflict { Text(ServiceError.contextConflict.localizedDescription) }
                if let result = model.humanComparison {
                    Text("\(result.request.binding.project) / \(result.request.contextID) · human-authored")
                    Text("FROM \(result.request.from.revision) · \(result.request.from.kind) · \(result.request.from.retired ? "retired" : "active")")
                    Text("TO \(result.request.to.revision) · \(result.request.to.kind) · \(result.request.to.retired ? "retired" : "active")")
                    Text("Text changed: \(result.textChanged ? "yes" : "no") · Kind changed: \(result.kindChanged ? "yes" : "no") · Retirement changed: \(result.retirementChanged ? "yes" : "no")")
                    segment("Common prefix (unchanged)", result.prefix)
                    segment("Removed from FROM revision", result.removed)
                    segment("Added in TO revision", result.added)
                    segment("Common suffix (unchanged)", result.suffix)
                    Text("Empty segments are labeled; CR/LF and final-newline bytes are not normalized. Reload history explicitly to see newer revisions; only Edit loaded revision replaces the editor and its CAS base.").font(.caption)
                }
            }
        }
    }
    private func segment(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading) {
            Text("\(label) · \(text.utf8.count) UTF-8 bytes").font(.headline)
            if text.isEmpty { Text("Empty segment") }
            else { Text(verbatim: text).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
        }
    }
}
