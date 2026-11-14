import SwiftUI

/// Human declarations only; no edit-base, source evidence or approval affordance.
public struct RankedHumanSearchView: View {
    @ObservedObject private var model: CompanionModel
    private let result: RankedHumanSearch
    public init(model: CompanionModel, result: RankedHumanSearch) { self.model = model; self.result = result }
    public var body: some View {
        let d = result.document
        VStack(alignment: .leading, spacing: 8) {
            Text("Project: \(d.project) · human-authored · latest active at read")
            Text("Kinds: \(d.selected_kinds.joined(separator: ", ")) · terms: \(d.terms.joined(separator: ", "))")
            Text(d.coverage).font(.caption)
            Text("\(d.matched_entries) matches; \(d.omitted_entries) whole entries omitted. Up to 8 entries / 8192 JSON bytes including newline; later fitting candidates allowed. Text is never truncated.")
            Text(d.limitations).font(.caption)
            ForEach(d.results) { entry in
                VStack(alignment: .leading) {
                    Text("\(entry.id) · \(entry.kind) · revision \(entry.revision) · human-authored · active")
                    Text("Matched terms: \(entry.matched_terms.joined(separator: ", ")) · \(entry.matched_terms.count) distinct · \(entry.occurrences) occurrences")
                    Text(entry.text).textSelection(.enabled)
                    Button("Inspect history: \(entry.id)") { model.inspectRankedHumanSearchEntry(entry.id, result: result) }.disabled(model.busy)
                }
            }
        }
    }
}
