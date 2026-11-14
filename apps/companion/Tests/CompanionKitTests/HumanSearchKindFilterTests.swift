import Foundation
import Testing
@testable import CompanionKit

private let filterProject = Project(id: "alpha", root: "/synthetic/alpha", sources: [], rootIdentity: .string("r1"), incarnation: String(repeating: "a", count: 32))
private func filterRequest(_ kinds: [String] = ["note"]) throws -> HumanSearchKindRequest {
    try HumanSearchKindRequest(binding: HumanContextReadBinding(project: filterProject), query: "needle", kinds: kinds)
}
private func filterPayload(_ request: HumanSearchKindRequest) -> [String: Any] {
    ["version": "human-search-kind-filter-v1", "selected_kinds": request.kinds,
     "project": request.binding.project, "root_identity": request.binding.rootIdentity, "incarnation": request.binding.incarnation,
     "producer": "human-authored", "status": "active-latest-at-read", "authority": "context-not-authorization-or-observed-truth",
     "coverage": HumanContextSearch.coverageLabel, "selection": HumanContextSearch.selectionLabel,
     "matched_entries": 1, "omitted_entries": 0, "truncated": false,
     "results": [["id": "memo", "kind": request.kinds[0], "revision": 1, "text": "Synthetic needle", "producer": "human-authored", "status": "active"]]]
}
private func frame(_ payload: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) + Data([10])
}

private actor FilterCore: CoreService {
    var calls = 0, searches = 0, oldSearches = 0
    var mode = "valid", didStart = false
    var held: CheckedContinuation<Void, Never>?, started: CheckedContinuation<Void, Never>?
    var requests: [[String]] = []
    func setMode(_ mode: String) { self.mode = mode; didStart = false }
    func waitForSearch() async { if !didStart { await withCheckedContinuation { started = $0 } } }
    func release() { held?.resume(); held = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        calls += 1
        switch operation {
        case .project: return .project(filterProject)
        case .contextsBound: return .contexts(ContextList(project: "alpha", contexts: []))
        case .contextBound(_, let id):
            return .context(ContextHistory(project: "alpha", id: id, producer: "human-authored", authority: .string("context-not-authorization-or-observed-truth"), history: [ContextRevision(revision: 1, kind: "note", text: "Synthetic retained history", retired: false)]))
        case .searchHumanContextKindsBound(let request):
            searches += 1; requests.append(request.kinds); didStart = true; started?.resume(); started = nil
            let capturedMode = mode
            if capturedMode == "hold" { await withCheckedContinuation { held = $0 } }
            if capturedMode == "error" { throw ServiceError.failed }
            if capturedMode == "unknown" { return .acknowledged }
            let decodedRequest = capturedMode == "wrong-filter" ? try filterRequest(["constraint"]) : request
            return .filteredHumanSearch(try FilteredHumanSearch.decode(frame(filterPayload(decodedRequest)), request: decodedRequest))
        case .searchHumanContextBound, .searchHumanContext:
            oldSearches += 1; throw ServiceError.invalid
        default: throw ServiceError.unavailable
        }
    }
}

@Suite("Explicit human kind filter")
struct HumanSearchKindFilterTests {
    @Test func ae06StrictClosedDuplicateRejectingFrame() throws {
        let request = try filterRequest(["note", "decision"])
        #expect(request.kinds == ["decision", "note"])
        let valid = try frame(filterPayload(request))
        let result = try FilteredHumanSearch.decode(valid, request: request)
        try result.validate(request: request, scope: filterProject)
        for kinds in [[], ["note", "note"], ["unknown"], [""], Array(repeating: "note", count: 6)] {
            #expect(throws: (any Error).self) { try filterRequest(kinds) }
        }
        for (key, value): (String, Any) in [("version", "old"), ("selected_kinds", ["note"]), ("selected_kinds", ["note", "decision"]), ("selected_kinds", ["decision", "decision"]), ("project", "other"), ("root_identity", "other"), ("incarnation", String(repeating: "b", count: 32)), ("extra", true), ("matched_entries", true), ("truncated", 0)] {
            var payload = filterPayload(request); payload[key] = value
            #expect(throws: (any Error).self) { try FilteredHumanSearch.decode(frame(payload), request: request) }
        }
        for key in filterPayload(request).keys {
            var payload = filterPayload(request); payload.removeValue(forKey: key)
            #expect(throws: (any Error).self) { try FilteredHumanSearch.decode(frame(payload), request: request) }
        }
        var wrongKind = filterPayload(request)
        var entries = try #require(wrongKind["results"] as? [[String: Any]])
        entries[0]["kind"] = "constraint"; wrongKind["results"] = entries
        #expect(throws: (any Error).self) { try FilteredHumanSearch.decode(frame(wrongKind), request: request) }
        let text = String(decoding: valid, as: UTF8.self)
        for bad in [Data(valid.dropLast()), Data(valid.prefix(20)), valid + valid,
                    Data(text.replacingOccurrences(of: "\"version\":", with: "\"version\":\"human-search-kind-filter-v1\",\"ver\\u0073ion\":").utf8),
                    Data(text.replacingOccurrences(of: "\"kind\":", with: "\"kind\":\"note\",\"kind\":").utf8)] {
            #expect(throws: (any Error).self) { try FilteredHumanSearch.decode(bad, request: request) }
        }
        let exact = Data(valid.dropLast()) + Data(repeating: 32, count: 8192 - valid.count) + Data([10])
        #expect(exact.count == 8192)
        _ = try FilteredHumanSearch.decode(exact, request: request)
        #expect(throws: ServiceError.outputLimit) { try FilteredHumanSearch.decode(exact + Data([10]), request: request) }
        #expect(throws: (any Error).self) { try result.validate(request: filterRequest(["note"]), scope: filterProject) }
        var slashPayload = filterPayload(request)
        slashPayload["matched_entries"] = 2
        slashPayload["results"] = ["a", "b"].map { id in
            ["id": id, "kind": "note", "revision": 1, "text": "needle" + String(repeating: "/", count: 3400), "producer": "human-authored", "status": "active"] as [String: Any]
        }
        let slashFrame = try JSONSerialization.data(withJSONObject: slashPayload, options: [.withoutEscapingSlashes]) + Data([10])
        #expect(slashFrame.count < 8192)
        _ = try FilteredHumanSearch.decode(slashFrame, request: request)
        let forged = FilteredHumanSearch(selectedKinds: ["note"], search: result.search, bytes: valid)
        #expect(throws: (any Error).self) { try forged.validate(request: request, scope: filterProject) }
    }

