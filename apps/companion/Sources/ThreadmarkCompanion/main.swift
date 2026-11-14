import AppKit
import SwiftUI
import Combine
import CompanionKit

// Explicit property-wrapper alias avoids the new SDK's same-named State macro,
// whose plugin is not shipped in the installed command-line-only SDK.
private typealias ViewState<Value> = SwiftUI.State<Value>

@MainActor
final class WindowNavigation: ObservableObject {
    @Published var tab = 0
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = CompanionModel()
    private lazy var providers = CompanionProviderSession { [weak self] in self?.model.dismissPreview() }
    let launch: LaunchConfiguration
    private var item: NSStatusItem!
    private var window: NSWindow?
    private var observation: AnyCancellable?
    private let navigation = WindowNavigation()

    init(launch: LaunchConfiguration) { self.launch = launch; super.init() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Threadmark"
        item.button?.setAccessibilityLabel("Threadmark status menu")
        observation = model.objectWillChange.sink { [weak self] in
            Task { @MainActor in self?.updateMenu() }
        }
        updateMenu()
        if let executable = launch.executable, let directory = launch.dataDirectory {
            model.configure(executable: executable, dataDirectory: directory)
        }
        // Configuration is session-only, so every launch needs a visible next step.
        open(tab: model.configured ? 0 : 2)
    }
    private func updateMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Project: \(model.selectedID ?? "None")", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: model.automaticRefreshConsent == nil ? "File-event + periodic refresh: off" : "File-event + periodic refresh: approved", action: nil, keyEquivalent: "")
        add(menu, model.paused ? "Resume approved refresh" : "Pause approved refresh", #selector(pause), "p")
        add(menu, "Manage projects/context…", #selector(manage), ",")
        add(menu, "Connections / Privacy…", #selector(connections), "")
        if model.busy { add(menu, "Cancel owned operation", #selector(cancel), ".") }
        menu.addItem(.separator())
        add(menu, "Quit Threadmark", #selector(quit), "q")
        item.menu = menu
    }
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        let row = menu.addItem(withTitle: title, action: action, keyEquivalent: key); row.target = self
    }
    @objc func pause() { model.togglePause() }
    @objc func cancel() { model.cancel() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func connections() { open(tab: 2) }
    @objc func manage() { open(tab: 0) }
    private func open(tab: Int) {
        navigation.tab = tab
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 700),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Threadmark — Manage"
            window.contentMinSize = NSSize(width: 640, height: 520)
            window.isReleasedWhenClosed = false; window.delegate = self
            window.contentView = NSHostingView(rootView: ManagementView(model: model, navigation: navigation, providers: providers))
            window.center(); self.window = window
        }
        model.showManagement(); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if !model.closeExplanationShown {
            let alert = NSAlert()
            alert.messageText = "Threadmark stays in the menu bar"
            alert.informativeText = "Closing Manage keeps owned work running. Use Quit Threadmark to cancel owned work and exit."
            alert.addButton(withTitle: "Close Manage"); alert.runModal()
        }
        model.closeManagement(); return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { await model.shutdown(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

@MainActor
struct ManagementView: View {
    @ObservedObject var model: CompanionModel
    @ObservedObject var navigation: WindowNavigation
    @ObservedObject var providers: CompanionProviderSession
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Local understanding, not another coding environment").font(.headline)
            Text(model.status).textSelection(.enabled).accessibilityLabel("Status: \(model.status)")
            HStack {
                Text(model.automaticRefreshSummary)
                Spacer()
                if model.busy { ProgressView().controlSize(.small); Button("Cancel", action: model.cancel).keyboardShortcut(".") }
            }
            TabView(selection: $navigation.tab) {
                ProjectsView(model: model).tabItem { Text("Projects") }.tag(0)
                ContextView(model: model).tabItem { Text("Context") }.tag(1)
                ConnectionsView(model: model, providers: providers).tabItem { Text("Connections") }.tag(2)
                PrivacyView(model: model).tabItem { Text("Privacy / Settings") }.tag(3)
            }
            HStack {
                Button("1. Connections") { navigation.tab = 2 }
                Button("2. Projects / Build") { navigation.tab = 0 }
                Button("3. Notes / Context preview") { navigation.tab = 1 }
            }.font(.caption)
            Text("Closing this window keeps Threadmark in the menu bar. Quit cancels owned work.").font(.caption)
        }.padding(16)
    }
}

@MainActor
struct ProjectsView: View {
    @ObservedObject var model: CompanionModel
    @ViewState<String> private var newID = ""
    @ViewState<String> private var root = ""
    @ViewState<String> private var files = ""
    @ViewState<String> private var query = ""
    @ViewState<String> private var selectionError = ""
    private var newSources: [String] { lines(files) }
    private var approvalRoot: String? {
        guard root.hasPrefix("/"), !root.contains("\0") else { return nil }
        return try? StoreSelection.existingDirectory(URL(fileURLWithPath: root)).path
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Picker("Active project", selection: Binding(get: { model.selectedID ?? "" }, set: { model.select($0.isEmpty ? nil : $0) })) {
                        Text("None").tag("")
                        ForEach(model.projects) { Text($0.id).tag($0.id) }
                    }
                    Button("Refresh projects", action: model.refreshProjects).disabled(!model.manualActionsAvailable)
                    Button("Refresh selected", action: model.refreshSelected).disabled(model.selectedID == nil || !model.manualActionsAvailable)
                }
                if let project = model.project {
                    Text("Registered root: \(project.root)").textSelection(.enabled)
                    Text("Root identity: \(project.root_identity?.description ?? "not supplied")").textSelection(.enabled)
                    Button("Inspect source suppression markers", action: model.inspectForgottenSources)
                        .disabled(!model.canRemoveProject || model.policyDirty)
                    if let markers = model.sourceMarkers {
                        Text("Suppressed relative files (non-content): \(markers.forgotten.map(\.path).joined(separator: ", "))").textSelection(.enabled)
                    }
                    Text("Source Forget requires a successful schema-v4 marker inspection in this scope. It is separate from plain allowlist editing.").font(.caption)
                    ForEach(project.sources, id: \.self) { path in
                        HStack {
                            Text(path).textSelection(.enabled)
                            Button("Forget source…", role: .destructive) { model.requestSourceForget(path) }
                                .disabled(!model.canForgetSource(path))
                                .accessibilityLabel("Forget source \(path)")
                        }
                    }
                    Button("Remove local project…", role: .destructive, action: model.requestRemoval)
                        .disabled(!model.canRemoveProject)
                    Text("Last project inspection snapshot: \(project.snapshot?.description ?? "not built")").textSelection(.enabled)
                    Text("Exact approved relative FILE allowlist — remove a line to exclude/revoke it. Empty policy revokes all sources.")
                    TextEditor(text: Binding(get: { model.sourceDraft.joined(separator: "\n") }, set: { model.stageSources(lines($0)) }))
                        .frame(minHeight: 85).accessibilityLabel("Approved relative file paths, one per line")
                    HStack {
                        Button("Apply source policy", action: model.applySources).disabled(!model.policyDirty || model.busy || model.sourceRequiresRefresh)
                        Button("Build project understanding", action: model.build).disabled(!model.canBuild).keyboardShortcut("b", modifiers: [.command, .shift])
                            .accessibilityIdentifier("project-build")
                    }
                    Text("Manual Build: bounded local lexical lines (30 seconds). No inference. Unsupported/unreadable files are decided by core; inspect coverage.").font(.caption)
                    if let consent = model.automaticRefreshProposal {
                        Text("Optional approved-file events + periodic bounded full lexical reconciliation — not an incremental symbol index.").font(.headline)
                        Text("Project: \(consent.projectID) · root: \(consent.root) · identity: \(consent.rootIdentity)").textSelection(.enabled)
                        Text("Exact files read automatically: \(consent.sources.joined(separator: ", "))").textSelection(.enabled)
                        Text("Metadata watches only these exact files; event bursts coalesce for 300 ms. Approved contents are reconciled after hints and every 60 seconds for missed/busy events; 30 seconds/job, 64 files/handles, 64 KiB/file, 1 MiB total. Session-only, off on relaunch. No immediate content read. Busy hints/ticks are skipped. Pause closes watches and cancels automatic work. Missing/unsafe files stop monitoring and require repair and re-enable. No directory discovery, inference, network, notifications or history archive.").font(.caption)
                        if model.automaticRefreshConsent == nil {
                            Button("Enable file metadata watches + automatic approved-content reads") { model.enableAutomaticRefresh(consent) }.disabled(model.busy)
                        } else {
                            Button("Disable automatic reads", action: model.disableAutomaticRefresh)
                        }
                    }
                    if let report = model.indexReport {
                        Text("Snapshot \(report.snapshot.description) · \(report.files) files · \(report.anchors) anchors")
                        Text("Coverage: \(report.coverage.description)").textSelection(.enabled)
                    }
                    Divider()
                    HStack {
                        TextField("Search authorized source evidence", text: $query)
                            .accessibilityIdentifier("project-evidence-query")
                        Button("Search") { model.query(query) }.disabled(query.isEmpty || query.utf8.count > 256 || !model.manualActionsAvailable || model.policyDirty || model.sourceRequiresRefresh)
                    }
                    Text("Search input is limited to 256 UTF-8 bytes; input is never truncated.").font(.caption)
                    if let result = model.evidence {
                        Text("\(result.currentness) · snapshot \(result.snapshot?.description ?? "none")")
                        Text("Coverage: \(result.coverage.description)")
                        ForEach(Array(result.results.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading) {
                                Text("\(item.path):\(item.line) · \(item.producer) · \(item.currentness)").font(.caption)
                                Text(item.text).textSelection(.enabled)
                            }
                        }
                    }
                }
                Divider()
                Text("Register a project — explicit approval before any Build").font(.headline)
                TextField("Project ID (letters, digits, hyphen, underscore)", text: $newID)
                    .accessibilityIdentifier("registration-project-id")
                HStack { Button("Choose project root…") { chooseRoot() }; Text(root.isEmpty ? "No root selected" : root).textSelection(.enabled) }
                TextField("Exact absolute project root (or choose above)", text: $root)
                    .accessibilityIdentifier("registration-root")
                    .onChange(of: root) { _ in files = ""; selectionError = "" }
                Text(approvalRoot.map { "Root used for approval: \($0)" } ?? "Choose an existing absolute root before approving.")
                    .textSelection(.enabled)
                Text("Choose exact files below this root, or enter relative file paths. No globs, directories, traversal or external paths. Nothing is scanned now. Omitted files are excluded; core enforces 64 files / 64 KiB each / 1 MiB total.")
                Button("Choose exact source files…") { chooseFiles() }.disabled(approvalRoot == nil)
                TextEditor(text: $files).frame(minHeight: 85).accessibilityLabel("New project exact relative file allowlist")
                if !selectionError.isEmpty { Text(selectionError) }
                Button("Approve root and file allowlist") {
                    if let approvalRoot { model.addProject(id: newID, root: approvalRoot, sources: newSources) }
                }
                    .accessibilityIdentifier("registration-approve")
                    .disabled(!model.configured || approvalRoot == nil || !InputPolicy.identifier(newID) || !InputPolicy.sources(newSources) || newSources.isEmpty || !model.manualActionsAvailable)
            }.padding()
        }
        .sheet(item: Binding(get: { model.pendingRemoval }, set: { if $0 == nil { model.cancelRemoval() } })) { confirmation in
            VStack(alignment: .leading, spacing: 14) {
                Text("Remove local project data?").font(.headline)
                Text("Project: \(confirmation.project.id)")
                Text("Root: \(confirmation.project.root)").textSelection(.enabled)
                Text("Root identity: \(confirmation.project.root_identity?.description ?? "unavailable")").textSelection(.enabled)
                Text("Permanently removes all local notes and their revision history, source evidence and project policy. Never deletes source files. This is not Forget/suppression or forensic erasure: SQLite free pages, sidecars, backups and exports may retain historical bytes. Re-registration may import source evidence again, not old notes.")
                HStack {
                    Button("Cancel", action: model.cancelRemoval).keyboardShortcut(.defaultAction)
                    Button("Remove all local project data", role: .destructive) { model.confirmRemoval(confirmation) }
                }
            }.padding().frame(width: 560)
        }
        .sheet(item: Binding(get: { model.pendingSourceForget }, set: { if $0 == nil { model.cancelSourceForget() } })) { confirmation in
            VStack(alignment: .leading, spacing: 14) {
                Text("Forget source derivatives and revoke this file?").font(.headline)
                Text("Project: \(confirmation.project.id) · File: \(confirmation.path)").textSelection(.enabled)
                Text("Root: \(confirmation.project.root)").textSelection(.enabled)
                Text("Root identity: \(confirmation.project.root_identity?.description ?? "unavailable")").textSelection(.enabled)
                Text("Registration incarnation: \(confirmation.project.incarnation ?? "unavailable")").textSelection(.enabled)
                Text("Exact captured approved policy: \(confirmation.project.sources.joined(separator: ", "))").textSelection(.enabled)
                Text("Removes active SOURCE facts and invalidates the entire project's coherent source snapshot. Revokes this file's read/reimport approval and retains a non-content suppression marker. No unforget is available. Remaining approved files need rebuilding as needed.")
                Text("The SOURCE FILE, saved HUMAN history, unsaved human editor and original request draft are untouched. Prior displayed copies, exports and backups cannot be recalled.")
                Text(ForgottenSource.retentionLimits)
                HStack {
                    Button("Cancel", action: model.cancelSourceForget).keyboardShortcut(.defaultAction)
                    Button("Forget source and revoke approval", role: .destructive) { model.confirmSourceForget(confirmation) }
                }
            }.padding().frame(width: 580)
        }
    }
    private func lines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }
    private func chooseRoot() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.prompt = "Select explicit root"
        if panel.runModal() == .OK, let url = panel.url { root = url.path; files = ""; selectionError = "" }
    }
    private func chooseFiles() {
        guard let approvalRoot else { return }
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: approvalRoot)
        if panel.runModal() == .OK {
            let prefix = URL(fileURLWithPath: approvalRoot).standardizedFileURL.path + "/"
            guard panel.urls.allSatisfy({ $0.standardizedFileURL.path.hasPrefix(prefix) }) else {
                selectionError = "Selection rejected: external paths are not authorized."; return
            }
            let paths = panel.urls.map { String($0.standardizedFileURL.path.dropFirst(prefix.count)) }
            guard InputPolicy.sources(paths) else { selectionError = "Selection rejected: choose at most 64 exact relative files."; return }
            files = paths.joined(separator: "\n"); selectionError = ""
        }
    }
}

