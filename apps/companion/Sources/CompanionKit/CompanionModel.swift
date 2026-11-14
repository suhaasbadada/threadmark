import Foundation
import Combine

@MainActor
public final class CompanionModel: ObservableObject {
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var pendingRemoval: RemovalConfirmation?
    @Published public private(set) var pendingForget: ForgetConfirmation?
    @Published public private(set) var pendingSourceForget: SourceForgetConfirmation?
    @Published public private(set) var sourceMarkers: ForgottenSources?
    @Published public private(set) var sourceRequiresRefresh = false
    private var mutationRefreshError: ServiceError?
    private var refreshRequiredError: ServiceError { mutationRefreshError ?? .sourceForgetUncertain }
    private var inspectedSourceScope: Project?
    @Published public private(set) var forgottenMarkers: ForgottenContexts?
    @Published public private(set) var contextEditorRevision: UInt64 = 0
    @Published public private(set) var forgetRequiresRefresh = false
    @Published public private(set) var selectedID: String?
    @Published public private(set) var project: Project?
    @Published public private(set) var contexts: [ContextEntry] = []
    @Published public private(set) var humanSearch: HumanContextSearch?
    private var humanSearchScope: Project?
    private var humanSearchTicket: UInt64?
    private var humanSearchCancellationTicket: UInt64?
    @Published public private(set) var history: ContextHistory?
    @Published public private(set) var evidence: QueryReport?
    @Published public private(set) var preview: ContextPreview?
    @Published public private(set) var originalDraft = ""
    @Published public private(set) var preparationQuery = ""
    @Published public private(set) var indexReport: IndexReport?
    @Published public private(set) var status = "Core unavailable — configure Connections"
    @Published public private(set) var busy = false
    @Published public private(set) var paused = true
    @Published public private(set) var managementVisible = false
    @Published public private(set) var closeExplanationShown = false
    @Published public private(set) var quitting = false
    @Published public private(set) var sourceDraft: [String] = []
    @Published public private(set) var policyDirty = false
    @Published public private(set) var configured = false
    @Published public private(set) var scopeRevision: UInt64 = 0
    @Published public private(set) var lastError: ServiceError?
    @Published public private(set) var automaticRefreshConsent: AutomaticRefreshConsent?
    public static let automaticRefreshInterval: TimeInterval = 60
    private let refreshDriver: any RefreshDriver
    private var automaticTicket: UInt64?
    public let notificationPolicy = "No OS notifications or content history are recorded."
    private var service: any CoreService
    private var job: Task<Void, Never>?
    private var ownedOperations: [UInt64: Task<Void, Never>] = [:]
    private var generation: UInt64 = 0

