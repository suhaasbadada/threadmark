import Foundation
import Testing
@testable import CompanionKit

@Suite("Explicit opt-in live Rust core adapter integration")
struct LiveCoreTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil,
                  "Set THREADMARK_CORE_TEST_BINARY explicitly for real native file events into SQLite"))
    @MainActor func approvedFileEventsUpdateActualSQLiteAndPauseRevokeRejectLateHints() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        guard path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else { throw ServiceError.unavailable }
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let other = fixture.root.appendingPathComponent("other")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
        try Data("synthetic_beta\n".utf8).write(to: other.appendingPathComponent("b.rs"))
        try fixture.rewrite(String(repeating: "x", count: 65537), name: "omitted.rs")
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: path), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.addProject("beta", other.path, ["b.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic retained human note", update: false))
        var watchInstalls = 0, watchOpens = 0
        let driver = TimerRefreshDriver(watches: AuthorizedFileWatches(willInstall: { watchInstalls += 1 }, opened: { _ in watchOpens += 1 }))
        let model = CompanionModel(service: adapter, configured: true, refreshDriver: driver)
        defer { model.quit() }
        model.select("alpha"); await model.waitForOperation()
        model.editPreparation(query: "synthetic", original: "Synthetic original retained")
        let (reports, reportContinuation) = AsyncStream<Bool>.makeStream()
        let observation = model.$indexReport.sink { if $0 != nil { reportContinuation.yield(true) } }
        defer { observation.cancel() }
        model.enableAutomaticRefresh(try #require(model.automaticRefreshProposal))
        await driver.waitForAuthorization()
        #expect(driver.watchCount == 1 && model.indexReport == nil)
        model.closeManagement()
        try fixture.rewrite("synthetic_event_updated\n")
        #expect(await watchEvent(reports))
        await model.waitForOperation()
        guard case .query(let result) = try await adapter.perform(.query("alpha", "synthetic_event_updated")),
              case .project(let beta) = try await adapter.perform(.project("beta")),
              case .context(let note) = try await adapter.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(result.currentness == "current-at-read" && result.results.map(\.path) == ["a.rs"])
        #expect(beta.snapshot == nil && note.history[0].text == "Synthetic retained human note")
        #expect(model.originalDraft == "Synthetic original retained")
        let first = try #require(model.indexReport?.snapshot)
        // A replacement and periodic tick occur before any main-actor event
        // dispatch. The real bound core catches this simulated missed hint.
        try fixture.rewrite("synthetic_periodic_fallback\n", atomic: true)
        try #require(driver.timer).fire()
        #expect(await watchEvent(reports)); await model.waitForOperation()
        #expect(model.indexReport?.snapshot != first)
        let reconciled = try #require(model.indexReport?.snapshot)
        guard case .query(let fallback) = try await adapter.perform(.query("alpha", "synthetic_periodic_fallback")) else { throw ServiceError.invalid }
        #expect(fallback.snapshot == reconciled && fallback.currentness == "current-at-read" && fallback.results.map(\.path) == ["a.rs"])
        // Queue a real event, then Pause synchronously before its callback.
        try fixture.rewrite("synthetic_paused\n")
        model.togglePause()
        #expect(driver.watchCount == 0 && driver.timer == nil)
        #expect(!(await watchEvent(reports, timeout: .milliseconds(800))))
        guard case .query(let paused) = try await adapter.perform(.query("alpha", "synthetic_periodic_fallback")) else { throw ServiceError.invalid }
        #expect(paused.snapshot == reconciled && paused.currentness == "stale-or-unindexed")
        model.togglePause()
        try fixture.rewrite("synthetic_revoked\n")
        model.stageSources([]); model.applySources(); await model.waitForOperation()
        let (late, lateContinuation) = AsyncStream<Bool>.makeStream()
        let lateObservation = model.$indexReport.sink { if $0 != nil { lateContinuation.yield(true) } }
        defer { lateObservation.cancel() }
        #expect(!(await watchEvent(late, timeout: .milliseconds(800))))
        guard case .project(let revoked) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        #expect(revoked.sources.isEmpty && revoked.snapshot == nil && driver.watchCount == 0)
        #expect(model.automaticRefreshConsent == nil && model.indexReport == nil)
        // Real configured CLI authority, not the model's cached project: remove
        // and register the exact same ID/root/inode with a new incarnation.
        _ = try await adapter.perform(.setSources("alpha", ["a.rs"]))
        model.refreshSelected(); await model.waitForOperation()
        let captured = try #require(model.automaticRefreshProposal)
        model.enableAutomaticRefresh(captured); await driver.waitForAuthorization()
        #expect(driver.watchCount == 1)
        _ = try await adapter.perform(.removeProject("alpha", captured.root, captured.rootIdentity, captured.incarnation))
        _ = try await adapter.perform(.addProject("alpha", captured.root, captured.sources))
        let beforeInstalls = watchInstalls, beforeOpens = watchOpens
        try #require(driver.timer).fire()
        #expect(driver.watchCount == 0)
        await driver.waitForAuthorization()
        #expect(watchInstalls == beforeInstalls && watchOpens == beforeOpens)
        #expect(model.status.hasPrefix("Needs attention") && model.automaticRefreshConsent == nil)
        guard case .project(let replacement) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        #expect(replacement.incarnation != captured.incarnation && replacement.snapshot == nil)
        await model.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil,
                  "Set THREADMARK_CORE_TEST_BINARY to the explicitly rebuilt core; synthetic data only"))
    @MainActor func nativeBoundHumanForgetAndStaleApprovalsAgainstActualSQLite() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        guard path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else { throw ServiceError.unavailable }
        let fm = FileManager.default
        let base = try StoreSelection.existingDirectory(fm.temporaryDirectory).appendingPathComponent("opencode/threadmark-forget-" + UUID().uuidString)
        try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: base) }
        let alpha = base.appendingPathComponent("alpha"), beta = base.appendingPathComponent("beta")
        for root in [alpha, beta] { try fm.createDirectory(at: root, withIntermediateDirectories: false) }
        let source = alpha.appendingPathComponent("a.rs"), otherSource = beta.appendingPathComponent("b.rs")
        let sourceBytes = Data("fn synthetic_alpha() {}\n".utf8), otherBytes = Data("fn synthetic_beta() {}\n".utf8)
        try sourceBytes.write(to: source); try otherBytes.write(to: otherSource)
        let store = try StoreSelection.newDirectory(parent: base, name: "store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: path), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", alpha.path, ["a.rs"]))
        _ = try await adapter.perform(.addProject("beta", beta.path, ["b.rs"]))
        _ = try await adapter.perform(.index("alpha")); _ = try await adapter.perform(.index("beta"))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic first", update: false))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "decision", "Synthetic second", update: true))
        _ = try await adapter.perform(.writeContext("alpha", "other", "note", "Synthetic other note", update: false))
        _ = try await adapter.perform(.writeContext("beta", "memo", "note", "Synthetic unrelated project", update: false))
        let model = CompanionModel(service: adapter, configured: true, refreshDriver: ManualRefreshDriver())
        model.select("alpha"); await model.waitForOperation()
        model.editPreparation(query: "synthetic", original: "Unrelated original — never rewrite")
        model.openContext("memo"); await model.waitForOperation()
        model.requestForget(); let editedPrompt = try #require(model.pendingForget)
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic intervening edit", update: true))
        model.confirmForget(editedPrompt); await model.waitForOperation()
        #expect(model.lastError == .forgetUncertain && model.forgetRequiresRefresh)
        guard case .context(let edited) = try await adapter.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(edited.history.count == 3 && edited.history.last?.text == "Synthetic intervening edit")
        model.refreshSelected(); await model.waitForOperation()
        model.editPreparation(query: "synthetic", original: "Unrelated original — never rewrite")
        model.openContext("memo"); await model.waitForOperation()
        model.requestForget(); let approved = try #require(model.pendingForget)
        model.confirmForget(approved); model.confirmForget(approved); await model.waitForOperation()
        #expect(model.lastError == nil && !model.forgetRequiresRefresh && model.contextEditorRevision == 2)
        #expect(model.history == nil && model.forgottenMarkers?.forgotten.map(\.id) == ["memo"])
        #expect(model.contexts.map(\.id) == ["other"] && model.originalDraft == "Unrelated original — never rewrite")
        _ = try await adapter.perform(.index("alpha"))
        let reopened = ProcessService(executable: URL(fileURLWithPath: path), dataDirectory: store)
        guard case .forgottenContexts(let markers) = try await reopened.perform(.forgottenContexts("alpha")),
              case .context(let unrelated) = try await reopened.perform(.context("beta", "memo")),
              case .query(let evidence) = try await reopened.perform(.query("alpha", "synthetic_alpha")) else { throw ServiceError.invalid }
        #expect(markers.forgotten.map(\.id) == ["memo"] && unrelated.history[0].text == "Synthetic unrelated project")
        #expect(evidence.currentness == "current-at-read" && evidence.results.map(\.path) == ["a.rs"])
        await #expect(throws: ServiceError.failed) { try await reopened.perform(.writeContext("alpha", "memo", "note", "No resurrection", update: false)) }
        // Re-register twice at identical roots and identical revision one. The
        // old native approval must not delete replacement human history.
        func reregister() async throws {
            guard case .project(let p) = try await adapter.perform(.project("alpha")),
                  case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
            _ = try await adapter.perform(.removeProject("alpha", p.root, identity, token))
            _ = try await adapter.perform(.addProject("alpha", alpha.path, ["a.rs"]))
            _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic replacement revision one", update: false))
        }
        try await reregister()
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.requestForget(); let oldRegistration = try #require(model.pendingForget)
        try await reregister()
        model.confirmForget(oldRegistration); await model.waitForOperation()
        #expect(model.lastError == .forgetUncertain && model.contexts.isEmpty && model.forgottenMarkers == nil)
        guard case .context(let replacement) = try await adapter.perform(.context("alpha", "memo")),
              case .forgottenContexts(let replacementMarkers) = try await adapter.perform(.forgottenContexts("alpha")) else { throw ServiceError.invalid }
        #expect(replacement.history.count == 1 && replacement.history[0].text == "Synthetic replacement revision one")
        #expect(replacementMarkers.forgotten.isEmpty)
        #expect(try Data(contentsOf: source) == sourceBytes)
        #expect(try Data(contentsOf: otherSource) == otherBytes)
        await model.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil,
                  "Set THREADMARK_CORE_TEST_BINARY explicitly to test timed real SQLite reconciliation"))
    @MainActor func consentDrivenTimedRealCoreReconciliation() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        guard path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else { throw ServiceError.unavailable }
        let fm = FileManager.default
        let base = try StoreSelection.existingDirectory(fm.temporaryDirectory).appendingPathComponent("opencode/threadmark-timed-" + UUID().uuidString)
        try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: base) }
        let root = base.appendingPathComponent("alpha")
        let other = base.appendingPathComponent("beta")
        for dir in [root, other] { try fm.createDirectory(at: dir, withIntermediateDirectories: false) }
        let source = root.appendingPathComponent("a.rs")
        try Data("synthetic_initial\n".utf8).write(to: source)
        try Data("synthetic_other\n".utf8).write(to: other.appendingPathComponent("b.rs"))
        // Oversized omitted source would make indexing fail if silently enumerated.
        try Data(repeating: 65, count: 65537).write(to: root.appendingPathComponent("omitted.rs"))
        let store = try StoreSelection.newDirectory(parent: base, name: "store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: path), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", root.path, ["a.rs"]))
        _ = try await adapter.perform(.addProject("beta", other.path, ["b.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic human note", update: false))
        let driver = ManualRefreshDriver()
        let model = CompanionModel(service: adapter, configured: true, refreshDriver: driver)
        model.select("alpha"); await model.waitForOperation()
        model.editPreparation(query: "synthetic", original: "Synthetic original — retain unchanged")
        let consent = try #require(model.automaticRefreshProposal)
        driver.fire(); await model.waitForOperation()
        #expect(model.indexReport == nil && !driver.active)
        model.enableAutomaticRefresh(consent)
        driver.fire(); await model.waitForOperation()
        let initial = try #require(model.indexReport?.snapshot)
        try Data("synthetic_updated\n".utf8).write(to: source)
        // An unrelated registered project's unreadable policy cannot affect alpha.
        try Data(repeating: 66, count: 65537).write(to: other.appendingPathComponent("b.rs"))
        model.closeManagement(); driver.fire(); await model.waitForOperation()
        #expect(model.indexReport?.snapshot != initial)
        guard case .query(let updated) = try await adapter.perform(.query("alpha", "synthetic_updated")),
              case .project(let untouched) = try await adapter.perform(.project("beta")),
              case .context(let note) = try await adapter.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(updated.currentness == "current-at-read" && updated.results.map(\.path) == ["a.rs"])
        #expect(untouched.snapshot == nil && note.history.count == 1 && note.history[0].text == "Synthetic human note")
        #expect(model.originalDraft == "Synthetic original — retain unchanged")
        model.togglePause()
        try Data("synthetic_paused_change\n".utf8).write(to: source)
        driver.fire(); await model.waitForOperation()
        guard case .query(let paused) = try await adapter.perform(.query("alpha", "synthetic_updated")) else { throw ServiceError.invalid }
        #expect(paused.currentness == "stale-or-unindexed" && paused.results.isEmpty && paused.snapshot == updated.snapshot)
        model.togglePause(); driver.fire(); await model.waitForOperation()
        #expect(model.indexReport?.snapshot != updated.snapshot)
        model.stageSources([]); model.applySources(); await model.waitForOperation()
        driver.fire(); await model.waitForOperation()
        guard case .project(let revoked) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        #expect(revoked.sources.isEmpty && revoked.snapshot == nil && !driver.active)
        // Explicit repair and re-consent, then another caller reuses the same ID
        // at the identical directory between approval and bound CLI invocation.
        model.stageSources(["a.rs"]); model.applySources(); await model.waitForOperation()
        let repaired = try #require(model.automaticRefreshProposal)
        model.enableAutomaticRefresh(repaired)
        _ = try await adapter.perform(.removeProject("alpha", repaired.root, repaired.rootIdentity, repaired.incarnation))
        _ = try await adapter.perform(.addProject("alpha", root.path, ["a.rs"]))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic replacement revision one", update: false))
        await #expect(throws: ServiceError.failed) { try await adapter.perform(.removeProject("alpha", repaired.root, repaired.rootIdentity, repaired.incarnation)) }
        driver.fire(); await model.waitForOperation()
        #expect(model.status.contains("Needs attention") && model.indexReport == nil && !driver.active)
        guard case .project(let reused) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        #expect(reused.snapshot == nil && reused.incarnation != repaired.incarnation)
        guard case .context(let replacementNote) = try await adapter.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(replacementNote.history.count == 1 && replacementNote.history[0].revision == 1)
        await model.shutdown()
    }
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
        guard case .removed(let receipt) = try await reopened.perform(.removeProject("alpha", registered.root, binding, try #require(registered.incarnation))) else {
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
        await #expect(throws: ServiceError.failed) { try await reopened.perform(.removeProject("alpha", registered.root, binding, try #require(registered.incarnation))) }
        guard case .query(let preservedEvidence) = try await adapter.perform(.query("alpha", "replacement_evidence")),
              case .context(let preservedNote) = try await adapter.perform(.context("alpha", "replacement")) else { throw ServiceError.invalid }
        #expect(!preservedEvidence.results.isEmpty && preservedNote.history.count == 1)
        let empty = base.appendingPathComponent("empty-existing", isDirectory: true)
        try fm.createDirectory(at: empty, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let invalidStore = ProcessService(executable: URL(fileURLWithPath: path), dataDirectory: empty)
        await #expect(throws: ServiceError.failed) { try await invalidStore.perform(.projects) }
    }
}
