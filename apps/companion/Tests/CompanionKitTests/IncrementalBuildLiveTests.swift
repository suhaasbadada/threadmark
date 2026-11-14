import Foundation
import Testing
@testable import CompanionKit

private actor IncrementalRaceCore: CoreService {
    let service: ProcessService
    let mode: String
    let replacementRoot: URL
    var committed = false
    var entered: CheckedContinuation<Void, Never>?
    var release: CheckedContinuation<Void, Never>?
    init(service: ProcessService, mode: String, replacementRoot: URL) {
        self.service = service; self.mode = mode; self.replacementRoot = replacementRoot
    }
    func waitForCommit() async { if committed { return }; await withCheckedContinuation { entered = $0 } }
    func finish() { release?.resume(); release = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        let reply = try await service.perform(operation)
        guard case .indexIncrementalBound(let request) = operation else { return reply }
        let p = request.project
        if mode == "receipt-lost" { throw ServiceError.failed } // Real commit, lost CLI receipt.
        if mode == "cancel" {
            committed = true; entered?.resume(); entered = nil
            await withCheckedContinuation { release = $0 }; return reply
        }
        guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
        switch mode {
        case "snapshot":
            try Data("fn peer() {}\n".utf8).write(to: URL(fileURLWithPath: p.root).appendingPathComponent("a.rs"))
            _ = try await service.perform(.index("alpha")) // Synthetic peer, never model corrective work.
        case "policy": _ = try await service.perform(.setSourcesBound(p.id, p.root, identity, token, p.sources, []))
        case "root", "nonce":
            _ = try await service.perform(.removeProject(p.id, p.root, identity, token))
            _ = try await service.perform(.addProject(p.id, mode == "root" ? replacementRoot.path : p.root, p.sources))
        default: throw ServiceError.invalid
        }
        return reply
    }
}

