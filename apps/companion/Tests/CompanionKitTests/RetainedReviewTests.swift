import Darwin
import Foundation
import Testing
@testable import CompanionKit

/// Owned numeric-loopback test peer. Every socket is explicitly nonblocking;
/// accept/read/write/hold are bounded, and stop joins before closing the listener.
private final class RetainedReviewHTTP: @unchecked Sendable {
    private let lock = NSLock()
    private let group = DispatchGroup()
    private let listener: Int32
    private var stopping = false
    private var captured: Data?
    private var calls = 0
    private var finished = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var sawEOF = false
    private var listenerClosed = false
    let endpoint: String
    let mode: String
    init(_ mode: String) throws {
        self.mode = mode
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        self.listener = listener
        guard listener >= 0 else { throw ServiceError.unavailable }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(listener, 1) == 0, fcntl(listener, F_SETFL, O_NONBLOCK) == 0 else {
            close(listener); throw ServiceError.unavailable
        }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &length) }
        }
        guard named == 0 else { close(listener); throw ServiceError.unavailable }
        endpoint = "http://127.0.0.1:\(UInt16(bigEndian: address.sin_port))/v1/chat/completions"
        group.enter(); DispatchQueue.global().async { self.serve(); self.group.leave() }
    }
    private var stopRequested: Bool { lock.lock(); defer { lock.unlock() }; return stopping }
    var request: Data? { lock.lock(); defer { lock.unlock() }; return captured }
    var count: Int { lock.lock(); defer { lock.unlock() }; return calls }
    var socketClosed: Bool { lock.lock(); defer { lock.unlock() }; return sawEOF }
    func waitForRequest() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if captured != nil || finished { lock.unlock(); continuation.resume() }
            else { waiter = continuation; lock.unlock() }
        }
    }
    func stop() -> Bool {
        lock.lock(); stopping = true; lock.unlock()
        let joined = group.wait(timeout: .now() + 3) == .success
        if joined {
            lock.lock(); let shouldClose = !listenerClosed; listenerClosed = true; lock.unlock()
            if shouldClose { close(listener) }
        }; return joined
    }
    private func serve() {
        defer {
            lock.lock(); finished = true; let pending = waiter; waiter = nil; lock.unlock(); pending?.resume()
        }
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        func live() -> Bool { !stopRequested && ProcessInfo.processInfo.systemUptime < deadline }
        var fd: Int32 = -1
        while live() {
            fd = accept(listener, nil, nil)
            if fd >= 0 { break }; usleep(2_000)
        }
        guard fd >= 0 else { return }
        defer { close(fd) }
        guard fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else { return }
        var one: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size)) == 0 else { return }
        lock.lock(); calls += 1; lock.unlock()
        var bytes = Data(), body: Data?
        while live() && bytes.count <= 65536 {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let got = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
            if got > 0 { bytes.append(contentsOf: buffer.prefix(got)) }
            else if got == 0 { return }
            else if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { return }
            if let end = bytes.range(of: Data([13, 10, 13, 10])) {
                let header = String(decoding: bytes[..<end.lowerBound], as: UTF8.self)
                guard !header.lowercased().contains("authorization"),
                      let length = header.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("content-length:") })?.split(separator: ":").last,
                      let size = Int(length.trimmingCharacters(in: .whitespaces)), size <= 65536 else { return }
                if bytes.count >= end.upperBound + size { body = Data(bytes[end.upperBound..<(end.upperBound + size)]); break }
            }
            usleep(2_000)
        }
        guard let body else { return }
        lock.lock(); captured = body; let pending = waiter; waiter = nil; lock.unlock(); pending?.resume()
        if mode == "hold" {
            while live() {
                var byte: UInt8 = 0
                if Darwin.read(fd, &byte, 1) == 0 {
                    lock.lock(); sawEOF = true; lock.unlock(); return
                }
                usleep(2_000)
            }
            var byte: UInt8 = 0
            if Darwin.read(fd, &byte, 1) == 0 { lock.lock(); sawEOF = true; lock.unlock() }
            return
        }
        let brief: [String: Any] = ["objective": "Inspect synthetic source.", "output_expectations": "Suggest checks.", "unknowns": [String](), "questions": mode == "questions" ? ["Synthetic question?"] : [String]()]
        guard let prose = try? JSONSerialization.data(withJSONObject: brief),
              let reply = try? JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": "stop", "message": ["role": "assistant", "content": String(decoding: prose, as: UTF8.self)]]]]) else { return }
        let status = mode == "failure" ? "500 Internal Server Error" : "200 OK"
        let response = Data("HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(reply.count)\r\nConnection: close\r\n\r\n".utf8) + reply
        var offset = 0
        while live() && offset < response.count {
            let wrote = response.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!.advanced(by: offset), response.count - offset) }
            if wrote > 0 { offset += wrote }
            else if wrote < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { return }
            usleep(2_000)
        }
    }
}

