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
            HStack {
                TextField("Literal human text (256 UTF-8 bytes maximum)", text: $query)
                    .accessibilityLabel("Human context search query")
                    .onSubmit(search)
                    .onChange(of: query) { _ in model.humanSearchQueryChanged() }
                Button("Search", action: search)
                    .disabled(!model.canSearchHumanContext || !InputPolicy.humanSearch(query))
                if model.busy { Button("Cancel", action: model.cancel) }
            }
            if let result = model.humanSearch {
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
            Text(model.status).font(.caption).accessibilityLabel("Human context operation status")
        }
        .onChange(of: model.scopeRevision) { _ in query = "" }
        .onChange(of: model.contextEditorRevision) { _ in query = "" }
    }
    private func search() {
        guard model.canSearchHumanContext, InputPolicy.humanSearch(query) else { return }
        model.searchHumanContext(query)
    }
}
