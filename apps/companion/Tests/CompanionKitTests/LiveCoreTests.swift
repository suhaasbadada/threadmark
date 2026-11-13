import Foundation
import Testing
@testable import CompanionKit

@Suite("Explicit opt-in live Rust core adapter integration")
struct LiveCoreTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil,
                  "Set THREADMARK_CORE_TEST_BINARY explicitly to test a built core; no PATH discovery"))
    func syntheticStoreLifecycle() async throws {
        // This environment variable is test-only. An explicitly invalid value
        // must fail, never skip or fall back to a fixture/installed binary.
        let path = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        guard path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else {
            throw ServiceError.unavailable
        }
        let fm = FileManager.default
        let base = try StoreSelection.existingDirectory(fm.temporaryDirectory).appendingPathComponent("opencode", isDirectory: true)
            .appendingPathComponent("threadmark-live-core-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: base) }
        let root = base.appendingPathComponent("alpha", isDirectory: true)
        let otherRoot = base.appendingPathComponent("beta", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: false)
        try fm.createDirectory(at: otherRoot, withIntermediateDirectories: false)
        let source = root.appendingPathComponent("a.rs")
        try Data("fn synthetic_alpha() { /* alpha_evidence */ }\n".utf8).write(to: source)
        try Data("fn synthetic_beta() { /* beta_evidence */ }\n".utf8).write(to: otherRoot.appendingPathComponent("b.rs"))
        let store = try StoreSelection.newDirectory(parent: base, name: "store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: path), dataDirectory: store)
        #expect(!fm.fileExists(atPath: store.path)) // Neither selection nor init creates state.
        _ = try await adapter.perform(.addProject("alpha", root.path, ["a.rs"]))
        #expect(fm.fileExists(atPath: store.path))
        let attributes = try fm.attributesOfItem(atPath: store.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        guard case .project(let registered) = try await adapter.perform(.project("alpha")) else {
            Issue.record("Missing registered project"); return
        }
        #expect(registered.sources == ["a.rs"] && registered.snapshot == nil)
        guard case .indexed(let indexed) = try await adapter.perform(.index("alpha")) else {
            Issue.record("Missing index report"); return
        }
        #expect(indexed.files == 1 && !indexed.empty)
        guard case .query(let current) = try await adapter.perform(.query("alpha", "alpha_evidence")) else {
            Issue.record("Missing query report"); return
        }
        #expect(current.currentness == "current-at-read" && !current.results.isEmpty)
        #expect(current.results.allSatisfy { $0.project == "alpha" && $0.path == "a.rs" })
        let original = "Do not change permissions or alpha_evidence. Preserve e\u{301}, café, 👩🏽‍💻.\n"
        guard case .preview(let prepared) = try await adapter.perform(.prepareContext("alpha", "alpha_evidence", original)) else {
            Issue.record("Missing Context preview"); return
        }
        #expect(prepared.state == "ready-for-review" && prepared.snapshot == current.snapshot)
        #expect(prepared.original.utf8.elementsEqual(original.utf8) && prepared.proposed.utf8.starts(with: original.utf8))
        #expect(prepared.proposed.contains("alpha_evidence") && prepared.provider == "not-invoked")
        guard case .contexts(let noNotes) = try await adapter.perform(.contexts("alpha")) else {
            Issue.record("Missing context list after preview"); return
        }
        #expect(noNotes.contexts.isEmpty) // Preparation is not human-note persistence.
        try Data("fn synthetic_alpha_changed() { /* alpha_changed */ }\n".utf8).write(to: source)
        guard case .query(let stale) = try await adapter.perform(.query("alpha", "alpha_evidence")) else {
            Issue.record("Missing stale report"); return
        }
        #expect(stale.currentness == "stale-or-unindexed")
        guard case .preview(let stalePreview) = try await adapter.perform(.prepareContext("alpha", "alpha_evidence", original)) else {
            Issue.record("Missing stale Context limitation"); return
        }
        #expect(stalePreview.state == "needs-input")
        #expect(!stalePreview.proposed.contains("fn synthetic_alpha()"))
        guard case .preview(let absent) = try await adapter.perform(.prepareContext("alpha", "nonexistent_token", original)) else {
            Issue.record("Missing empty Context limitation"); return
        }
        #expect(absent.state == "needs-input" && absent.original.utf8.elementsEqual(original.utf8))
        _ = try await adapter.perform(.index("alpha"))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic human note", update: false))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "decision", "Synthetic declared decision", update: true))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "correction", "Synthetic human correction", update: true))
        guard case .context(let history) = try await adapter.perform(.context("alpha", "memo")) else {
            Issue.record("Missing context history"); return
        }
        #expect(history.history.count == 3 && history.history.last?.text == "Synthetic human correction")
        #expect(history.history.first?.kind == "note" && history.history[1].kind == "decision")
        #expect(history.history.last?.kind == "correction" && history.producer == "human-authored")
        _ = try await adapter.perform(.retireContext("alpha", "memo"))
        guard case .context(let retired) = try await adapter.perform(.context("alpha", "memo")) else {
            Issue.record("Missing retired history"); return
        }
        #expect(retired.history.last?.retired == true && retired.history.count == 4)
        _ = try await adapter.perform(.addProject("beta", otherRoot.path, ["b.rs"]))
        _ = try await adapter.perform(.index("beta"))
        guard case .query(let isolated) = try await adapter.perform(.query("beta", "alpha_changed")),
              case .contexts(let otherContexts) = try await adapter.perform(.contexts("beta")) else {
            Issue.record("Missing isolation results"); return
        }
        #expect(isolated.results.isEmpty && otherContexts.contexts.isEmpty)
        _ = try await adapter.perform(.setSources("alpha", []))
        guard case .query(let revoked) = try await adapter.perform(.query("alpha", "alpha_changed")) else {
            Issue.record("Missing revocation result"); return
        }
        #expect(revoked.results.isEmpty && revoked.currentness == "stale-or-unindexed")
        // A fresh adapter reopens only this explicitly selected, initialized store.
        let reopened = ProcessService(executable: URL(fileURLWithPath: path), dataDirectory: store)
        guard case .projects(let projects) = try await reopened.perform(.projects),
              case .context(let persisted) = try await reopened.perform(.context("alpha", "memo")) else {
            Issue.record("Missing persisted state"); return
        }
        #expect(Set(projects.map(\.id)) == ["alpha", "beta"])
        #expect(persisted.history.last?.retired == true)
        let identity = try #require(registered.root_identity)
        guard case .string(let binding) = identity else { throw ServiceError.invalid }
        guard case .removed(let receipt) = try await reopened.perform(.removeProject("alpha", registered.root, binding)) else {
            Issue.record("Missing typed removal receipt"); return
        }
        try receipt.validate(project: "alpha")
        #expect(fm.fileExists(atPath: source.path) && fm.fileExists(atPath: otherRoot.appendingPathComponent("b.rs").path))
        guard case .projects(let afterRemoval) = try await adapter.perform(.projects),
              case .query(let otherEvidence) = try await adapter.perform(.query("beta", "beta_evidence")) else { throw ServiceError.invalid }
        #expect(afterRemoval.map(\.id) == ["beta"] && !otherEvidence.results.isEmpty)
        let replacementRoot = base.appendingPathComponent("replacement", isDirectory: true)
        try fm.createDirectory(at: replacementRoot, withIntermediateDirectories: false)
        try Data("fn replacement_evidence() {}\n".utf8).write(to: replacementRoot.appendingPathComponent("a.rs"))
        _ = try await adapter.perform(.addProject("alpha", replacementRoot.path, ["a.rs"]))
        _ = try await adapter.perform(.index("alpha"))
        guard case .contexts(let removedHistory) = try await adapter.perform(.contexts("alpha")) else { throw ServiceError.invalid }
        #expect(removedHistory.contexts.isEmpty)
        _ = try await adapter.perform(.writeContext("alpha", "replacement", "note", "Synthetic replacement note", update: false))
        await #expect(throws: ServiceError.failed) { try await reopened.perform(.removeProject("alpha", registered.root, binding)) }
        guard case .query(let preservedEvidence) = try await adapter.perform(.query("alpha", "replacement_evidence")),
              case .context(let preservedNote) = try await adapter.perform(.context("alpha", "replacement")) else { throw ServiceError.invalid }
        #expect(!preservedEvidence.results.isEmpty && preservedNote.history.count == 1)
        let empty = base.appendingPathComponent("empty-existing", isDirectory: true)
        try fm.createDirectory(at: empty, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let invalidStore = ProcessService(executable: URL(fileURLWithPath: path), dataDirectory: empty)
        await #expect(throws: ServiceError.failed) { try await invalidStore.perform(.projects) }
    }
}
