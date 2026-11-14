// TM-01–04/07/10; partial P2-A1/A3/A4/A5/A6, P3-A3/A5/A6. Synthetic files only.
import Darwin
import Foundation
import Testing
@testable import CompanionKit

private struct ExportFixture {
    let base: URL
    let root: URL
    let store: URL
    let output: URL
    let project: Project
    init() throws {
        let fm = FileManager.default
        base = try StoreSelection.existingDirectory(fm.temporaryDirectory).appendingPathComponent("opencode/export-X-" + UUID().uuidString)
        root = base.appendingPathComponent("source"); store = base.appendingPathComponent("store"); output = base.appendingPathComponent("output")
        for dir in [base, root, store, output] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        project = Project(id: "alpha", root: root.path, sources: ["a.rs"], rootIdentity: .string("1:2"), incarnation: String(repeating: "a", count: 32))
    }
    func cleanup() { try? FileManager.default.removeItem(at: base) }
    var destination: URL { output.appendingPathComponent("new.json") }
}

private func exportBytes(_ p: Project) throws -> Data {
    var o: [String: Any] = ["format": "threadmark-project-export", "version": 1,
        "project": ["id": p.id, "root_identity": p.root_identity?.description ?? "", "sources": p.sources],
        "snapshot": NSNull(), "currentness": "stale-or-unindexed",
        "coverage": "lexical-lines-only; no semantic coverage; evidence current-at-read only; stale or unindexed evidence omitted",
        "evidence": [], "human_history": [
            ["id": "memo", "revision": 1, "kind": "note", "text": "Synthetic old edit\n\"quoted\"", "retired": false,
             "producer": "human-authored", "authority": "context-not-authorization-or-observed-truth"],
            ["id": "memo", "revision": 2, "kind": "decision", "text": "Synthetic retired edit", "retired": true,
             "producer": "human-authored", "authority": "context-not-authorization-or-observed-truth"]]]
    if case .string(let hash) = p.snapshot { o["snapshot"] = hash }
    return try JSONSerialization.data(withJSONObject: o, options: [.sortedKeys, .withoutEscapingSlashes]) + Data([10])
}

private actor ExportGateService: CoreService {
    let project: Project
    var exports = 0
    var calls = 0
    var hold = false
    var holdBeforeClaim = false
    var active = false
    var overlap = false
    var result: Data?
    var execution: ProjectExportExecution?
    var entered: CheckedContinuation<Void, Never>?
    var release: CheckedContinuation<Void, Never>?
    init(_ p: Project) { project = p }
    func holding() { hold = true }
    func holdingBeforeClaim() { hold = true; holdBeforeClaim = true }
    func setResult(_ data: Data) { result = data }
    func waitForExport() async {
        if active { return }
        await withCheckedContinuation { entered = $0 }
    }
    func resume() { release?.resume(); release = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        calls += 1
        switch operation {
        case .project: return .project(project)
        case .contextsBound(let binding):
            try binding.validate()
            guard try HumanContextReadBinding(project: project) == binding else { throw ServiceError.scopeMismatch }
            return .contexts(ContextList(project: project.id, contexts: []))
        case .projects: overlap = overlap || active; return .projects([project])
        case .exportProjectBound(let authority):
            execution = authority
            if !holdBeforeClaim { _ = try authority.claim() }
            exports += 1; active = true; entered?.resume(); entered = nil
            if hold { await withCheckedContinuation { release = $0 } } // Deliberately ignores cancellation.
            defer { active = false }
            let consent = holdBeforeClaim ? try authority.claim() : authority.confirmation
            return .projectExport(try ProjectExportDocument.decode(result ?? exportBytes(project), scope: consent.project))
        default: throw ServiceError.invalid
        }
    }
}

