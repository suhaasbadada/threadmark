import Foundation
import Testing
import Darwin
@testable import CompanionKit

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(json.utf8))
}

/// Deliberately test-only; never compiled into the application or adapter.
private actor ExplicitFakeCoreService: CoreService {
    var projects = [
        Project(id: "alpha", root: "/synthetic/alpha", sources: ["a.rs"]),
        Project(id: "beta", root: "/synthetic/beta", sources: ["b.rs"]),
    ]
    var revisions: [String: [ContextRevision]] = [:]
    var nextFailure: ServiceError?
    var mismatch = false
    var holdIndex = false
    var pending: CheckedContinuation<Reply, any Error>?
    var started = false
    var observer: CheckedContinuation<Void, Never>?
    var calls = 0
    func failNext(_ error: ServiceError) { nextFailure = error }
    func setMismatch() { mismatch = true }
    func holdNextIndex() { holdIndex = true }
    func waitForIndex() async {
        if started { return }
        await withCheckedContinuation { observer = $0 }
    }
    func finishIndex() throws {
        pending?.resume(returning: .indexed(try report("alpha"))); pending = nil
    }
    private func report(_ id: String) throws -> IndexReport {
        try decode(IndexReport.self, """
        {"project":"\(id)","snapshot":"s1","files":1,"anchors":1,"coverage":"partial","empty":false}
        """)
    }
    private func metadata(_ p: String) -> ContextList {
        ContextList(project: p, contexts: revisions.sorted(by: { $0.key < $1.key }).compactMap { id, values in
            guard let last = values.last else { return nil }
            return ContextEntry(id: id, revision: last.revision, kind: last.kind, retired: last.retired,
                                producer: "human-authored", authority: .string("human-declared"))
        })
    }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        calls += 1
        if let error = nextFailure { nextFailure = nil; throw error }
        switch operation {
        case .projects: return .projects(projects)
        case .project(let p):
            guard let project = projects.first(where: { $0.id == p }) else { throw ServiceError.invalid }
            return .project(mismatch ? projects[1] : project)
        case .addProject(let id, let root, let sources):
            projects.append(Project(id: id, root: root, sources: sources)); return .acknowledged
        case .setSources(let id, let sources):
            guard let i = projects.firstIndex(where: { $0.id == id }) else { throw ServiceError.invalid }
            projects[i] = Project(id: id, root: projects[i].root, sources: sources); return .acknowledged
        case .index(let p):
            if holdIndex {
                holdIndex = false; started = true; observer?.resume(); observer = nil
                // Intentionally ignores cancellation to verify the UI rejects late success.
                return try await withCheckedThrowingContinuation { pending = $0 }
            }
            return .indexed(try report(p))
        case .query(let p, _):
            return .query(try decode(QueryReport.self, """
            {"project":"\(p)","snapshot":"s1","currentness":"stale-or-unindexed","coverage":"partial","results":[]}
            """))
        case .contexts(let p): return .contexts(metadata(p))
        case .context(let p, let id):
            return .context(ContextHistory(project: p, id: id, producer: "human-authored", authority: .string("human-declared"), history: revisions[id] ?? []))
        case .writeContext(_, let id, let kind, let text, let update):
            guard update == (revisions[id] != nil) else { throw ServiceError.invalid }
            let revision = ContextRevision(revision: (revisions[id]?.count ?? 0) + 1, kind: kind, text: text, retired: false)
            revisions[id, default: []].append(revision); return .acknowledged
        case .retireContext(_, let id):
            guard let last = revisions[id]?.last else { throw ServiceError.invalid }
            revisions[id]?.append(ContextRevision(revision: last.revision + 1, kind: last.kind, text: last.text, retired: true))
            return .acknowledged
        }
    }
}