@MainActor
struct ContextView: View {
    @ObservedObject var model: CompanionModel
    @ViewState<String> private var search = ""
    @ViewState<String> private var id = ""
    @ViewState<String> private var kind = "note"
    @ViewState<String> private var text = ""
    @ViewState<Bool> private var editing = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Explicit project: \(model.selectedID ?? "None")").font(.headline)
                ContextPreparationView(model: model)
                Divider()
                Text("Human declarations are not observed source truth. Edits create revisions in core; retire preserves history. Conflicts are not silently resolved by this shell.")
                TextField("Filter context IDs or kinds", text: $search)
                ForEach(model.contexts.filter { search.isEmpty || $0.id.localizedCaseInsensitiveContains(search) || $0.kind.localizedCaseInsensitiveContains(search) }) { entry in
                    Button("\(entry.id) · \(entry.kind) · revision \(entry.revision) · \(entry.retired ? "retired" : "active") · \(entry.producer)") {
                        editing = false; model.openContext(entry.id)
                    }.disabled(!model.manualActionsAvailable)
                }
                if let history = model.history {
                    Text("Scope: \(history.project) · \(history.producer) · authority \(history.authority.description)").font(.caption)
                    ForEach(history.history, id: \.revision) { revision in
                        VStack(alignment: .leading) {
                            Text("Revision \(revision.revision) · \(revision.kind) · \(revision.retired ? "retired" : "active")").font(.headline)
                            Text(revision.text).textSelection(.enabled)
                        }
                    }
                    HStack {
                        Button("Edit latest revision") {
                            if let latest = history.history.max(by: { $0.revision < $1.revision }) {
                                id = history.id; kind = latest.kind; text = latest.text; editing = true
                            }
                        }
                        Button("Retire (retain history)") { model.retireContext(history.id); editing = false }.disabled(!model.manualActionsAvailable || model.project?.incarnation == nil || model.sourceRequiresRefresh)
                        Button("Forget entry…", role: .destructive, action: model.requestForget).disabled(!model.canForgetContext)
                    }
                }
                Divider()
                Text(editing ? "Edit human context" : "Add human context").font(.headline)
                TextField("Context ID", text: $id).disabled(editing)
                    .accessibilityIdentifier("human-context-id")
                Picker("Kind", selection: $kind) {
                    ForEach(InputPolicy.contextKinds, id: \.self) { Text($0).tag($0) }
                }
                TextEditor(text: $text).frame(minHeight: 120).accessibilityLabel("Human context text")
                    .accessibilityIdentifier("human-context-draft")
                Text("Human context is limited to 4 KiB of UTF-8 text; input is never truncated.").font(.caption)
                HStack {
                    Button(editing ? "Save new revision" : "Add context") {
                        model.writeContext(id: id, kind: kind, text: text, update: editing)
                    }.accessibilityIdentifier("human-context-save")
                        .disabled(model.project?.incarnation == nil || model.sourceRequiresRefresh || !model.manualActionsAvailable || !InputPolicy.identifier(id) || text.isEmpty || text.utf8.count > 4096)
                    Button("New entry") { id = ""; text = ""; kind = "note"; editing = false }
                }
                Button("Inspect non-content suppression markers", action: model.inspectForgottenContexts)
                    .disabled(model.project?.incarnation == nil || !model.manualActionsAvailable)
                if let markers = model.forgottenMarkers {
                    Text("Forgotten IDs (not retained history): \(markers.forgotten.map(\.id).joined(separator: ", "))").textSelection(.enabled)
                }
                Text("Retire retains history. Human Forget requires schema v3 or later and explicit confirmation. Source Forget is separate in Projects after v4 marker inspection. Restore and unforget are unavailable.").font(.caption)
            }.padding()
        }.onChange(of: model.contextEditorRevision) { _ in id = ""; text = ""; editing = false; kind = "note" }
        .onChange(of: id) { _ in model.contextEditorChanged() }
        .onChange(of: kind) { _ in model.contextEditorChanged() }
        .onChange(of: text) { _ in model.contextEditorChanged() }
        .onChange(of: editing) { _ in model.contextEditorChanged() }
        .sheet(item: Binding(get: { model.pendingForget }, set: { if $0 == nil { model.cancelForget() } })) { confirmation in
            VStack(alignment: .leading, spacing: 14) {
                Text("Forget ALL local history for this entry?").font(.headline)
                Text("Project: \(confirmation.project.id) · Context: \(confirmation.contextID)")
                Text("Latest revision: \(confirmation.revision) · Revisions to remove: \(confirmation.revision)")
                Text("Root: \(confirmation.project.root)").textSelection(.enabled)
                Text("Root identity: \(confirmation.project.root_identity?.description ?? "unavailable")").textSelection(.enabled)
                Text("Registration incarnation: \(confirmation.project.incarnation ?? "unavailable")").textSelection(.enabled)
                Text("Permanently removes ALL local revisions for this human entry and suppresses same-ID recreation in this registration. Unsaved human editor text will be cleared on confirmation; the unrelated original request draft is preserved. Retire instead if you need retained history.")
                Text(ForgottenContext.retentionLimits)
                Text("Already displayed copies cannot be recalled. No restore or unforget is provided.")
                HStack {
                    Button("Cancel", action: model.cancelForget).keyboardShortcut(.defaultAction)
                    Button("Forget all local entry history", role: .destructive) { model.confirmForget(confirmation) }
                }
            }.padding().frame(width: 580)
        }
    }
}

