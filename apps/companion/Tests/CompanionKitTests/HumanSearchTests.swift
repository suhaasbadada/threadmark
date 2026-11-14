import Darwin
import Foundation
import Testing
@testable import CompanionKit

private let syntheticIncarnation = "0123456789abcdef0123456789abcdef"
private func searchPayload() -> [String: Any] {
    ["project": "alpha", "root_identity": "r1", "incarnation": syntheticIncarnation,
     "producer": "human-authored", "status": "active-latest-at-read",
     "authority": "context-not-authorization-or-observed-truth",
     "coverage": HumanContextSearch.coverageLabel, "selection": HumanContextSearch.selectionLabel,
     "matched_entries": 1, "omitted_entries": 0, "truncated": false,
     "results": [["id": "memo", "kind": "note", "revision": 1, "text": "Synthetic needle",
                  "producer": "human-authored", "status": "active"]]]
}
private func searchReceipt() throws -> HumanContextSearch {
    try HumanContextSearch.decode(JSONSerialization.data(withJSONObject: searchPayload()), project: "alpha")
}

private actor SearchCore: CoreService {
    var project = Project(id: "alpha", root: "/synthetic/alpha", sources: ["a.rs"], rootIdentity: .string("r1"), incarnation: syntheticIncarnation)
    var mode = "valid"
    var calls = 0
    var held: CheckedContinuation<Void, Never>?
    var started: CheckedContinuation<Void, Never>?
    var didStart = false
    func setMode(_ mode: String) { self.mode = mode }
    func holdNext() { mode = "hold"; didStart = false }
    func legacy() { project = Project(id: project.id, root: project.root, sources: project.sources, rootIdentity: project.root_identity) }
    func waitForSearch() async {
        if didStart { return }
        await withCheckedContinuation { started = $0 }
    }
    func release() { held?.resume(); held = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        switch operation {
        case .project: return .project(project)
        case .contexts: return .contexts(ContextList(project: "alpha", contexts: []))
        case .context(_, let id):
            return .context(ContextHistory(project: "alpha", id: id, producer: "human-authored", authority: .string("human-declared"), history: []))
        case .searchHumanContext:
            calls += 1; didStart = true; started?.resume(); started = nil
            if mode == "hold" { await withCheckedContinuation { held = $0 } }
            if mode == "error" { throw ServiceError.failed }
            if mode == "unknown" { return .acknowledged }
            if mode == "replace" {
                project = Project(id: project.id, root: project.root, sources: project.sources,
                                  rootIdentity: project.root_identity, incarnation: String(repeating: "f", count: 32))
            }
            if mode == "receipt" {
                var data = searchPayload(); data["root_identity"] = "other"
                return .humanContextSearch(try JSONDecoder().decode(HumanContextSearch.self, from: JSONSerialization.data(withJSONObject: data)))
            }
            return .humanContextSearch(try searchReceipt())
        default: throw ServiceError.unavailable
        }
    }
}

