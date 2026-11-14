import SwiftUI

public struct IncrementalBuildView: View {
    @ObservedObject private var model: CompanionModel
    public init(model: CompanionModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("Incremental lexical Build (SQL row reuse)", action: model.buildIncrementally)
                .disabled(!model.canBuildIncrementally)
                .accessibilityIdentifier("incremental-lexical-build")
            Text("Optional explicit alternative to Full Build, not an automatic refresh mode. Reads every approved source and computes lexical lines; reuses eligible SQL rows only. Not AST/semantic understanding, skipped CPU work or measured performance gains.")
                .font(.caption)
            if let r = model.incrementalBuildReport {
                Text("Files: \(r.files) · reused \(r.reusedFiles) · reindexed \(r.reindexedFiles)")
                Text("Anchor SQL rows: reused \(r.reusedAnchors) · deleted \(r.deletedAnchors) · inserted \(r.writtenAnchors) · total \(r.anchors)")
                Text("Persistent SQL writes: \(r.persistentWrites ? "yes" : "no (validated no-op)") · snapshot changed: \(r.snapshotUpdated ? "yes" : "no")")
                Text("Snapshot: \(r.snapshot)").textSelection(.enabled)
                Text("Lexical only; not Ready or complete. Even a zero-write no-op runs all freshness and validation checks. Cancellation is cooperative; interrupted/failed commit or metadata adoption may leave an unknown persisted outcome, not a rollback guarantee.")
                    .font(.caption)
            }
        }
    }
}
