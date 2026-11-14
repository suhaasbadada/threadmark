import Darwin
import Foundation
import Testing
@testable import CompanionKit

private final class RankedSpawnReceipt: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int32?
    func record(_ pid: Int32) { lock.lock(); value = pid; lock.unlock() }
    var pid: Int32? { lock.lock(); defer { lock.unlock() }; return value }
}

/// One owned bounded numeric-loopback peer; no credentials or real provider.
private final class RankedRefinementPeer: @unchecked Sendable {
    private let lock = NSLock()
    private let group = DispatchGroup()
    private let fd: Int32
    private var stopping = false
    private var body: Data?
    private var waiter: CheckedContinuation<Void, Never>?
    private var finished = false
    let endpoint: String
    init(_ mode: String) throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        self.fd = fd
        guard fd >= 0 else { throw ServiceError.unavailable }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(fd, 1) == 0, fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else { close(fd); throw ServiceError.unavailable }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        endpoint = "http://127.0.0.1:\(UInt16(bigEndian: address.sin_port))/v1/chat/completions"
        group.enter(); DispatchQueue.global().async { self.serve(mode); self.group.leave() }
    }
    var request: Data? { lock.lock(); defer { lock.unlock() }; return body }
    private var stopped: Bool { lock.lock(); defer { lock.unlock() }; return stopping }
    func waitForRequest() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if body != nil || finished { lock.unlock(); continuation.resume() }
            else { waiter = continuation; lock.unlock() }
        }
    }
    func stop() -> Bool {
        lock.lock(); stopping = true; lock.unlock()
        let joined = group.wait(timeout: .now() + 3) == .success
        if joined { close(fd) }; return joined
    }
    private func serve(_ mode: String) {
        defer { lock.lock(); finished = true; let pending = waiter; waiter = nil; lock.unlock(); pending?.resume() }
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        func live() -> Bool { !stopped && ProcessInfo.processInfo.systemUptime < deadline }
        var client: Int32 = -1
        while live() { client = accept(fd, nil, nil); if client >= 0 { break }; usleep(2_000) }
        guard client >= 0 else { return }; defer { close(client) }
        guard fcntl(client, F_SETFL, O_NONBLOCK) == 0 else { return }
        var one: Int32 = 1
        guard setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size)) == 0 else { return }
        var bytes = Data(), captured: Data?
        while live() && bytes.count <= 65536 {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let count = buffer.withUnsafeMutableBytes { Darwin.read(client, $0.baseAddress, $0.count) }
            if count > 0 { bytes.append(contentsOf: buffer.prefix(count)) }
            else if count == 0 { return }
            else if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { return }
            if let end = bytes.range(of: Data([13, 10, 13, 10])) {
                let header = String(decoding: bytes[..<end.lowerBound], as: UTF8.self)
                guard !header.lowercased().contains("authorization"),
                      let sizeText = header.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("content-length:") })?.split(separator: ":").last,
                      let size = Int(sizeText.trimmingCharacters(in: .whitespaces)), size <= 65536 else { return }
                if bytes.count >= end.upperBound + size { captured = Data(bytes[end.upperBound..<(end.upperBound + size)]); break }
            }
            usleep(2_000)
        }
        guard let captured else { return }
        lock.lock(); body = captured; let pending = waiter; waiter = nil; lock.unlock(); pending?.resume()
        if mode == "hold" {
            while live() { var byte: UInt8 = 0; if Darwin.read(client, &byte, 1) == 0 { return }; usleep(2_000) }
            return
        }
        let brief: [String: Any] = ["objective": "Inspect synthetic source.", "output_expectations": "Suggest checks.", "unknowns": [String](), "questions": mode == "questions" ? ["Synthetic question?"] : []]
        guard let prose = try? JSONSerialization.data(withJSONObject: brief),
              let reply = try? JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": "stop", "message": ["role": "assistant", "content": String(decoding: prose, as: UTF8.self)]]]]) else { return }
        let response = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(reply.count)\r\nConnection: close\r\n\r\n".utf8) + reply
        var offset = 0
        while live() && offset < response.count {
            let count = response.withUnsafeBytes { Darwin.write(client, $0.baseAddress!.advanced(by: offset), response.count - offset) }
            if count > 0 { offset += count }
            else if count < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { return }
            usleep(2_000)
        }
    }
}