@Suite("Retained Rust review native adapter")
struct RetainedReviewTests {
    private func reaped(_ pid: Int32) -> Bool {
        var status: Int32 = 0
        return waitpid(pid, &status, WNOHANG) == -1 && errno == ECHILD
    }

    @MainActor private func capture(_ adapter: ProcessService, endpoint: String) async throws -> (CompanionModel, RefinementConsent) {
        let model = CompanionModel(service: adapter, configured: true)
        let root = try #require(adapter.dataDirectory).deletingLastPathComponent()
        model.addProject(id: "alpha", root: root.path, sources: ["a.rs"]); await model.waitForOperation()
        model.build(); await model.waitForOperation()
        model.writeContext(id: "memo", kind: "note", text: "Synthetic human history", update: false); await model.waitForOperation()
        model.editPreparation(query: "fn", original: "Do NOT deploy e\u{301} 👋\n{\"cancel\":{}}")
        model.requestRefinement(settings: try refinementSettings(endpoint)); await model.waitForOperation()
        return (model, try #require(model.pendingRefinement))
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func actualPreviewEditStaleFreshExactRustValueAndHistory() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        try fixture.rewrite("fn synthetic_source() {}\n")
        let peer = try RetainedReviewHTTP("valid"); defer { #expect(peer.stop()) }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "retained-store")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        let (model, consent) = try await capture(adapter, endpoint: peer.endpoint)
        let history = model.history?.history.last?.text
        let controller = RetainedReviewController()
        await controller.synchronize(.init(consent: consent, configurationGeneration: 1))
        await controller.start(consent: consent, executable: URL(fileURLWithPath: binary), store: store)
        #expect(controller.state == .ready && peer.count == 1)
        let pid = try #require(controller.ownedPID), first = try #require(controller.challenge)
        await controller.edit(first, objective: "Synthetic edited objective", outputExpectations: "Synthetic edited checks")
        let next = try #require(controller.challenge), proposed = try #require(controller.proposed)
        #expect(next.revision == first.revision + 1 && next.digest != first.digest)
        await controller.usePrepared(first)
        #expect(controller.state == .reviewRequired && controller.challenge == next)
        await controller.usePrepared(next)
        guard case .approvedValue(let handoff) = controller.state else { Issue.record("Missing Rust handoff"); await controller.cancelAndJoin(); await model.shutdown(); return }
        #expect(handoff.text.utf8.elementsEqual(proposed.utf8) && handoff.delivery == "DeliveryNotAttempted")
        #expect(reaped(pid) && peer.count == 1 && peer.request != nil)
        #expect(model.originalDraft.utf8.elementsEqual(consent.original.utf8) && model.history?.history.last?.text == history)
        guard case .context(let persisted) = try await adapter.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(persisted.history.last?.text == "Synthetic human history" && persisted.history.count == 1)
        #expect(try String(contentsOf: fixture.root.appendingPathComponent("a.rs"), encoding: .utf8) == "fn synthetic_source() {}\n")
        for file in try FileManager.default.contentsOfDirectory(at: store, includingPropertiesForKeys: [.isRegularFileKey]) {
            if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                let bytes = try Data(contentsOf: file)
                #expect(bytes.range(of: Data(consent.original.utf8)) == nil)
                #expect(bytes.range(of: Data("Synthetic edited objective".utf8)) == nil)
            }
        }
        await controller.start(consent: consent, executable: URL(fileURLWithPath: binary), store: store)
        #expect(peer.count == 1) // Consumed confirmation cannot restart a call.
        await controller.cancelAndJoin(); await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func actualQuestionsFailureOriginalSourceAndNamespaceInvalidation() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        for mode in ["questions", "failure", "source", "namespace", "failure-source"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            try fixture.rewrite("fn synthetic_source() {}\n")
            let peer = try RetainedReviewHTTP(mode.hasPrefix("failure") ? "failure" : mode); defer { #expect(peer.stop()) }
            let store = try StoreSelection.newDirectory(parent: fixture.root, name: "retained-store")
            let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
            let (model, consent) = try await capture(adapter, endpoint: peer.endpoint)
            let controller = RetainedReviewController()
            await controller.synchronize(.init(consent: consent, configurationGeneration: 1))
            await controller.start(consent: consent, executable: URL(fileURLWithPath: binary), store: store)
            let pid = try #require(controller.ownedPID), challenge = try #require(controller.challenge)
            if mode == "questions" {
                #expect(controller.state == .needsInput && !controller.questions.isEmpty)
                await controller.edit(challenge, objective: "Synthetic edit", outputExpectations: "Synthetic checks")
                await controller.usePrepared(try #require(controller.challenge))
                #expect(controller.state == .reviewRequired && !controller.questions.isEmpty)
                await controller.cancelAndJoin()
            } else {
                if mode == "source" || mode == "failure-source" { try fixture.rewrite("fn changed_source() {}\n") }
                if mode == "namespace" {
                    let p = consent.project
                    guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
                    _ = try await adapter.perform(.removeProject(p.id, p.root, identity, token))
                    _ = try await adapter.perform(.addProject(p.id, p.root, p.sources)); _ = try await adapter.perform(.index(p.id))
                }
                await controller.useOriginal(challenge)
                if mode == "failure" {
                    guard case .approvedValue(let handoff) = controller.state else { Issue.record("Explicit original not returned"); await controller.cancelAndJoin(); await model.shutdown(); continue }
                    #expect(handoff.text.utf8.elementsEqual(consent.original.utf8))
                } else { #expect(controller.state == .failed && controller.challenge == nil) }
            }
            #expect(reaped(pid) && peer.count == 1 && model.originalDraft.utf8.elementsEqual(consent.original.utf8))
            await controller.cancelAndJoin(); await model.shutdown()
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func actualCancelDeadlineRebindAndNoLateAdoption() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        for action in ["cancel", "timeout", "rebind"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            try fixture.rewrite("fn synthetic_source() {}\n")
            let peer = try RetainedReviewHTTP("hold"); defer { #expect(peer.stop()) }
            let store = try StoreSelection.newDirectory(parent: fixture.root, name: "retained-store")
            let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
            let (model, consent) = try await capture(adapter, endpoint: peer.endpoint)
            let controller = RetainedReviewController()
            await controller.synchronize(.init(consent: consent, configurationGeneration: 1))
            let start = Task { await controller.start(consent: consent, executable: URL(fileURLWithPath: binary), store: store, seconds: action == "timeout" ? 0.4 : 10) }
            await peer.waitForRequest()
            let pid = try #require(controller.ownedPID)
            if action == "cancel" { await controller.cancelAndJoin() }
            if action == "rebind" { await controller.synchronize(nil) }
            await start.value
            #expect(reaped(pid) && peer.count == 1 && peer.request != nil)
            #expect(controller.state == (action == "rebind" ? .idle : (action == "cancel" ? .canceled : .failed)))
            #expect(controller.proposed == nil && controller.challenge == nil)
            // stop joins the server; EOF is observable before that join returns.
            #expect(peer.stop() && peer.socketClosed)
            await controller.cancelAndJoin(); await model.shutdown()
        }
    }

    @Test func frameEscapingAndClosedDecoders() throws {
        let original = "Synthetic\n{\"cancel\":{}}"
        let frame = try RetainedReviewCommand.capture(original).frame()
        #expect(frame.filter { $0 == 10 }.count == 1)
        let decoded = try #require(JSONSerialization.jsonObject(with: frame) as? [String: Any])
        #expect(decoded["original"] as? String == original)
        #expect(throws: (any Error).self) { _ = try RetainedReviewCommand.capture(String(repeating: "\n", count: 8192)).frame() }
    }

    private func syntheticConsent() throws -> RefinementConsent {
        let project = Project(id: "alpha", root: "/synthetic/alpha", sources: ["a.rs"],
            snapshot: .string(String(repeating: "a", count: 64)), rootIdentity: .string("r1"), incarnation: String(repeating: "b", count: 32))
        let settings = try refinementSettings()
        let selection = QueryReport(project: project.id, snapshot: project.snapshot, currentness: "current-at-read",
            coverage: .string("lexical-lines-only; no semantic coverage"), results: [])
        return RefinementConsent(id: UUID(), project: project, query: "synthetic", original: "Do NOT deploy synthetic.", settings: settings,
            profile: try settings.selectedProfile(), selection: selection, generation: 0, scopeRevision: 0)
    }

    @Test func strictEventSchemaAndNestedIdentity() throws {
        let consent = try syntheticConsent()
        let failure = "{\"version\":1,\"event\":\"failure\",\"terminal\":true,\"code\":\"Invalid\",\"delivery\":\"DeliveryNotAttempted\"}\n"
        _ = try RetainedReviewEvent.decode(Data(failure.utf8), consent: consent)
        for bad in [failure.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"ver\\u0073ion\":1"),
                    failure.replacingOccurrences(of: "\"Invalid\"", with: "\"Diagnostic text\""),
                    failure.replacingOccurrences(of: "\"failure\"", with: "\"approved\""),
                    failure.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"original\":\"extra\""),
                    failure.replacingOccurrences(of: "true", with: "false"), String(failure.dropLast()), failure + "{}\n"] {
            #expect(throws: (any Error).self) { try RetainedReviewEvent.decode(Data(bad.utf8), consent: consent) }
        }
        let payload: [String: Any] = ["version": 1, "event": "needsinput", "terminal": false,
            "delivery": "DeliveryNotAttempted", "downstream": "clipboard-draft-send-execution-not-attempted",
            "revision": 1, "digest": String(repeating: "a", count: 64), "code": NSNull(), "proposed": "Synthetic proposal",
            "changed": true, "editable": ["objective": "Synthetic", "output_expectations": "Checks"], "material_questions": [String](),
            "coverage": consent.selection.coverage.description,
            "provider": ["profile": consent.profile.id, "model": consent.profile.model, "endpoint": consent.profile.endpoint,
                "locality": "local", "max_calls": 1, "max_tokens": 1024, "deadline_seconds": 30, "output_byte_budget": 8192, "data_scope": "request-and-selected-evidence"]]
        func frame(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) + Data([10]) }
        _ = try RetainedReviewEvent.decode(frame(payload), consent: consent)
        for key in payload.keys {
            var bad = payload; bad.removeValue(forKey: key)
            #expect(throws: (any Error).self) { try RetainedReviewEvent.decode(frame(bad), consent: consent) }
        }
        for key in ["profile", "model", "endpoint", "locality", "data_scope", "max_calls", "max_tokens", "deadline_seconds", "output_byte_budget"] {
            var bad = payload, provider = try #require(payload["provider"] as? [String: Any])
            provider[key] = "wrong"; bad["provider"] = provider
            #expect(throws: (any Error).self) { try RetainedReviewEvent.decode(frame(bad), consent: consent) }
        }
        #expect(throws: (any Error).self) { try RetainedReviewEvent.decode(Data(repeating: 32, count: 8192) + Data([10]), consent: consent) }
    }

    @Test @MainActor func bindingChangesAndDefaultOffNeverStartChild() async throws {
        let consent = try syntheticConsent()
        let controller = RetainedReviewController()
        let project = consent.project
        for change in ["id", "original", "query", "project", "policy", "profile", "generation", "scope"] {
            var settings = consent.settings
            if change == "profile" { settings.enabled = false }
            let currentProject = Project(id: change == "project" ? "beta" : project.id, root: project.root,
                sources: change == "policy" ? [] : project.sources, snapshot: project.snapshot,
                rootIdentity: project.root_identity, incarnation: project.incarnation)
            await controller.synchronize(.init(consentID: change == "id" ? UUID() : consent.id, project: currentProject,
                original: change == "original" ? "Changed synthetic" : consent.original,
                query: change == "query" ? "different" : consent.query, settings: settings,
                generation: change == "generation" ? 1 : 0, scopeRevision: change == "scope" ? 1 : 0, configurationGeneration: 1))
            await controller.start(consent: consent, executable: URL(fileURLWithPath: "/nonexistent/synthetic"), store: URL(fileURLWithPath: "/nonexistent/store"))
            #expect(controller.state == .idle && controller.lastError == .invalid && controller.ownedLifetime == nil)
        }
        var disabled = consent.settings; disabled.enabled = false
        let denied = RefinementConsent(id: UUID(), project: consent.project, query: consent.query, original: consent.original,
            settings: disabled, profile: consent.profile, selection: consent.selection, generation: 0, scopeRevision: 0)
        #expect(throws: (any Error).self) { try denied.validate() }
        await controller.cancelAndJoin()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_RETAINED_FIXTURES"] != nil))
    func hostileChildEOFFramingDeadlineSingleQueueAndDeinitReap() async throws {
        let directory = try #require(ProcessInfo.processInfo.environment["THREADMARK_RETAINED_FIXTURES"])
        let consent = try syntheticConsent()
        for mode in ["malformed", "duplicate", "oversize", "unknown", "partial", "eof", "pipeclose", "idle", "hold", "deinit"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let store = fixture.root
            var driver: RetainedReviewProcess? = try RetainedReviewProcess(
                executable: URL(fileURLWithPath: directory).appendingPathComponent("retained-" + mode), store: store, consent: consent, seconds: 0.35)
            let completion = try #require(driver).completion
            if mode == "idle" || mode == "deinit" {
                let event = try await driver!.exchange(.capture(consent.original))
                #expect(event.code == "ProviderFailed" && !event.terminal)
                if mode == "deinit" { driver = nil }
            } else {
                do { _ = try await driver!.exchange(.capture(consent.original)); Issue.record("Hostile child accepted") }
                catch { #expect(error is ServiceError) }
            }
            let error = await completion.value
            #expect(error != nil)
            let marker = try String(contentsOf: store.appendingPathComponent("retained-fixture.pid"), encoding: .utf8)
            let pid = try #require(Int32(marker.trimmingCharacters(in: .whitespacesAndNewlines)))
            #expect(reaped(pid))
            await driver?.cancelAndJoin()
        }
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let driver = try RetainedReviewProcess(executable: URL(fileURLWithPath: directory).appendingPathComponent("retained-hold"),
            store: fixture.root, consent: consent, seconds: 2)
        // Competing commands fail closed regardless of which reaches the slot
        // first; neither transcript can turn this hostile child into approval.
        async let first: Void = expectFailure(driver, .capture(consent.original))
        async let second: Void = expectFailure(driver, .prepared(.init(revision: 1, digest: String(repeating: "a", count: 64))))
        _ = await (first, second)
        await driver.cancelAndJoin()
        if let pid = driver.pid { #expect(reaped(pid)) }
    }

    private func expectFailure(_ driver: RetainedReviewProcess, _ command: RetainedReviewCommand) async {
        do { _ = try await driver.exchange(command); Issue.record("Unexpected hostile child event") }
        catch { #expect(error is ServiceError) }
    }
}