@Suite("Explicit fake-service model acceptance") @MainActor
struct ModelTests {
    private func selected() async -> (CompanionModel, ExplicitFakeCoreService) {
        let service = ExplicitFakeCoreService()
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation()
        return (model, service)
    }
    @Test func noAutomaticWorkOrSampleFallback() async {
        let service = ExplicitFakeCoreService()
        let model = CompanionModel(service: service, configured: true)
        #expect(await service.calls == 0)
        #expect(model.projects.isEmpty && model.paused && model.evidence == nil)
        let production = CompanionModel()
        production.refreshProjects(); await production.waitForOperation()
        #expect(production.lastError == .unavailable)
        #expect(production.projects.isEmpty && !production.configured)
    }
    @Test func explicitRegistrationBuildAndPolicyRevocation() async {
        let (model, _) = await selected()
        model.addProject(id: "gamma", root: "/synthetic/gamma", sources: ["c.rs"])
        await model.waitForOperation()
        #expect(model.selectedID == "gamma" && model.indexReport == nil)
        model.build(); await model.waitForOperation()
        #expect(model.indexReport?.project == "gamma")
        model.stageSources([])
        #expect(model.indexReport == nil && model.evidence == nil && !model.canBuild)
        model.applySources(); await model.waitForOperation()
        #expect(model.project?.sources == [] && !model.policyDirty && !model.canBuild)
    }
    @Test func mismatchedProjectAndHostFailClosed() async {
        let (model, service) = await selected()
        #expect(!model.resolveHostProject("beta"))
        #expect(model.lastError == .scopeMismatch && model.evidence == nil)
        await service.setMismatch()
        model.refreshSelected(); await model.waitForOperation()
        #expect(model.project == nil && model.lastError == .scopeMismatch)
    }
    @Test func noteAddEditHistoryRetireAndRebuild() async {
        let (model, _) = await selected()
        model.writeContext(id: "memo", kind: "note", text: "Synthetic note", update: false)
        await model.waitForOperation()
        #expect(model.history?.history.count == 1)
        model.writeContext(id: "memo", kind: "decision", text: "Synthetic decision", update: true)
        await model.waitForOperation()
        #expect(model.history?.history.count == 2 && model.history?.history.last?.kind == "decision")
        model.retireContext("memo"); await model.waitForOperation()
        #expect(model.history?.history.last?.retired == true && model.contexts.first?.retired == true)
        model.build(); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        #expect(model.history?.history.count == 3)
        #expect(model.history?.history.first?.text == "Synthetic note")
    }
    @Test func failureStaleAndFreshRecovery() async {
        let (model, service) = await selected()
        await service.failNext(.failed)
        model.build(); await model.waitForOperation()
        #expect(model.lastError == .failed && !model.busy && model.indexReport == nil)
        model.refreshSelected(); await model.waitForOperation()
        #expect(model.lastError == nil && model.canBuild)
        model.query("synthetic"); await model.waitForOperation()
        #expect(model.status.contains("Stale") && model.evidence?.currentness == "stale-or-unindexed")
        model.build(); await model.waitForOperation()
        #expect(model.evidence == nil && model.indexReport != nil)
        #expect(!model.status.contains("Ready"))
    }
    @Test func cancelLateResultProjectSwitchAndRevocation() async throws {
        let (model, service) = await selected()
        await service.holdNextIndex()
        model.build(); await service.waitForIndex()
        let waiter = Task { await model.waitForOperation() }
        await Task.yield()
        model.select("beta"); await model.waitForOperation()
        try await service.finishIndex(); await waiter.value
        #expect(model.selectedID == "beta" && model.indexReport == nil && model.project?.id == "beta")
        let (second, held) = await selected()
        await held.holdNextIndex(); second.build(); await held.waitForIndex()
        let otherWaiter = Task { await second.waitForOperation() }; await Task.yield()
        second.stageSources([])
        try await held.finishIndex(); await otherWaiter.value
        #expect(second.indexReport == nil && second.policyDirty && second.sourceDraft.isEmpty)
    }
    @Test func pauseResumeCloseAndQuitAreDistinct() async throws {
        let (model, service) = await selected()
        model.showManagement(); model.togglePause()
        #expect(!model.paused && model.managementVisible)
        model.togglePause(); #expect(model.paused)
        await service.holdNextIndex(); model.build(); await service.waitForIndex()
        model.closeManagement()
        #expect(model.busy && !model.managementVisible && model.closeExplanationShown)
        let waiter = Task { await model.waitForOperation() }; await Task.yield()
        model.quit(); #expect(!model.busy && model.quitting)
        try await service.finishIndex(); await waiter.value
        #expect(model.indexReport == nil)
        #expect(!model.notificationPolicy.contains("Synthetic note"))
        #expect(model.notificationPolicy.contains("No OS notifications"))
    }
    @Test func shutdownWaitsForPreviouslyCanceledOwnedWork() async throws {
        let (model, service) = await selected()
        await service.holdNextIndex(); model.build(); await service.waitForIndex()
        model.cancel()
        var completed = false
        let shutdown = Task { await model.shutdown(); completed = true }
        await Task.yield()
        #expect(!completed)
        try await service.finishIndex(); await shutdown.value
        #expect(completed && model.quitting && model.indexReport == nil)
    }
    @Test func failedSourcePolicyRemainsUnusableUntilRecovery() async {
        let (model, service) = await selected()
        model.stageSources(["changed.rs"])
        await service.failNext(.failed)
        model.applySources(); await model.waitForOperation()
        #expect(model.policyDirty && !model.canBuild && model.evidence == nil)
        model.refreshSelected(); await model.waitForOperation()
        #expect(model.sourceDraft == ["a.rs"] && !model.policyDirty)
    }
}

