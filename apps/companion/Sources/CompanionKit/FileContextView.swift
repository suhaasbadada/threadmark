import SwiftUI

/// Mounted only in explicit Context preparation, never in Refine consent.
public struct FileContextControls: View {
    @ObservedObject var model: CompanionModel
    public init(model: CompanionModel) { self.model = model }
    public var body: some View {
        GroupBox("Context output file scope") {
            VStack(alignment: .leading) {
                Text("Context only. Independent of Query file choices, even an empty Query subset. Refine and retained review keep separate full-scope consent.").font(.caption)
                Toggle("Restrict Context evidence to selected registered files", isOn: Binding(
                    get: { model.contextFileFilter != nil }, set: { model.setContextFileFilter($0 ? [] : nil) }))
                    .accessibilityIdentifier("context-file-filter-enabled")
                if let selected = model.contextFileFilter {
                    ForEach(model.project?.sources ?? [], id: \.self) { path in
                        Toggle(path, isOn: Binding(get: { selected.contains(path) }, set: { enabled in
                            var paths = model.contextFileFilter ?? []
                            if enabled { if !paths.contains(path) { paths.append(path) } }
                            else { paths.removeAll { $0 == path } }
                            model.setContextFileFilter(paths)
                        })).accessibilityLabel("Include \(path) in Context output candidates")
                    }
                    if selected.isEmpty { Text("Select at least one registered file to enable Prepare Context. Never falls back to all files.") }
                } else { Text("Default: all approved files; existing bound Context route.").font(.caption) }
                Text("Selected files restrict output candidates only. ALL approved files still receive freshness reads; unselected changes or unsafe files can stale the whole snapshot. No permission, privacy, I/O avoidance, AST or performance gain.").font(.caption)
                if let captured = model.contextSelectedPaths {
                    Text("Displayed Context file scope: \(captured.joined(separator: ", "))").font(.caption).textSelection(.enabled)
                }
            }
        }
    }
}
