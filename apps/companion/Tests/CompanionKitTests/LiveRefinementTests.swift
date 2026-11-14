import Darwin
import Foundation
import Testing
@testable import CompanionKit

/// Test-only, numeric-loopback HTTP peer; one bounded request, no production fake.
private final class RefinementHTTPFixture: @unchecked Sendable {
    private let lock = NSLock()
    private var stopping = false
    private var request: Data?
    private var connections = 0
    private var finished = false
    private var requestWaiter: CheckedContinuation<Void, Never>?
    private let group = DispatchGroup()
    private let listener: Int32
    let endpoint: String
    let mode: String
    init(mode: String) throws {
        self.mode = mode
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        self.listener = listener
        guard listener >= 0 else { throw ServiceError.unavailable }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1"); address.sin_port = 0
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
        group.enter()
        DispatchQueue.global().async { self.serve(); self.group.leave() }
    }
    private var shouldStop: Bool { lock.lock(); defer { lock.unlock() }; return stopping }
    func captured() -> Data? { lock.lock(); defer { lock.unlock() }; return request }
    func connectionCount() -> Int { lock.lock(); defer { lock.unlock() }; return connections }
    func waitForRequest() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if request != nil || finished { lock.unlock(); continuation.resume() }
            else { requestWaiter = continuation; lock.unlock() }
        }
    }
    func stop() -> Bool {
        lock.lock(); stopping = true; lock.unlock()
        let joined = group.wait(timeout: .now() + 5) == .success
        if joined { close(listener) }
        return joined
    }
    private func serve() {
        defer {
            lock.lock(); finished = true; let waiter = requestWaiter; requestWaiter = nil; lock.unlock()
            waiter?.resume() // Also bound failed/no-request waits to the fixture deadline.
        }
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        var fd: Int32 = -1
        while !shouldStop && ProcessInfo.processInfo.systemUptime < deadline {
            fd = accept(listener, nil, nil)
            if fd >= 0 { break }
            if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { return }
            usleep(2_000)
        }
        guard fd >= 0 else { return }
        lock.lock(); connections += 1; lock.unlock()
        defer { close(fd) }
        _ = fcntl(fd, F_SETFL, 0) // Accepted sockets can inherit O_NONBLOCK on macOS.
        var timeout = timeval(tv_sec: 2, tv_usec: 0), one: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        _ = setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        var header = Data()
        while header.count < 4096 && !header.suffix(4).elementsEqual([13, 10, 13, 10]) {
            var byte: UInt8 = 0
            guard Darwin.read(fd, &byte, 1) == 1 else { return }; header.append(byte)
        }
        let headerText = String(decoding: header, as: UTF8.self)
        guard headerText.hasPrefix("POST /v1/chat/completions HTTP/1.1\r\n"),
              !headerText.lowercased().contains("authorization"),
              let lengthText = headerText.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("content-length:") })?.split(separator: ":").last,
              let count = Int(lengthText.trimmingCharacters(in: .whitespaces)), count <= 65536 else { return }
        var body = Data()
        while body.count < count {
            var buffer = [UInt8](repeating: 0, count: min(4096, count - body.count))
            let got = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
            guard got > 0 else { return }; body.append(contentsOf: buffer.prefix(got))
        }
        lock.lock(); request = body; let waiter = requestWaiter; requestWaiter = nil; lock.unlock()
        waiter?.resume()
        if mode == "hold" {
            while !shouldStop && ProcessInfo.processInfo.systemUptime < deadline { usleep(2_000) }
        }
        let content: [String: Any] = ["objective": "Inspect synthetic source without deployment.", "output_expectations": "Propose checks, not execution.", "unknowns": [String](), "questions": mode == "questions" ? ["Synthetic material question?"] : []]
        guard let proposal = try? JSONSerialization.data(withJSONObject: content),
              let payload = try? JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": "stop", "message": ["role": "assistant", "content": String(decoding: proposal, as: UTF8.self)]]]]) else { return }
        let reply: Data
        if mode == "malformed" { reply = Data("{not-json}".utf8) }
        else if mode == "duplicate" { reply = Data("{\"choices\":[],\"choices\":[]}".utf8) }
        else { reply = payload }
        let status = mode == "error" ? "500 Internal Server Error" : "200 OK"
        let response = Data("HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(reply.count)\r\nConnection: close\r\n\r\n".utf8) + reply
        response.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let sent = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if sent <= 0 { break }; offset += sent
            }
        }
    }
}