@Suite("Owned synthetic subprocess adapter")
struct AdapterTests {
    @discardableResult private func withAdapter<T: Sendable>(_ mode: String, limits: ProcessLimits = .init(),
                                         body: (ProcessService) async throws -> T) async throws -> T {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("threadmark-shell-test-" + UUID().uuidString)
        let dir = root.appendingPathComponent(mode)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let binary = package.appendingPathComponent(".build/debug/CompanionTestProcess")
        return try await body(ProcessService(executable: binary, dataDirectory: dir, limits: limits))
    }
    @Test func jsonRoundTripAndStaleStatus() async throws {
        try await withAdapter("valid") { adapter in
            guard case .projects(let projects) = try await adapter.perform(.projects) else { Issue.record("Wrong reply"); return }
            #expect(projects.count == 1 && projects[0].sources == ["a.rs"])
            guard case .query(let query) = try await adapter.perform(.query("alpha", "synthetic")) else { Issue.record("Wrong reply"); return }
            #expect(query.currentness == "stale-or-unindexed")
        }
    }
    @Test func stdinAndCleanEnvironment() async throws {
        try await withAdapter("stdin") { adapter in
            guard case .acknowledged = try await adapter.perform(.writeContext("alpha", "memo", "note", "synthetic note", update: false)) else {
                Issue.record("Expected acknowledged mutation"); return
            }
        }
    }
    @Test func projectAndContextCommandMapping() async throws {
        try await withAdapter("contract") { adapter in
            _ = try await adapter.perform(.addProject("alpha", "/synthetic", ["a.rs"]))
            _ = try await adapter.perform(.setSources("alpha", ["a.rs"]))
            _ = try await adapter.perform(.setSources("alpha", []))
            guard case .project(let project) = try await adapter.perform(.project("alpha")) else { Issue.record("Wrong reply"); return }
            #expect(project.id == "alpha")
            _ = try await adapter.perform(.writeContext("alpha", "memo", "decision", "synthetic decision", update: true))
            guard case .contexts(let contexts) = try await adapter.perform(.contexts("alpha")) else { Issue.record("Wrong reply"); return }
            #expect(contexts.contexts[0].producer == "human-authored")
            guard case .context(let context) = try await adapter.perform(.context("alpha", "memo")) else { Issue.record("Wrong reply"); return }
            #expect(context.history.count == 2 && context.history.last?.kind == "decision")
            _ = try await adapter.perform(.retireContext("alpha", "memo"))
        }
    }
    @Test func retrievalOutputBudget() async throws {
        try await withAdapter("large-query") { adapter in
            await #expect(throws: ServiceError.outputLimit) { try await adapter.perform(.query("alpha", "synthetic")) }
        }
    }
    @Test func unavailableMalformedFailureAndMismatch() async throws {
        await #expect(throws: ServiceError.unavailable) { try await ProcessService().perform(.projects) }
        for (mode, expected) in [("invalid", ServiceError.invalid), ("failure", .failed), ("mismatch", .scopeMismatch)] {
            try await withAdapter(mode) { adapter in
                await #expect(throws: expected) { try await adapter.perform(.index("alpha")) }
            }
        }
        #expect(!ServiceError.failed.localizedDescription.contains("synthetic-private-diagnostic"))
    }
    @Test func stdoutStderrInputAndTimeBounds() async throws {
        var limits = ProcessLimits(); limits.stdoutBytes = 1024; limits.stderrBytes = 1024; limits.seconds = 3
        for mode in ["stdout", "stderr"] {
            try await withAdapter(mode, limits: limits) { adapter in
                await #expect(throws: ServiceError.outputLimit) { try await adapter.perform(.projects) }
            }
        }
        limits.seconds = 0.1
        try await withAdapter("hang", limits: limits) { adapter in
            let start = ProcessInfo.processInfo.systemUptime
            await #expect(throws: ServiceError.timedOut) { try await adapter.perform(.projects) }
            #expect(ProcessInfo.processInfo.systemUptime - start < 3)
        }
        try await withAdapter("valid") { adapter in
            await #expect(throws: ServiceError.invalid) {
                try await adapter.perform(.writeContext("alpha", "memo", "note", String(repeating: "a", count: 16_385), update: false))
            }
        }
    }
    @Test func cancellationKillsOnlyOwnedChild() async throws {
        try await withAdapter("hang") { adapter in
            let task = Task { try await adapter.perform(.projects) }
            defer { task.cancel() }
            let marker = adapter.dataDirectory!.appendingPathComponent("started")
            // Bounded test-only readiness handshake with our own synthetic fixture.
            for _ in 0..<200 {
                if FileManager.default.fileExists(atPath: marker.path) { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            let pid = try Int32(String(contentsOf: marker, encoding: .utf8)) ?? 0
            #expect(pid > 0)
            task.cancel()
            let start = ProcessInfo.processInfo.systemUptime
            await #expect(throws: ServiceError.canceled) { try await task.value }
            #expect(ProcessInfo.processInfo.systemUptime - start < 3)
            #expect(Darwin.kill(pid, 0) == -1 && errno == ESRCH)
        }
        try await withAdapter("valid") { adapter in _ = try await adapter.perform(.projects) }
    }
    @Test func exactSourceAndIdentifierValidation() {
        for source in ["../secret", "/absolute", "a//b", "a/./b", "*.rs", "-option", "a\nprivate"] {
            #expect(!InputPolicy.sources([source]))
        }
        #expect(InputPolicy.sources([]))
        #expect(!InputPolicy.sources(Array(repeating: "a.rs", count: 65)))
        #expect(InputPolicy.sources(["src/a file.rs"]))
        #expect(!InputPolicy.identifier("--invalid argument"))
    }
}
