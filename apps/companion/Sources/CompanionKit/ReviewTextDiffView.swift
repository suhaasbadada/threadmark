import SwiftUI

private typealias DiffViewState<Value> = SwiftUI.State<Value>

/// Untrusted prose is always verbatim Text, never Markdown/HTML or instructions.
@MainActor
struct ReviewTextDiffView: View {
    let comparison: ReviewTextDiff
    var proposedLabel = "Proposed · unverified, not delivered"
    @DiffViewState private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Original · unchanged").font(.headline)
            fullText(comparison.original)
            Text(verbatim: proposedLabel).font(.headline)
            fullText(comparison.proposed)
            DisclosureGroup("Textual changes · original versus displayed value", isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Byte-exact line comparison; shared leading/trailing lines are context. The changed middle is shown as Removed then Added, not a minimal or semantic alignment. This does not certify intent preservation.").font(.caption)
                    if let fallback = comparison.fallback {
                        Text(verbatim: fallback.rawValue).accessibilityIdentifier("review-diff-fallback")
                    } else if comparison.identical {
                        Text("No UTF-8 byte changes.")
                    }
                    ForEach(Array(comparison.rows.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading) {
                            Text(verbatim: row.label).font(.caption.bold())
                            Text(verbatim: row.line.text.isEmpty ? "[Empty line]" : row.line.text)
                                .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            if row.kind != .context {
                                DisclosureGroup("Exact UTF-8 bytes · \(row.kind.rawValue)") {
                                    Text(verbatim: row.line.hex).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                }
                            }
                        }.accessibilityElement(children: .contain)
                    }
                    Text("LF and CRLF are explicit; No line ending means no final newline. Exact byte disclosures distinguish visually identical Unicode and whitespace. Full text above stays selectable; nothing is copied automatically.").font(.caption)
                }
            }.accessibilityIdentifier("review-text-diff")
        }
    }

    private func fullText(_ text: String) -> some View {
        VStack(alignment: .leading) {
            if text.isEmpty { Text("[Empty text]").font(.caption) }
            Text(verbatim: text).textSelection(.enabled)
        }
    }
}