@Suite("Actual CLI SQLite local refinement HTTP preview")
struct LiveRefinementTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func actualOwnedChildTimeoutCancelAndProfileChangeJoinWithoutAdoption() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        for action in ["timeout", "cancel", "profile"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            try fixture.rewrite("fn synthetic_source() {}\n")
            let peer = try RefinementHTTPFixture(mode: "hold"); defer { #expect(peer.stop()) }
            var limits = ProcessLimits(); limits.seconds = 0.5
            let adapter = ProcessService(executable: URL(fileURLWithPath: binary),
                dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "refine-store"), limits: limits)
            let model = CompanionModel(service: adapter, configured: true)
            let session = CompanionProviderSession { model.dismissPreview() }
            model.addProject(id: "alpha", root: fixture.root.path, sources: ["a.rs"]); await model.waitForOperation()
            model.build(); await model.waitForOperation()
            model.editPreparation(query: "fn", original: "Do NOT deploy e\u{301} 👋")
            session.update(try refinementSettings(peer.endpoint)) // Identity change forces off first.
            var enabled = session.settings; enabled.enabled = true; session.update(enabled)
            model.requestRefinement(settings: session.settings); await model.waitForOperation()
            model.confirmRefinement(try #require(model.pendingRefinement), settings: session.settings)
            await peer.waitForRequest()
            #expect(peer.captured() != nil && peer.connectionCount() == 1)
            if action == "cancel" { model.cancelRefinement() }
            if action == "profile" {
                var changed = session.settings; changed.profiles[0].model = "different-model"; session.update(changed)
            }
            await model.waitForOperation() // Joins the actual killed/reaped CLI, not a detached owner.
            #expect(model.refinementPreview == nil && model.originalDraft == "Do NOT deploy e\u{301} 👋")
            if action == "timeout" { #expect(model.lastError == .timedOut) }
            await model.shutdown()
        }
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func actualConsentPreviewQuestionsAndProviderRejections() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        for mode in ["valid", "questions", "malformed", "duplicate", "error"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            try fixture.rewrite("fn synthetic_source() {}\n")
            let peer = try RefinementHTTPFixture(mode: mode); defer { #expect(peer.stop()) }
            let store = try StoreSelection.newDirectory(parent: fixture.root, name: "refine-store")
            let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
            let model = CompanionModel(service: adapter, configured: true)
            model.addProject(id: "alpha", root: fixture.root.path, sources: ["a.rs"]); await model.waitForOperation()
            model.build(); await model.waitForOperation()
            model.writeContext(id: "memo", kind: "note", text: "Synthetic human note retained", update: false); await model.waitForOperation()
            let original = "Do NOT deploy or change permissions. e\u{301} 👋\r\nSynthetic α"
            let editorRevision = model.contextEditorRevision, savedHistory = model.history?.history.last?.text
            model.editPreparation(query: "fn", original: original)
            let settings = try refinementSettings(peer.endpoint)
            model.requestRefinement(settings: settings); await model.waitForOperation()
            let consent = try #require(model.pendingRefinement)
            #expect(peer.connectionCount() == 0 && !consent.selection.results.isEmpty)
            model.cancelRefinement(); model.confirmRefinement(consent, settings: settings); await model.waitForOperation()
            #expect(peer.connectionCount() == 0 && model.originalDraft.utf8.elementsEqual(original.utf8))
            model.requestRefinement(settings: settings); await model.waitForOperation()
            model.confirmRefinement(try #require(model.pendingRefinement), settings: settings); await model.waitForOperation()
            let wire = try #require(peer.captured())
            #expect(peer.connectionCount() == 1)
            let request = try #require(JSONSerialization.jsonObject(with: wire) as? [String: Any])
            #expect(request["model"] as? String == "synthetic-model" && request["max_tokens"] as? Int == 1024)
            let messages = try #require(request["messages"] as? [[String: Any]])
            let content = try #require(messages.last?["content"] as? String)
            let input = try #require(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any])
            #expect((input["original"] as? String)?.utf8.elementsEqual(original.utf8) == true)
            #expect((input["evidence"] as? [[String: Any]])?.count == consent.selection.results.count)
            #expect(!content.contains("Synthetic human note retained"))
            if mode == "valid" || mode == "questions" {
                let preview = try #require(model.refinementPreview)
                #expect(preview.original.utf8.elementsEqual(original.utf8) && preview.approval == "not-requested" && preview.delivery == "not-attempted")
                #expect(preview.state == (mode == "questions" ? "needs-input" : "ready-for-review"))
            } else { #expect(model.refinementPreview == nil && model.lastError != nil) }
            model.cancelRefinement()
            #expect(model.originalDraft.utf8.elementsEqual(original.utf8) && model.contextEditorRevision == editorRevision && model.history?.history.last?.text == savedHistory)
            await model.shutdown()
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func noHTTPForMissingRemoteStaleProfileAndNamespaceMismatch() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        for change in ["missing", "remote", "profile", "snapshot", "namespace", "stale-source", "context"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            try fixture.rewrite("fn synthetic_source() {}\n")
            let peer = try RefinementHTTPFixture(mode: "valid"); defer { #expect(peer.stop()) }
            let store = try StoreSelection.newDirectory(parent: fixture.root, name: "refine-store")
            let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
            let model = CompanionModel(service: adapter, configured: true)
            model.addProject(id: "alpha", root: fixture.root.path, sources: ["a.rs"]); await model.waitForOperation()
            model.build(); await model.waitForOperation()
            model.editPreparation(query: "fn", original: "Do NOT deploy 👋")
            var settings = try refinementSettings(peer.endpoint)
            if change == "missing" { settings = ProviderSettings() }
            if change == "remote" {
                settings.profiles[0].endpoint = "https://example.invalid/v1/chat/completions"
                settings.profiles[0].locality = .remote
            }
            if change == "context" {
                model.prepareContext(); await model.waitForOperation(); #expect(model.preview?.provider == "not-invoked")
            } else {
                model.requestRefinement(settings: settings); await model.waitForOperation()
                if change == "missing" || change == "remote" { #expect(model.pendingRefinement == nil) }
                else {
                    let consent = try #require(model.pendingRefinement)
                    if change == "profile" { settings.profiles[0].model = "changed" }
                    if ["snapshot", "stale-source"].contains(change) {
                        try Data("fn changed_synthetic() {}\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
                        if change == "snapshot" { _ = try await adapter.perform(.index("alpha")) }
                    }
                    if change == "namespace" {
                        guard case .project(let p) = try await adapter.perform(.project("alpha")), case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
                        _ = try await adapter.perform(.removeProject(p.id, p.root, identity, token))
                        _ = try await adapter.perform(.addProject(p.id, p.root, p.sources)); _ = try await adapter.perform(.index(p.id))
                    }
                    model.confirmRefinement(consent, settings: settings); await model.waitForOperation()
                    #expect(model.refinementPreview == nil)
                }
            }
            #expect(peer.connectionCount() == 0 && model.originalDraft == "Do NOT deploy 👋")
            await model.shutdown()
        }
    }
}
