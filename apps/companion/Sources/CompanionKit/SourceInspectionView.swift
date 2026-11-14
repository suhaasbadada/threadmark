import SwiftUI

/// Mounted below actual Query / QueryTerms rows. No task/onAppear/selection I/O.
public struct SourceInspectionControls: View {
    @ObservedObject var model: CompanionModel
    public init(model: CompanionModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading) {
            Picker("Source inspection neighboring-line radius", selection: Binding(
                get: { model.inspectionRadius }, set: { model.setInspectionRadius($0) })) {
                ForEach(0...3, id: \.self) { Text("\($0) each side").tag($0) }
            }
            .accessibilityIdentifier("source-inspection-radius")
            Text("Inspect source reads only after an explicit button action. Radius changes do not fetch. Current-at-read is not a future freshness guarantee. Lexical only; no inference or source authorization granted.").font(.caption)
            if let document = model.sourceInspection {
                Text("\(document.path) · current-at-read · lexical only").font(.headline)
                Text("Source SHA-256: \(document.sourceHash)\nSnapshot: \(document.snapshot)").font(.caption)
                Text("Indexed center producer: \(document.producer). Neighbors are newly observed source text, not indexed claims.").font(.caption)
                ForEach(Array(document.lines.enumerated()), id: \.offset) { _, line in
                    Text("\(line.number) [\(line.isAnchor ? "indexed anchor" : "observed neighbor")] \(line.text)")
                        .font(.system(.body, design: .monospaced))
                        .accessibilityLabel("Line \(line.number), \(line.isAnchor ? "indexed anchor" : "observed source text"), \(line.text.isEmpty ? "blank" : line.text)")
                }
                Text("Read-only display. No edit, copy/send, host launch or automatic reinspection.").font(.caption)
            }
        }
    }
}