@Suite("Native human-only search contract")
struct HumanSearchTests {
    @Test func inputMatchesActualCoreBounds() {
        for text in ["", " \u{2003}", "a\n", "a\t", "a\0", "a\u{0085}", String(repeating: "é", count: 129)] {
            #expect(!InputPolicy.humanSearch(text))
        }
        for text in [" needle ", "\u{2003}needle\u{2003}", String(repeating: "é", count: 128)] {
            #expect(InputPolicy.humanSearch(text))
        }
    }
    @Test func closedPayloadBoundsAndProvenanceFailClosed() throws {
        let valid = try searchReceipt(); try valid.validate(project: "alpha")
        for key in ["project", "root_identity", "incarnation", "producer", "status", "authority", "coverage", "selection", "matched_entries", "omitted_entries", "truncated", "results"] {
            var payload = searchPayload(); payload.removeValue(forKey: key)
            #expect(throws: (any Error).self) { try HumanContextSearch.decode(JSONSerialization.data(withJSONObject: payload), project: "alpha") }
        }
        for (key, value): (String, Any) in [
            ("project", "beta"), ("producer", "source"), ("status", "current-at-read"),
            ("authority", "verified"), ("coverage", "complete"), ("selection", "prefix"),
            ("matched_entries", -1), ("matched_entries", 4097), ("omitted_entries", 1),
            ("truncated", true), ("incarnation", "invalid"), ("source_hash", "unexpected")
        ] {
            var payload = searchPayload(); payload[key] = value
            #expect(throws: (any Error).self) { try HumanContextSearch.decode(JSONSerialization.data(withJSONObject: payload), project: "alpha") }
        }
        let entry = try #require((searchPayload()["results"] as? [[String: Any]])?.first)
        for (key, value): (String, Any) in [
            ("id", "../bad"), ("kind", "rule"), ("revision", 0), ("revision", 33),
            ("text", ""), ("text", "a\0"), ("text", String(repeating: "é", count: 2049)),
            ("producer", "source"), ("status", "retired"), ("source_hash", "unexpected")
        ] {
            var bad = entry; bad[key] = value
            var payload = searchPayload(); payload["results"] = [bad]
            #expect(throws: (any Error).self) { try HumanContextSearch.decode(JSONSerialization.data(withJSONObject: payload), project: "alpha") }
        }
        for count in [2, 9] {
            var payload = searchPayload(); payload["results"] = Array(repeating: entry, count: count); payload["matched_entries"] = count
            #expect(throws: (any Error).self) { try HumanContextSearch.decode(JSONSerialization.data(withJSONObject: payload), project: "alpha") }
        }
        var eight = searchPayload()
        eight["results"] = (0..<8).map { n -> [String: Any] in var e = entry; e["id"] = "memo-\(n)"; return e }
        eight["matched_entries"] = 8
        _ = try HumanContextSearch.decode(JSONSerialization.data(withJSONObject: eight), project: "alpha")
        eight["results"] = (0..<8).map { n -> [String: Any] in
            var e = entry; e["id"] = "memo-\(n)"; e["text"] = String(repeating: "\"", count: 1000); return e
        }
        let overBudget = try JSONDecoder().decode(HumanContextSearch.self, from: JSONSerialization.data(withJSONObject: eight))
        #expect(throws: ServiceError.outputLimit) { try overBudget.validate(project: "alpha") }
        var omitted = searchPayload(); omitted["results"] = []; omitted["omitted_entries"] = 1; omitted["truncated"] = true
        _ = try HumanContextSearch.decode(JSONSerialization.data(withJSONObject: omitted), project: "alpha")
        #expect(throws: ServiceError.outputLimit) { try HumanContextSearch.decode(Data(repeating: 32, count: 8193), project: "alpha") }
    }
    @Test @MainActor func namespaceErrorsRecoveryAndDraftPreservation() async throws {
        let core = SearchCore()
        let selected = CompanionModel(service: core, configured: true)
        selected.select("alpha"); await selected.waitForOperation()
        selected.editPreparation(query: "source", original: "Synthetic unsaved original")
        let editor = selected.contextEditorRevision
        selected.searchHumanContext("needle"); await selected.waitForOperation()
        #expect(selected.humanSearch?.results.first?.id == "memo")
        #expect(selected.originalDraft == "Synthetic unsaved original" && selected.contextEditorRevision == editor)
        selected.inspectHumanSearchEntry("memo"); await selected.waitForOperation()
        #expect(selected.history?.id == "memo" && selected.contextEditorRevision == editor)
        #expect(selected.originalDraft == "Synthetic unsaved original")
        for mode in ["error", "unknown"] {
            await core.setMode(mode); selected.searchHumanContext("needle"); await selected.waitForOperation()
            #expect(selected.humanSearch == nil && selected.lastError != nil)
            #expect(selected.originalDraft == "Synthetic unsaved original" && selected.contextEditorRevision == editor)
        }
        await core.setMode("valid"); selected.searchHumanContext("needle"); await selected.waitForOperation()
        #expect(selected.humanSearch != nil)
        selected.stageSources([])
        #expect(selected.humanSearch == nil && selected.originalDraft == "Synthetic unsaved original" && selected.contextEditorRevision == editor)
        await selected.shutdown()
    }
    @Test(arguments: ["replace", "receipt"]) @MainActor func replacementAndReceiptBindingCannotPublish(mode: String) async {
        let core = SearchCore()
        let selected = CompanionModel(service: core, configured: true)
        selected.select("alpha"); await selected.waitForOperation()
        await core.setMode(mode); selected.searchHumanContext("needle"); await selected.waitForOperation()
        #expect(selected.humanSearch == nil && selected.project == nil && selected.lastError == .namespaceChanged)
        await selected.shutdown()
    }
    @Test @MainActor func canceledLateResultAndSupersedingSearchAreJoined() async throws {
        let core = SearchCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        await core.setMode("hold"); model.searchHumanContext("needle"); await core.waitForSearch()
        model.cancel()
        #expect(model.humanSearch == nil && model.status.contains("joining"))
        await core.release(); await model.waitForOperation()
        #expect(model.humanSearch == nil && model.status.contains("joined"))
        await core.setMode("valid"); model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(model.humanSearch != nil)
        model.humanSearchQueryChanged(); #expect(model.humanSearch == nil)
        await core.holdNext(); model.searchHumanContext("needle"); await core.waitForSearch()
        let calls = await core.calls
        await core.setMode("valid"); model.searchHumanContext("replacement needle")
        #expect(await core.calls == calls) // Replacement cannot overtake an ignoring worker.
        await core.release(); await model.waitForOperation()
        #expect(await core.calls == calls + 1 && model.humanSearch != nil)
        await model.shutdown()
    }
    @Test(arguments: ["project", "configure", "sources", "quit"]) @MainActor
    func lateSearchCannotSurviveLifecycleInvalidation(action: String) async {
        let core = SearchCore(), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        await core.holdNext(); model.searchHumanContext("needle"); await core.waitForSearch()
        switch action {
        case "project": model.select(nil)
        case "configure": model.configure(executable: URL(fileURLWithPath: "/synthetic/unavailable"), dataDirectory: URL(fileURLWithPath: "/synthetic/store"))
        case "sources": model.stageSources([])
        default: model.quit()
        }
        let lifecycleStatus = model.status
        await core.release(); await model.waitForOperation()
        #expect(model.humanSearch == nil && model.status == lifecycleStatus)
        await model.shutdown()
    }
    @Test @MainActor func legacyNamespaceNeverDispatchesSearch() async {
        let core = SearchCore(); await core.legacy()
        let model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        #expect(!model.canSearchHumanContext)
        model.searchHumanContext("needle"); await model.waitForOperation()
        #expect(await core.calls == 0 && model.humanSearch == nil)
        await model.shutdown()
    }