@Suite("Actual CLI explicit native incremental Build")
struct IncrementalBuildLiveTests {
    func setup(_ paths: [String]) async throws -> (ApprovedWatchFixture, ProcessService) {
        try await CoverageLiveTests().setup(paths)
    }
    func project(_ s: ProcessService) async throws -> Project { try await CoverageLiveTests().project(s) }
    func build(_ s: ProcessService, _ p: Project) async throws -> IncrementalBuildReport {
        guard case .incrementalBuild(let r) = try await s.perform(.indexIncrementalBound(IncrementalBuildRequest(project: p))) else { throw ServiceError.invalid }
        try r.validateAdoption(await project(s), request: IncrementalBuildRequest(project: p)); return r
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func initialNoopOneEditInodeReplacementAndHumanPreservation() async throws {
        let (f, s) = try await setup(["a.rs", "b.rs"]); defer { f.remove() }
        _ = try await s.perform(.writeContext("alpha", "memo", "note", "Synthetic human history", update: false))
        let model = CompanionModel(service: s, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "unsent original")
        let old = try #require(model.project), base = model.humanContextRevisionBinding("memo"), editor = model.contextEditorRevision
        #expect(old.snapshot == nil || old.snapshot == .null)
        model.buildIncrementally(); await model.waitForOperation()
        let first = try #require(model.incrementalBuildReport)
        #expect(first.reindexedFiles == 2 && first.reusedFiles == 0 && first.writtenAnchors == 2 && first.snapshotUpdated)
        #expect(model.project?.snapshot == .string(first.snapshot) && !model.sourceRequiresRefresh)
        model.query("center"); await model.waitForOperation()
        #expect(model.evidence?.results.count == 2)
        let p = try #require(model.project), database = s.dataDirectory!.appendingPathComponent("knowledge.sqlite")
        let bytes = try Data(contentsOf: database)
        model.buildIncrementally(); await model.waitForOperation()
        let noop = try #require(model.incrementalBuildReport)
        #expect(noop.reusedFiles == 2 && noop.reusedAnchors == 2 && noop.writtenAnchors == 0 && noop.deletedAnchors == 0)
        #expect(!noop.persistentWrites && !noop.snapshotUpdated && model.project == p)
        #expect(try Data(contentsOf: database) == bytes)
        try Data("fn edited() {}\nfn second() {}\n".utf8).write(to: f.root.appendingPathComponent("a.rs"))
        model.buildIncrementally(); await model.waitForOperation()
        let edit = try #require(model.incrementalBuildReport)
        #expect(edit.reusedFiles == 1 && edit.reindexedFiles == 1 && edit.reusedAnchors == 1 && edit.deletedAnchors == 1 && edit.writtenAnchors == 2)
        let unchanged = try Data(contentsOf: f.root.appendingPathComponent("b.rs"))
        try unchanged.write(to: f.root.appendingPathComponent("b.rs"), options: .atomic)
        model.buildIncrementally(); await model.waitForOperation()
        let inode = try #require(model.incrementalBuildReport)
        #expect(inode.reindexedFiles == 1 && inode.reusedFiles == 1 && inode.writtenAnchors == 1 && inode.deletedAnchors == 1)
        #expect(model.history?.history.last?.text == "Synthetic human history" && model.originalDraft == "unsent original")
        #expect(model.contextEditorRevision == editor && model.humanContextRevisionBinding("memo") == base)
        #expect(try Data(contentsOf: f.root.appendingPathComponent("b.rs")) == unchanged)
        await #expect(throws: (any Error).self) { try await build(s, old) }
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    func sixtyFourEmptyFilesEmptyPolicyAndSourceForgetRebuild() async throws {
        let paths = (0..<64).map { "f\($0).rs" }
        let (f, s) = try await setup(paths); defer { f.remove() }
        for path in paths { try Data().write(to: f.root.appendingPathComponent(path)) }
        let r = try await build(s, project(s))
        #expect(r.files == 64 && r.empty && r.anchors == 0 && r.reindexedFiles == 64)
        let noop = try await build(s, project(s))
        #expect(noop.reusedFiles == 64 && !noop.persistentWrites)
        _ = try await s.perform(.writeContext("alpha", "memo", "note", "Preserved note", update: false))
        let captured = try await project(s)
        guard case .string(let identity) = captured.root_identity, let token = captured.incarnation else { throw ServiceError.invalid }
        _ = try await s.perform(.forgetSource("alpha", paths[0], captured.root, identity, token, captured.sources))
        await #expect(throws: (any Error).self) { try await build(s, captured) }
        let fresh = try await project(s), rebuilt = try await build(s, fresh)
        #expect(fresh.sources == Array(paths.dropFirst()) && rebuilt.files == 63 && rebuilt.reusedFiles == 0)
        let binding = try HumanContextReadBinding(project: fresh)
        guard case .context(let history) = try await s.perform(.contextBound(binding, "memo")) else { throw ServiceError.invalid }
        #expect(history.history.last?.text == "Preserved note")
        #expect(try Data(contentsOf: f.root.appendingPathComponent(paths[0])).isEmpty)
        let latest = try await project(s)
        _ = try await s.perform(.setSourcesBound(latest.id, latest.root, identity, token, latest.sources, []))
        let empty = try await build(s, project(s)), emptyNoop = try await build(s, project(s))
        #expect(empty.files == 0 && empty.empty && empty.snapshotUpdated && empty.persistentWrites)
        #expect(emptyNoop.files == 0 && !emptyNoop.persistentWrites && !emptyNoop.snapshotUpdated)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: ["snapshot", "policy", "nonce", "root", "source"])
    func staleCaptureOrSourceFailurePreservesStoreAndNeverFallsBack(change: String) async throws {
        let (f, s) = try await setup(["a.rs"]); defer { f.remove() }
        _ = try await build(s, project(s))
        let old = try await project(s)
        guard case .string(let identity) = old.root_identity, let token = old.incarnation else { throw ServiceError.invalid }
        switch change {
        case "snapshot":
            try Data("fn changed() {}\n".utf8).write(to: f.root.appendingPathComponent("a.rs"))
            _ = try await s.perform(.index("alpha"))
        case "policy": _ = try await s.perform(.setSourcesBound("alpha", old.root, identity, token, old.sources, []))
        case "nonce", "root":
            _ = try await s.perform(.removeProject("alpha", old.root, identity, token))
            let root = change == "root" ? f.root.appendingPathComponent("replacement") : f.root
            if change == "root" { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false) }
            _ = try await s.perform(.addProject("alpha", root.path, ["a.rs"]))
        default: break
        }
        // With stale bindings even a now-unsafe/missing source must not be traversed.
        try FileManager.default.removeItem(at: f.root.appendingPathComponent("a.rs"))
        let database = s.dataDirectory!.appendingPathComponent("knowledge.sqlite"), before = try Data(contentsOf: database)
        await #expect(throws: (any Error).self) { try await build(s, old) }
        #expect(try Data(contentsOf: database) == before)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_INCREMENTAL_FIXTURE_BINARY"] != nil), arguments: [true, false])
    func closed64ArgvEOFAndWholeResponseRejection(baseline: Bool) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_INCREMENTAL_FIXTURE_BINARY"])
        let f = try ApprovedWatchFixture(); defer { f.remove() }
        let p = Project(id: "alpha", root: inspectionScope.root, sources: ["a.rs"] + (1..<64).map { "f\($0).rs" },
                        snapshot: baseline ? inspectionScope.snapshot : nil,
                        rootIdentity: inspectionScope.root_identity, incarnation: inspectionScope.incarnation)
        let request = try IncrementalBuildRequest(project: p), data = try incrementalBytes(request)
        let s = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: f.root)
        let response = f.root.appendingPathComponent("response.json")
        try data.write(to: response)
        guard case .incrementalBuild(let r) = try await s.perform(.indexIncrementalBound(request)) else { throw ServiceError.invalid }
        #expect(r.files == 64)
        let text = String(decoding: data, as: UTF8.self)
        for bad in ["{\"version\":1," + text.dropFirst(), text + "{}", String(text.dropLast()),
                    String(text.dropLast(2)), String(repeating: " ", count: 65537),
                    text.replacingOccurrences(of: "\"reused_files\":64", with: "\"reused_files\":63"),
                    text.replacingOccurrences(of: "\"files\":64", with: "\"files\":65")] {
            // The reused_files replacement is only hostile when a baseline exists.
            if bad == text { continue }
            try Data(bad.utf8).write(to: response)
            await #expect(throws: (any Error).self) { try await s.perform(.indexIncrementalBound(request)) }
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: ["receipt-lost", "snapshot", "policy", "nonce", "root", "cancel"])
    @MainActor func actualCommitThenLostReceiptOrPeerRaceNeverAdoptsReplacement(mode: String) async throws {
        let (f, s) = try await setup(["a.rs"]); defer { f.remove() }
        let replacement = f.root.appendingPathComponent("replacement")
        try FileManager.default.createDirectory(at: replacement, withIntermediateDirectories: false)
        _ = try await s.perform(.writeContext("alpha", "memo", "note", "Synthetic human history", update: false))
        let wrapper = IncrementalRaceCore(service: s, mode: mode, replacementRoot: replacement)
        let model = CompanionModel(service: wrapper, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "unsent original")
        let old = try #require(model.project), editor = model.contextEditorRevision
        model.buildIncrementally()
        if mode == "cancel" { await wrapper.waitForCommit(); model.cancel(); await wrapper.finish() }
        await model.waitForOperation()
        #expect(model.project == old && model.incrementalBuildReport == nil && model.sourceRequiresRefresh)
        #expect(model.history?.history.last?.text == "Synthetic human history" && model.originalDraft == "unsent original")
        #expect(model.contextEditorRevision == editor)
        if mode != "cancel" { #expect(model.lastError == .mutationUncertain) }
        let actual = try await project(s)
        #expect(!ProjectExportDocument.exact(actual, old))
        if mode == "receipt-lost" || mode == "cancel" {
            // Cancellation/lost output cannot honestly be described as no effect or rollback.
            #expect(actual.snapshot != nil && actual.snapshot != .null)
        }
        await model.shutdown()
    }
}
