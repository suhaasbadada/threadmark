import Foundation
import Combine

@MainActor
public final class CompanionModel: ObservableObject {
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var pendingRemoval: RemovalConfirmation?
    @Published public private(set) var pendingForget: ForgetConfirmation?
    @Published public private(set) var forgottenMarkers: ForgottenContexts?
    @Published public private(set) var contextEditorRevision: UInt64 = 0
    @Published public private(set) var forgetRequiresRefresh = false
    @Published public private(set) var selectedID: String?
    @Published public private(set) var project: Project?
    @Published public private(set) var contexts: [ContextEntry] = []
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
        pendingRemoval = RemovalConfirmation(id: UUID(), project: project, generation: generation, scopeRevision: scopeRevision)
    }
    public func cancelRemoval() { pendingRemoval = nil }
    public var canForgetContext: Bool {
        guard canRemoveProject, !policyDirty, !forgetRequiresRefresh, let history,
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
        pendingForget = ForgetConfirmation(id: UUID(), project: project, contextID: history.id,
            revision: history.history.count, generation: generation, scopeRevision: scopeRevision)
    }
    public func cancelForget() { pendingForget = nil }
    /// View-local unsaved edits invalidate approval, without saving or changing source authority.
    public func contextEditorChanged() { pendingForget = nil }
    nonisolated private static func sameForgetScope(_ current: Project, _ captured: Project) -> Bool {
        current.id == captured.id && current.root == captured.root &&
        current.root_identity == captured.root_identity && current.incarnation == captured.incarnation &&
        current.sources == captured.sources && current.incarnation.map(InputPolicy.incarnation) == true
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
            [try await service.perform(.project(id)), try await service.perform(.contexts(id))]
        } apply: { replies in
            guard case .project(let project) = replies[0], project.id == id,
                  case .contexts(let contexts) = replies[1], contexts.project == id else { throw ServiceError.scopeMismatch }
            self.project = project; self.sourceDraft = project.sources; self.policyDirty = false
            self.contexts = contexts.contexts
            self.forgetRequiresRefresh = false
            self.status = project.snapshot == nil || project.snapshot == .null
                ? "Not built — explicit Build required" : "Snapshot recorded — currentness not checked"
            if project.incarnation == nil {
                self.status = "Schema v3 required for native Forget/cached removal/automatic refresh. Stop older workers, then explicitly run store upgrade --to-version 3 --confirm-local-schema-upgrade --confirm-legacy-workers-stopped. Manual operations remain available."
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
        status = "Source policy changed — apply before Build; displayed evidence invalidated"
    }
    public func applySources() {
        disableAutomaticRefresh()
        guard let id = selectedID, project != nil, InputPolicy.sources(sourceDraft) else { fail(.invalid); return }
        let sources = sourceDraft
        clearResults()
        start { service in
            _ = try await service.perform(.setSources(id, sources))
            return [try await service.perform(.project(id))]
        } apply: { replies in
            guard case .project(let project) = replies[0], project.id == id,
                  Set(project.sources) == Set(sources) else { throw ServiceError.scopeMismatch }
            self.project = project; self.policyDirty = false
            self.status = "Policy applied — old evidence invalidated; Build explicitly"
        }
    }
    public var manualActionsAvailable: Bool { !busy || automaticTicket != nil }
    public var canBuild: Bool { configured && project != nil && !policyDirty && !sourceDraft.isEmpty && manualActionsAvailable && !quitting }
    public func build() {
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
        guard !text.isEmpty, text.utf8.count <= 256 else { fail(.invalid); return }
        guard let id = selectedID, project != nil, !policyDirty else { fail(.invalid); return }
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
        guard let id = selectedID, project != nil else { return }
        history = nil
        start { service in [try await service.perform(.context(id, contextID))] } apply: { replies in
            guard case .context(let result) = replies[0], result.project == id, result.id == contextID else { throw ServiceError.scopeMismatch }
            self.history = result; self.status = "Human context history loaded"
        }
    }
    public func editPreparation(query: String, original: String) {
        guard !preparationQuery.utf8.elementsEqual(query.utf8) || !originalDraft.utf8.elementsEqual(original.utf8) else { return }
        cancel(); preparationQuery = query; originalDraft = original
    }
    public var canPrepareContext: Bool {
        configured && project?.id == selectedID && project != nil && !policyDirty &&
        InputPolicy.sources(sourceDraft) && manualActionsAvailable && !quitting &&
        InputPolicy.preparation(query: preparationQuery, original: originalDraft)
    }
    public func prepareContext() {
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
        guard let id = selectedID, project != nil, InputPolicy.identifier(contextID), !text.isEmpty,
              text.utf8.count <= 4096, InputPolicy.contextKinds.contains(kind) else { fail(.invalid); return }
        clearResults()
        mutateContext(.writeContext(id, contextID, kind, text, update: update), projectID: id, contextID: contextID)
    }
    public func retireContext(_ contextID: String) {
        guard let id = selectedID, project != nil else { return }
        clearResults()
        mutateContext(.retireContext(id, contextID), projectID: id, contextID: contextID)
    }
    private func mutateContext(_ operation: Operation, projectID: String, contextID: String) {
        start { service in
            _ = try await service.perform(operation)
            return [try await service.perform(.contexts(projectID)), try await service.perform(.context(projectID, contextID))]
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
        guard configured, !quitting, !policyDirty, let project, project.id == selectedID,
              InputPolicy.identifier(project.id), !sourceDraft.isEmpty, InputPolicy.sources(sourceDraft),
              sourceDraft == project.sources, case .string(let identity) = project.root_identity,
              let token = project.incarnation, InputPolicy.incarnation(token),
              InputPolicy.removal(root: project.root, identity: identity) else { return nil }
        return AutomaticRefreshConsent(projectID: project.id, root: project.root, rootIdentity: identity, incarnation: token,
                                       sources: sourceDraft, scopeRevision: scopeRevision)
    }
    public func enableAutomaticRefresh(_ consent: AutomaticRefreshConsent) {
        guard !busy, consent == automaticRefreshProposal else { return }
        automaticRefreshConsent = consent
        paused = false
        updateRefreshDriver()
        status = "Timed lexical refresh enabled — approved files read automatically every 60 seconds"
    }
    public func disableAutomaticRefresh() {
        let wasEnabled = automaticRefreshConsent != nil
        automaticRefreshConsent = nil
        refreshDriver.stop()
        if automaticTicket != nil { cancel() }
        if wasEnabled { status = "Automatic reads disabled — refresh persisted state after any canceled work" }
    }
    private func updateRefreshDriver() {
        refreshDriver.stop()
        guard !paused, !quitting, let consent = automaticRefreshConsent,
              consent == automaticRefreshProposal else { return }
        refreshDriver.start(interval: Self.automaticRefreshInterval) { [weak self] in self?.automaticRefreshTick() }
    }
    /// Busy ticks are skipped, never queued or allowed to cancel manual work.
    private func automaticRefreshTick() {
        guard !paused, !quitting, let consent = automaticRefreshConsent else { return }
        guard consent == automaticRefreshProposal else { disableAutomaticRefresh(); return }
        guard !busy, ownedOperations.isEmpty, pendingRemoval == nil, pendingForget == nil, !forgetRequiresRefresh else { return }
        evidence = nil; indexReport = nil
        start(status: "Updating — timed bounded full lexical reconciliation", automatic: true) { service in
            [try await service.perform(.indexBound(consent.projectID, consent.root, consent.rootIdentity, consent.sources, consent.incarnation))]
        } apply: { replies in
            guard case .indexed(let report) = replies[0], report.project == consent.projectID else { throw ServiceError.scopeMismatch }
            self.indexReport = report
            self.status = report.empty ? "Partial — timed lexical snapshot empty; inspect coverage" : "Timed lexical refresh completed — currentness checked only at Build"
        }
    }
    public func togglePause() {
        pendingForget = nil
        paused.toggle()
        if paused, automaticTicket != nil { cancel() }
        updateRefreshDriver()
        if !busy {
            status = paused ? "Paused — no automatic reads; manual actions remain available"
                : (automaticRefreshConsent == nil ? "Automatic reads off — explicit scope consent required" : "Timed lexical refresh resumed for the same approved scope")
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
        for operation in pending { await operation.value }
    }
    /// Also useful to embed the model without observing its UI. Never starts work.
    public func waitForOperation() async {
        let pending = Array(ownedOperations.values)
        for operation in pending { await operation.value }
    }
    public func cancel() {
        automaticTicket = nil
        pendingRemoval = nil
        pendingForget = nil
        preview = nil
        generation &+= 1; job?.cancel(); job = nil
        if busy { status = "Canceled — refresh persisted state before continuing"; clearResults() }
        if forgetRequiresRefresh {
            contexts = []; forgottenMarkers = nil; status = ServiceError.forgetUncertain.localizedDescription
        }
        busy = false
    }
    private func clearResults() { evidence = nil; history = nil; indexReport = nil; preview = nil; forgottenMarkers = nil }
    private func clearProject() {
        disableAutomaticRefresh()
        scopeRevision &+= 1
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
    private func start(status: String = "Working — bounded local core operation", automatic: Bool = false, work: @escaping @Sendable (any CoreService) async throws -> [Reply],
                       apply: @escaping @MainActor ([Reply]) throws -> Void) {
        guard !quitting else { return }
        cancel(); let ticket = generation; let service = service
        automaticTicket = automatic ? ticket : nil
        let prior = Array(ownedOperations.values)
        for pending in prior { pending.cancel() }
        busy = true; lastError = nil; self.status = status
        job = Task { [weak self] in
            defer { self?.ownedOperations.removeValue(forKey: ticket) }
            do {
                // UI invalidation is immediate, but persistent effects must not
                // be overtaken by replacement work, even if a service ignores
                // cancellation. Join teardown before touching the service.
                for pending in prior { await pending.value }
                guard let self, self.generation == ticket, !Task.isCancelled, !self.quitting else { return }
                let replies = try await work(service)
                guard self.generation == ticket, !Task.isCancelled, !self.quitting else { return }
                try apply(replies); self.busy = false; self.job = nil; self.automaticTicket = nil
            } catch {
                guard let self, self.generation == ticket, !self.quitting else { return }
                self.clearResults(); self.busy = false; self.job = nil
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