@Suite("Explicit scoped private local export", .serialized)
struct ProjectExportTests {
    @Test @MainActor func defaultCancelPickerReplayAndInvalidationPerformNoExportIO() async throws {
        let f = try ExportFixture(); defer { f.cleanup() }
        let service = ExportGateService(f.project), model = CompanionModel(service: service, configured: true)
        model.exportStoreDirectory = f.store
        model.select("alpha"); await model.waitForOperation()
        let calls = await service.calls
        model.requestProjectExport(); let first = try #require(model.pendingProjectExport)
        #expect(await service.calls == calls)
        // A destination callback is not confirmation.
        model.completeProjectExportSelection(first, destination: f.destination)
        model.cancelProjectExport(); #expect(model.confirmProjectExport(first) == nil)
        for action in ["cancel", "policy", "config", "provider", "snapshot", "scope", "pause", "quit"] {
            let model = CompanionModel(service: service, configured: true)
            model.exportStoreDirectory = f.store
            model.select("alpha"); await model.waitForOperation()
            model.requestProjectExport(); let c = try #require(model.pendingProjectExport)
            _ = try #require(model.confirmProjectExport(c))
            switch action {
            case "cancel": model.cancelProjectExport()
            case "policy": model.stageSources([])
            case "config": model.configure(executable: URL(fileURLWithPath: "/invalid"), dataDirectory: f.store)
            case "provider": model.refinementSettingsChanged(ProviderSettings())
            case "snapshot": model.build()
            case "pause": model.togglePause()
            case "quit": model.quit()
            default: model.select(nil)
            }
            model.completeProjectExportSelection(c, destination: f.destination)
            await model.waitForOperation()
            #expect(await service.exports == 0)
            #expect(!FileManager.default.fileExists(atPath: f.destination.path))
            await model.shutdown()
        }
        await model.shutdown()
    }

