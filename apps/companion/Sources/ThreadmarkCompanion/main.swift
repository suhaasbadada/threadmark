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
    private var item: NSStatusItem!
    private var window: NSWindow?
    private var observation: AnyCancellable?
    private let navigation = WindowNavigation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Threadmark"
        item.button?.setAccessibilityLabel("Threadmark status menu")
        observation = model.objectWillChange.sink { [weak self] in
            Task { @MainActor in self?.updateMenu() }
        }
        updateMenu()
    }
    private func updateMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Project: \(model.selectedID ?? "None")", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: model.status, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, model.paused ? "Resume automatic scheduling (no scheduler installed)" : "Pause automatic scheduling", #selector(pause), "p")
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
            window.contentView = NSHostingView(rootView: ManagementView(model: model, navigation: navigation))
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
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Local understanding, not another coding environment").font(.headline)
            Text(model.status).textSelection(.enabled).accessibilityLabel("Status: \(model.status)")
            HStack {
                Text(model.paused ? "Automatic scheduling: paused" : "Automatic scheduling: resumed (no scheduler installed)")
                Spacer()
                if model.busy { ProgressView().controlSize(.small); Button("Cancel", action: model.cancel).keyboardShortcut(".") }
            }
            TabView(selection: $navigation.tab) {
                ProjectsView(model: model).tabItem { Text("Projects") }.tag(0)
                ContextView(model: model).tabItem { Text("Context") }.tag(1)
                ConnectionsView(model: model).tabItem { Text("Connections") }.tag(2)
                PrivacyView(model: model).tabItem { Text("Privacy / Settings") }.tag(3)
            }
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Picker("Active project", selection: Binding(get: { model.selectedID ?? "" }, set: { model.select($0.isEmpty ? nil : $0) })) {
                        Text("None").tag("")
                        ForEach(model.projects) { Text($0.id).tag($0.id) }
                    }
                    Button("Refresh projects", action: model.refreshProjects).disabled(model.busy)
                    Button("Refresh selected", action: model.refreshSelected).disabled(model.selectedID == nil || model.busy)
                }
                if let project = model.project {
                    Text("Registered root: \(project.root)").textSelection(.enabled)
                    Text("Root identity: \(project.root_identity?.description ?? "not supplied")").textSelection(.enabled)
                    Button("Remove local project…", role: .destructive, action: model.requestRemoval)
                        .disabled(!model.canRemoveProject)
                    Text("Last project inspection snapshot: \(project.snapshot?.description ?? "not built")").textSelection(.enabled)
                    Text("Exact approved relative FILE allowlist — remove a line to exclude/revoke it. Empty policy revokes all sources.")
                    TextEditor(text: Binding(get: { model.sourceDraft.joined(separator: "\n") }, set: { model.stageSources(lines($0)) }))
                        .frame(minHeight: 85).accessibilityLabel("Approved relative file paths, one per line")
                    HStack {
                        Button("Apply source policy", action: model.applySources).disabled(!model.policyDirty || model.busy)
                        Button("Build project understanding", action: model.build).disabled(!model.canBuild).keyboardShortcut("b", modifiers: [.command, .shift])
                    }
                    Text("Build is a bounded local source-evidence operation (30 seconds; current core: lexical lines). No inference or automatic scan. Unsupported/unreadable files are decided by core; inspect coverage.").font(.caption)
                    if let report = model.indexReport {
                        Text("Snapshot \(report.snapshot.description) · \(report.files) files · \(report.anchors) anchors")
                        Text("Coverage: \(report.coverage.description)").textSelection(.enabled)
                    }
                    Divider()
                    HStack {
                        TextField("Search authorized source evidence", text: $query)
                        Button("Search") { model.query(query) }.disabled(query.isEmpty || query.utf8.count > 256 || model.busy || model.policyDirty)
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
                HStack { Button("Choose project root…") { chooseRoot() }; Text(root.isEmpty ? "No root selected" : root).textSelection(.enabled) }
                Text("Choose exact files below this root, or enter relative file paths. No globs, directories, traversal or external paths. Nothing is scanned now. Omitted files are excluded; core enforces 64 files / 64 KiB each / 1 MiB total.")
                Button("Choose exact source files…") { chooseFiles() }.disabled(root.isEmpty)
                TextEditor(text: $files).frame(minHeight: 85).accessibilityLabel("New project exact relative file allowlist")
                if !selectionError.isEmpty { Text(selectionError) }
                Button("Approve root and file allowlist") { model.addProject(id: newID, root: root, sources: newSources) }
                    .disabled(root.isEmpty || !InputPolicy.identifier(newID) || !InputPolicy.sources(newSources) || newSources.isEmpty || model.busy)
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
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: root)
        if panel.runModal() == .OK {
            let prefix = URL(fileURLWithPath: root).standardizedFileURL.path + "/"
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
                    }.disabled(model.busy)
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
                        Button("Retire (retain history)") { model.retireContext(history.id); editing = false }.disabled(model.busy)
                    }
                }
                Divider()
                Text(editing ? "Edit human context" : "Add human context").font(.headline)
                TextField("Context ID", text: $id).disabled(editing)
                Picker("Kind", selection: $kind) {
                    ForEach(InputPolicy.contextKinds, id: \.self) { Text($0).tag($0) }
                }
                TextEditor(text: $text).frame(minHeight: 120).accessibilityLabel("Human context text")
                Text("Human context is limited to 4 KiB of UTF-8 text; input is never truncated.").font(.caption)
                HStack {
                    Button(editing ? "Save new revision" : "Add context") {
                        model.writeContext(id: id, kind: kind, text: text, update: editing)
                    }.disabled(model.project == nil || model.busy || !InputPolicy.identifier(id) || text.isEmpty || text.utf8.count > 4096)
                    Button("New entry") { id = ""; text = ""; kind = "note"; editing = false }
                }
                Text("Forget is unavailable in client-v1. Retire does not delete retained history. No removal or persistence claim is made beyond the core response.").font(.caption)
            }.padding()
        }.onChange(of: model.scopeRevision) { _ in id = ""; text = ""; editing = false }
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
                Button("Cancel / dismiss preview", action: model.dismissPreview)
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
            }.disabled(binary == nil || dataDirectory == nil || model.busy)
            Text("\(model.configured ? "Configured (not certified)" : "Unavailable") · configuration is memory-only; no executable is invoked until an explicit operation.")
            Divider()
            Text("Inference profiles: unavailable / disabled").font(.headline)
            Text("No provider client, credentials, consent or budget transport is implemented. Semantic work cannot start.")
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
            Text("Search results, note drafts, configuration and previews remain in process memory. No shell content archive, telemetry, OS notifications or provider calls. Core history retention is separate; Retire preserves history.")
            Text(model.notificationPolicy)
            Button(model.paused ? "Resume automatic scheduling" : "Pause automatic scheduling", action: model.togglePause)
            Text("No automatic scheduler is installed. Pause blocks future automatic work; explicit Build remains a labeled manual action.")
            Text("Launch at login: off / unavailable in this build. No login item or global preferences are written.")
            Text("System light/dark appearance, standard controls, keyboard focus and text status are used. No custom animation; reduced-motion settings need no override. Native accessibility/runtime acceptance is still pending.")
            Spacer()
        }.padding()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
