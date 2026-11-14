// TM-01–04/07/10; bounded live P2-A1/A3/A5, P3-A3/A4. No GUI/user data.
import Foundation
import Testing
@testable import CompanionKit

@Suite("Explicit opt-in live native source Forget")
struct LiveSourceForgetTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil,
                  "Set THREADMARK_CORE_TEST_BINARY to the explicitly rebuilt core; synthetic data only"))
    @MainActor func staleSourceAndHumanMutationsCannotChangeReplacementNamespace() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fm = FileManager.default
        let base = try StoreSelection.existingDirectory(fm.temporaryDirectory).appendingPathComponent("opencode/threadmark-bound-mutations-" + UUID().uuidString)
        try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: base) }
        for otherRoot in [false, true] {
            for action in ["sources", "write", "retire"] {
                let fixture = base.appendingPathComponent("\(otherRoot)-\(action)")
                try fm.createDirectory(at: fixture, withIntermediateDirectories: false)
                let original = fixture.appendingPathComponent("original"), replacement = fixture.appendingPathComponent("replacement")
                for root in [original, replacement] {
                    try fm.createDirectory(at: root, withIntermediateDirectories: false)
                    try Data("fn synthetic_preserved_evidence() {}\n".utf8).write(to: root.appendingPathComponent("a.rs"))
                }
                let store = try StoreSelection.newDirectory(parent: fixture, name: "store")
                let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
                _ = try await adapter.perform(.addProject("alpha", original.path, ["a.rs"]))
                _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic old namespace note", update: false))
                let model = CompanionModel(service: adapter, configured: true)
                model.select("alpha"); await model.waitForOperation()
                model.openContext("memo"); await model.waitForOperation()
                model.editPreparation(query: "q", original: "Synthetic unsaved old request")
                let captured = try #require(model.project), editor = model.contextEditorRevision
                guard case .string(let identity) = captured.root_identity else { throw ServiceError.invalid }
                let token = try #require(captured.incarnation)
                _ = try await adapter.perform(.removeProject("alpha", captured.root, identity, token))
                _ = try await adapter.perform(.addProject("alpha", otherRoot ? replacement.path : original.path, ["a.rs"]))
                _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic replacement human note", update: false))
                _ = try await adapter.perform(.index("alpha"))
                guard case .project(let before) = try await adapter.perform(.project("alpha")),
                      case .context(let historyBefore) = try await adapter.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
                await #expect(throws: ServiceError.failed) {
                    try await adapter.perform(.setSourcesBound("alpha", captured.root, identity, token, captured.sources, []))
                }
                await #expect(throws: ServiceError.failed) {
                    try await adapter.perform(.writeContextBound("alpha", "memo", "note", "Synthetic stale editor text", true, captured.root, identity, token))
                }
                await #expect(throws: ServiceError.failed) {
                    try await adapter.perform(.retireContextBound("alpha", "memo", captured.root, identity, token))
                }
                switch action {
                case "sources": model.stageSources([]); model.applySources()
                case "write": model.writeContext(id: "memo", kind: "note", text: "Synthetic stale editor text", update: true, expected: model.humanContextRevisionBinding("memo"))
                default: model.retireContext("memo")
                }
                await model.waitForOperation()
                #expect(model.project == nil && model.history == nil && model.contexts.isEmpty && model.sourceRequiresRefresh)
                #expect(model.contextEditorRevision > editor && model.originalDraft.isEmpty && model.lastError == .namespaceChanged)
                guard case .project(let after) = try await adapter.perform(.project("alpha")),
                      case .context(let historyAfter) = try await adapter.perform(.context("alpha", "memo")),
                      case .query(let evidence) = try await adapter.perform(.query("alpha", "synthetic_preserved_evidence")) else { throw ServiceError.invalid }
                #expect(before == after && evidence.results.count == 1 && historyAfter.history.count == 1)
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                #expect(try encoder.encode(historyBefore) == encoder.encode(historyAfter))
                #expect(try Data(contentsOf: original.appendingPathComponent("a.rs")) == Data("fn synthetic_preserved_evidence() {}\n".utf8))
            }
        }
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil,
                  "Set THREADMARK_CORE_TEST_BINARY to the explicitly rebuilt core; synthetic data only"))
    @MainActor func boundNativeForgetPreservesFilesHumansAndOtherProjectsWithoutResurrection() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        guard binary.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: binary) else { throw ServiceError.unavailable }
        let fm = FileManager.default
        let base = try StoreSelection.existingDirectory(fm.temporaryDirectory).appendingPathComponent("opencode/threadmark-source-forget-" + UUID().uuidString)
        try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: base) }
        let alpha = base.appendingPathComponent("alpha"), beta = base.appendingPathComponent("beta"), replacement = base.appendingPathComponent("replacement")
        let newRoot = base.appendingPathComponent("new-root")
        for root in [alpha, beta, replacement, newRoot] { try fm.createDirectory(at: root, withIntermediateDirectories: false) }
        let forgotten = Data("fn synthetic_forgotten_unique() {}\n".utf8), retained = Data("fn synthetic_remaining_unique() {}\n".utf8)
        let other = Data("fn synthetic_other_unique() {}\n".utf8)
        try forgotten.write(to: alpha.appendingPathComponent("a.rs")); try retained.write(to: alpha.appendingPathComponent("b.rs"))
        try other.write(to: beta.appendingPathComponent("a.rs")); try forgotten.write(to: replacement.appendingPathComponent("a.rs"))
        try forgotten.write(to: newRoot.appendingPathComponent("a.rs"))
        let store = try StoreSelection.newDirectory(parent: base, name: "store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await adapter.perform(.addProject("alpha", alpha.path, ["a.rs", "b.rs"]))
        _ = try await adapter.perform(.addProject("beta", beta.path, ["a.rs"]))
        _ = try await adapter.perform(.index("alpha")); _ = try await adapter.perform(.index("beta"))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "note", "Synthetic first human revision", update: false))
        _ = try await adapter.perform(.writeContext("alpha", "memo", "decision", "Synthetic retained human revision", update: true))
        guard case .project(let betaBefore) = try await adapter.perform(.project("beta")),
              case .context(let humanBefore) = try await adapter.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        let driver = ManualRefreshDriver(), model = CompanionModel(service: adapter, configured: true, refreshDriver: driver)
        model.select("alpha"); await model.waitForOperation()
        model.editPreparation(query: "synthetic_forgotten_unique", original: "Synthetic unrelated request draft")
        model.prepareContext(); await model.waitForOperation(); #expect(model.preview != nil)
        model.query("synthetic_forgotten_unique"); await model.waitForOperation(); #expect(model.evidence?.results.map(\.path) == ["a.rs"])
        model.openContext("memo"); await model.waitForOperation()
        let editor = model.contextEditorRevision
        #expect(!model.canForgetSource("a.rs"))
        model.inspectForgottenSources(); await model.waitForOperation()
        model.requestSourceForget("a.rs"); let prompt = try #require(model.pendingSourceForget)
        model.cancelSourceForget(); model.confirmSourceForget(prompt)
        #expect(model.sourceDraft == ["a.rs", "b.rs"] && model.contextEditorRevision == editor)
        model.requestSourceForget("a.rs"); let approved = try #require(model.pendingSourceForget)
        model.confirmSourceForget(approved); model.confirmSourceForget(approved)
        #expect(model.preview == nil && model.evidence == nil && model.indexReport == nil && model.sourceRequiresRefresh)
        await model.waitForOperation()
        #expect(model.lastError == nil && !model.sourceRequiresRefresh && model.selectedID == "alpha")
        #expect(model.sourceDraft == ["b.rs"] && model.project?.sources == ["b.rs"] && model.sourceMarkers?.forgotten.map(\.path) == ["a.rs"])
        #expect(model.history?.history.count == 2 && model.contexts.map(\.id) == ["memo"])
        #expect(model.contextEditorRevision == editor && model.originalDraft == "Synthetic unrelated request draft")
        #expect(try Data(contentsOf: alpha.appendingPathComponent("a.rs")) == forgotten)
        #expect(try Data(contentsOf: alpha.appendingPathComponent("b.rs")) == retained)
        #expect(try Data(contentsOf: beta.appendingPathComponent("a.rs")) == other)
        guard case .context(let humanAfter) = try await adapter.perform(.context("alpha", "memo")),
              case .project(let betaAfter) = try await adapter.perform(.project("beta")),
              case .project(let revoked) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        #expect(try encoder.encode(humanBefore) == encoder.encode(humanAfter))
        #expect(betaBefore == betaAfter && revoked.snapshot == nil)
        // A fresh adapter and every source-derived read/rebuild retain suppression.
        let reopened = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        model.build(); await model.waitForOperation()
        #expect(model.indexReport?.files == 1 && model.automaticRefreshProposal?.sources == ["b.rs"])
        guard case .query(let absent) = try await reopened.perform(.query("alpha", "synthetic_forgotten_unique")),
              case .query(let present) = try await reopened.perform(.query("alpha", "synthetic_remaining_unique")),
              case .preview(let prepared) = try await reopened.perform(.prepareContext("alpha", "synthetic_forgotten_unique", "Synthetic original")),
              case .forgottenSources(let markers) = try await reopened.perform(.forgottenSources("alpha")) else { throw ServiceError.invalid }
        #expect(absent.results.isEmpty && present.results.map(\.path) == ["b.rs"])
        #expect(!prepared.proposed.contains("fn synthetic_forgotten_unique()"))
        #expect(markers.forgotten.map(\.path) == ["a.rs"])
        await #expect(throws: ServiceError.failed) { try await reopened.perform(.setSources("alpha", ["a.rs", "b.rs"])) }
        // Bound repeats must fail even though unbound operator CLI repeats are idempotent.
        guard case .string(let identity) = approved.project.root_identity, let token = approved.project.incarnation else { throw ServiceError.invalid }
        await #expect(throws: ServiceError.failed) {
            try await reopened.perform(.forgetSource("alpha", "a.rs", approved.project.root, identity, token, approved.project.sources))
        }
        // Missing source files are forgettable: no source read or filesystem deletion.
        try fm.removeItem(at: alpha.appendingPathComponent("b.rs"))
        model.inspectForgottenSources(); await model.waitForOperation()
        model.requestSourceForget("b.rs"); model.confirmSourceForget(try #require(model.pendingSourceForget)); await model.waitForOperation()
        #expect(model.lastError == nil && model.sourceDraft.isEmpty && model.sourceMarkers?.forgotten.map(\.path) == ["a.rs", "b.rs"])
        #expect(try Data(contentsOf: alpha.appendingPathComponent("a.rs")) == forgotten)
        // Peer policy changes reject approval even when the target remains approved.
        _ = try await adapter.perform(.addProject("peer", replacement.path, ["a.rs"]))
        model.select("peer"); await model.waitForOperation(); model.inspectForgottenSources(); await model.waitForOperation()
        model.requestSourceForget("a.rs"); let stalePolicy = try #require(model.pendingSourceForget)
        _ = try await adapter.perform(.setSources("peer", []))
        model.confirmSourceForget(stalePolicy); await model.waitForOperation()
        #expect(model.sourceRequiresRefresh && model.lastError == .sourceForgetUncertain)
        guard case .forgottenSources(let noMarkers) = try await adapter.perform(.forgottenSources("peer")) else { throw ServiceError.invalid }
        #expect(noMarkers.forgotten.isEmpty)
        _ = try await adapter.perform(.setSources("peer", ["a.rs"]))
        // Same-root ID reuse and replacement-root reuse cannot consume an old prompt.
        for root in [replacement.path, newRoot.path] {
            model.refreshSelected(); await model.waitForOperation(); model.inspectForgottenSources(); await model.waitForOperation()
            model.requestSourceForget("a.rs"); let stale = try #require(model.pendingSourceForget)
            guard case .string(let rootIdentity) = stale.project.root_identity, let incarnation = stale.project.incarnation else { throw ServiceError.invalid }
            _ = try await adapter.perform(.removeProject("peer", stale.project.root, rootIdentity, incarnation))
            _ = try await adapter.perform(.addProject("peer", root, ["a.rs"]))
            model.confirmSourceForget(stale); await model.waitForOperation()
            #expect(model.lastError == .sourceForgetUncertain && model.project == stale.project)
            guard case .project(let current) = try await adapter.perform(.project("peer")),
                  case .forgottenSources(let markers) = try await adapter.perform(.forgottenSources("peer")) else { throw ServiceError.invalid }
            #expect(current.sources == ["a.rs"] && current.incarnation != incarnation && markers.forgotten.isEmpty)
        }
        #expect(try Data(contentsOf: beta.appendingPathComponent("a.rs")) == other)
        await model.shutdown()
    }
}
