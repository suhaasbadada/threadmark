import Foundation
import Testing
@testable import CompanionKit

private actor APRankedPeer: CoreService {
    let adapter: ProcessService
    var replacement: String?, fail = false, fallback = 0, rejected = 0
    init(_ adapter: ProcessService) { self.adapter = adapter }
    func replace(_ root: String) { replacement = root }
    func failing(_ value: Bool) { fail = value }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        switch operation {
        case .searchHumanContextBound, .searchHumanContextKindsBound, .searchHumanContext:
            fallback += 1; throw ServiceError.invalid
        case .searchHumanContextTermsBound(let request):
            if fail { throw ServiceError.failed }
            if let root = replacement {
                replacement = nil; let b = request.binding
                _ = try await adapter.perform(.removeProject(b.project, b.root, b.rootIdentity, b.incarnation))
                _ = try await adapter.perform(.addProject(b.project, root, []))
                _ = try await adapter.perform(.writeContext(b.project, "memo", "note", "Synthetic B secret needle", update: false))
                do { return try await adapter.perform(operation) }
                catch { rejected += 1; throw error }
            }
            return try await adapter.perform(operation)
        default: return try await adapter.perform(operation)
        }
    }
}

@Suite("AP actual CLI ranked human notes")
struct RankedHumanSearchLiveTests {
    private func adapter(_ f: ApprovedWatchFixture) throws -> ProcessService {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        return ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: try StoreSelection.newDirectory(parent: f.root, name: "ap-store"))
    }
    private func read(_ service: ProcessService, _ project: Project, _ query: String, _ kinds: [String] = InputPolicy.contextKinds.sorted()) async throws -> RankedHumanSearch {
        let request = try RankedHumanSearchRequest(binding: HumanContextReadBinding(project: project), query: query, kinds: kinds)
        guard case .rankedHumanSearch(let r) = try await service.perform(.searchHumanContextTermsBound(request)) else { throw ServiceError.invalid }
        try r.validate(request: request, scope: project); return r
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    func ap05RankGainKindsUnicodeLatestAndBudgets() async throws {
        let f = try ApprovedWatchFixture(); defer { f.remove() }
        let s = try adapter(f)
        _ = try await s.perform(.addProject("alpha", f.root.path, ["a.rs"]))
        guard case .project(let p) = try await s.perform(.project("alpha")) else { throw ServiceError.invalid }
        let source = f.root.appendingPathComponent("a.rs"), original = try Data(contentsOf: source)
        for n in 0..<12 { _ = try await s.perform(.writeContext("alpha", "a\(n)", "pitfall", String(repeating: "ÉCHO ", count: 20), update: false)) }
        let quoted = "Synthetic ÉCHO and \"quoted\" / 📝"
        _ = try await s.perform(.writeContext("alpha", "wanted", "note", quoted, update: false))
        _ = try await s.perform(.writeContext("alpha", "tie-a", "decision", quoted, update: false))
        _ = try await s.perform(.writeContext("alpha", "tie-b", "decision", quoted, update: false))
        let ranked = try await read(s, p, "ÉCHO \"quoted\" ÉCHO")
        #expect(ranked.document.results.prefix(3).map(\.id) == ["tie-a", "tie-b", "wanted"])
        #expect(ranked.document.results.first?.matched_terms == ["écho", "\"quoted\""])
        #expect(ranked.document.results.first?.occurrences == 2)
        #expect(ranked.document.matched_entries == 15 && ranked.document.omitted_entries == 7 && ranked.document.truncated)
        #expect(ranked.bytes.count <= 8192 && ranked.bytes.last == 10)
        let note = try await read(s, p, "ÉCHO \"quoted\"", ["note"])
        #expect(note.document.results.map(\.id) == ["wanted"] && note.document.matched_entries == 1)
        #expect(note.document.results.first?.text == quoted)
        _ = try await s.perform(.writeContext("alpha", "wanted", "correction", "Synthetic changed ÉCHO", update: true))
        #expect(try await read(s, p, "ÉCHO", ["note"]).document.results.isEmpty)
        #expect(try await read(s, p, "ÉCHO", ["correction"]).document.results.first?.revision == 2)
        _ = try await s.perform(.retireContext("alpha", "wanted"))
        #expect(try await read(s, p, "ÉCHO", ["correction"]).document.results.isEmpty)
        _ = try await s.perform(.writeContext("alpha", "wanted", "note", quoted, update: true))
        #expect(try await read(s, p, "ÉCHO", ["note"]).document.results.first?.revision == 4)
        let b = try HumanContextReadBinding(project: p)
        _ = try await s.perform(.forgetContext("alpha", "wanted", b.root, b.rootIdentity, b.incarnation, 4))
        #expect(try await read(s, p, "ÉCHO", ["note"]).document.results.isEmpty)
        _ = try await s.perform(.index("alpha"))
        #expect(try await read(s, p, "ÉCHO", ["note"]).document.results.isEmpty)
        await #expect(throws: (any Error).self) { try await s.perform(.writeContext("alpha", "wanted", "note", quoted, update: false)) }
        // Whole-entry omission with a smaller later fitting row; escaped data never sliced.
        _ = try await s.perform(.writeContext("alpha", "big-a", "constraint", "budget budget " + String(repeating: "\"\\", count: 2000), update: false))
        _ = try await s.perform(.writeContext("alpha", "big-b", "constraint", "budget budget " + String(repeating: "📝", count: 1000), update: false))
        _ = try await s.perform(.writeContext("alpha", "small-z", "constraint", "budget", update: false))
        let budget = try await read(s, p, "budget", ["constraint"])
        #expect(budget.document.results.map(\.id) == ["big-b", "small-z"])
        #expect(budget.document.matched_entries == 3 && budget.document.omitted_entries == 1)
        #expect(budget.bytes.count <= 8192 && budget.bytes.last == 10)
        #expect(try Data(contentsOf: source) == original)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func ap04CASHistoryInspectSourceIndependenceAndNoWrites() async throws {
        let f = try ApprovedWatchFixture(); defer { f.remove() }
        let s = try adapter(f)
        _ = try await s.perform(.addProject("alpha", f.root.path, ["a.rs"]))
        _ = try await s.perform(.writeContext("alpha", "memo", "note", "Synthetic needle first", update: false))
        let peer = APRankedPeer(s), model = CompanionModel(service: peer, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        let base = try #require(model.humanContextRevisionBinding("memo")), editor = model.contextEditorRevision
        model.editPreparation(query: "source", original: "Synthetic original exactly 📝")
        _ = try await s.perform(.writeContext("alpha", "memo", "decision", "Synthetic needle second", update: true))
        model.writeContext(id: "memo", kind: "note", text: "Synthetic unsaved editor", update: true, expected: base); await model.waitForOperation()
        #expect(model.lastError == .contextConflict)
        model.setHumanSearchMode(.rankedAnyTerms); model.searchHumanContext("needle second"); await model.waitForOperation()
        #expect(model.rankedHumanSearch?.document.results.first?.revision == 2 && model.lastError == .contextConflict)
        #expect(model.humanContextRevisionBinding("memo") == base && model.contextEditorRevision == editor)
        await peer.failing(true); model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.rankedHumanSearch == nil && model.history?.history.count == 1 && model.lastError == .contextConflict)
        await peer.failing(false)
        // Unsafe/unapplied source draft cannot grant source access or block human authority.
        model.stageSources(["../outside.rs"])
        #expect(model.policyDirty)
        #expect(model.humanContextRevisionBinding("memo") == base && model.lastError == .contextConflict)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.rankedHumanSearch?.document.results.first?.id == "memo")
        #expect(model.sourceDraft == ["../outside.rs"] && model.policyDirty)
        #expect(model.originalDraft == "Synthetic original exactly 📝" && model.contextEditorRevision == editor)
        // Missing source and changed stored policy are not human authority. No metadata adoption.
        _ = try await s.perform(.setSources("alpha", []))
        try FileManager.default.removeItem(at: f.root.appendingPathComponent("a.rs"))
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.rankedHumanSearch?.document.results.first?.id == "memo")
        #expect(model.project?.sources == ["a.rs"])
        model.inspectRankedHumanSearchEntry("memo", result: try #require(model.rankedHumanSearch)); await model.waitForOperation()
        #expect(model.history?.history.count == 2 && model.contextEditorRevision == editor)
        // Search does not append history or replace original draft.
        guard case .context(let history) = try await s.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(history.history.count == 2 && history.history.last?.text == "Synthetic needle second")
        #expect(await peer.fallback == 0)
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil), arguments: [false, true])
    @MainActor func ap05ReplacementAfterPrecheckRejectsOldBinding(differentRoot: Bool) async throws {
        let f = try ApprovedWatchFixture(); defer { f.remove() }
        let s = try adapter(f)
        _ = try await s.perform(.addProject("alpha", f.root.path, []))
        _ = try await s.perform(.writeContext("alpha", "memo", "note", "Synthetic A needle", update: false))
        let peer = APRankedPeer(s), model = CompanionModel(service: peer, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        let old = try #require(model.project)
        let other = f.root.appendingPathComponent("other"); try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
        await peer.replace(differentRoot ? other.path : f.root.path)
        model.setHumanSearchMode(.rankedAnyTerms); model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(await peer.rejected == 1)
        #expect(await peer.fallback == 0)
        #expect(model.project == nil && model.history == nil && model.rankedHumanSearch == nil && model.lastError == .namespaceChanged)
        await #expect(throws: (any Error).self) { try await read(s, old, "needle") }
        await model.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func ap05UnindexedStaleAndAbsentSourceRootAreNotHumanAuthority() async throws {
        let f = try ApprovedWatchFixture(); defer { f.remove() }
        let s = try adapter(f), root = f.root.appendingPathComponent("source-root")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        let source = root.appendingPathComponent("a.rs")
        try Data("Synthetic original source\n".utf8).write(to: source)
        _ = try await s.perform(.addProject("alpha", root.path, ["a.rs"]))
        _ = try await s.perform(.writeContext("alpha", "memo", "note", "Synthetic durable needle", update: false))
        let model = CompanionModel(service: s, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.setHumanSearchMode(.rankedAnyTerms)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.rankedHumanSearch?.document.results.first?.id == "memo")
        _ = try await s.perform(.index("alpha"))
        let changed = Data("Synthetic changed source — stale\n".utf8); try changed.write(to: source)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.rankedHumanSearch?.document.results.first?.id == "memo")
        #expect(try Data(contentsOf: source) == changed)
        try FileManager.default.removeItem(at: source); try FileManager.default.removeItem(at: root)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.rankedHumanSearch?.document.results.first?.id == "memo")
        #expect(!FileManager.default.fileExists(atPath: root.path))
        await model.shutdown()
    }
}
