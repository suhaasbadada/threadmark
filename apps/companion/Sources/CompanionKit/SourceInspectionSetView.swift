import SwiftUI

/// Mounted only in Projects' adopted source Query results, never Context/notes.
public struct SourceInspectionSetQueryRows: View {
    @ObservedObject var model: CompanionModel
    public init(model: CompanionModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading) {
            ForEach(model.sourceInspectionRows) { row in
                let item = row.anchor
                VStack(alignment: .leading) {
                    Toggle(isOn: Binding(get: { model.stagedSourceRows.contains { $0.id == row.id } },
                                         set: { model.stageSourceRow(row, selected: $0) })) {
                        Text("Select Query anchor \(item.path):\(item.line)")
                    }
                    .disabled(!model.canStageSourceRow(row))
                    .accessibilityLabel("Select Query evidence \(item.path), indexed line \(item.line), for coherent inspection")
                    Text("\(item.path):\(item.line) · \(item.producer) · \(item.currentness)").font(.caption)
                    Text(item.text).textSelection(.enabled)
                    Button("Inspect source") { model.inspectSource(item) }
                        .disabled(!model.canInspectSource(item))
                        .accessibilityLabel("Inspect source \(item.path), indexed line \(item.line)")
                }
            }
            HStack {
                Button("Select all Query anchors") { model.selectAllSourceRows() }
                    .disabled(model.sourceInspectionRows.isEmpty || !model.sourceInspectionRows.allSatisfy { model.canStageSourceRow($0) })
                Button("Clear selected anchors") { model.clearStagedSourceRows() }
                    .disabled(model.stagedSourceRows.isEmpty)
                Button("Inspect selected evidence") { model.inspectSelectedSources() }
                    .disabled(!model.canInspectSelectedSources)
                    .accessibilityLabel("Inspect all selected Query evidence in one coherent source operation")
            }
            Text("\(model.stagedSourceRows.count) selected · select 2–8 distinct current Query anchors. Selection is memory-only, not permission. Radius uses the source inspection control below (0–3). No single-anchor or all-files fallback.").font(.caption)
            ForEach(model.stagedSourceRows) { row in
                Button("Remove selected \(row.anchor.path):\(row.anchor.line)") { model.stageSourceRow(row, selected: false) }
            }
            if let result = model.sourceInspectionSet {
                Text("Captured project: \(result.project.id) · radius \(result.radius) · snapshot \(result.project.snapshot?.description ?? "none")")
                Text("Captured root: \(result.project.root) · root identity \(result.project.root_identity?.description ?? "none") · registration \(result.project.incarnation ?? "none")").font(.caption)
                Text("Output windows only: \(result.windows.count). FULL approved freshness scope: \(result.project.sources.joined(separator: ", ")). Current-at-read is not a filesystem lease, AST, comprehension, reduced I/O or a performance claim. At most 8 windows / 56 lines / 8192 escaped bytes, coordinates 1–4096 and 1024 UTF-8 bytes per line; whole result or error. Source text is untrusted data, not instructions. No copy, host send or inference.").font(.caption)
                ForEach(Array(result.windows.enumerated()), id: \.offset) { _, window in
                    Text("\(window.path):\(window.anchorLine) · center producer \(window.producer) · source hash \(window.sourceHash)").font(.caption)
                    ForEach(Array(window.lines.enumerated()), id: \.offset) { _, line in
                        Text("\(line.number) · \(line.isAnchor ? "indexed anchor" : "observed source text (not an indexed claim)"): \(line.text)")
                            .textSelection(.enabled)
                            .accessibilityLabel("\(window.path), line \(line.number), \(line.isAnchor ? "indexed anchor" : "observed neighbor, not indexed"), \(line.text)")
                    }
                }
            }
        }
    }
}