    @Test @MainActor func nilPickerStaleCallbackCannotConsumeNewConsentAndSuccessIsComplete() async throws {
        let f = try ExportFixture(); defer { f.cleanup() }
        let s = ExportGateService(f.project), m = CompanionModel(service: s, configured: true)
        m.exportStoreDirectory = f.store; m.select("alpha"); await m.waitForOperation()
        m.requestProjectExport(); let first = try #require(m.pendingProjectExport)
        _ = try #require(m.confirmProjectExport(first)); m.completeProjectExportSelection(first, destination: nil)
        #expect(await s.exports == 0)
        m.requestProjectExport(); let second = try #require(m.pendingProjectExport)
        _ = try #require(m.confirmProjectExport(second))
        m.completeProjectExportSelection(first, destination: f.destination)
        #expect(await s.exports == 0)
        m.completeProjectExportSelection(second, destination: f.destination); await m.waitForOperation()
        #expect(await s.exports == 1)
        #expect(m.lastError == nil)
        let execution = try #require(await s.execution)
        #expect(throws: ServiceError.invalid) { try execution.claim() }
        #expect(try Data(contentsOf: f.destination) == exportBytes(f.project))
        var metadata = stat(); #expect(lstat(f.destination.path, &metadata) == 0 && metadata.st_mode & 0o7777 == 0o600)
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.output.path) == ["new.json"])
        m.completeProjectExportSelection(second, destination: f.output.appendingPathComponent("replay.json"))
        #expect(await s.exports == 1)
        await m.shutdown()
    }

    @Test @MainActor func canceledWorkerIsJoinedBeforeSuccessorAndLateBytesNeverWrite() async throws {
        let f = try ExportFixture(); defer { f.cleanup() }
        let s = ExportGateService(f.project), m = CompanionModel(service: s, configured: true)
        m.exportStoreDirectory = f.store; m.select("alpha"); await m.waitForOperation(); await s.holding()
        m.requestProjectExport(); let c = try #require(m.pendingProjectExport)
        _ = m.confirmProjectExport(c); m.completeProjectExportSelection(c, destination: f.destination)
        await s.waitForExport()
        let execution = try #require(await s.execution)
        m.cancel(); m.refreshProjects()
        await s.resume(); await m.waitForOperation()
        #expect(await s.overlap == false)
        #expect(throws: ServiceError.invalid) { try execution.claim() }
        #expect(!FileManager.default.fileExists(atPath: f.destination.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.output.path).isEmpty)
        await m.shutdown()
    }

    @Test func closedDuplicateRejectingBoundedFrames() throws {
        let f = try ExportFixture(); defer { f.cleanup() }
        let bytes = try exportBytes(f.project), raw = String(decoding: bytes, as: UTF8.self)
        #expect(try ProjectExportDocument.decode(bytes, scope: f.project).bytes == bytes)
        for invalid in [raw.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"version\":1"),
                        raw.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"ver\\u0073ion\":1"),
                        raw.replacingOccurrences(of: "\"version\":1", with: "\"version\":true"),
                        raw.replacingOccurrences(of: "\"version\":1", with: "\"version\":1.0"),
                        raw.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"extra\":null"),
                        raw.replacingOccurrences(of: "alpha", with: "beta"),
                        raw.replacingOccurrences(of: "human-authored", with: "observed"),
                        raw.replacingOccurrences(of: "\"revision\":2", with: "\"revision\":3"),
                        raw.replacingOccurrences(of: "\"retired\":true", with: "\"retired\":1"), raw + "{}"] {
            #expect(throws: (any Error).self) { try ProjectExportDocument.decode(Data(invalid.utf8), scope: f.project) }
        }
        var exact = bytes; exact.append(Data(repeating: 32, count: ProjectExportDocument.limit - bytes.count))
        #expect(try ProjectExportDocument.decode(exact, scope: f.project).bytes.count == ProjectExportDocument.limit)
        exact.append(10)
        #expect(throws: ServiceError.outputLimit) { try ProjectExportDocument.decode(exact, scope: f.project) }
    }

    @Test func newPrivateFileRejectsExistingLinksRootsAndNonlocalURLs() throws {
        #expect(throws: ServiceError.invalid) { try ProjectExportFile.validateLocalFilesystem(flags: 0) }
        try ProjectExportFile.validateLocalFilesystem(flags: UInt32(MNT_LOCAL))
        let f = try ExportFixture(); defer { f.cleanup() }
        let doc = try ProjectExportDocument.decode(exportBytes(f.project), scope: f.project)
        try Data("Synthetic existing data".utf8).write(to: f.destination)
        #expect(throws: (any Error).self) { try ProjectExportFile.save(doc, to: f.destination, project: f.project, store: f.store) }
        #expect(try String(contentsOf: f.destination, encoding: .utf8) == "Synthetic existing data")
        let link = f.output.appendingPathComponent("link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: f.destination)
        let parentLink = f.base.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: parentLink, withDestinationURL: f.output)
        for directory in [f.root, f.store] {
            try FileManager.default.createDirectory(at: directory.appendingPathComponent("nested"), withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        for url in [link, parentLink.appendingPathComponent("new.json"), f.root.appendingPathComponent("new.json"),
                    f.store.appendingPathComponent("new.json"), URL(string: "file://remote.invalid/share/new.json")!,
                    f.root.appendingPathComponent("nested/new.json"), f.store.appendingPathComponent("nested/new.json"),
                    f.base.appendingPathComponent("missing/new.json")] {
            #expect(throws: (any Error).self) { try ProjectExportFile.save(doc, to: url, project: f.project, store: f.store) }
        }
        #expect(throws: (any Error).self) {
            try ProjectExportFile.save(doc, to: f.output.appendingPathComponent("another.json"), project: f.project, store: f.store, roots: [f.output.path])
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.output.path).sorted() == ["link.json", "new.json"])
    }

    @Test func rootScopeAndInitialRootIdentityRejectAllDescendantDestinations() throws {
        let f = try ExportFixture(); defer { f.cleanup() }
        let root = Project(id: "alpha", root: "/", sources: [], rootIdentity: .string("1:2"), incarnation: String(repeating: "a", count: 32))
        // Validation only: no source/export access and no destination creation.
        #expect(throws: ServiceError.invalid) {
            try ProjectExportFile.validateDestination(f.destination, project: root, store: f.store)
        }
        #expect(throws: ServiceError.invalid) {
            try ProjectExportFile.validateDestination(f.destination, project: f.project, store: f.store, roots: ["/"])
        }
        // This existing spelling resolves to the initial descriptor's identity;
        // textual descendant containment alone does not detect that alias.
        #expect(throws: ServiceError.invalid) {
            try ProjectExportFile.validateDestination(f.destination, project: f.project, store: f.store, roots: ["/dev/.."])
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.output.path).isEmpty)
    }

    @Test func executionIsOneUseAndRevocationBeforeClaimIsFinal() throws {
        let f = try ExportFixture(); defer { f.cleanup() }
        let c = ProjectExportConfirmation(id: UUID(), project: f.project, generation: 1, scopeRevision: 1, configurationGeneration: 1)
        let once = ProjectExportExecution(c)
        #expect(try once.claim() == c)
        #expect(throws: ServiceError.invalid) { try once.claim() }
        let revoked = ProjectExportExecution(c)
        revoked.revoke(); revoked.revoke()
        #expect(throws: ServiceError.invalid) { try revoked.claim() }
    }

    @Test @MainActor func ownedCancellationRevokesEvenBeforeTransportClaims() async throws {
        let f = try ExportFixture(); defer { f.cleanup() }
        let s = ExportGateService(f.project), m = CompanionModel(service: s, configured: true)
        m.exportStoreDirectory = f.store; m.select("alpha"); await m.waitForOperation()
        await s.holdingBeforeClaim()
        m.requestProjectExport(); let c = try #require(m.pendingProjectExport)
        _ = m.confirmProjectExport(c); m.completeProjectExportSelection(c, destination: f.destination)
        await s.waitForExport()
        let execution = try #require(await s.execution)
        m.cancel()
        #expect(throws: ServiceError.invalid) { try execution.claim() }
        await s.resume(); await m.waitForOperation()
        #expect(throws: ServiceError.invalid) { try execution.claim() }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.output.path).isEmpty)
        await m.shutdown()
    }

    @Test @MainActor func dependencyInvalidDocumentAndUnsafeDestinationNeverPublish() async throws {
        let f = try ExportFixture(); defer { f.cleanup() }
        for mode in ["invalid", "duplicate", "wrongscope", "overflow", "destination"] {
            let service = ExportGateService(f.project), m = CompanionModel(service: service, configured: true)
            m.exportStoreDirectory = f.store; m.select("alpha"); await m.waitForOperation()
            let raw = String(decoding: try exportBytes(f.project), as: UTF8.self)
            let data: Data
            switch mode {
            case "invalid": data = Data("{}".utf8)
            case "duplicate": data = Data(raw.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"version\":1").utf8)
            case "wrongscope": data = Data(raw.replacingOccurrences(of: "alpha", with: "beta").utf8)
            case "overflow": data = Data(repeating: 32, count: ProjectExportDocument.limit + 1)
            default: data = Data(raw.utf8)
            }
            await service.setResult(data)
            m.requestProjectExport(); let c = try #require(m.pendingProjectExport)
            _ = m.confirmProjectExport(c)
            m.completeProjectExportSelection(c, destination: mode == "destination" ? f.root.appendingPathComponent("bad.json") : f.destination)
            await m.waitForOperation()
            #expect(m.lastError != nil)
            #expect(await service.exports == (mode == "destination" ? 0 : 1))
            #expect(try FileManager.default.contentsOfDirectory(atPath: f.output.path).isEmpty)
            await m.shutdown()
        }
    }

    @Test func partialWritesDiskFailureAndCancellationLeaveNoOwnedTemps() async throws {
        let f = try ExportFixture(); defer { f.cleanup() }
        let doc = try ProjectExportDocument.decode(exportBytes(f.project), scope: f.project)
        // Short writes must still produce the entire original document.
        var short = ProjectExportFile.IO(); short.write = { Darwin.write($0, $1, min(3, $2)) }
        try ProjectExportFile.save(doc, to: f.destination, project: f.project, store: f.store, io: short)
        #expect(try Data(contentsOf: f.destination) == doc.bytes)
        for mode in ["disk", "sync", "cancel"] {
            let target = f.output.appendingPathComponent(mode + ".json")
            var io = ProjectExportFile.IO()
            if mode == "sync" { io.sync = { _ in -1 } }
            else { io.write = { fd, pointer, count in
                _ = Darwin.write(fd, pointer, min(2, count))
                if mode == "cancel" { withUnsafeCurrentTask { $0?.cancel() }; return min(2, count) }
                errno = ENOSPC; return -1
            } }
            let selectedIO = io
            let task = Task.detached { try ProjectExportFile.save(doc, to: target, project: f.project, store: f.store, io: selectedIO) }
            await #expect(throws: (any Error).self) { try await task.value }
            #expect(!FileManager.default.fileExists(atPath: target.path))
            #expect(try FileManager.default.contentsOfDirectory(atPath: f.output.path) == ["new.json"])
        }
    }

    @Test func postPublicationDurabilityFailureNeverDeletesUserDataOrUnrelatedFiles() throws {
        let f = try ExportFixture(); defer { f.cleanup() }
        let doc = try ProjectExportDocument.decode(exportBytes(f.project), scope: f.project)
        let sentinel = f.output.appendingPathComponent(".threadmark-export-unrelated")
        try Data("Synthetic unrelated file".utf8).write(to: sentinel)
        var io = ProjectExportFile.IO()
        io.sync = { fd in
            var metadata = stat()
            guard fstat(fd, &metadata) == 0 else { return -1 }
            return metadata.st_mode & S_IFMT == S_IFDIR ? -1 : Darwin.fsync(fd)
        }
        #expect(throws: ServiceError.exportUncertain) { try ProjectExportFile.save(doc, to: f.destination, project: f.project, store: f.store, io: io) }
        #expect(try Data(contentsOf: f.destination) == doc.bytes)
        #expect(try String(contentsOf: sentinel, encoding: .utf8) == "Synthetic unrelated file")
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.output.path).sorted() == [".threadmark-export-unrelated", "new.json"])
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_EXPORT_FIXTURE"] != nil))
    func processTransportBoundsWholeStdoutAndRejectsInvalidFrames() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_EXPORT_FIXTURE"])
        let f = try ExportFixture(); defer { f.cleanup() }
        let c = ProjectExportConfirmation(id: UUID(), project: f.project, generation: 1, scopeRevision: 1, configurationGeneration: 1)
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: f.store)
        let valid = try exportBytes(f.project), text = String(decoding: valid, as: UTF8.self)
        var exact = valid; exact.append(Data(repeating: 32, count: ProjectExportDocument.limit - valid.count))
        for data in [valid, exact] {
            try data.write(to: f.store.appendingPathComponent("response.json"))
            let execution = ProjectExportExecution(c)
            guard case .projectExport(let doc) = try await service.perform(.exportProjectBound(execution)) else { throw ServiceError.invalid }
            #expect(doc.bytes == data)
            await #expect(throws: ServiceError.invalid) { try await service.perform(.exportProjectBound(execution)) }
        }
        exact.append(10)
        try exact.write(to: f.store.appendingPathComponent("response.json"))
        await #expect(throws: ServiceError.outputLimit) { try await service.perform(.exportProjectBound(ProjectExportExecution(c))) }
        for frame in ["{}", text + "{}", text.replacingOccurrences(of: "alpha", with: "beta"),
                      text.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"version\":1")] {
            try Data(frame.utf8).write(to: f.store.appendingPathComponent("response.json"))
            await #expect(throws: (any Error).self) { try await service.perform(.exportProjectBound(ProjectExportExecution(c))) }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.output.path).isEmpty)
    }
}