@Suite("Immutable ranked inference consent boundary", .serialized)
struct RankedRefinementTests {
    private func consent(_ project: Project, _ selection: QueryReport, _ endpoint: String,
                         query: String = "synthetic blue", mode: SourceRetrievalMode = .rankedTerms,
                         id: UUID = UUID()) throws -> RefinementConsent {
        let settings = try refinementSettings(endpoint)
        return RefinementConsent(id: id, project: project, query: query, original: "Do NOT deploy e\u{301} 👋\n{\"cancel\":{}}",
            settings: settings, profile: try settings.selectedProfile(), selection: selection,
            generation: 1, scopeRevision: 1, retrievalMode: mode)
    }
    private func reaped(_ pid: Int32) -> Bool {
        var status: Int32 = 0
        return waitpid(pid, &status, WNOHANG) == -1 && errno == ECHILD
    }

    @Test func grammarMatchesCoreAndRejectsBeforeStoreOrSpawn() throws {
        #expect(try RefinementConsent.rankedTerms(" BLUE blue\u{2003}Σ ΟΣ e\u{301} é ") == ["blue", "σ", "ος", "e\u{301}", "é"])
        for query in ["", "  ", "a\tb", "a\nb", "a\u{7f}", String(repeating: "é", count: 33), "a b c d e f g h i", String(repeating: "x", count: 257)] {
            #expect(throws: ServiceError.self) { try RefinementConsent.rankedTerms(query) }
        }
        let project = Project(id: "alpha", root: "/synthetic/alpha", sources: ["a.rs"], snapshot: .string(String(repeating: "a", count: 64)), rootIdentity: .string("r1"), incarnation: String(repeating: "b", count: 32))
        let selection = QueryReport(project: "alpha", snapshot: project.snapshot, currentness: "current-at-read", coverage: .string("synthetic"), results: [])
        let invalid = try consent(project, selection, "http://127.0.0.1:1/v1/chat/completions", query: "a\nb")
        #expect(throws: ServiceError.invalid) {
            _ = try RetainedReviewProcess(executable: URL(fileURLWithPath: "/absent/cli"), store: URL(fileURLWithPath: "/absent/store"), consent: invalid)
        }
        let old = RefinementConsent(id: UUID(), project: project, query: "synthetic", original: "Synthetic", settings: invalid.settings,
            profile: invalid.profile, selection: selection, generation: 0, scopeRevision: 0)
        try old.validate(); #expect(old.retrievalMode == .literal)
        #expect(RetainedReviewBinding(consent: old, configurationGeneration: 0).retrievalMode == .literal)
    }

    @Test @MainActor func exactBindingAndSelectionGuardsBeforeLaunch() async throws {
        let project = Project(id: "alpha", root: "/synthetic/alpha", sources: ["a.rs"], snapshot: .string(String(repeating: "a", count: 64)), rootIdentity: .string("r1"), incarnation: String(repeating: "b", count: 32))
        let selection = QueryReport(project: "alpha", snapshot: project.snapshot, currentness: "current-at-read",
            coverage: .string("indexed-source-lines-only; any-term literal text matches; no semantic/symbol coverage"), results: [],
            truncated: false, selection: "distinct-matched-terms-desc,total-nonoverlap-occurrences-desc,path-line-asc", terms: ["synthetic", "blue"])
        let captured = try consent(project, selection, "http://127.0.0.1:1/v1/chat/completions")
        try captured.validate()
        let binding = RetainedReviewBinding(consent: captured, configurationGeneration: 1)
        for change in ["mode", "original-bytes", "query", "settings", "scope", "generation", "config"] {
            var settings = captured.settings
            if change == "settings" { settings.enabled = false }
            let changed = RetainedReviewBinding(consentID: captured.id, project: project,
                original: change == "original-bytes" ? captured.original.replacingOccurrences(of: "e\u{301}", with: "é") : captured.original,
                query: change == "query" ? "SYNTHETIC blue" : captured.query, settings: settings,
                generation: change == "generation" ? 2 : 1, scopeRevision: change == "scope" ? 2 : 1,
                configurationGeneration: change == "config" ? 2 : 1, retrievalMode: change == "mode" ? .literal : .rankedTerms)
            #expect(changed != binding)
            if change != "config" { #expect(!changed.matches(captured)) }
            // Configuration belongs to the host generation, not the consent DTO.
        }
        for change in ["snapshot", "currentness", "terms", "coverage", "selection", "truncated"] {
            let wrong = QueryReport(project: "alpha", snapshot: change == "snapshot" ? .string(String(repeating: "c", count: 64)) : project.snapshot,
                currentness: change == "currentness" ? "stale-or-unindexed" : "current-at-read",
                coverage: change == "coverage" ? .string("semantic") : selection.coverage, results: [],
                truncated: change == "truncated" ? nil : false,
                selection: change == "selection" ? "bounded-path-line-prefix" : selection.selection,
                terms: change == "terms" ? ["different"] : selection.terms)
            #expect(throws: ServiceError.self) { try consent(project, wrong, captured.profile.endpoint).validate() }
        }
        let controller = RetainedReviewController()
        await controller.synchronize(binding)
        await controller.synchronize(nil)
        await controller.synchronize(binding)
        await controller.start(consent: captured, executable: URL(fileURLWithPath: "/absent/cli"), store: URL(fileURLWithPath: "/absent/store"))
        #expect(controller.state == .idle && controller.lastError == .invalid && controller.ownedLifetime == nil)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    func contextualLowercaseAndDeduplicationMatchActualCore() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        try fixture.rewrite("// synthetic ΟΣ ος οσ\n")
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary),
            dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "case-parity"))
        _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await adapter.perform(.index("alpha"))
        guard case .project(let project) = try await adapter.perform(.project("alpha")) else { throw ServiceError.invalid }
        for query in ["ΟΣ ος", "ΟΣ οσ", "Σ Σ", "AΣ AΣA", "Ο\u{301}Σ ο\u{301}ς", "Σ'Σ Σ'"] {
            guard case .query(let selected) = try await adapter.perform(.queryTermsBound(project, query)) else { throw ServiceError.invalid }
            let native = try RefinementConsent.rankedTerms(query), core = try #require(selected.terms)
            #expect(native.count == core.count && zip(native, core).allSatisfy { $0.utf8.elementsEqual($1.utf8) })
            try consent(project, selected, "http://127.0.0.1:1/v1/chat/completions", query: query).validate()
            if query == "ΟΣ ος" { #expect(core == ["ος"]) }
        }
    }

    @Test @MainActor func canonicallyEquivalentScopeBytesRevokeUnusedConsent() async throws {
        let project = Project(id: "alpha", root: "/synthetic/é", sources: ["é.rs"],
            snapshot: .string(String(repeating: "a", count: 64)), rootIdentity: .string("é"), incarnation: String(repeating: "b", count: 32))
        let selection = QueryReport(project: "alpha", snapshot: project.snapshot, currentness: "current-at-read",
            coverage: .string("indexed-source-lines-only; any-term literal text matches; no semantic/symbol coverage"), results: [],
            truncated: false, selection: "distinct-matched-terms-desc,total-nonoverlap-occurrences-desc,path-line-asc", terms: ["synthetic", "blue"])
        for change in ["root", "policy", "identity"] {
            let captured = try consent(project, selection, "http://127.0.0.1:1/v1/chat/completions")
            let binding = RetainedReviewBinding(consent: captured, configurationGeneration: 1)
            let changedProject = Project(id: project.id, root: change == "root" ? "/synthetic/e\u{301}" : project.root,
                sources: change == "policy" ? ["e\u{301}.rs"] : project.sources, snapshot: project.snapshot,
                rootIdentity: change == "identity" ? .string("e\u{301}") : project.root_identity, incarnation: project.incarnation)
            #expect(project == changedProject) // Swift equality is not the core's byte identity.
            let changed = RetainedReviewBinding(consentID: captured.id, project: changedProject, original: captured.original,
                query: captured.query, settings: captured.settings, generation: 1, scopeRevision: 1,
                configurationGeneration: 1, retrievalMode: .rankedTerms)
            #expect(binding != changed && !changed.matches(captured))
            let controller = RetainedReviewController()
            await controller.synchronize(binding); await controller.synchronize(changed); await controller.synchronize(binding)
            await controller.start(consent: captured, executable: URL(fileURLWithPath: "/absent/cli"), store: URL(fileURLWithPath: "/absent/store"))
            #expect(controller.lastError == .invalid && controller.ownedLifetime == nil && controller.state == .idle)
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func actualRankedReviewEditQuestionsCancelStaleAndFinitePreview() async throws {
        let binary = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"]))
        for action in ["edit", "questions", "cancel", "stale-before", "stale-after", "finite", "mode-back"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            try fixture.rewrite("// synthetic_gap_blue blue\n")
            let peer = try RankedRefinementPeer(action == "cancel" ? "hold" : action)
            defer { #expect(peer.stop()) }
            let store = try StoreSelection.newDirectory(parent: fixture.root, name: "ranked-refine-store")
            let adapter = ProcessService(executable: binary, dataDirectory: store)
            _ = try await adapter.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
            _ = try await adapter.perform(.index("alpha"))
            guard case .project(let project) = try await adapter.perform(.project("alpha")),
                  case .query(let literal) = try await adapter.perform(.queryBound(project, "synthetic blue")),
                  case .query(let selection) = try await adapter.perform(.queryTermsBound(project, "synthetic blue")) else { throw ServiceError.invalid }
            #expect(literal.results.isEmpty && selection.results.count == 1)
            let captured = try consent(project, selection, peer.endpoint); try captured.validate()
            // A ranked DTO cannot be passed off as literal, nor vice versa.
            #expect(throws: ServiceError.self) { try consent(project, selection, peer.endpoint, mode: .literal).validate() }
            #expect(throws: ServiceError.self) { try consent(project, literal, peer.endpoint).validate() }
            var wrong = selection; wrong.terms = ["different"]
            #expect(throws: ServiceError.self) { try consent(project, wrong, peer.endpoint).validate() }
            if action == "finite" {
                guard case .refinementPreview(let preview) = try await adapter.perform(.refinePreview(captured)) else { throw ServiceError.invalid }
                #expect(preview.state == "ready-for-review" && preview.coverage == captured.reviewCoverage)
                #expect(preview.original.utf8.elementsEqual(captured.original.utf8))
                var wire = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(preview)) as? [String: Any])
                let entries = try selection.results.enumerated().map { index, anchor -> [String: Any] in
                    var entry = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(anchor)) as? [String: Any])
                    entry["id"] = "source-\(index)"; return entry
                }
                wire["retrieval_mode"] = "ranked-terms"; wire["evidence"] = entries
                _ = try RefinementPreview.decode(JSONSerialization.data(withJSONObject: wire), consent: captured)
                for change in ["mode", "missing", "evidence", "unknown"] {
                    var bad = wire
                    if change == "mode" { bad["retrieval_mode"] = "literal" }
                    if change == "missing" { bad.removeValue(forKey: "retrieval_mode") }
                    if change == "evidence" { bad["evidence"] = [[String: Any]]() }
                    if change == "unknown" { bad["extra"] = "untrusted" }
                    #expect(throws: (any Error).self) { try RefinementPreview.decode(JSONSerialization.data(withJSONObject: bad), consent: captured) }
                }
            } else {
                let controller = RetainedReviewController()
                let binding = RetainedReviewBinding(consent: captured, configurationGeneration: 1)
                await controller.synchronize(binding)
                if action == "mode-back" {
                    await controller.synchronize(.init(consentID: captured.id, project: project, original: captured.original, query: captured.query,
                        settings: captured.settings, generation: 1, scopeRevision: 1, configurationGeneration: 1))
                    await controller.synchronize(binding)
                }
                if action == "stale-before" { try fixture.rewrite("// changed\n") }
                let spawned = RankedSpawnReceipt()
                let start = Task { await controller.start(consent: captured, executable: binary, store: store, seconds: 10, didSpawn: { spawned.record($0) }) }
                if action == "cancel" { await peer.waitForRequest(); await controller.cancelAndJoin() }
                await start.value
                if action == "mode-back" { #expect(controller.lastError == .invalid && peer.request == nil) }
                else if action == "stale-before" { #expect(controller.state == .failed && peer.request == nil) }
                else if action == "cancel" { #expect(controller.state == .canceled && controller.proposed == nil) }
                else {
                    let pid = try #require(controller.ownedPID), first = try #require(controller.challenge)
                    await controller.edit(first, objective: "Synthetic edited objective", outputExpectations: "Synthetic checks")
                    let fresh = try #require(controller.challenge), text = try #require(controller.proposed)
                    #expect(first != fresh && fresh.revision == first.revision + 1)
                    await controller.usePrepared(first); #expect(controller.state == .reviewRequired)
                    if action == "stale-after" {
                        try fixture.rewrite("// changed\n"); await controller.useOriginal(fresh)
                        #expect(controller.state == .failed)
                    } else {
                        await controller.usePrepared(fresh)
                        if action == "questions" {
                            #expect(controller.state == .reviewRequired && !controller.questions.isEmpty)
                            await controller.cancelAndJoin()
                        } else {
                            guard case .approvedValue(let handoff) = controller.state else { throw ServiceError.invalid }
                            #expect(handoff.text.utf8.elementsEqual(text.utf8))
                        }
                    }
                    #expect(reaped(pid))
                    await controller.synchronize(binding)
                    await controller.start(consent: captured, executable: binary, store: store)
                    #expect(controller.lastError == .invalid && controller.ownedLifetime == nil)
                }
                await controller.cancelAndJoin()
                if let pid = spawned.pid { #expect(reaped(pid)) }
            }
            if let request = peer.request {
                let envelope = try #require(JSONSerialization.jsonObject(with: request) as? [String: Any])
                let messages = try #require(envelope["messages"] as? [[String: Any]])
                let text = try #require(messages.last?["content"] as? String)
                let payload = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
                #expect((payload["original"] as? String)?.utf8.elementsEqual(captured.original.utf8) == true)
                let evidence = try #require(payload["evidence"] as? [[String: Any]])
                let anchor = try #require(evidence.first), expected = try #require(selection.results.first)
                #expect(evidence.count == 1 && anchor["path"] as? String == expected.path && anchor["text"] as? String == expected.text)
                #expect(anchor["source_hash"] as? String == expected.source_hash && anchor["producer"] as? String == expected.producer)
            }
            for file in try FileManager.default.contentsOfDirectory(at: store, includingPropertiesForKeys: [.isRegularFileKey]) {
                if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                    let data = try Data(contentsOf: file)
                    #expect(data.range(of: Data(captured.original.utf8)) == nil)
                    #expect(data.range(of: Data("Synthetic edited objective".utf8)) == nil)
                }
            }
        }
    }
}