    @Test func actualProcessArgvEmptyStdinEnvironmentAndFailures() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let executable = fixture.root.appendingPathComponent("search-fixture.py")
        let payload = try JSONSerialization.data(withJSONObject: searchPayload(), options: [.sortedKeys])
        let body = """
        #!/usr/bin/python3
        import os, sys
        assert sys.argv[1:] == ['--data-dir', os.getcwd(), 'context', 'search', 'alpha', ' needle ']
        assert sys.stdin.buffer.read() == b''
        # Apple's /usr/bin/python3 shim adds only toolchain metadata after spawn.
        assert set(os.environ) <= {'LANG', 'LC_ALL', 'LC_CTYPE', 'CPATH', 'LIBRARY_PATH', 'MANPATH', 'SDKROOT', '__CF_USER_TEXT_ENCODING'}
        sys.stdout.buffer.write(bytes.fromhex('\(payload.map { String(format: "%02x", $0) }.joined())') + b'\\n')
        """
        try Data(body.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let service = ProcessService(executable: executable, dataDirectory: fixture.root)
        guard case .humanContextSearch(let result) = try await service.perform(.searchHumanContext("alpha", " needle ")) else { throw ServiceError.invalid }
        #expect(result.results.first?.text == "Synthetic needle")
        for output in ["{}", "unknown", String(repeating: "x", count: 8193)] {
            try Data(("#!/usr/bin/python3\nimport sys\nsys.stdout.write(" + String(reflecting: output) + ")\n").utf8).write(to: executable)
            await #expect(throws: (any Error).self) { try await service.perform(.searchHumanContext("alpha", "needle")) }
        }
        try Data("#!/usr/bin/python3\nimport os,time\nopen('child.pid','w').write(str(os.getpid()))\ntime.sleep(10)\n".utf8).write(to: executable)
        var limits = ProcessLimits(); limits.seconds = 0.05
        await #expect(throws: ServiceError.timedOut) {
            try await ProcessService(executable: executable, dataDirectory: fixture.root, limits: limits).perform(.searchHumanContext("alpha", "needle"))
        }
        let timedOutPID = try #require(Int32(String(contentsOf: fixture.root.appendingPathComponent("child.pid"), encoding: .utf8)))
        #expect(kill(timedOutPID, 0) == -1 && errno == ESRCH)
        let task = Task { try await service.perform(.searchHumanContext("alpha", "needle")) }
        try await Task.sleep(for: .milliseconds(50)); task.cancel()
        await #expect(throws: ServiceError.canceled) { try await task.value }
        let canceledPID = try #require(Int32(String(contentsOf: fixture.root.appendingPathComponent("child.pid"), encoding: .utf8)))
        #expect(kill(canceledPID, 0) == -1 && errno == ESRCH)
    }
}
