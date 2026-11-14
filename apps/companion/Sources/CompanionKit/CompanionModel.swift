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
    @Published public private(set) var sourceInspection: SourceInspectionDocument?
    @Published public private(set) var inspectionRadius = 2
    private var inspectionQueryScope: Project?
    private var inspectionQueryGeneration: UInt64?
    private var inspectionOperation = false
    private var sourceQueryOperation = false
    private let inspectionOwner = UUID()
    private struct InspectionAction: Sendable {
        let request: SourceInspectionRequest
        let owner: UUID
        let generation: UInt64
        let configurationGeneration: UInt64
        let scopeRevision: UInt64
    }
    @Published public private(set) var preview: ContextPreview?
    @Published public private(set) var pendingRefinement: RefinementConsent?
    @Published public private(set) var refinementPreview: RefinementPreview?
    // The module-owned view may observe this controller, but external callers
    // must use model methods so revoked consent cannot bypass its registry.
    let retainedReview = RetainedReviewController()
    @Published public private(set) var retainedReviewVisible = false
    @Published public private(set) var retainedActionBusy = false
    private var retainedLifetime: RetainedReviewLifetime?
    private var retainedOperationActive = false
    private var retainedPreparation: Task<Void, Never>?
    private var retainedActionTask: Task<Void, Never>?
    private var configurationGeneration: UInt64 = 0
    private var refinementSettings: ProviderSettings?
    private var refinementOperation = false
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
    private var ownedOperations: [UUID: Task<Void, Never>] = [:]
    private var generation: UInt64 = 0
    @Published public private(set) var pendingProjectExport: ProjectExportConfirmation?
    @Published public private(set) var projectExportStatus: String?
    private var exportPicker: ProjectExportConfirmation?
    private var exportActive = false
    private var exportWriteStarted = false
    // Internal injection is only for synthetic model tests; production captures
    // the exact configured ProcessService store, never a response destination.
    var exportStoreDirectory: URL?

    public init(service: any CoreService = ProcessService(), configured: Bool = false,
                refreshDriver: any RefreshDriver = TimerRefreshDriver()) {
        self.refreshDriver = refreshDriver
        self.service = service; self.configured = configured
        exportStoreDirectory = (service as? ProcessService)?.dataDirectory
        if configured { status = "Not refreshed — explicit actions only" }
    }
    deinit {
        retainedLifetime?.cancel()
        for operation in ownedOperations.values { operation.cancel() }
    }
    public func configure(executable: URL, dataDirectory: URL) {
        invalidate(clearProject: true)
        configurationGeneration &+= 1
        service = ProcessService(executable: executable, dataDirectory: dataDirectory)
        exportStoreDirectory = dataDirectory
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
    public var canExportProject: Bool {
        guard canRemoveProject, !policyDirty, !sourceRequiresRefresh, !forgetRequiresRefresh,
              !retainedOperationActive, sourceDraft == project?.sources,
              pendingRemoval == nil, pendingForget == nil, pendingSourceForget == nil,
              let project, exportStoreDirectory != nil else { return false }
        return (try? ProjectExportDocument.validateBinding(project)) != nil
    }
    /// No service, filesystem read, or data fetch when opening this confirmation.
    public func requestProjectExport() {
        guard canExportProject else { return }
        disableAutomaticRefresh()
        cancelOperation()
        guard let project else { return }
        pendingProjectExport = ProjectExportConfirmation(id: UUID(), project: project,
            generation: generation, scopeRevision: scopeRevision, configurationGeneration: configurationGeneration)
        status = "Review sensitive local export scope — Cancel is the default; no export read yet"
    }
    private func currentExport(_ c: ProjectExportConfirmation) -> Bool {
        guard !quitting, !policyDirty, !sourceRequiresRefresh, !forgetRequiresRefresh,
              selectedID == c.project.id, let project, ProjectExportDocument.exact(project, c.project),
              sourceDraft.count == project.sources.count,
              zip(sourceDraft, project.sources).allSatisfy({ $0.utf8.elementsEqual($1.utf8) }),
              generation == c.generation, scopeRevision == c.scopeRevision,
              configurationGeneration == c.configurationGeneration,
              pendingRemoval == nil, pendingForget == nil, pendingSourceForget == nil else { return false }
        return true
    }
    /// Returns the immutable picker token only after explicit current approval.
    /// An old callback cannot consume a newer confirmation or picker.
    public func confirmProjectExport(_ c: ProjectExportConfirmation) -> ProjectExportConfirmation? {
        guard pendingProjectExport == c, currentExport(c) else { return nil }
        pendingProjectExport = nil; exportPicker = c
        status = "Choose a NEW private local file — no export read until selection"
        return c
    }
    public func cancelProjectExport() {
        pendingProjectExport = nil; exportPicker = nil
        if exportActive { cancel() }
    }
    public func completeProjectExportSelection(_ c: ProjectExportConfirmation, destination: URL?) {
        guard exportPicker == c, currentExport(c) else { return }
        exportPicker = nil
        guard let destination, let store = exportStoreDirectory else { return }
        let prior = Array(ownedOperations.values), ticket = generation, operationID = UUID(), service = service
        for operation in prior { operation.cancel() }
        busy = true; exportActive = true; exportWriteStarted = false; lastError = nil
        status = "Exporting confirmed local content — no sharing or provider call"
        job = Task { [weak self] in
            defer { self?.ownedOperations.removeValue(forKey: operationID) }
            do {
                for operation in prior { await operation.value }
                guard let self, self.currentExport(c), !Task.isCancelled else { return }
                await self.refreshDriver.shutdown()
                guard self.currentExport(c), !Task.isCancelled else { return }
                try ProjectExportFile.validateDestination(destination, project: c.project, store: store)
                try Task.checkCancellation()
                guard case .projects(let registered) = try await service.perform(.projects), registered.count <= 64,
                      registered.allSatisfy({ $0.root.hasPrefix("/") && !$0.root.contains("\0") }) else { throw ServiceError.invalid }
                guard self.currentExport(c), !Task.isCancelled else { return }
                let roots = registered.map(\.root)
                try ProjectExportFile.validateDestination(destination, project: c.project, store: store, roots: roots)
                // Core checks the captured binding within its export transaction.
                // Never replace this with project-show + an unbound ID export.
                let execution = ProjectExportExecution(c)
                defer { execution.revoke() }
                let reply = try await withTaskCancellationHandler {
                    try Task.checkCancellation()
                    return try await service.perform(.exportProjectBound(execution))
                } onCancel: { execution.revoke() }
                guard case .projectExport(let document) = reply else { throw ServiceError.invalid }
                guard self.currentExport(c), !Task.isCancelled else { return }
                let validated = try ProjectExportDocument.decode(document.bytes, scope: c.project)
                self.exportWriteStarted = true
                let writer = Task.detached { try ProjectExportFile.save(validated, to: destination, project: c.project, store: store, roots: roots) }
                try await withTaskCancellationHandler {
                    if Task.isCancelled { writer.cancel() }
                    try await writer.value
                } onCancel: { writer.cancel() }
                guard self.generation == ticket, !Task.isCancelled else { return }
                self.status = "Private local export saved — complete bounded JSON; no upload. Local folders may be synced or backed up; retention/isolation not guaranteed."
                self.projectExportStatus = self.status
                self.busy = false; self.exportActive = false; self.exportWriteStarted = false; self.job = nil
            } catch {
                guard let self, self.generation == ticket else { return }
                let uncertain = self.exportWriteStarted
                self.busy = false; self.exportActive = false; self.exportWriteStarted = false; self.job = nil
                self.fail(uncertain ? .exportUncertain : (error as? ServiceError ?? .failed))
                self.projectExportStatus = self.status
            }
        }
        ownedOperations[operationID] = job
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
        cancelProjectExport()
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
        cancelProjectExport()
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
        // Marker inspection/Forget follow-up fences use the same exact bytes as
        // the bound read; source-policy corroboration remains an additional gate.
        sameHumanNamespace(current, captured) && current.sources == captured.sources
    }
    nonisolated private static func sameNamespace(_ current: Project, _ captured: Project) -> Bool {
        current.id == captured.id && current.root == captured.root &&
        current.root_identity == captured.root_identity && current.incarnation == captured.incarnation
    }
    nonisolated private static func sameHumanNamespace(_ current: Project, _ captured: Project) -> Bool {
        guard let a = try? HumanContextReadBinding(project: current),
              let b = try? HumanContextReadBinding(project: captured) else { return false }
        return a == b
    }
    nonisolated private static func checkHumanNamespace(_ service: any CoreService, _ captured: Project) async throws -> Project {
        guard case .project(let current) = try await service.perform(.project(captured.id)),
              sameHumanNamespace(current, captured) else { throw ServiceError.namespaceChanged }
        return current
    }
    nonisolated private static func checkNamespace(_ service: any CoreService, _ captured: Project) async throws -> Project {
        guard case .project(let current) = try await service.perform(.project(captured.id)),
              sameNamespace(current, captured) else { throw ServiceError.namespaceChanged }
        return current
    }
    /// Core admits the exact captured registration before human/marker SQL; these
    /// checks additionally fence native publication and classify replacement.
    nonisolated private static func checkedHumanRead(_ service: any CoreService, _ operation: Operation, _ captured: Project, prechecked: Bool = false) async throws -> Reply {
        let binding = try HumanContextReadBinding(project: captured) // Legacy fails before service I/O.
        switch operation {
        case .contextsBound(let supplied), .contextBound(let supplied, _), .searchHumanContextBound(let supplied, _):
            guard supplied == binding else { throw ServiceError.invalid }
        case .forgottenContextsBound(let supplied), .forgottenSourcesBound(let supplied):
            guard supplied == binding else { throw ServiceError.invalid }
        default: throw ServiceError.invalid // No trusted-operator fallback in this boundary.
        }
        do {
            try Task.checkCancellation()
            if !prechecked { _ = try await checkHumanNamespace(service, captured) }
            try Task.checkCancellation()
            let reply = try await service.perform(operation)
            try Task.checkCancellation()
            _ = try await checkHumanNamespace(service, captured)
            try Task.checkCancellation()
            return reply
        } catch {
            if error as? ServiceError == .namespaceChanged || error is CancellationError || error as? ServiceError == .canceled { throw error }
            if let reply = try? await service.perform(.project(captured.id)), case .project(let current) = reply,
               !sameHumanNamespace(current, captured) { throw ServiceError.namespaceChanged }
            throw error
        }
    }
    nonisolated private static func checkedSourceRead(_ service: any CoreService, _ operation: Operation, _ captured: Project) async throws -> Reply {
        guard captured.incarnation.map(InputPolicy.incarnation) == true else { throw ServiceError.readRequiresRefresh }
        do {
            try Task.checkCancellation()
            let before = try await checkNamespace(service, captured)
            try Task.checkCancellation()
            guard before == captured else { throw ServiceError.readRequiresRefresh }
            let reply = try await service.perform(operation)
            try Task.checkCancellation()
            let after = try await checkNamespace(service, captured)
            guard after == captured else { throw ServiceError.readRequiresRefresh }
            return reply
        } catch {
            if error as? ServiceError == .namespaceChanged { throw error }
            if error is CancellationError || error as? ServiceError == .canceled { throw error }
            if let reply = try? await service.perform(.project(captured.id)), case .project(let p) = reply,
               !sameNamespace(p, captured) { throw ServiceError.namespaceChanged }
            throw ServiceError.readRequiresRefresh
        }
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
        guard let target = project, target.id == selectedID, configured, manualActionsAvailable, !quitting, !policyDirty else { return }
        guard let binding = try? HumanContextReadBinding(project: target) else { fail(.sourceInspectionUnavailable); return }
        guard canRemoveProject else { return }
        disableAutomaticRefresh()
        sourceMarkers = nil; inspectedSourceScope = nil
        start(status: "Inspecting non-content source suppression markers", joinRefreshDriver: true, preserveHistory: true) { service in
            do {
                let before = try await service.perform(.project(target.id))
                guard case .project(let current) = before, Self.sameForgetScope(current, target) else { throw ServiceError.scopeMismatch }
                let markers = try await Self.checkedHumanRead(service, .forgottenSourcesBound(binding), target)
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
        cancelProjectExport()
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
                let markers = try await Self.checkedHumanRead(service, .forgottenSourcesBound(HumanContextReadBinding(project: expected)), expected)
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
                let contexts = try await Self.checkedHumanRead(service, .contextsBound(HumanContextReadBinding(project: target)), target)
                let markers = try await Self.checkedHumanRead(service, .forgottenContextsBound(HumanContextReadBinding(project: target)), target)
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
        guard let binding = try? HumanContextReadBinding(project: target) else { fail(.humanReadRequiresRefresh); return }
        forgottenMarkers = nil
        start(preserveHistory: true) { service in
            let before = try await service.perform(.project(target.id))
            guard case .project(let project) = before, Self.sameForgetScope(project, target) else { throw ServiceError.scopeMismatch }
            let markers: Reply
            do { markers = try await Self.checkedHumanRead(service, .forgottenContextsBound(binding), target) }
            catch ServiceError.namespaceChanged { throw ServiceError.scopeMismatch } // Preserve inspection's existing clearing/error policy.
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
        guard let id = selectedID else { return }
        if let target = project, target.id == id {
            disableAutomaticRefresh()
            refresh(id, captured: target)
        } else {
            invalidate(clearProject: true); refresh(id)
        }
    }
    private func refresh(_ id: String, captured target: Project? = nil) {
        start(preserveHistory: true) { service in
            let captured: Project
            if let target {
                // Refresh may refresh source metadata, never silently adopt a
                // replacement registration known only by the same local ID.
                if target.incarnation == nil {
                    guard case .project(let current) = try await service.perform(.project(id)),
                          current.root.utf8.elementsEqual(target.root.utf8), current.root_identity == target.root_identity,
                          current.incarnation == nil else { throw ServiceError.namespaceChanged }
                    captured = current
                } else { captured = try await Self.checkHumanNamespace(service, target) }
            } else {
                guard case .project(let current) = try await service.perform(.project(id)), current.id == id else { throw ServiceError.namespaceChanged }
                captured = current
            }
            // Metadata-only legacy selection permits explicit upgrade guidance,
            // never a legacy LIST/HISTORY/SEARCH command or an inferred binding.
            if (try? HumanContextReadBinding(project: captured)) == nil {
                return [.project(captured), .contexts(ContextList(project: id, contexts: []))]
            }
            let contexts = try await Self.checkedHumanRead(service, .contextsBound(HumanContextReadBinding(project: captured)), captured, prechecked: true)
            return [.project(captured), contexts]
        } apply: { replies in
            guard case .project(let project) = replies[0], project.id == id,
                  case .contexts(let contexts) = replies[1], contexts.project == id else { throw ServiceError.scopeMismatch }
            if target != nil {
                // Preserve drafts/history until successful explicit Refresh, not
                // while an uncertain same-namespace read is still outstanding.
                self.contextEditorRevision &+= 1
                self.originalDraft = ""; self.preparationQuery = ""
                self.clearResults(); self.humanHistoryScope = nil
            }
            self.project = project; self.sourceDraft = project.sources; self.policyDirty = false
            self.contexts = contexts.contexts
            self.forgetRequiresRefresh = false
            self.sourceRequiresRefresh = false
            self.mutationRefreshError = nil
            self.status = project.snapshot == nil || project.snapshot == .null
                ? "Not built — explicit Build required" : "Snapshot recorded — currentness not checked"
            if project.incarnation == nil {
                self.status = "Schema v3 required for native cached human reads and mutations. Stop older workers, then explicitly run store upgrade --to-version 3 --confirm-local-schema-upgrade --confirm-legacy-workers-stopped (or --to-version 4 for source Forget). No unbound native read or mutation fallback."
            } else if (try? HumanContextReadBinding(project: project)) == nil {
                self.status = ServiceError.humanReadRequiresRefresh.localizedDescription
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
    public var canBuild: Bool { canRemoveProject && !policyDirty && !sourceRequiresRefresh && !sourceDraft.isEmpty && pendingSourceForget == nil }
    public func build() {
        if inspectionOperation { cancel() }
        pendingSourceForget = nil
        guard !sourceRequiresRefresh else { fail(refreshRequiredError); return }
        guard let target = project, target.id == selectedID,
              case .string(let identity) = target.root_identity,
              let token = target.incarnation, InputPolicy.incarnation(token),
              InputPolicy.removal(root: target.root, identity: identity) else {
            sourceRequiresRefresh = true; mutationRefreshError = .readRequiresRefresh
            fail(.readRequiresRefresh); return
        }
        guard canBuild else { fail(.invalid); return }
        let id = target.id
        clearResults(preserveHistory: true)
        start(status: "Updating — bounded local source-evidence Build; Cancel available", preserveHistory: true) { service in
            do {
                // Snapshot may legitimately change during Build; registration
                // and exact approved sources may not. Core rechecks both before
                // reading files and transactionally before publishing its index.
                let indexed = try await service.perform(.indexBound(id, target.root, identity, target.sources, token))
                let fresh = try await Self.checkNamespace(service, target)
                guard fresh.sources == target.sources else { throw ServiceError.readRequiresRefresh }
                return [indexed, .project(fresh)]
            } catch {
                if error as? ServiceError == .namespaceChanged || error is CancellationError || error as? ServiceError == .canceled { throw error }
                if let reply = try? await service.perform(.project(id)), case .project(let current) = reply {
                    guard Self.sameNamespace(current, target) else { throw ServiceError.namespaceChanged }
                    guard current.sources == target.sources else { throw ServiceError.readRequiresRefresh }
                    throw error
                }
                throw ServiceError.readRequiresRefresh
            }
        } apply: { replies in
            guard case .indexed(let report) = replies[0], report.project == id else { throw ServiceError.scopeMismatch }
            guard case .project(let fresh) = replies[1] else { throw ServiceError.invalid }
            guard Self.sameNamespace(fresh, target) else { throw ServiceError.namespaceChanged }
            guard fresh.sources == target.sources else { throw ServiceError.readRequiresRefresh }
            self.indexReport = report
            self.project = fresh
            self.status = report.empty ? "Partial — empty snapshot; inspect coverage" : "Build completed — inspect coverage; currentness not checked"
        }
    }
    @Published public private(set) var sourceRetrievalMode: SourceRetrievalMode = .literal
    public func setSourceRetrievalMode(_ mode: SourceRetrievalMode) {
        guard mode != sourceRetrievalMode else { return }
        cancel()
        evidence = nil; preview = nil
        sourceRetrievalMode = mode
        status = "Source Query/Context mode changed — cached results discarded; Refine mode unchanged"
    }
    @Published public private(set) var refinementRetrievalMode: SourceRetrievalMode = .literal
    public func setRefinementRetrievalMode(_ mode: SourceRetrievalMode) {
        guard mode != refinementRetrievalMode else { return }
        cancel()
        refinementRetrievalMode = mode
        status = "Refine retrieval mode changed — inspect again for fresh consent; original and human history unchanged"
    }
    public func query(_ text: String) {
        guard !sourceRequiresRefresh else { fail(refreshRequiredError); return }
        guard !text.isEmpty, text.utf8.count <= 256 else { fail(.invalid); return }
        guard let id = selectedID, let target = project, !policyDirty, !sourceRequiresRefresh else { fail(.invalid); return }
        evidence = nil
        let operation: Operation = sourceRetrievalMode == .literal ? .queryBound(target, text) : .queryTermsBound(target, text)
        start(preserveHistory: true) { service in [try await Self.checkedSourceRead(service, operation, target)] } apply: { replies in
            guard case .query(let result) = replies[0], result.project == id,
                  result.results.allSatisfy({ $0.project == id && self.sourceDraft.contains($0.path) }) else { throw ServiceError.scopeMismatch }
            self.evidence = result
            self.sourceQueryOperation = false
            self.inspectionQueryScope = target
            self.inspectionQueryGeneration = self.generation
            self.status = result.currentness == "current-at-read"
                ? "Current at read — inspect coverage, not complete comprehension" : "Stale or unindexed — Build explicitly"
        }
        sourceQueryOperation = true
    }
    /// Changing the window never reads sources or silently renews query eligibility.
    public func setInspectionRadius(_ radius: Int) {
        guard (0...3).contains(radius), radius != inspectionRadius else { return }
        if inspectionOperation { cancel() }
        inspectionRadius = radius; sourceInspection = nil
    }
    /// Called when the source query text changes; displayed rows are not fresh authority.
    public func sourceQueryChanged() {
        if inspectionOperation || sourceQueryOperation { cancel() }
        inspectionQueryGeneration = nil; sourceInspection = nil
    }
    public func canInspectSource(_ anchor: Evidence) -> Bool {
        guard configured, manualActionsAvailable, !quitting, !policyDirty,
              !sourceRequiresRefresh, !forgetRequiresRefresh,
              pendingRemoval == nil, pendingForget == nil, pendingSourceForget == nil,
              let target = project, selectedID == target.id,
              let captured = inspectionQueryScope, ProjectExportDocument.exact(target, captured),
              inspectionQueryGeneration == generation, let evidence,
              evidence.currentness == "current-at-read", evidence.snapshot == target.snapshot,
              evidence.results.contains(where: { SourceInspectionRequest.exact($0, anchor) }),
              sourceDraft == target.sources else { return false }
        return (try? SourceInspectionRequest(project: captured, anchor: anchor, radius: inspectionRadius)) != nil
    }
    public func inspectSource(_ anchor: Evidence) {
        guard canInspectSource(anchor), let captured = inspectionQueryScope,
              let request = try? SourceInspectionRequest(project: captured, anchor: anchor, radius: inspectionRadius) else { return }
        // Reuse the normal owned read registry. No inference/export consent token,
        // preflight source read, automatic refresh grant or unbound fallback.
        disableAutomaticRefresh()
        let action = InspectionAction(request: request, owner: inspectionOwner, generation: generation &+ 1,
            configurationGeneration: configurationGeneration, scopeRevision: scopeRevision)
        start(status: "Inspecting explicitly selected source anchor — local lexical text only",
              joinRefreshDriver: true, preserveHistory: true, preserveQuery: true) { service in
            try Task.checkCancellation()
            // Z owns the complete transactional binding/currentness checks. Even
            // metadata-only normal commands use a writable store opener: never
            // run one before/after inspection or to diagnose an opaque failure.
            let reply = try await service.perform(.inspectSourceAnchorBound(action.request))
            try Task.checkCancellation()
            return [reply]
        } apply: { replies in
            guard case .sourceInspection(let document) = replies[0],
                  self.inspectionOwner == action.owner, self.generation == action.generation,
                  self.configurationGeneration == action.configurationGeneration,
                  self.scopeRevision == action.scopeRevision, let current = self.project,
                  ProjectExportDocument.exact(current, captured) else { throw ServiceError.invalid }
            self.sourceInspection = try SourceInspectionDocument.decode(document.bytes, request: request)
            self.inspectionQueryScope = captured; self.inspectionQueryGeneration = self.generation
            self.status = "Source inspected · current-at-read · lexical only; neighbors are observed text, not indexed claims. No edit, copy, send or inference."
        }
        inspectionOperation = true
    }
    private var humanHistoryScope: Project?
    /// Returns the revision currently displayed, not a fresh revision fetched at Save.
    public func humanContextRevisionBinding(_ contextID: String) -> HumanContextRevisionBinding? {
        guard let project, project.id == selectedID, let scope = humanHistoryScope,
              Self.sameHumanNamespace(project, scope), let history, history.id == contextID else { return nil }
        return try? HumanContextRevisionBinding(project: scope, history: history)
    }
    public func openContext(_ contextID: String) {
        guard let target = project, target.id == selectedID, !sourceRequiresRefresh else { return }
        guard let binding = try? HumanContextReadBinding(project: target) else { fail(.humanReadRequiresRefresh); return }
        start(preserveHistory: true) { service in
            let reply = try await Self.checkedHumanRead(service, .contextBound(binding, contextID), target)
            return [reply]
        } apply: { replies in
            guard case .context(let result) = replies[0], result.project == target.id, result.id == contextID else { throw ServiceError.scopeMismatch }
            try result.validate(project: target.id, id: contextID)
            self.history = result; self.humanHistoryScope = target; self.status = "Human context history loaded"
        }
    }
    public var canSearchHumanContext: Bool {
        configured && canRemoveProject && !policyDirty && !sourceRequiresRefresh && !forgetRequiresRefresh &&
        pendingRemoval == nil && pendingForget == nil && pendingSourceForget == nil
    }
    public func searchHumanContext(_ query: String) {
        humanSearchQueryChanged()
        guard canSearchHumanContext, let target = project, InputPolicy.humanSearch(query) else { fail(.invalid); return }
        start(status: "Searching human-authored context — no source reads or inference", preserveHistory: true) { service in
            let reply = try await Self.checkedHumanRead(service, .searchHumanContextBound(HumanContextReadBinding(project: target), query), target)
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
        guard !busy, let scope = humanSearchScope, let project, Self.sameHumanNamespace(project, scope),
              humanSearch?.results.contains(where: { $0.id == id }) == true else { return }
        openContext(id)
    }
    private func clearHumanSearch() { humanSearch = nil; humanSearchScope = nil }
    public func editPreparation(query: String, original: String) {
        guard !preparationQuery.utf8.elementsEqual(query.utf8) || !originalDraft.utf8.elementsEqual(original.utf8) else { return }
        cancelOperation(); preparationQuery = query; originalDraft = original
    }
    /// Preflight is provider-free. Enabling a saved profile never grants this consent.
    public func requestRefinement(settings: ProviderSettings) {
        refinementSettingsChanged(settings)
        guard canPrepareContext, !forgetRequiresRefresh, let target = project,
              pendingRemoval == nil, pendingForget == nil else { cancel(); fail(.invalid); return }
        let profile: ProviderProfile
        do {
            profile = try settings.selectedProfile()
            guard profile.locality == .local else { throw ServiceError.invalid }
        } catch { cancel(); fail(.invalid); return }
        let query = preparationQuery, original = originalDraft, revision = scopeRevision
        let mode = refinementRetrievalMode
        let inspection = RetainedReviewBinding(consentID: UUID(), project: target, original: original,
            query: query, settings: settings, generation: generation, scopeRevision: revision,
            configurationGeneration: configurationGeneration, retrievalMode: mode)
        disableAutomaticRefresh()
        start(status: "Inspecting exact local inference data — no provider call", joinRefreshDriver: true, preserveHistory: true) { service in
            let selection = try await Self.refinementSelection(service, inspection)
            return [.project(target), selection]
        } apply: { replies in
            guard case .project(let current) = replies[0], case .query(let selection) = replies[1] else { throw ServiceError.invalid }
            let consent = RefinementConsent(id: UUID(), project: current, query: query, original: original,
                settings: settings, profile: profile, selection: selection, generation: self.generation, scopeRevision: revision,
                retrievalMode: mode)
            try consent.validate()
            guard self.currentRefinementBinding(consentID: consent.id, settings: settings)?.matches(consent) == true else { throw ServiceError.scopeMismatch }
            self.project = current; self.pendingRefinement = consent
            self.status = "Review exact request, selection, destination and budget; Cancel is the default"
        }
    }
    public func cancelRefinement() { cancel() }
    /// All app profile mutations, including disable/load, revoke old actions now.
    public func refinementSettingsChanged(_ settings: ProviderSettings) {
        guard refinementSettings.map({ Self.sameRefinementValue($0, settings) }) != true else { return }
        cancel(); refinementSettings = settings
    }
    nonisolated private static func sameRefinementValue<T: Encodable>(_ lhs: T, _ rhs: T) -> Bool {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let left = try? encoder.encode(lhs), let right = try? encoder.encode(rhs) else { return false }
        return left == right
    }
    private func currentRefinementBinding(consentID: UUID, settings: ProviderSettings) -> RetainedReviewBinding? {
        guard !quitting, let project, let refinementSettings,
              Self.sameRefinementValue(refinementSettings, settings),
              selectedID?.utf8.elementsEqual(project.id.utf8) == true,
              sourceDraft.count == project.sources.count,
              zip(sourceDraft, project.sources).allSatisfy({ $0.utf8.elementsEqual($1.utf8) }),
              !policyDirty, !sourceRequiresRefresh, !forgetRequiresRefresh,
              pendingRemoval == nil, pendingForget == nil, pendingSourceForget == nil else { return nil }
        return RetainedReviewBinding(consentID: consentID, project: project, original: originalDraft,
            query: preparationQuery, settings: settings, generation: generation, scopeRevision: scopeRevision,
            configurationGeneration: configurationGeneration, retrievalMode: refinementRetrievalMode)
    }
    /// Mounted human confirmation uses the retained engine, never the finite path.
    public func confirmRetainedRefinement(_ consent: RefinementConsent, settings: ProviderSettings) {
        guard !busy, pendingRefinement == consent, let pending = pendingRefinement,
              Self.sameRefinementValue(pending.selection, consent.selection),
              Self.sameRefinementValue(pending.settings, consent.settings),
              let binding = currentRefinementBinding(consentID: consent.id, settings: settings),
              binding.matches(consent) else { cancel(); return }
        guard let transport = service as? ProcessService,
              let executable = transport.executable, let store = transport.dataDirectory else {
            cancel(); fail(.unavailable); return
        }
        do { try consent.validate() } catch { cancel(); fail(.invalid); return }
        let ticket = generation, controller = retainedReview
        let prior = Array(ownedOperations.values)
        pendingRefinement = nil; refinementPreview = nil; retainedReviewVisible = false; retainedOperationActive = true
        refinementOperation = true; busy = true; lastError = nil
        status = "Preparing retained \(consent.retrievalMode.label) review — one local call; delivery not attempted"
        let startID = UUID(), ownerID = UUID()
        let preparation = Task { [weak self] in
            defer { self?.ownedOperations.removeValue(forKey: startID) }
            for operation in prior { await operation.value }
            guard self?.generation == ticket, !Task.isCancelled else { return }
            await controller.synchronize(binding)
            guard self?.generation == ticket, !Task.isCancelled else { return }
            await controller.start(consent: consent, executable: executable, store: store)
            guard self?.generation == ticket, !Task.isCancelled else { return }
            self?.retainedLifetime = controller.ownedLifetime
            self?.retainedReviewVisible = true
            self?.busy = false
            self?.status = "Retained engine review — inspect questions and choose explicitly; nothing delivered"
        }
        retainedPreparation = preparation
        ownedOperations[startID] = preparation
        // This owner survives the first preview and is joined by every successor.
        ownedOperations[ownerID] = Task { [weak self] in
            defer { self?.ownedOperations.removeValue(forKey: ownerID) }
            await withTaskCancellationHandler {
                await preparation.value
                if let lifetime = controller.ownedLifetime {
                    await withTaskCancellationHandler {
                        if Task.isCancelled { lifetime.cancel() }
                        await lifetime.join()
                    } onCancel: { lifetime.cancel() }
                }
            } onCancel: { preparation.cancel() }
        }
    }
    /// Wait only for initial preparation, not the deliberately idle review owner.
    public func waitForRetainedPreparation() async { await retainedPreparation?.value }
    func waitForRetainedAction() async { await retainedActionTask?.value }
    public var retainedActionsAvailable: Bool {
        guard retainedReviewVisible, !quitting, !busy, !retainedActionBusy, !retainedReview.busy,
              retainedReview.challenge != nil, let consent = retainedReview.consent,
              let settings = refinementSettings, Self.sameRefinementValue(settings, consent.settings),
              let current = currentRefinementBinding(consentID: consent.id, settings: settings),
              current.matches(consent) else { return false }
        return retainedReview.binding == current
    }
    public func editRetainedReview(_ challenge: RetainedReviewChallenge, objective: String, outputExpectations: String) {
        retainedAction { await $0.edit(challenge, objective: objective, outputExpectations: outputExpectations) }
    }
    public func useRetainedPrepared(_ challenge: RetainedReviewChallenge) {
        retainedAction { await $0.usePrepared(challenge) }
    }
    public func useRetainedOriginal(_ challenge: RetainedReviewChallenge) {
        retainedAction { await $0.useOriginal(challenge) }
    }
    private func retainedAction(_ action: @escaping @MainActor (RetainedReviewController) async -> Void) {
        guard retainedActionsAvailable else { return }
        retainedActionBusy = true
        let id = UUID(), ticket = generation, controller = retainedReview
        let operation = Task { [weak self] in
            defer { self?.ownedOperations.removeValue(forKey: id) }
            guard self?.generation == ticket, !Task.isCancelled else { return }
            await action(controller)
            guard self?.generation == ticket, !Task.isCancelled else { return }
            self?.retainedActionBusy = false
            self?.status = "Retained review updated — delivery not attempted; original and human history unchanged"
        }
        retainedActionTask = operation
        ownedOperations[id] = operation
    }
    public func confirmRefinement(_ consent: RefinementConsent, settings: ProviderSettings) {
        guard !busy, pendingRefinement == consent, let pending = pendingRefinement,
              Self.sameRefinementValue(pending.selection, consent.selection),
              Self.sameRefinementValue(pending.settings, consent.settings),
              let binding = currentRefinementBinding(consentID: consent.id, settings: settings),
              binding.matches(consent) else { cancel(); return }
        do { try consent.validate() } catch { cancel(); fail(.invalid); return }
        start(status: "Preparing local refinement preview — one call; no Send", preserveHistory: true) { service in
            try await Self.checkRefinementScope(service, consent)
            // Re-inspect the exact selection before giving the CLI the confirmation flag.
            guard case .query(let selection) = try await Self.refinementSelection(service, binding),
                  Self.sameRefinementValue(selection, consent.selection) else { throw ServiceError.scopeMismatch }
            try await Self.checkRefinementScope(service, consent)
            try Task.checkCancellation()
            let reply = try await service.perform(.refinePreview(consent))
            try Task.checkCancellation()
            try await Self.checkRefinementScope(service, consent)
            return [reply]
        } apply: { replies in
            guard case .refinementPreview(let result) = replies[0] else { throw ServiceError.invalid }
            try result.validate(consent: consent)
            self.refinementPreview = result
            self.status = result.state == "needs-input" ? "Material questions require input — nothing sent" : "Reviewable preview only — engine approval and host delivery unavailable"
        }
    }
    nonisolated private static func checkRefinementScope(_ service: any CoreService, _ consent: RefinementConsent) async throws {
        try await checkRefinementBinding(service, RetainedReviewBinding(consent: consent, configurationGeneration: 0))
    }
    nonisolated private static func checkRefinementBinding(_ service: any CoreService, _ binding: RetainedReviewBinding) async throws {
        let current = try await checkNamespace(service, binding.project)
        let observed = RetainedReviewBinding(consentID: binding.consentID, project: current,
            original: binding.original, query: binding.query, settings: binding.settings, generation: binding.generation,
            scopeRevision: binding.scopeRevision, configurationGeneration: binding.configurationGeneration,
            retrievalMode: binding.retrievalMode)
        guard observed == binding else { throw ServiceError.readRequiresRefresh }
    }
    nonisolated private static func refinementSelection(_ service: any CoreService, _ binding: RetainedReviewBinding) async throws -> Reply {
        guard binding.project.incarnation.map(InputPolicy.incarnation) == true else { throw ServiceError.readRequiresRefresh }
        try Task.checkCancellation()
        try await checkRefinementBinding(service, binding)
        try Task.checkCancellation()
        let operation: Operation = binding.retrievalMode == .literal
            ? .queryBound(binding.project, binding.query) : .queryTermsBound(binding.project, binding.query)
        // Retain existing legacy/namespace/recovery classification as well as
        // the stricter byte-exact refinement binding checks around the read.
        let selection = try await checkedSourceRead(service, operation, binding.project)
        try Task.checkCancellation()
        try await checkRefinementBinding(service, binding)
        return selection
    }
    public var canPrepareContext: Bool {
        configured && project?.id == selectedID && project != nil && !policyDirty && !sourceRequiresRefresh && pendingSourceForget == nil &&
        InputPolicy.sources(sourceDraft) && manualActionsAvailable && !quitting &&
        InputPolicy.preparation(query: preparationQuery, original: originalDraft)
    }
    public func prepareContext() {
        guard !sourceRequiresRefresh else { cancel(); fail(refreshRequiredError); return }
        guard canPrepareContext, let id = selectedID, let target = project else { cancel(); fail(.invalid); return }
        let query = preparationQuery, original = originalDraft
        let operation: Operation = sourceRetrievalMode == .literal
            ? .prepareContextBound(target, query, original) : .prepareContextTermsBound(target, query, original)
        start(status: "Preparing Context-only preview — no AI or handoff", preserveHistory: true) { service in
            [try await Self.checkedSourceRead(service, operation, target)]
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
    public func writeContext(id contextID: String, kind: String, text: String, update: Bool,
                             expected: HumanContextRevisionBinding? = nil) {
        guard !policyDirty else { fail(.invalid); return }
        guard !sourceRequiresRefresh, let target = project, target.id == selectedID,
              case .string(let identity) = target.root_identity, let token = target.incarnation, InputPolicy.incarnation(token) else { fail(.mutationUncertain); return }
        guard InputPolicy.identifier(contextID), !text.isEmpty,
               text.utf8.count <= 4096, !text.contains("\0"), InputPolicy.contextKinds.contains(kind),
               InputPolicy.removal(root: target.root, identity: identity) else { fail(.invalid); return }
        if update {
            guard let expected, expected.contextID == contextID,
                  expected == humanContextRevisionBinding(contextID) else { fail(.contextConflict); return }
            mutateContext(.updateContextRevisionBound(expected, kind, text), target: target, contextID: contextID, expected: expected)
        } else {
            guard expected == nil else { fail(.invalid); return }
            mutateContext(.writeContextBound(target.id, contextID, kind, text, false, target.root, identity, token), target: target, contextID: contextID)
        }
    }
    public func retireContext(_ contextID: String) {
        guard !policyDirty else { fail(.invalid); return }
        guard !sourceRequiresRefresh, let target = project, target.id == selectedID,
              case .string(let identity) = target.root_identity, let token = target.incarnation, InputPolicy.incarnation(token) else { fail(.mutationUncertain); return }
        guard InputPolicy.removal(root: target.root, identity: identity),
              let expected = humanContextRevisionBinding(contextID) else { fail(.contextConflict); return }
        mutateContext(.retireContextRevisionBound(expected), target: target, contextID: contextID, expected: expected)
    }
    private func mutateContext(_ operation: Operation, target: Project, contextID: String,
                               expected: HumanContextRevisionBinding? = nil) {
        let projectID = target.id
        clearResults(preserveHistory: true)
        start(preserveHistory: true) { service in
            var acknowledged = false
            do {
                // No precheck followed by a legacy write: all comparison is in core's transaction.
                _ = try await service.perform(operation)
                acknowledged = true
                try Task.checkCancellation()
                let binding = try HumanContextReadBinding(project: target)
                let list = try await Self.checkedHumanRead(service, .contextsBound(binding), target)
                let history = try await Self.checkedHumanRead(service, .contextBound(binding, contextID), target)
                guard case .contexts(let metadata) = list, metadata.project == projectID,
                      case .context(let loaded) = history else { throw ServiceError.invalid }
                try loaded.validate(project: projectID, id: contextID)
                if let expected {
                    guard loaded.history.count > expected.revision else { throw ServiceError.mutationUncertain }
                }
                _ = try await Self.checkNamespace(service, target)
                return [list, history]
            } catch {
                if error as? ServiceError == .namespaceChanged { throw ServiceError.namespaceChanged }
                if let reply = try? await service.perform(.project(projectID)), case .project(let current) = reply,
                   !Self.sameNamespace(current, target) { throw ServiceError.namespaceChanged }
                // Only classify a rejected mutation with corroborating metadata.
                // Timeout/cancel, receipt failures and post-commit read failures stay uncertain.
                if !acknowledged, error as? ServiceError == .failed, let expected,
                   let binding = try? HumanContextReadBinding(project: target),
                   let reply = try? await Self.checkedHumanRead(service, .contextsBound(binding), target), case .contexts(let list) = reply,
                   list.project == projectID,
                   list.contexts.contains(where: { $0.id == contextID && ($0.revision > expected.revision && $0.revision <= 32) }) {
                    do {
                        _ = try await Self.checkNamespace(service, target)
                        throw ServiceError.contextConflict
                    } catch let classification as ServiceError where classification == .contextConflict || classification == .namespaceChanged {
                        throw classification
                    } catch { throw ServiceError.mutationUncertain }
                }
                if !acknowledged, error as? ServiceError == .failed, expected != nil,
                   let binding = try? HumanContextReadBinding(project: target),
                   let reply = try? await Self.checkedHumanRead(service, .forgottenContextsBound(binding), target), case .forgottenContexts(let markers) = reply {
                    do { try markers.validate(project: projectID) }
                    catch { throw ServiceError.mutationUncertain }
                    if markers.forgotten.contains(where: { $0.id == contextID }) {
                        do {
                            _ = try await Self.checkNamespace(service, target)
                            throw ServiceError.contextConflict
                        } catch let classification as ServiceError where classification == .contextConflict || classification == .namespaceChanged {
                            throw classification
                        } catch { throw ServiceError.mutationUncertain }
                    }
                }
                throw ServiceError.mutationUncertain
            }
        } apply: { replies in
            guard case .contexts(let list) = replies[0], list.project == projectID,
                  case .context(let history) = replies[1], history.project == projectID, history.id == contextID else { throw ServiceError.scopeMismatch }
            try history.validate(project: projectID, id: contextID)
            self.contexts = list.contexts; self.history = history; self.humanHistoryScope = target
            self.status = "Human context changed — dependent displayed evidence invalidated"
        }
    }
    public func resolveHostProject(_ hostProject: String) -> Bool {
        guard hostProject == selectedID else { cancel(); clearResults(); fail(.scopeMismatch); return false }
        return true // No host transport or delivery is implemented.
    }
    public var automaticRefreshProposal: AutomaticRefreshConsent? {
        guard configured, !quitting, !policyDirty, !sourceRequiresRefresh, !retainedOperationActive, pendingRefinement == nil,
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
        guard !busy, ownedOperations.isEmpty, consent == automaticRefreshProposal else { return }
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
        guard !busy, ownedOperations.isEmpty, pendingRemoval == nil, pendingForget == nil, pendingSourceForget == nil, !forgetRequiresRefresh, !sourceRequiresRefresh, let target = project else { return }
        evidence = nil; indexReport = nil
        start(status: "Updating — file-event/periodic bounded full lexical reconciliation", automatic: true, preserveHistory: true) { service in
            do {
                let indexed = try await service.perform(.indexBound(consent.projectID, consent.root, consent.rootIdentity, consent.sources, consent.incarnation))
                try Task.checkCancellation()
                let fresh = try await Self.checkNamespace(service, target)
                guard consent.matches(fresh) else { throw ServiceError.readRequiresRefresh }
                let checked = try await Self.checkedSourceRead(service, .queryBound(fresh, "threadmark-refresh-currentness"), fresh)
                return [indexed, .project(fresh), checked]
            } catch {
                if error is CancellationError || error as? ServiceError == .canceled { throw error }
                if let reply = try? await service.perform(.project(target.id)), case .project(let current) = reply,
                   !Self.sameNamespace(current, target) { throw ServiceError.namespaceChanged }
                throw ServiceError.readRequiresRefresh
            }
        } apply: { replies in
            guard case .indexed(let report) = replies[0], report.project == consent.projectID else { throw ServiceError.scopeMismatch }
            self.indexReport = report
            guard case .project(let fresh) = replies[1], case .query(let checked) = replies[2], checked.project == consent.projectID else { throw ServiceError.invalid }
            self.project = fresh
            self.status = report.empty ? "Partial — lexical snapshot empty; inspect coverage" : "File-event/periodic lexical refresh completed — currentness checked only at Build"
        }
    }
    public func togglePause() {
        if pendingProjectExport != nil || exportPicker != nil || exportActive { cancelProjectExport() }
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
        quit()
        let pending = Array(ownedOperations.values)
        await refreshDriver.shutdown()
        for operation in pending { await operation.value }
        await retainedReview.cancelAndJoin()
    }
    /// Joins all currently owned work, including an idle retained review. Cancel
    /// first for teardown; use waitForRetainedPreparation for the first preview.
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
        let preserveQuery = inspectionOperation
        sourceQueryOperation = false
        inspectionOperation = false; sourceInspection = nil
        inspectionQueryGeneration = nil; inspectionQueryScope = nil
        let uncertainExport = exportWriteStarted
        pendingProjectExport = nil; exportPicker = nil; exportActive = false; exportWriteStarted = false
        let preserveHistory = refinementOperation || retainedOperationActive || preserveQuery
        let revokeReview = retainedOperationActive
        retainedOperationActive = false
        retainedReviewVisible = false; retainedActionBusy = false
        retainedLifetime?.cancel(); retainedLifetime = nil; retainedPreparation = nil
        let previous = Array(ownedOperations.values)
        for operation in previous { operation.cancel() }
        if revokeReview {
            let id = UUID(), controller = retainedReview
            // Owned serialized boundary: synchronous setters revoke actions now;
            // successors await cancellation AND join before any service/spawn.
            ownedOperations[id] = Task { [weak self] in
                defer { self?.ownedOperations.removeValue(forKey: id) }
                for operation in previous { await operation.value }
                await controller.synchronize(nil)
            }
        }
        refinementOperation = false
        pendingRefinement = nil; refinementPreview = nil
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
            } else if !preserveQuery { clearResults(preserveHistory: preserveHistory) }
        }
        if forgetRequiresRefresh {
            contexts = []; forgottenMarkers = nil; status = ServiceError.forgetUncertain.localizedDescription
        }
        if sourceRequiresRefresh { status = refreshRequiredError.localizedDescription }
        busy = false
        if preserveQuery, !sourceRequiresRefresh, !forgetRequiresRefresh {
            status = "Source inspection canceled — owned teardown requested; prior query and human history retained. Explicitly Query again before Inspect source."
        }
        if cancelingSearch != nil { status = "Human search cancel requested — joining owned worker" }
        if uncertainExport {
            status = ServiceError.exportUncertain.localizedDescription
            projectExportStatus = status // Other settings/status updates must not hide an uncertain file outcome.
        }
    }
    private func clearResults(preserveHistory: Bool = false) {
        sourceInspection = nil; inspectionQueryScope = nil; inspectionQueryGeneration = nil
        pendingProjectExport = nil; exportPicker = nil
        pendingRefinement = nil; refinementPreview = nil
        clearHumanSearch(); evidence = nil; if !preserveHistory { history = nil }
        indexReport = nil; preview = nil; forgottenMarkers = nil; sourceMarkers = nil; inspectedSourceScope = nil
    }
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
    private func start(status: String = "Working — bounded local core operation", automatic: Bool = false, joinRefreshDriver: Bool = false, preserveHistory: Bool = false, preserveQuery: Bool = false, work: @escaping @Sendable (any CoreService) async throws -> [Reply],
                       apply: @escaping @MainActor ([Reply]) throws -> Void) {
        guard !quitting else { return }
        cancelOperation(); let ticket = generation; let service = service; let operationID = UUID()
        refinementOperation = preserveHistory
        automaticTicket = automatic ? ticket : nil
        let prior = Array(ownedOperations.values)
        for pending in prior { pending.cancel() }
        busy = true; lastError = nil; self.status = status
        job = Task { [weak self] in
            defer {
                self?.ownedOperations.removeValue(forKey: operationID)
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
                try apply(replies); self.busy = false; self.job = nil; self.automaticTicket = nil; self.inspectionOperation = false
            } catch {
                guard let self, self.generation == ticket, !self.quitting else { return }
                if error as? ServiceError == .namespaceChanged {
                    self.clearProject(); self.sourceRequiresRefresh = true
                    self.mutationRefreshError = .namespaceChanged
                } else if error as? ServiceError == .mutationUncertain {
                    self.sourceRequiresRefresh = true
                    self.mutationRefreshError = .mutationUncertain
                } else if error as? ServiceError == .readRequiresRefresh {
                    self.sourceRequiresRefresh = true
                    self.mutationRefreshError = .readRequiresRefresh
                }
                if self.sourceRequiresRefresh {
                    self.evidence = nil; self.indexReport = nil; self.preview = nil
                    self.sourceMarkers = nil; self.inspectedSourceScope = nil
                } else if !preserveQuery { self.clearResults(preserveHistory: preserveHistory) }
                if preserveQuery {
                    self.sourceInspection = nil; self.inspectionQueryGeneration = nil; self.inspectionQueryScope = nil
                }
                self.inspectionOperation = false
                self.sourceQueryOperation = false
                self.busy = false; self.job = nil
                self.fail(error as? ServiceError ?? (error is CancellationError ? .canceled : .failed))
                if preserveQuery { self.status += " Source inspection discarded; explicitly Query again before Inspect source. No automatic retry." }
                self.automaticTicket = nil
                if automatic {
                    self.disableAutomaticRefresh()
                    self.status = "Needs attention — automatic refresh stopped. Check permissions/configuration, refresh project policy, then explicitly enable again."
                }
            }
        }
        ownedOperations[operationID] = job
    }
}