    public init(service: any CoreService = ProcessService(), configured: Bool = false,
                refreshDriver: any RefreshDriver = TimerRefreshDriver()) {
        self.refreshDriver = refreshDriver
        self.service = service; self.configured = configured
        if configured { status = "Not refreshed — explicit actions only" }
    }
    public func configure(executable: URL, dataDirectory: URL) {
        invalidate(clearProject: true)
        service = ProcessService(executable: executable, dataDirectory: dataDirectory)
        configured = true; projects = []; selectedID = nil
        status = "Configured, not tested — Refresh projects to connect"
    }
    public func refreshProjects() {
        disableAutomaticRefresh()
        start { service in [try await service.perform(.projects)] } apply: { replies in
            guard case .projects(let projects) = replies[0], projects.count <= 64 else { throw ServiceError.invalid }
            self.projects = projects
            if let id = self.selectedID, !projects.contains(where: { $0.id == id }) {
                self.selectedID = nil; self.clearProject()
            } else if let id = self.selectedID {
                // Listing alone does not prove that an old selection/policy is still valid.
                self.clearProject(); self.selectedID = id
            }
            self.status = "Projects refreshed — select a project to verify policy"
        }
    }
    public var canRemoveProject: Bool {
        guard configured, manualActionsAvailable, !quitting, let project, project.id == selectedID,
              case .string(let identity) = project.root_identity,
              let token = project.incarnation, InputPolicy.incarnation(token) else { return false }
        return InputPolicy.identifier(project.id) && InputPolicy.removal(root: project.root, identity: identity)
    }
    /// Opening/canceling this immutable approval performs no core operation.
    public func requestRemoval() {
        guard canRemoveProject, let project else { return }
        if automaticTicket != nil { cancel() }
        pendingForget = nil
        pendingSourceForget = nil
        pendingRemoval = RemovalConfirmation(id: UUID(), project: project, generation: generation, scopeRevision: scopeRevision)
    }
    public func cancelRemoval() { pendingRemoval = nil }
    public var canForgetContext: Bool {
        guard canRemoveProject, !policyDirty, !forgetRequiresRefresh, !sourceRequiresRefresh, let history,
              history.project == selectedID, InputPolicy.identifier(history.id),
              history.producer == "human-authored", !history.history.isEmpty,
              history.history.count <= 32 else { return false }
        return history.history.map(\.revision).sorted() == Array(1...history.history.count)
    }
    public func requestForget() {
        guard canForgetContext, let project, let history else { return }
        disableAutomaticRefresh()
        self.history = history
        pendingRemoval = nil
        pendingSourceForget = nil
        pendingForget = ForgetConfirmation(id: UUID(), project: project, contextID: history.id,
            revision: history.history.count, generation: generation, scopeRevision: scopeRevision)
    }
    public func cancelForget() { pendingForget = nil }
    /// View-local unsaved edits invalidate approval, without saving or changing source authority.
    public func contextEditorChanged() { pendingForget = nil; pendingSourceForget = nil }
    nonisolated private static func sameForgetScope(_ current: Project, _ captured: Project) -> Bool {
        current.id == captured.id && current.root == captured.root &&
        current.root_identity == captured.root_identity && current.incarnation == captured.incarnation &&
        current.sources == captured.sources && current.incarnation.map(InputPolicy.incarnation) == true
    }
    nonisolated private static func sameNamespace(_ current: Project, _ captured: Project) -> Bool {
        current.id == captured.id && current.root == captured.root &&
        current.root_identity == captured.root_identity && current.incarnation == captured.incarnation
    }
    nonisolated private static func checkNamespace(_ service: any CoreService, _ captured: Project) async throws -> Project {
        guard case .project(let current) = try await service.perform(.project(captured.id)),
              sameNamespace(current, captured) else { throw ServiceError.namespaceChanged }
        return current
    }
    nonisolated private static func checkedMutation(_ service: any CoreService, _ operation: Operation, _ captured: Project, sources: [String]? = nil) async throws -> Project {
        do {
            _ = try await service.perform(operation) // Core checks the captured binding inside its write transaction.
            let current = try await checkNamespace(service, captured)
            if let sources, current.sources != sources { throw ServiceError.mutationUncertain }
            return current
        } catch {
            if error as? ServiceError == .namespaceChanged { throw ServiceError.namespaceChanged }
            // Failed bindings may mean a replaced registration. Never adopt it.
            if let reply = try? await service.perform(.project(captured.id)), case .project(let current) = reply,
               !sameNamespace(current, captured) { throw ServiceError.namespaceChanged }
            throw ServiceError.mutationUncertain
        }
    }
    /// Explicit v4 capability inspection; an incarnation alone proves only v3.
    public func inspectForgottenSources() {
        guard let target = project, target.id == selectedID, canRemoveProject, !policyDirty else { return }
        disableAutomaticRefresh()
        sourceMarkers = nil; inspectedSourceScope = nil
        start(status: "Inspecting non-content source suppression markers", joinRefreshDriver: true) { service in
            do {
                let before = try await service.perform(.project(target.id))
                guard case .project(let current) = before, Self.sameForgetScope(current, target) else { throw ServiceError.scopeMismatch }
                let markers = try await service.perform(.forgottenSources(target.id))
                let after = try await service.perform(.project(target.id))
                guard case .project(let current) = after, Self.sameForgetScope(current, target) else { throw ServiceError.scopeMismatch }
                return [markers]
            } catch { throw ServiceError.sourceInspectionUnavailable }
        } apply: { replies in
            guard case .forgottenSources(let markers) = replies[0] else { throw ServiceError.invalid }
            try markers.validate(project: target.id)
            guard !markers.forgotten.contains(where: { target.sources.contains($0.path) }) else { throw ServiceError.invalid }
            self.sourceMarkers = markers; self.inspectedSourceScope = target
            self.status = "Source suppression markers verified — no archive, restore or unforget"
        }
    }
    public func canForgetSource(_ path: String) -> Bool {
        guard canRemoveProject, !policyDirty, !sourceRequiresRefresh, !forgetRequiresRefresh,
              let target = project, let inspectedSourceScope, sourceMarkers != nil,
              Self.sameForgetScope(target, inspectedSourceScope), sourceDraft == target.sources,
              target.sources.allSatisfy(InputPolicy.sourceMarker), target.sources.contains(path) else { return false }
        return InputPolicy.sourceMarker(path)
    }
    public func requestSourceForget(_ path: String) {
        guard canForgetSource(path), let target = project else { return }
        let markers = sourceMarkers, retainedHistory = history
        disableAutomaticRefresh()
        // Canceling an automatic index may clear display results, not this metadata proof.
        sourceMarkers = markers; inspectedSourceScope = target; history = retainedHistory
        pendingRemoval = nil; pendingForget = nil
        pendingSourceForget = SourceForgetConfirmation(id: UUID(), project: target, path: path,
            generation: generation, scopeRevision: scopeRevision)
    }
    public func cancelSourceForget() { pendingSourceForget = nil }
    public func confirmSourceForget(_ confirmation: SourceForgetConfirmation) {
        guard pendingSourceForget == confirmation, confirmation.generation == generation,
              confirmation.scopeRevision == scopeRevision, canForgetSource(confirmation.path),
              project == confirmation.project, case .string(let identity) = confirmation.project.root_identity,
              let token = confirmation.project.incarnation, InputPolicy.incarnation(token) else {
            pendingSourceForget = nil; return
        }
        let target = confirmation.project, path = confirmation.path
        mutationRefreshError = nil
        let remaining = target.sources.filter { $0 != path }
        disableAutomaticRefresh(); pendingSourceForget = nil
        // Source policy changes invalidate derivatives, never unrelated human drafts/history.
        evidence = nil; indexReport = nil; preview = nil; sourceMarkers = nil; inspectedSourceScope = nil
        scopeRevision &+= 1; sourceRequiresRefresh = true
        start(status: "Forgetting source derivatives — policy requires Refresh until confirmed", joinRefreshDriver: true) { service in
            do {
                let receipt = try await service.perform(.forgetSource(target.id, path, target.root, identity, token, target.sources))
                guard case .forgottenSource(let result) = receipt else { throw ServiceError.invalid }
                try result.validate(project: target.id, path: path)
                try Task.checkCancellation()
                let expected = Project(id: target.id, root: target.root, sources: remaining,
                    rootIdentity: target.root_identity, incarnation: token)
                let before = try await service.perform(.project(target.id))
                guard case .project(let current) = before, Self.sameForgetScope(current, expected) else { throw ServiceError.scopeMismatch }
                let markers = try await service.perform(.forgottenSources(target.id))
                let after = try await service.perform(.project(target.id))
                guard case .project(let current) = after, Self.sameForgetScope(current, expected) else { throw ServiceError.scopeMismatch }
                return [receipt, after, markers]
            } catch { throw ServiceError.sourceForgetUncertain }
        } apply: { replies in
            guard case .forgottenSource(let receipt) = replies[0], case .project(let current) = replies[1],
                  case .forgottenSources(let markers) = replies[2] else { throw ServiceError.sourceForgetUncertain }
            do {
                try receipt.validate(project: target.id, path: path)
                try markers.validate(project: target.id)
                guard markers.forgotten.contains(where: { $0.path == path }),
                      !markers.forgotten.contains(where: { remaining.contains($0.path) }) else { throw ServiceError.invalid }
            } catch { throw ServiceError.sourceForgetUncertain }
            self.project = current; self.sourceDraft = remaining; self.policyDirty = false
            self.sourceMarkers = markers; self.inspectedSourceScope = current; self.sourceRequiresRefresh = false
            self.status = "Source authorization revoked and suppression confirmed — all project source snapshots invalidated; rebuild remaining files as needed. Human history and source files untouched; not forensic erasure."
        }
    }
    public func confirmForget(_ confirmation: ForgetConfirmation) {
        guard pendingForget == confirmation, confirmation.generation == generation,
              confirmation.scopeRevision == scopeRevision, canForgetContext,
              project == confirmation.project, history?.id == confirmation.contextID,
              history?.history.count == confirmation.revision,
              case .string(let identity) = confirmation.project.root_identity,
              let token = confirmation.project.incarnation, InputPolicy.incarnation(token) else {
            pendingForget = nil; return
        }
        let target = confirmation.project, id = confirmation.contextID, revision = confirmation.revision
        disableAutomaticRefresh()
        pendingForget = nil; clearResults(); contexts = []; forgottenMarkers = nil
        contextEditorRevision &+= 1 // Only dispatch clears unsaved human text; original request stays intact.
        forgetRequiresRefresh = true
        start(status: "Forgetting all local human history — cancellation requires Refresh") { service in
            do {
                let reply = try await service.perform(.forgetContext(target.id, id, target.root, identity, token, revision))
                guard case .forgotten(let receipt) = reply else { throw ServiceError.invalid }
                try receipt.validate(project: target.id, id: id, revision: revision)
                try Task.checkCancellation()
                let before = try await service.perform(.project(target.id))
                guard case .project(let project) = before, Self.sameForgetScope(project, target) else { throw ServiceError.scopeMismatch }
                let contexts = try await service.perform(.contexts(target.id))
                let markers = try await service.perform(.forgottenContexts(target.id))
                let after = try await service.perform(.project(target.id))
                guard case .project(let project) = after, Self.sameForgetScope(project, target) else { throw ServiceError.scopeMismatch }
                return [reply, contexts, markers]
            } catch { throw ServiceError.forgetUncertain }
        } apply: { replies in
            guard case .forgotten(let receipt) = replies[0], case .contexts(let contexts) = replies[1],
                  contexts.project == target.id, !contexts.contexts.contains(where: { $0.id == id }),
                  case .forgottenContexts(let markers) = replies[2] else { throw ServiceError.forgetUncertain }
            do {
                try receipt.validate(project: target.id, id: id, revision: revision)
                try markers.validate(project: target.id)
                guard markers.forgotten.contains(where: { $0.id == id }) else { throw ServiceError.invalid }
            } catch { throw ServiceError.forgetUncertain }
            self.contexts = contexts.contexts; self.forgottenMarkers = markers; self.forgetRequiresRefresh = false
            self.status = "All target human history forgotten — same-scope suppression confirmed; sources untouched. Not forensic erasure."
        }
    }
    public func inspectForgottenContexts() {
        guard let target = project, target.id == selectedID, manualActionsAvailable else { return }
        forgottenMarkers = nil
        start { service in
            let before = try await service.perform(.project(target.id))
            guard case .project(let project) = before, Self.sameForgetScope(project, target) else { throw ServiceError.scopeMismatch }
            let markers = try await service.perform(.forgottenContexts(target.id))
            let after = try await service.perform(.project(target.id))
            guard case .project(let project) = after, Self.sameForgetScope(project, target) else { throw ServiceError.scopeMismatch }
            return [markers]
        } apply: { replies in
            guard case .forgottenContexts(let markers) = replies[0] else { throw ServiceError.invalid }
            try markers.validate(project: target.id)
            self.forgottenMarkers = markers
            self.status = "Non-content suppression markers inspected — not an archive or restore capability"
        }
    }
    public func confirmRemoval(_ confirmation: RemovalConfirmation) {
        guard pendingRemoval == confirmation, confirmation.generation == generation,
              confirmation.scopeRevision == scopeRevision, canRemoveProject,
              project == confirmation.project, case .string(let identity) = confirmation.project.root_identity,
              let token = confirmation.project.incarnation, InputPolicy.incarnation(token) else {
            pendingRemoval = nil; return
        }
        let target = confirmation.project
        invalidate(clearProject: true); selectedID = nil; projects = []
        start(status: "Removing local project data — cancellation may require Refresh") { service in
            do {
                let reply = try await service.perform(.removeProject(target.id, target.root, identity, token))
                guard case .removed(let receipt) = reply else { throw ServiceError.invalid }
                try receipt.validate(project: target.id)
                try Task.checkCancellation()
                return [reply, try await service.perform(.projects)]
            } catch { throw ServiceError.removalUncertain }
        } apply: { replies in
            guard case .removed(let receipt) = replies[0], case .projects(let projects) = replies[1],
                  projects.count <= 64, !projects.contains(where: { $0.id == target.id }) else { throw ServiceError.removalUncertain }
            try receipt.validate(project: target.id)
            self.projects = projects
            self.status = "Local project removed — sources untouched; not Forget or forensic erasure"
        }
    }
    public func select(_ id: String?) {
        invalidate(clearProject: true); selectedID = id
        guard let id else { status = "No active project"; return }
        refresh(id)
    }
    public func refreshSelected() {
        guard let id = selectedID else { return }; invalidate(clearProject: true); refresh(id)
    }
    private func refresh(_ id: String) {
        start { service in
            guard case .project(let captured) = try await service.perform(.project(id)), captured.id == id else { throw ServiceError.namespaceChanged }
            let contexts = try await service.perform(.contexts(id))
            _ = try await Self.checkNamespace(service, captured)
            return [.project(captured), contexts]
        } apply: { replies in
            guard case .project(let project) = replies[0], project.id == id,
                  case .contexts(let contexts) = replies[1], contexts.project == id else { throw ServiceError.scopeMismatch }
            self.project = project; self.sourceDraft = project.sources; self.policyDirty = false
            self.contexts = contexts.contexts
            self.forgetRequiresRefresh = false
            self.sourceRequiresRefresh = false
            self.mutationRefreshError = nil
            self.status = project.snapshot == nil || project.snapshot == .null
                ? "Not built — explicit Build required" : "Snapshot recorded — currentness not checked"
            if project.incarnation == nil {
                self.status = "Schema v3 required for native cached mutations. Stop older workers, then explicitly run store upgrade --to-version 3 --confirm-local-schema-upgrade --confirm-legacy-workers-stopped (or --to-version 4 for source Forget). No unbound native mutation fallback."
            }
        }
    }
    public func addProject(id: String, root: String, sources: [String]) {
        invalidate(clearProject: true); selectedID = nil
        guard InputPolicy.identifier(id), root.hasPrefix("/"), InputPolicy.sources(sources), !sources.isEmpty else {
            fail(.invalid); return
        }
        start { service in
            _ = try await service.perform(.addProject(id, root, sources))
            return [try await service.perform(.project(id)), try await service.perform(.projects)]
        } apply: { replies in
            guard case .project(let project) = replies[0], project.id == id,
                  project.root == root, Set(project.sources) == Set(sources),
                  case .projects(let projects) = replies[1], projects.count <= 64 else { throw ServiceError.scopeMismatch }
            self.projects = projects; self.selectedID = id; self.project = project
            self.sourceDraft = sources; self.policyDirty = false
            self.status = "Source policy registered — no scan performed"
        }
    }
    /// Removal/revocation takes effect in the UI immediately, including during an index job.
    public func stageSources(_ sources: [String]) {
        disableAutomaticRefresh()
        cancel(); clearResults(); scopeRevision &+= 1; sourceDraft = sources; policyDirty = true
        status = sourceRequiresRefresh ? refreshRequiredError.localizedDescription
            : "Source policy changed — apply before Build; displayed evidence invalidated"
    }
    public func applySources() {
        disableAutomaticRefresh()
        guard !sourceRequiresRefresh else { fail(refreshRequiredError); return }
        guard let target = project, target.id == selectedID, case .string(let identity) = target.root_identity,
              let token = target.incarnation, InputPolicy.incarnation(token), InputPolicy.sources(sourceDraft) else { fail(.mutationUncertain); return }
        let sources = sourceDraft
        clearResults()
        start { service in
            [.project(try await Self.checkedMutation(service, .setSourcesBound(target.id, target.root, identity, token, target.sources, sources), target, sources: sources))]
        } apply: { replies in
            guard case .project(let project) = replies[0], Self.sameNamespace(project, target),
                  project.sources == sources else { throw ServiceError.namespaceChanged }
            self.project = project; self.policyDirty = false
            self.status = "Policy applied — old evidence invalidated; Build explicitly"
        }
    }
    public var manualActionsAvailable: Bool { !busy || automaticTicket != nil }
    public var canBuild: Bool { configured && project != nil && !policyDirty && !sourceRequiresRefresh && !sourceDraft.isEmpty && manualActionsAvailable && !quitting && pendingSourceForget == nil }
    public func build() {
        pendingSourceForget = nil
        guard !sourceRequiresRefresh else { fail(refreshRequiredError); return }
        guard canBuild, let id = selectedID else { fail(.invalid); return }
        clearResults()
        start(status: "Updating — bounded local source-evidence Build; Cancel available") { service in
            [try await service.perform(.index(id))]
        } apply: { replies in
            guard case .indexed(let report) = replies[0], report.project == id else { throw ServiceError.scopeMismatch }
            self.indexReport = report
            self.status = report.empty ? "Partial — empty snapshot; inspect coverage" : "Build completed — inspect coverage; currentness not checked"
        }
    }
    public func query(_ text: String) {
        guard !sourceRequiresRefresh else { fail(refreshRequiredError); return }
        guard !text.isEmpty, text.utf8.count <= 256 else { fail(.invalid); return }
        guard let id = selectedID, project != nil, !policyDirty, !sourceRequiresRefresh else { fail(.invalid); return }
        evidence = nil
        start { service in [try await service.perform(.query(id, text))] } apply: { replies in
            guard case .query(let result) = replies[0], result.project == id,
                  result.results.allSatisfy({ $0.project == id && self.sourceDraft.contains($0.path) }) else { throw ServiceError.scopeMismatch }
            self.evidence = result
            self.status = result.currentness == "current-at-read"
                ? "Current at read — inspect coverage, not complete comprehension" : "Stale or unindexed — Build explicitly"
        }
    }
    public func openContext(_ contextID: String) {
        guard let target = project, target.id == selectedID, !sourceRequiresRefresh else { return }
        history = nil
        start { service in
            _ = try await Self.checkNamespace(service, target)
            let reply = try await service.perform(.context(target.id, contextID))
            _ = try await Self.checkNamespace(service, target)
            return [reply]
        } apply: { replies in
            guard case .context(let result) = replies[0], result.project == target.id, result.id == contextID else { throw ServiceError.scopeMismatch }
            self.history = result; self.status = "Human context history loaded"
        }
    }
    public var canSearchHumanContext: Bool {
        configured && canRemoveProject && !policyDirty && !sourceRequiresRefresh && !forgetRequiresRefresh &&
        pendingRemoval == nil && pendingForget == nil && pendingSourceForget == nil
    }
    public func searchHumanContext(_ query: String) {
        humanSearchQueryChanged()
        guard canSearchHumanContext, let target = project, InputPolicy.humanSearch(query) else { fail(.invalid); return }
        start(status: "Searching human-authored context — no source reads or inference") { service in
            _ = try await Self.checkNamespace(service, target)
            let reply = try await service.perform(.searchHumanContext(target.id, query))
            _ = try await Self.checkNamespace(service, target)
            return [reply]
        } apply: { replies in
            guard case .humanContextSearch(let result) = replies[0] else { throw ServiceError.invalid }
            try result.validate(scope: target)
            self.humanSearch = result; self.humanSearchScope = target
            self.status = "Human context: latest active revisions at read only — not source evidence or authorization"
        }
        humanSearchTicket = generation
    }
    public func humanSearchQueryChanged() {
        if humanSearchTicket != nil { cancel() }
        clearHumanSearch()
    }
    /// Loads the existing history pane; never copies text into an editor or approves a rule.
    public func inspectHumanSearchEntry(_ id: String) {
        guard !busy, let scope = humanSearchScope, let project, Self.sameNamespace(project, scope),
              humanSearch?.results.contains(where: { $0.id == id }) == true else { return }
        openContext(id)
    }
    private func clearHumanSearch() { humanSearch = nil; humanSearchScope = nil }
    public func editPreparation(query: String, original: String) {
        guard !preparationQuery.utf8.elementsEqual(query.utf8) || !originalDraft.utf8.elementsEqual(original.utf8) else { return }
        cancelOperation(); preparationQuery = query; originalDraft = original
    }
    public var canPrepareContext: Bool {
        configured && project?.id == selectedID && project != nil && !policyDirty && !sourceRequiresRefresh && pendingSourceForget == nil &&
        InputPolicy.sources(sourceDraft) && manualActionsAvailable && !quitting &&
        InputPolicy.preparation(query: preparationQuery, original: originalDraft)
    }
    public func prepareContext() {
        guard !sourceRequiresRefresh else { cancel(); fail(refreshRequiredError); return }
        guard canPrepareContext, let id = selectedID else { cancel(); fail(.invalid); return }
        let query = preparationQuery, original = originalDraft
        start(status: "Preparing Context-only preview — no AI or handoff") { service in
            [try await service.perform(.prepareContext(id, query, original))]
        } apply: { replies in
            guard case .preview(let result) = replies[0] else { throw ServiceError.invalid }
            try result.validate(project: id, original: original)
            self.preview = result
            self.status = result.state == "needs-input"
                ? "Needs input — missing current evidence or snapshot; no handoff"
                : "Context-only preview — review required; no handoff"
        }
    }
    public func dismissPreview() { cancel() }
    public func writeContext(id contextID: String, kind: String, text: String, update: Bool) {
        guard !sourceRequiresRefresh, let target = project, target.id == selectedID,
              case .string(let identity) = target.root_identity, let token = target.incarnation, InputPolicy.incarnation(token) else { fail(.mutationUncertain); return }
        guard InputPolicy.identifier(contextID), !text.isEmpty,
              text.utf8.count <= 4096, InputPolicy.contextKinds.contains(kind) else { fail(.invalid); return }
        clearResults()
        mutateContext(.writeContextBound(target.id, contextID, kind, text, update, target.root, identity, token), target: target, contextID: contextID)
    }
    public func retireContext(_ contextID: String) {
        guard !sourceRequiresRefresh, let target = project, target.id == selectedID,
              case .string(let identity) = target.root_identity, let token = target.incarnation, InputPolicy.incarnation(token) else { fail(.mutationUncertain); return }
        clearResults()
        mutateContext(.retireContextBound(target.id, contextID, target.root, identity, token), target: target, contextID: contextID)
    }
    private func mutateContext(_ operation: Operation, target: Project, contextID: String) {
        let projectID = target.id
        start { service in
            do {
                _ = try await Self.checkedMutation(service, operation, target)
                let list = try await service.perform(.contexts(projectID))
                let history = try await service.perform(.context(projectID, contextID))
                _ = try await Self.checkNamespace(service, target)
                return [list, history]
            } catch {
                if error as? ServiceError == .namespaceChanged { throw ServiceError.namespaceChanged }
                if let reply = try? await service.perform(.project(projectID)), case .project(let current) = reply,
                   !Self.sameNamespace(current, target) { throw ServiceError.namespaceChanged }
                throw ServiceError.mutationUncertain
            }
        } apply: { replies in
            guard case .contexts(let list) = replies[0], list.project == projectID,
                  case .context(let history) = replies[1], history.project == projectID, history.id == contextID else { throw ServiceError.scopeMismatch }
            self.contexts = list.contexts; self.history = history
            self.status = "Human context changed — dependent displayed evidence invalidated"
        }
    }
    public func resolveHostProject(_ hostProject: String) -> Bool {
        guard hostProject == selectedID else { cancel(); clearResults(); fail(.scopeMismatch); return false }
        return true // No host transport or delivery is implemented.
    }
    public var automaticRefreshProposal: AutomaticRefreshConsent? {
        guard configured, !quitting, !policyDirty, !sourceRequiresRefresh,
              pendingSourceForget == nil, pendingForget == nil, pendingRemoval == nil,
              let project, project.id == selectedID,
              InputPolicy.identifier(project.id), !sourceDraft.isEmpty, InputPolicy.sources(sourceDraft),
              sourceDraft == project.sources, case .string(let identity) = project.root_identity,
              let token = project.incarnation, InputPolicy.incarnation(token),
              InputPolicy.removal(root: project.root, identity: identity) else { return nil }
        return AutomaticRefreshConsent(projectID: project.id, root: project.root, rootIdentity: identity, incarnation: token,
                                       sources: sourceDraft, scopeRevision: scopeRevision)
    }
    public var automaticRefreshSummary: String {
        paused ? "Automatic refresh: paused" : (automaticRefreshConsent == nil
            ? "Automatic refresh: off (no consent)" : "File-event + periodic refresh: approved")
    }
    public func enableAutomaticRefresh(_ consent: AutomaticRefreshConsent) {
        guard !busy, consent == automaticRefreshProposal else { return }
        automaticRefreshConsent = consent
        paused = false
        updateRefreshDriver()
    }
    public func disableAutomaticRefresh() {
        let wasEnabled = automaticRefreshConsent != nil
        automaticRefreshConsent = nil
        refreshDriver.stop()
        if automaticTicket != nil { cancelOperation() }
        if wasEnabled { status = "Automatic reads disabled — refresh persisted state after any canceled work" }
    }
    @discardableResult private func updateRefreshDriver() -> Bool {
        refreshDriver.stop()
        guard !paused, !quitting, let consent = automaticRefreshConsent,
              consent == automaticRefreshProposal else { return true }
        do {
            status = "Checking approved policy — monitoring not yet enabled"
            try refreshDriver.start(consent: consent, service: service, interval: Self.automaticRefreshInterval,
                                    ready: { [weak self] in
                guard let self, !self.paused, !self.quitting,
                      self.automaticRefreshConsent == consent, self.automaticRefreshProposal == consent else { return }
                self.status = "File-event + periodic lexical refresh enabled — exact approved files only"
            }) { [weak self] in
                self?.automaticRefreshTick()
            } failure: { [weak self] in self?.automaticRefreshFailed() }
            return true
        } catch { automaticRefreshFailed(); return false }
    }
    private func automaticRefreshFailed() {
        disableAutomaticRefresh()
        lastError = .unavailable
        status = "Needs attention — approved-file monitoring stopped. Refresh policy, repair unavailable files/permissions, then explicitly enable again."
    }
    /// Busy ticks are skipped, never queued or allowed to cancel manual work.
    private func automaticRefreshTick() {
        guard !paused, !quitting, let consent = automaticRefreshConsent else { return }
        guard consent == automaticRefreshProposal else { disableAutomaticRefresh(); return }
        guard !busy, ownedOperations.isEmpty, pendingRemoval == nil, pendingForget == nil, pendingSourceForget == nil, !forgetRequiresRefresh, !sourceRequiresRefresh else { return }
        evidence = nil; indexReport = nil
        start(status: "Updating — file-event/periodic bounded full lexical reconciliation", automatic: true) { service in
            [try await service.perform(.indexBound(consent.projectID, consent.root, consent.rootIdentity, consent.sources, consent.incarnation))]
        } apply: { replies in
            guard case .indexed(let report) = replies[0], report.project == consent.projectID else { throw ServiceError.scopeMismatch }
            self.indexReport = report
            self.status = report.empty ? "Partial — lexical snapshot empty; inspect coverage" : "File-event/periodic lexical refresh completed — currentness checked only at Build"
        }
    }
    public func togglePause() {
        pendingForget = nil
        pendingSourceForget = nil
        paused.toggle()
        if paused, automaticTicket != nil { cancelOperation() }
        guard updateRefreshDriver() else { return }
        if !busy {
            status = paused ? "Paused — no automatic reads; manual actions remain available"
                : (automaticRefreshConsent == nil ? "Automatic reads off — explicit scope consent required" : status)
        }
    }
    public func showManagement() { managementVisible = true }
    public func closeManagement() { managementVisible = false; closeExplanationShown = true }
    public func quit() {
        disableAutomaticRefresh()
        quitting = true; cancel()
        for pending in ownedOperations.values { pending.cancel() }
        status = "Quitting — owned work canceled"
    }
    public func shutdown() async {
        let pending = Array(ownedOperations.values)
        quit()
        await refreshDriver.shutdown()
        for operation in pending { await operation.value }
    }
    /// Also useful to embed the model without observing its UI. Never starts work.
    public func waitForOperation() async {
        let pending = Array(ownedOperations.values)
        for operation in pending { await operation.value }
    }
    public func cancel() {
        // An explicit Cancel tears down automatic producers too. Internal
        // serialized replacements cancel only the operation, preserving consent.
        disableAutomaticRefresh()
        cancelOperation()
    }
    private func cancelOperation() {
        let cancelingSearch = humanSearchTicket
        if let cancelingSearch { humanSearchCancellationTicket = cancelingSearch }
        humanSearchTicket = nil
        clearHumanSearch()
        automaticTicket = nil
        pendingRemoval = nil
        pendingForget = nil
        pendingSourceForget = nil
        preview = nil
        generation &+= 1; job?.cancel(); job = nil
        if busy {
            status = "Canceled — refresh persisted state before continuing"
            if sourceRequiresRefresh {
                evidence = nil; indexReport = nil; preview = nil; sourceMarkers = nil; inspectedSourceScope = nil
            } else { clearResults() }
        }
        if forgetRequiresRefresh {
            contexts = []; forgottenMarkers = nil; status = ServiceError.forgetUncertain.localizedDescription
        }
        if sourceRequiresRefresh { status = refreshRequiredError.localizedDescription }
        busy = false
        if cancelingSearch != nil { status = "Human search cancel requested — joining owned worker" }
    }
    private func clearResults() { clearHumanSearch(); evidence = nil; history = nil; indexReport = nil; preview = nil; forgottenMarkers = nil; sourceMarkers = nil; inspectedSourceScope = nil }
    private func clearProject() {
        disableAutomaticRefresh()
        scopeRevision &+= 1
        contextEditorRevision &+= 1
        originalDraft = ""; preparationQuery = ""
        project = nil; contexts = []; sourceDraft = []; policyDirty = false; clearResults()
    }
    private func invalidate(clearProject: Bool) {
        disableAutomaticRefresh()
        cancel(); clearResults(); if clearProject { self.clearProject() }
    }
    private func fail(_ error: ServiceError) {
        lastError = error; status = error.localizedDescription
    }
    private func start(status: String = "Working — bounded local core operation", automatic: Bool = false, joinRefreshDriver: Bool = false, work: @escaping @Sendable (any CoreService) async throws -> [Reply],
                       apply: @escaping @MainActor ([Reply]) throws -> Void) {
        guard !quitting else { return }
        cancelOperation(); let ticket = generation; let service = service
        automaticTicket = automatic ? ticket : nil
        let prior = Array(ownedOperations.values)
        for pending in prior { pending.cancel() }
        busy = true; lastError = nil; self.status = status
        job = Task { [weak self] in
            defer {
                self?.ownedOperations.removeValue(forKey: ticket)
                if self?.humanSearchTicket == ticket { self?.humanSearchTicket = nil }
                if self?.humanSearchCancellationTicket == ticket {
                    self?.humanSearchCancellationTicket = nil
                    if self?.generation == ticket &+ 1, self?.job == nil, self?.quitting == false,
                       self?.status == "Human search cancel requested — joining owned worker" {
                        self?.status = "Human search canceled — owned worker joined; no result adopted"
                    }
                }
            }
            do {
                // UI invalidation is immediate, but persistent effects must not
                // be overtaken by replacement work, even if a service ignores
                // cancellation. Join teardown before touching the service.
                for pending in prior { await pending.value }
                guard let self, self.generation == ticket, !Task.isCancelled, !self.quitting else { return }
                if joinRefreshDriver { await self.refreshDriver.shutdown() }
                guard self.generation == ticket, !Task.isCancelled, !self.quitting else { return }
                let replies = try await work(service)
                guard self.generation == ticket, !Task.isCancelled, !self.quitting else { return }
                try apply(replies); self.busy = false; self.job = nil; self.automaticTicket = nil
            } catch {
                guard let self, self.generation == ticket, !self.quitting else { return }
                if error as? ServiceError == .namespaceChanged {
                    self.clearProject(); self.sourceRequiresRefresh = true
                    self.mutationRefreshError = .namespaceChanged
                } else if error as? ServiceError == .mutationUncertain {
                    self.sourceRequiresRefresh = true
                    self.mutationRefreshError = .mutationUncertain
                }
                if self.sourceRequiresRefresh {
                    self.evidence = nil; self.indexReport = nil; self.preview = nil
                    self.sourceMarkers = nil; self.inspectedSourceScope = nil
                } else { self.clearResults() }
                self.busy = false; self.job = nil
                self.fail(error as? ServiceError ?? (error is CancellationError ? .canceled : .failed))
                self.automaticTicket = nil
                if automatic {
                    self.disableAutomaticRefresh()
                    self.status = "Needs attention — automatic refresh stopped. Check permissions/configuration, refresh project policy, then explicitly enable again."
                }
            }
        }
        ownedOperations[ticket] = job
    }
}