@MainActor
struct ContextPreparationView: View {
    @ObservedObject var model: CompanionModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Context-only preview · no AI").font(.headline)
            Text("Occasional local evidence review, not a chat or coding-tool composer. Drafts and previews stay in memory; nothing is saved, copied or sent.")
            TextField("Evidence query (up to 256 UTF-8 bytes)", text: Binding(
                get: { model.preparationQuery },
                set: { model.editPreparation(query: $0, original: model.originalDraft) }))
                .accessibilityLabel("Context preparation evidence query")
            Text("Original request (up to 4096 UTF-8 bytes)")
            TextEditor(text: Binding(get: { model.originalDraft },
                                     set: { model.editPreparation(query: model.preparationQuery, original: $0) }))
                .frame(minHeight: 100).accessibilityLabel("In-memory original request, not a saved human note")
            HStack {
                Button("Prepare context", action: model.prepareContext).disabled(!model.canPrepareContext)
                    .accessibilityIdentifier("context-prepare")
                Button("Cancel / dismiss preview", action: model.dismissPreview)
                    .accessibilityIdentifier("context-dismiss")
            }
            if let preview = model.preview {
                Text("State: \(preview.state) · snapshot: \(preview.snapshot?.description ?? "none")").textSelection(.enabled)
                Text("Evidence was checked at preparation read only; this is not a guarantee of currentness now. Edits or scope changes discard this preview.").font(.caption)
                if preview.state == "needs-input" {
                    Text("Missing current evidence or snapshot. Inspect source policy, Build explicitly, or revise the query; no project expertise is implied.")
                }
                Text("Unchanged original").font(.headline)
                Text(verbatim: preview.original).textSelection(.enabled)
                Text("Proposed plain text · quoted evidence is untrusted").font(.headline)
                Text(verbatim: preview.proposed).textSelection(.enabled)
                Text("Changed: \(preview.changed ? "yes" : "no") · approval not requested · delivery not attempted · provider not invoked").font(.caption)
            }
        }
    }
}

