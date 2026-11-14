import SwiftUI

/// Query-only, inert choices over the current registered policy.
public struct QueryFilterControls: View {
    @ObservedObject var model: CompanionModel
    public init(model: CompanionModel) { self.model = model }
    public var body: some View {
        GroupBox("Query result file scope") {
            VStack(alignment: .leading) {
                Text("Query results only; Context/Refine use separate settings and full approved scope").font(.caption)
                Toggle("Filter Query results to selected registered files", isOn: Binding(
                    get: { model.queryFileFilter != nil },
                    set: { model.setQueryFileFilter($0 ? [] : nil) }))
                    .accessibilityIdentifier("query-file-filter-enabled")
                if let selected = model.queryFileFilter {
                    ForEach(model.project?.sources ?? [], id: \.self) { path in
                        Toggle(path, isOn: Binding(get: { selected.contains(path) }, set: { enabled in
                            var paths = model.queryFileFilter ?? []
                            if enabled { if !paths.contains(path) { paths.append(path) } }
                            else { paths.removeAll { $0 == path } }
                            model.setQueryFileFilter(paths)
                        })).accessibilityLabel("Include \(path) in Query results")
                    }
                    if selected.isEmpty { Text("Select at least one registered file to enable Query. Never falls back to all files.") }
                    Text("Candidate output only. ALL approved files are still freshness-read; an unselected changed or unsafe file can invalidate the whole snapshot. No I/O, privacy or performance reduction.").font(.caption)
                } else { Text("Default: all approved files; existing bound Query route.").font(.caption) }
                if let captured = model.querySelectedPaths {
                    Text("Displayed Query file scope: \(captured.joined(separator: ", "))").font(.caption).textSelection(.enabled)
                }
            }
        }
    }
}
