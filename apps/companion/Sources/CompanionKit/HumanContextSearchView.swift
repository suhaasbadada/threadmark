import SwiftUI

// Match the application's command-line SDK workaround for the same-named macro.
private typealias SearchViewState<Value> = SwiftUI.State<Value>

/// Mount inside the existing Context tab. No Send, provider, editor, or execution surface.
public struct HumanContextSearchView: View {
    @ObservedObject private var model: CompanionModel
    @SearchViewState<String> private var query = ""
    public init(model: CompanionModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search human-authored context").font(.headline)
            Text("Separate from source evidence. Human declarations are untrusted context, not observed truth or authorization.")
                .font(.caption)
            Picker("Human note search mode", selection: Binding(get: { model.humanSearchMode }, set: { value in model.setHumanSearchMode(value) })) {
                ForEach(HumanSearchMode.allCases, id: \.self) { mode in Text(mode.label).tag(mode) }
            }.accessibilityLabel("Human note search mode, independent of source and Refine")
            Text(model.humanSearchMode == .literal
                ? "Literal: one Unicode-lowercase substring, up to 256 UTF-8 bytes. Existing literal matching and ordering."
                : "Any terms: 256 UTF-8 query bytes; 1–8 first-seen distinct Unicode-lowercase whitespace terms, at most 64 UTF-8 bytes each. Rank distinct matched terms before frequency, then ID byte order. No normalization, stemming or semantic quality claim.")
                .font(.caption)
            HStack {
                TextField("Human note text (256 UTF-8 bytes maximum)", text: Binding(get: { query }, set: { value in setQuery(value) }))
                    .accessibilityLabel("Human context search query")
                Button("Search notes", action: search)
                    .disabled(!model.canSearchHumanNotes(query))
                if model.busy { Button("Cancel", action: model.cancel) }
            }
            Toggle("Filter human context kinds (opt-in)", isOn: Binding(
                get: { model.humanSearchKindFilter != nil },
                set: { model.setHumanSearchKindFilter($0 ? InputPolicy.contextKinds.sorted() : nil) }))
            if let kinds = model.humanSearchKindFilter {
                HStack {
                    ForEach(InputPolicy.contextKinds.sorted(), id: \.self) { kind in
                        Toggle(kind, isOn: Binding(get: { kinds.contains(kind) }, set: { selected in
                            model.setHumanSearchKindFilter(selected ? kinds + [kind] : kinds.filter { $0 != kind })
                        })).toggleStyle(.checkbox).accessibilityLabel("Include human context kind: \(kind)")
                    }
                }
                Text("Choose at least one kind, then Search notes. Changing choices does not read storage.").font(.caption)
            }
            if let result = model.humanSearch {
                if let kinds = model.humanSearchSelectedKinds { Text("Selected human kinds: \(kinds.joined(separator: ", "))") }
                Text("Project: \(result.project) · human-authored context only").font(.subheadline)
                Text("Latest active revisions at read only; later edits, retirement or Forget may change results. No historical, semantic or source search.")
                    .font(.caption)
                Text("\(result.matched_entries) matches; \(result.omitted_entries) whole entries omitted (8-entry / 8192-byte JSON limits). No entry text is truncated.")
                ForEach(result.results) { entry in
                    VStack(alignment: .leading) {
                        Text("\(entry.id) · \(entry.kind) · revision \(entry.revision) · human-authored · active")
                            .font(.subheadline)
                        Text(entry.text).textSelection(.enabled)
                        Button("Inspect history: \(entry.id)") { model.inspectHumanSearchEntry(entry.id) }
                            .disabled(model.busy)
                    }
                }
            }
            if let ranked = model.rankedHumanSearch { RankedHumanSearchView(model: model, result: ranked) }
            Text(model.status).font(.caption).accessibilityLabel("Human context operation status")
        }
        .onChange(of: model.scopeRevision) { _ in setQuery("") }
        .onChange(of: model.contextEditorRevision) { _ in setQuery("") }
    }
    private func setQuery(_ value: String) {
        guard !query.utf8.elementsEqual(value.utf8) else { return }
        model.humanSearchQueryChanged(); query = value
    }
    private func search() {
        guard model.canSearchHumanNotes(query) else { return }
        model.searchHumanContext(query)
    }
}