    @Test @MainActor func ae05ChoiceZeroIOAndLateAJoinsBeforeBPreservesHumanState() async throws {
        let core = FilterCore()
        let selected = CompanionModel(service: core, configured: true)
        _ = HumanContextSearchView(model: selected)
        #expect(selected.humanSearchKindFilter == nil)
        #expect(await core.calls == 0)
        selected.select("alpha"); await selected.waitForOperation()
        selected.openContext("memo"); await selected.waitForOperation()
        selected.editPreparation(query: "source", original: "Synthetic unsaved original")
        let base = try #require(selected.humanContextRevisionBinding("memo")), editor = selected.contextEditorRevision
        let before = await core.calls
        selected.setHumanSearchKindFilter(["note"])
        #expect(await core.calls == before)
        await core.setMode("hold"); selected.searchHumanContext("needle"); await core.waitForSearch()
        selected.setHumanSearchKindFilter(["decision"])
        let calls = await core.calls
        #expect(selected.humanSearch == nil && selected.humanSearchSelectedKinds == nil)
        await core.setMode("valid"); selected.searchHumanContext("needle")
        #expect(await core.calls == calls)
        await core.release(); await selected.waitForOperation()
        #expect(await core.requests == [["note"], ["decision"]])
        #expect(selected.humanSearchSelectedKinds == ["decision"])
        #expect(selected.humanSearch?.results.first?.kind == "decision")
        #expect(selected.history?.id == "memo" && selected.humanContextRevisionBinding("memo") == base)
        #expect(selected.contextEditorRevision == editor && selected.originalDraft == "Synthetic unsaved original")
        for mode in ["error", "unknown", "wrong-filter"] {
            await core.setMode(mode); selected.searchHumanContext("needle"); await selected.waitForOperation()
            #expect(selected.humanSearch == nil && selected.lastError != nil)
            #expect(selected.history?.id == "memo" && selected.humanContextRevisionBinding("memo") == base)
            #expect(selected.contextEditorRevision == editor && selected.originalDraft == "Synthetic unsaved original")
        }
        #expect(await core.oldSearches == 0)
        let after = await core.calls
        selected.setHumanSearchKindFilter([]); selected.searchHumanContext("needle"); await selected.waitForOperation()
        #expect(await core.calls == after)
        await selected.shutdown()
    }

    @Test(arguments: ["cancel", "selection", "configuration", "quit"]) @MainActor
    func ae05LifecycleNoLateAdoption(action: String) async {
        let core = FilterCore()
        let selected = CompanionModel(service: core, configured: true)
        selected.select("alpha"); await selected.waitForOperation(); selected.setHumanSearchKindFilter(["note"])
        await core.setMode("hold"); selected.searchHumanContext("needle"); await core.waitForSearch()
        switch action {
        case "cancel": selected.cancel()
        case "selection": selected.select(nil)
        case "configuration": selected.configure(executable: URL(fileURLWithPath: "/synthetic/unavailable"), dataDirectory: URL(fileURLWithPath: "/synthetic/store"))
        default: selected.quit()
        }
        await core.release(); await selected.waitForOperation()
        #expect(selected.humanSearch == nil && selected.humanSearchSelectedKinds == nil)
        #expect(await core.oldSearches == 0)
        await selected.shutdown()
    }

    @Test func ae06ActualProcessClosedArgvEmptyStdinAndStrictFrame() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let executable = fixture.root.appendingPathComponent("filtered.py")
        let request = try filterRequest(["note", "decision"]), bytes = try frame(filterPayload(filterRequest(["note", "decision"])))
        let body = """
        #!/usr/bin/python3
        import os,sys
        assert sys.argv[1:] == ['--data-dir', os.getcwd(), 'context', 'search', 'alpha', 'needle', '--kinds', 'decision', 'note', '--expected-root', '/synthetic/alpha', '--expected-root-identity', 'r1', '--expected-incarnation', '\(request.binding.incarnation)']
        assert sys.stdin.buffer.read() == b''
        sys.stdout.buffer.write(bytes.fromhex('\(bytes.map { String(format: "%02x", $0) }.joined())'))
        """
        try Data(body.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let service = ProcessService(executable: executable, dataDirectory: fixture.root)
        guard case .filteredHumanSearch(let result) = try await service.perform(.searchHumanContextKindsBound(request)) else { throw ServiceError.invalid }
        #expect(result.selectedKinds == ["decision", "note"])
        for output in ["{}\n", String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "decision", with: "constraint"), String(repeating: "x", count: 8193)] {
            try Data(("#!/usr/bin/python3\nimport sys\nsys.stdout.write(" + String(reflecting: output) + ")\n").utf8).write(to: executable)
            await #expect(throws: (any Error).self) { try await service.perform(.searchHumanContextKindsBound(request)) }
        }
    }
}
