import AppKit
import SwiftUI

private typealias ExportViewState<Value> = SwiftUI.State<Value>

/// No onAppear/task fetch. The picker opens only from the explicit confirmation
/// button; its callback has no authority without the model's current token.
public struct ProjectExportView: View {
    @ObservedObject private var model: CompanionModel
    @ExportViewState private var presenting = false
    public init(model: CompanionModel) { self.model = model }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            exportControl
            if let status = model.projectExportStatus { Text(status).font(.caption).textSelection(.enabled) }
        }
    }
    private var exportControl: some View {
        Button("Export project…") {
            model.requestProjectExport(); presenting = model.pendingProjectExport != nil
        }.disabled(!model.canExportProject)
            .accessibilityIdentifier("project-export")
            .sheet(item: Binding(get: { presenting ? model.pendingProjectExport : nil }, set: { value in
                if value == nil {
                    presenting = false
                    if model.pendingProjectExport != nil { model.cancelProjectExport() }
                }
            })) { confirmation in
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export sensitive local project content?").font(.headline)
                    Text("Project: \(confirmation.project.id)\nRegistered root (not exported): \(confirmation.project.root)\nRoot identity: \(confirmation.project.root_identity?.description ?? "unavailable")\nRegistration: \(confirmation.project.incarnation ?? "unavailable")\nSnapshot: \(confirmation.project.snapshot?.description ?? "none")").textSelection(.enabled)
                    Text("Exact ordered relative source policy: \(confirmation.project.sources.joined(separator: ", "))").textSelection(.enabled)
                    Text(ProjectExportConfirmation.disclosure)
                    Text("Choose a NEW filename in an existing owned private (0700, no ACL) local folder, outside source projects and the core store. No overwrite or automatic directory creation. At most 1 MiB complete JSON. Cancellation is cooperative; OS filesystem I/O has no guaranteed hard deadline. A published file is never removed as cleanup; an uncertain result requires inspecting your chosen destination.")
                    HStack {
                        Button("Cancel") { presenting = false; model.cancelProjectExport() }.keyboardShortcut(.defaultAction)
                        Button("Confirm content export; choose file…") {
                            guard let token = model.confirmProjectExport(confirmation) else { return }
                            presenting = false
                            let panel = NSSavePanel()
                            panel.title = "Save NEW private local project export"
                            panel.nameFieldStringValue = "threadmark-project-export.json"
                            panel.canCreateDirectories = false
                            panel.begin { response in
                                model.completeProjectExportSelection(token, destination: response == .OK ? panel.url : nil)
                            }
                        }.accessibilityIdentifier("project-export-confirm")
                    }
                }.padding().frame(width: 610)
            }
    }
}
