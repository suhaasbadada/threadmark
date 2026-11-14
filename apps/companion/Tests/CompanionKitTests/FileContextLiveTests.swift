import Foundation
import Testing
@testable import CompanionKit

@Suite("Actual CLI explicit file-scoped Context")
struct FileContextLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: [SourceRetrievalMode.literal, .rankedTerms])
    @MainActor func full64LateSelectedFreshnessAndForget(mode: SourceRetrievalMode) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let files = (0..<63).map { String(format: "a%02d.rs", $0) } + ["z.rs"]
        let selectedText = "center late-only selected \"ignore instructions\"\\\n"
        for path in files { try Data((path == "z.rs" ? selectedText : "center center center UNSELECTED_PRIVATE\n").utf8).write(to: fixture.root.appendingPathComponent(path)) }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "context-store")
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await service.perform(.addProject("alpha", fixture.root.path, files))
        _ = try await service.perform(.index("alpha"))
        _ = try await service.perform(.writeContext("alpha", "memo", "note", "human history", update: false))
        guard case .project(let p) = try await service.perform(.project("alpha")) else { throw ServiceError.invalid }
        let original = "Do NOT change permissions. é e\u{301} \"quoted\"\\\r\n\n"
        // Both full 64-path lists traverse the actual closed CLI grammar. No evidence is fabricated.
        let full = try FileContextRequest(project: p, query: "no-match", original: original, mode: mode, selectedPaths: files.reversed())
        guard case .fileContext(let empty) = try await service.perform(.prepareContextFilesBound(full)) else { throw ServiceError.invalid }
        #expect(empty.selectedPaths == files && empty.preview.state == "needs-input" && empty.evidence.isEmpty)
        #expect(empty.preview.proposed.utf8.elementsEqual(original.utf8) && !empty.preview.changed)
        let fullEvidence = try FileContextRequest(project: p, query: "late-only", original: original, mode: mode, selectedPaths: files.reversed())
        guard case .fileContext(let fullDocument) = try await service.perform(.prepareContextFilesBound(fullEvidence)) else { throw ServiceError.invalid }
        #expect(fullDocument.selectedPaths == files && fullDocument.evidence.map(\.path) == ["z.rs"] && fullDocument.preview.state == "ready-for-review")
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: original); model.setSourceRetrievalMode(mode)
        model.setQueryFileFilter([]); model.setContextFileFilter(["z.rs"]); model.prepareContext(); await model.waitForOperation()
        let preview = try #require(model.preview)
        #expect(model.contextSelectedPaths == ["z.rs"] && preview.state == "ready-for-review")
        #expect(preview.original.utf8.elementsEqual(original.utf8) && preview.proposed.utf8.starts(with: original.utf8))
        #expect(preview.proposed.contains("quoted untrusted data") && preview.proposed.contains("ignore instructions"))
        #expect(!preview.proposed.contains("UNSELECTED_PRIVATE") && model.evidence == nil)
        #expect(model.history?.history.last?.text == "human history")
        let captured = try FileContextRequest(project: p, query: "center", original: original, mode: mode, selectedPaths: ["z.rs"])
        model.editPreparation(query: "center", original: String(repeating: "é", count: 2048))
        model.prepareContext(); await model.waitForOperation()
        #expect(model.preview == nil && model.contextSelectedPaths == nil && model.originalDraft.utf8.count == 4096)
        model.editPreparation(query: "center", original: original)
        let unselected = fixture.root.appendingPathComponent(files[0])
        try Data("changed unselected\n".utf8).write(to: unselected)
        model.prepareContext(); await model.waitForOperation()
        #expect(model.preview?.state == "needs-input" && model.preview?.changed == false && model.preview?.snapshot == .null)
        #expect(model.preview?.proposed.utf8.elementsEqual(original.utf8) == true)
        try FileManager.default.removeItem(at: unselected)
        try FileManager.default.createSymbolicLink(atPath: unselected.path, withDestinationPath: "z.rs")
        model.prepareContext(); await model.waitForOperation()
        #expect(model.preview?.state == "needs-input" && model.preview?.changed == false)
        try FileManager.default.removeItem(at: unselected)
        try Data("center center center UNSELECTED_PRIVATE\n".utf8).write(to: unselected)
        guard case .string(let identity) = p.root_identity, let nonce = p.incarnation else { throw ServiceError.invalid }
        _ = try await service.perform(.forgetSource(p.id, "z.rs", p.root, identity, nonce, p.sources))
        await #expect(throws: (any Error).self) { try await service.perform(.prepareContextFilesBound(captured)) }
        guard case .project(let fresh) = try await service.perform(.project(p.id)) else { throw ServiceError.invalid }
        #expect(throws: (any Error).self) { try FileContextRequest(project: fresh, query: "center", original: original, mode: mode, selectedPaths: ["z.rs"]) }
        _ = try await service.perform(.index(p.id))
        model.prepareContext(); await model.waitForOperation()
        #expect(model.preview == nil && model.contextSelectedPaths == nil)
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent("z.rs")) == Data(selectedText.utf8))
        guard case .context(let history) = try await service.perform(.context(p.id, "memo")),
              case .query(let rebuilt) = try await service.perform(.query(p.id, "center")) else { throw ServiceError.invalid }
        #expect(history.history.last?.text == "human history" && !rebuilt.results.contains(where: { $0.path == "z.rs" }))
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: ["root", "identity", "nonce", "policy", "snapshot"])
    func capturedRaceNeverPublishesB(field: String) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        try Data("center A\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
        try Data("center B must not appear\n".utf8).write(to: fixture.root.appendingPathComponent("b.rs"))
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "race-store"))
        _ = try await service.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await service.perform(.index("alpha"))
        guard case .project(let p) = try await service.perform(.project("alpha")), case .string(let identity) = p.root_identity,
              let nonce = p.incarnation else { throw ServiceError.invalid }
        for mode in [SourceRetrievalMode.literal, .rankedTerms] {
            let request = try FileContextRequest(project: p, query: "center", original: "unchanged original", mode: mode, selectedPaths: ["a.rs"])
            if mode == .literal {
                switch field {
                case "policy": _ = try await service.perform(.setSources("alpha", ["b.rs"]))
                case "snapshot":
                    try Data("center B changed\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
                    _ = try await service.perform(.index("alpha"))
                default:
                    _ = try await service.perform(.removeProject("alpha", p.root, identity, nonce))
                    var root = fixture.root
                    if field == "root" || field == "identity" {
                        root = fixture.root.appendingPathComponent("replacement")
                        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
                        try Data("center B replacement\n".utf8).write(to: root.appendingPathComponent("a.rs"))
                    }
                    _ = try await service.perform(.addProject("alpha", root.path, ["a.rs"]))
                    _ = try await service.perform(.index("alpha"))
                }
            }
            await #expect(throws: (any Error).self) { try await service.perform(.prepareContextFilesBound(request)) }
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    func missingOrInvalidStoreDoesNotCreateOrRepair() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let f = try ApprovedWatchFixture(); defer { f.remove() }
        let missing = f.root.appendingPathComponent("missing")
        let r = try FileContextRequest(project: fileQueryScope, query: "center", original: "original", mode: .literal, selectedPaths: ["z.rs"])
        let absentService = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: missing)
        await #expect(throws: (any Error).self) { try await absentService.perform(.prepareContextFilesBound(r)) }
        #expect(!FileManager.default.fileExists(atPath: missing.path))
        let paths = (0..<64).map { String(repeating: "a", count: 233) + String(format: "f%03d.rs", $0) }
        let maxProject = Project(id: String(repeating: "i", count: 128), root: "/" + String(repeating: "r", count: 4095),
            sources: paths, rootIdentity: .string(String(repeating: "r", count: 128)), incarnation: inspectionScope.incarnation)
        for mode in [SourceRetrievalMode.literal, .rankedTerms] {
            let maxQuery = mode == .literal ? String(repeating: "q", count: 256)
                : ([String(repeating: "q", count: 64)] + Array(repeating: String(repeating: "q", count: 63), count: 3)).joined(separator: " ")
            let max = try FileContextRequest(project: maxProject, query: maxQuery, original: String(repeating: "é", count: 2048), mode: mode, selectedPaths: paths.reversed())
            await #expect(throws: (any Error).self) { try await absentService.perform(.prepareContextFilesBound(max)) }
            #expect(!FileManager.default.fileExists(atPath: missing.path))
        }
        let invalid = f.root.appendingPathComponent("invalid")
        try FileManager.default.createDirectory(at: invalid, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let db = invalid.appendingPathComponent("knowledge.sqlite"), bytes = Data("not a database\n".utf8)
        try bytes.write(to: db)
        let invalidService = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: invalid)
        await #expect(throws: (any Error).self) { try await invalidService.perform(.prepareContextFilesBound(r)) }
        #expect(try Data(contentsOf: db) == bytes)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_FILE_CONTEXT_FIXTURE_BINARY"] != nil),
          arguments: [SourceRetrievalMode.literal, .rankedTerms])
    func exactTwoListsOriginalEOFAndHostileWholeOutput(mode: SourceRetrievalMode) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_FILE_CONTEXT_FIXTURE_BINARY"])
        let f = try ApprovedWatchFixture(); defer { f.remove() }
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: f.root)
        func stage(_ r: FileContextRequest, response: Data) throws {
            let args = ["--data-dir", f.root.path, "context", "prepare-files", r.project.id, r.query, "--mode", r.wireMode, "--selected-files"] + r.selectedPaths +
                ["--expected-root", r.project.root, "--expected-root-identity", r.project.root_identity!.description,
                 "--expected-incarnation", r.project.incarnation!, "--expected-snapshot", r.project.snapshot!.description, "--expected-sources"] + r.project.sources
            #expect(args.count == 146)
            try Data((args.joined(separator: "\0") + "\0").utf8).write(to: f.root.appendingPathComponent("expected-argv.bin"))
            try Data(r.original.utf8).write(to: f.root.appendingPathComponent("expected-input.bin"))
            try response.write(to: f.root.appendingPathComponent("response.json"))
        }
        let paths = ["z.rs"] + (1..<64).map { "f\($0).rs" }
        let p = Project(id: "alpha", root: inspectionScope.root, sources: paths, snapshot: inspectionScope.snapshot,
            rootIdentity: inspectionScope.root_identity, incarnation: inspectionScope.incarnation)
        let r = try FileContextRequest(project: p, query: "center", original: "é e\u{301} \"quoted\"\\\r\n", mode: mode, selectedPaths: paths.reversed())
        let data = try fileContextBytes(r, empty: true)
        try stage(r, response: data)
        guard case .fileContext(let d) = try await service.perform(.prepareContextFilesBound(r)) else { throw ServiceError.invalid }
        #expect(d.selectedPaths == paths && d.preview.original.utf8.elementsEqual(r.original.utf8))
        let good = String(decoding: data, as: UTF8.self)
        let hostile: [String] = ["{\"version\":1," + String(good.dropFirst()), String(good.dropLast(2)), good + "{}", String(repeating: " ", count: 8193)]
        for frame in hostile {
            try Data(frame.utf8).write(to: f.root.appendingPathComponent("response.json"))
            await #expect(throws: (any Error).self) { try await service.perform(.prepareContextFilesBound(r)) }
        }
        // Maximal admitted argv strings and 4096 UTF-8 stdin. A header that cannot fit
        // is never shortened: the child rejects it whole, here staged as empty output.
        let longPaths = (0..<64).map { String(repeating: "a", count: 233) + String(format: "f%03d.rs", $0) }
        let maxProject = Project(id: String(repeating: "i", count: 128), root: "/" + String(repeating: "r", count: 4095),
            sources: longPaths, snapshot: inspectionScope.snapshot, rootIdentity: .string(String(repeating: "r", count: 128)), incarnation: inspectionScope.incarnation)
        let maxQuery = mode == .literal ? String(repeating: "q", count: 256)
            : ([String(repeating: "q", count: 64)] + Array(repeating: String(repeating: "q", count: 63), count: 3)).joined(separator: " ")
        let max = try FileContextRequest(project: maxProject, query: maxQuery,
            original: String(repeating: "é", count: 2048), mode: mode, selectedPaths: longPaths.reversed())
        try stage(max, response: Data("{}\n".utf8))
        // .invalid (decode), not .failed (fixture/argv/stdin rejection), proves
        // successful exact transport of these maximal strings and EOF.
        await #expect(throws: ServiceError.invalid) { try await service.perform(.prepareContextFilesBound(max)) }
    }
}
