import Foundation
import Combine

@MainActor
public final class CompanionModel: ObservableObject {
    @Published public private(set) var projects: [Project] = []
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
    public let notificationPolicy = "No OS notifications or content history are recorded."
    private var service: any CoreService
    private var job: Task<Void, Never>?
    private var ownedOperations: [UInt64: Task<Void, Never>] = [:]
    private var generation: UInt64 = 0

    public init(service: any CoreService = ProcessService(), configured: Bool = false) {
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
            self.status = project.snapshot == nil || project.snapshot == .null
                ? "Not built — explicit Build required" : "Snapshot recorded — currentness not checked"
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
        cancel(); clearResults(); scopeRevision &+= 1; sourceDraft = sources; policyDirty = true
        status = "Source policy changed — apply before Build; displayed evidence invalidated"
    }
    public func applySources() {
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
    public var canBuild: Bool { configured && project != nil && !policyDirty && !sourceDraft.isEmpty && !busy && !quitting }
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
        InputPolicy.sources(sourceDraft) && !busy && !quitting &&
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
    public func togglePause() { paused.toggle() } // No automatic scheduler is installed.
    public func showManagement() { managementVisible = true }
    public func closeManagement() { managementVisible = false; closeExplanationShown = true }
    public func quit() {
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
        preview = nil
        generation &+= 1; job?.cancel(); job = nil
        if busy { status = "Canceled — refresh persisted state before continuing"; clearResults() }
        busy = false
    }
    private func clearResults() { evidence = nil; history = nil; indexReport = nil; preview = nil }
    private func clearProject() {
        scopeRevision &+= 1
        originalDraft = ""; preparationQuery = ""
        project = nil; contexts = []; sourceDraft = []; policyDirty = false; clearResults()
    }
    private func invalidate(clearProject: Bool) {
        cancel(); clearResults(); if clearProject { self.clearProject() }
    }
    private func fail(_ error: ServiceError) {
        lastError = error; status = error.localizedDescription
    }
    private func start(status: String = "Working — bounded local core operation", work: @escaping @Sendable (any CoreService) async throws -> [Reply],
                       apply: @escaping @MainActor ([Reply]) throws -> Void) {
        guard !quitting else { return }
        cancel(); let ticket = generation; let service = service
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
                try apply(replies); self.busy = false; self.job = nil
            } catch {
                guard let self, self.generation == ticket, !self.quitting else { return }
                self.clearResults(); self.busy = false; self.job = nil
                self.fail(error as? ServiceError ?? (error is CancellationError ? .canceled : .failed))
            }
        }
        ownedOperations[ticket] = job
    }
}