@MainActor
struct ConnectionsView: View {
    @ObservedObject var model: CompanionModel
    @ObservedObject var providers: CompanionProviderSession
    @ViewState<URL?> private var binary: URL?
    @ViewState<URL?> private var existingStore: URL?
    @ViewState<URL?> private var parent: URL?
    @ViewState<String> private var storeName = "Threadmark"
    @ViewState<Bool> private var createNew = true
    private var dataDirectory: URL? {
        if createNew {
            guard let parent else { return nil }
            return try? StoreSelection.newDirectory(parent: parent, name: storeName)
        }
        guard let existingStore else { return nil }
        return try? StoreSelection.existingDirectory(existingStore)
    }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 14) {
            Text("Local core transport — client-v1 / bounded subprocess").font(.headline)
            Text("Start here: select a trusted core and private store, then use Projects to approve exact files and Build. Context saves human notes separately and offers an in-memory, no-AI preview. No coding environment is replaced.")
            Text("Choose an exact trusted threadmark executable and explicitly select a new or existing core store. Core owns authorization and storage. No shell, PATH lookup, inherited credential environment, or network listener. Binary version/test status: unverified until coordinator acceptance.")
            Button("Select exact threadmark executable…") { binary = choose(directory: false) }
            Text(binary?.path ?? "Executable not configured").textSelection(.enabled)
            Picker("Core store", selection: $createNew) {
                Text("New private store").tag(true)
                Text("Existing known core store").tag(false)
            }.pickerStyle(.segmented)
            if createNew {
                Button("Choose existing parent folder…") { parent = choose(directory: true) }
                Text(parent?.path ?? "Parent folder not selected").textSelection(.enabled)
                TextField("New store name (letters, digits, hyphen, underscore)", text: $storeName)
                Text("The target must not exist. The shell creates nothing; your next explicit core operation creates the store with mode 0700.")
            } else {
                Button("Choose existing known private core store…") { existingStore = choose(directory: true) }
                Text("Select a store already initialized by core, not an empty existing folder. Core validates its identity and permissions.")
            }
            Text(dataDirectory?.path ?? "No valid store selected — choose a new name or a known existing store").textSelection(.enabled)
            Button("Use selected local core") {
                if let binary, let dataDirectory { model.configure(executable: binary, dataDirectory: dataDirectory) }
            }.disabled(binary == nil || dataDirectory == nil || !model.manualActionsAvailable)
            Text("\(model.configured ? "Configured (not certified)" : "Unavailable") · configuration is memory-only; executable runs only for explicit actions or separately opted-in file-event/periodic lexical refresh.")
            Divider()
            ProviderConfigurationView(settings: providers.binding)
            HStack {
                Button("Save private profile file…") {
                    let panel = NSSavePanel(); panel.nameFieldStringValue = "provider-profile.json"
                    panel.title = "Save NEW nonsecret profile in an owned private (0700) folder"
                    panel.canCreateDirectories = false
                    providers.save(to: panel.runModal() == .OK ? panel.url : nil)
                }.accessibilityIdentifier("provider-profile-file-save")
                Button("Load private profile file…") {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true
                    panel.allowsMultipleSelection = false; panel.resolvesAliases = false
                    providers.load(from: panel.runModal() == .OK ? panel.url : nil)
                }.accessibilityIdentifier("provider-profile-file-load")
            }
            Text(providers.status).accessibilityIdentifier("provider-profile-file-status")
            Text("Changing, enabling, disabling or loading settings clears the current preview and cancels owned work through the existing app cancellation boundary. Original request and note editor text remain intact; automatic lexical refresh must be approved again if canceled.").font(.caption)
            Text("Save writes only nonsecret profiles/selection, never drafts or consent, at most 64 KiB. Use a new filename in an existing owned 0700 folder (no ACLs); files must be owned regular 0600 files, without ACLs, links or symlink parents. Existing destinations are never overwritten. Load accepts only Threadmark's canonical JSON format and always leaves inference off. No automatic loading or global configuration.").font(.caption)
            Text("Transport capability: numeric-loopback HTTP only. Remote HTTPS profiles may be saved but remote inference is NOT ready. App Refine/runtime consent integration remains unavailable here; settings never call a model or send a request.").font(.caption)
            Text("Coding-client adapters: unavailable / not certified").font(.headline)
            Text("No host is installed, modified, launched, or connected. No send operation exists. Version, trust test and uninstall: not applicable.")
            Spacer()
        }.padding() }
    }
    private func choose(directory: Bool) -> URL? {
        let panel = NSOpenPanel(); panel.canChooseDirectories = directory; panel.canChooseFiles = !directory
        panel.resolvesAliases = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

@MainActor
struct PrivacyView: View {
    @ObservedObject var model: CompanionModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Privacy and background behavior").font(.headline)
            Text("Local storage is owned by core in your explicitly selected data directory. Source scope is an exact file allowlist; source files are never changed by this shell. IDs are not credentials.")
            Text("Search results, note drafts and previews remain in process memory. Nonsecret provider profiles are saved only to an explicitly chosen private app profile file; loading never enables inference. No shell content archive, telemetry, OS notifications or provider calls. Core history retention is separate; Retire preserves history.")
            Text(model.notificationPolicy)
            Button(model.paused ? "Resume automatic scheduling" : "Pause automatic scheduling", action: model.togglePause)
            Text("File-event + periodic lexical refresh is off by default. Projects offers exact-scope session-only consent to file metadata watches and automatic approved-content reconciliation, with a 60-second fallback for missed/busy events. Pause closes watches, stops debounce/timer and cancels automatic work; Resume never grants consent. Manual Build remains available while paused. Disable, scope/configuration changes and Quit stop automatic work. Closing Manage does not stop opted-in refresh. No directory discovery or automatic inference.")
            Text("Launch at login: off / unavailable in this build. No login item or global preferences are written.")
            Text("System light/dark appearance, standard controls, keyboard focus and text status are used. No custom animation; reduced-motion settings need no override. Native accessibility/runtime acceptance is still pending.")
            Spacer()
        }.padding()
    }
}

let launch: LaunchConfiguration
do {
    launch = try LaunchConfiguration.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    FileHandle.standardError.write(Data("Invalid or unavailable launch configuration; use paired absolute --core-binary and --data-dir paths.\n".utf8))
    exit(2)
}
if launch.validateOnly {
    print("Launch configuration valid; core not invoked; store not created or inspected by core.")
    exit(0)
}
let app = NSApplication.shared
let delegate = AppDelegate(launch: launch)
app.delegate = delegate
app.run()
