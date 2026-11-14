import SwiftUI

/// Metadata only. There is deliberately no appearance/selection/refresh fetch.
public struct CoverageControls: View {
    @ObservedObject var model: CompanionModel
    public init(model: CompanionModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Inspect coverage", action: model.inspectCoverage)
                .disabled(!model.canInspectCoverage)
                .accessibilityLabel("Inspect approved project file coverage and freshness, metadata only")
                .accessibilityIdentifier("project-inspect-coverage")
            Text("Explicit approved files only · lexical inventory, not semantic completeness. No automatic Build or refresh.").font(.caption)
            Text("After a failed or canceled inspection, explicitly Refresh project metadata before inspecting coverage again.").font(.caption)
            if let report = model.coverageReport {
                Text("Current-at-read only — not a future filesystem lease. Semantic completeness: not assessed.")
                Text("Approved: \(report.files.count) · readable: \(report.readableFiles) · unavailable or unsafe: \(report.files.count - report.readableFiles) · baseline matching: \(report.matchingFiles)")
                Text("Stored anchor records: \(report.storedAnchorRecords) — records, not semantic evidence or completeness.")
                Text("Entire project baseline current at read: \(report.projectSnapshotCurrent ? "yes" : "no"). Needs Build: \(report.needsBuild.map { $0 ? "yes" : "no" } ?? "unknown"). Readability review: \(report.needsReadabilityReview ? "needed" : "not indicated").")
                Text("Historical baseline snapshot: \(report.baselineSnapshot ?? "none")").font(.caption)
                if report.files.isEmpty { Text("Empty approved policy — no semantic completeness claim.") }
                ForEach(Array(report.files.enumerated()), id: \.offset) { _, file in
                    VStack(alignment: .leading) {
                        Text("\(file.path) · \(file.status)")
                        Text("Baseline exists: \(file.baselineExists ? "yes" : "no") · matches: \(file.baselineMatches ? "yes" : "no") · stored anchor records: \(file.storedAnchorRecords)").font(.caption)
                        if let hash = file.observedHash, let bytes = file.byteCount, let lines = file.lineCount {
                            Text("Admitted current-at-read observation: \(bytes) bytes · \(lines) lines · hash \(hash)").font(.caption)
                        } else {
                            Text("Current metadata unknown — unavailable or unsafe; no missing/permission diagnosis.").font(.caption)
                        }
                    }
                }
            }
        }
    }
}
