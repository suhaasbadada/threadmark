import Darwin
import Foundation
import Testing
@testable import CompanionKit

/// Task-owned numeric-loopback peer; accepts/counts every connection, never a
/// real provider. Bounded nonblocking I/O; stop joins and closes the listener.
private final class ModelReviewPeer: @unchecked Sendable {
    private let lock = NSLock()
    private let group = DispatchGroup()
    private let listener: Int32
    private var stopped = false
    private var closed = false
    private var calls = 0
    private var received = false
    private var waiter: CheckedContinuation<Void, Never>?
    let endpoint: String
    let mode: String
    init(_ mode: String = "valid") throws {
        self.mode = mode
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        self.listener = listener
        guard listener >= 0 else { throw ServiceError.unavailable }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET); address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(listener, 8) == 0, fcntl(listener, F_SETFL, O_NONBLOCK) == 0 else {
            close(listener); throw ServiceError.unavailable
        }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &length) }
        }
        guard named == 0 else { close(listener); throw ServiceError.unavailable }
        endpoint = "http://127.0.0.1:\(UInt16(bigEndian: address.sin_port))/v1/chat/completions"
        group.enter()
        DispatchQueue.global().async { self.serve(); self.group.leave() }
    }
    var count: Int { lock.lock(); defer { lock.unlock() }; return calls }
    private var live: Bool { lock.lock(); defer { lock.unlock() }; return !stopped }
    func waitForRequest() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if received || stopped { lock.unlock(); continuation.resume() }
            else { waiter = continuation; lock.unlock() }
        }
    }
    func stop() -> Bool {
        lock.lock(); stopped = true; let pending = waiter; waiter = nil; lock.unlock(); pending?.resume()
        guard group.wait(timeout: .now() + 3) == .success else { return false }
        lock.lock(); let shouldClose = !closed; closed = true; lock.unlock()
        if shouldClose { close(listener) }
        return true
    }
    private func serve() {
        let deadline = ProcessInfo.processInfo.systemUptime + 20
        while live && ProcessInfo.processInfo.systemUptime < deadline {
            let fd = accept(listener, nil, nil)
            if fd < 0 { usleep(2_000); continue }
            lock.lock(); calls += 1; lock.unlock()
            respond(fd, deadline: deadline); close(fd)
        }
        lock.lock(); let pending = waiter; waiter = nil; lock.unlock(); pending?.resume()
    }
    private func respond(_ fd: Int32, deadline: Double) {
        guard fcntl(fd, F_SETFL, O_NONBLOCK) == 0 else { return }
        var one: Int32 = 1
        guard setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size)) == 0 else { return }
        func active() -> Bool { live && ProcessInfo.processInfo.systemUptime < deadline }
        var bytes = Data(), complete = false
        while active() && bytes.count <= 65536 {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let got = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
            if got > 0 { bytes.append(contentsOf: buffer.prefix(got)) }
            else if got == 0 { return }
            else if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { return }
            if let end = bytes.range(of: Data([13, 10, 13, 10])) {
                let headers = String(decoding: bytes[..<end.lowerBound], as: UTF8.self)
                guard !headers.lowercased().contains("authorization"),
                      let field = headers.components(separatedBy: "\r\n").first(where: { $0.lowercased().hasPrefix("content-length:") }),
                      let length = Int(field.dropFirst(15).trimmingCharacters(in: .whitespaces)), length <= 65536 else { return }
                if bytes.count >= end.upperBound + length { complete = true; break }
            }
            usleep(2_000)
        }
        guard complete else { return }
        lock.lock(); received = true; let pending = waiter; waiter = nil; lock.unlock(); pending?.resume()
        if mode == "hold" {
            while active() {
                var byte: UInt8 = 0
                if Darwin.read(fd, &byte, 1) == 0 { return }
                usleep(2_000)
            }
            return
        }
        let brief: [String: Any] = ["objective": "Inspect synthetic source.", "output_expectations": "Suggest checks.",
            "unknowns": [String](), "questions": mode == "questions" ? ["Synthetic question?"] : [String]()]
        guard let prose = try? JSONSerialization.data(withJSONObject: brief),
              let reply = try? JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": "stop", "message": ["role": "assistant", "content": String(decoding: prose, as: UTF8.self)]]]]) else { return }
        let status = mode == "failure" ? "500 Internal Server Error" : "200 OK"
        let response = Data("HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(reply.count)\r\nConnection: close\r\n\r\n".utf8) + reply
        var offset = 0
        while active() && offset < response.count {
            let wrote = response.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!.advanced(by: offset), response.count - offset) }
            if wrote > 0 { offset += wrote }
            else if wrote < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { return }
            usleep(2_000)
        }
    }
}

@Suite("Mounted actual-core retained model", .serialized,
       .enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
struct RetainedModelTests {
    private func reaped(_ pid: Int32) -> Bool {
        var status: Int32 = 0
        return waitpid(pid, &status, WNOHANG) == -1 && errno == ECHILD
    }
    @MainActor private func capture(_ fixture: ApprovedWatchFixture, peer: ModelReviewPeer) async throws -> (CompanionModel, ProcessService, RefinementConsent) {
        try fixture.rewrite("fn synthetic_source() {}\n")
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "model-review-store")
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        let model = CompanionModel(service: service, configured: true)
        model.addProject(id: "alpha", root: fixture.root.path, sources: ["a.rs"]); await model.waitForOperation()
        model.build(); await model.waitForOperation()
        model.writeContext(id: "memo", kind: "note", text: "Synthetic human history", update: false); await model.waitForOperation()
        model.editPreparation(query: "fn", original: "Do NOT deploy e\u{301} 👋\n{\"cancel\":{}}")
        model.requestRefinement(settings: try refinementSettings(peer.endpoint)); await model.waitForOperation()
        #expect(peer.count == 0)
        return (model, service, try #require(model.pendingRefinement))
    }
    @MainActor private func begin(_ model: CompanionModel, _ consent: RefinementConsent) async throws -> Int32 {
        model.confirmRetainedRefinement(consent, settings: consent.settings)
        await model.waitForRetainedPreparation()
        #expect(model.retainedReviewVisible && !model.busy)
        return try #require(model.retainedReview.ownedPID)
    }

    @Test @MainActor func editableChallengeBoundExactValueAndNoPersistence() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let peer = try ModelReviewPeer(); defer { #expect(peer.stop()) }
        let (model, service, consent) = try await capture(fixture, peer: peer)
        model.setSourceRetrievalMode(.rankedTerms)
        model.requestRefinement(settings: consent.settings); await model.waitForOperation()
        let literalConsent = try #require(model.pendingRefinement)
        #expect(literalConsent.selection.terms == nil)
        let pid = try await begin(model, literalConsent)
        let first = try #require(model.retainedReview.challenge)
        model.editRetainedReview(first, objective: "Synthetic edited objective", outputExpectations: "Synthetic checks")
        #expect(!model.retainedActionsAvailable)
        await model.waitForRetainedAction()
        let next = try #require(model.retainedReview.challenge), proposed = try #require(model.retainedReview.proposed)
        #expect(next.revision == first.revision + 1 && next.digest != first.digest)
        model.useRetainedPrepared(first); await model.waitForRetainedAction()
        #expect(model.retainedReview.state == .reviewRequired && model.retainedReview.challenge == next)
        model.useRetainedPrepared(next); await model.waitForRetainedAction()
        guard case .approvedValue(let value) = model.retainedReview.state else { Issue.record("Missing actual engine value"); await model.shutdown(); return }
        #expect(value.text.utf8.elementsEqual(proposed.utf8) && value.delivery == "DeliveryNotAttempted")
        #expect(reaped(pid) && peer.count == 1)
        #expect(model.originalDraft.utf8.elementsEqual(consent.original.utf8))
        #expect(model.history?.history.last?.text == "Synthetic human history")
        guard case .context(let persisted) = try await service.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(persisted.history.count == 1 && persisted.history.last?.text == "Synthetic human history")
        #expect(try String(contentsOf: fixture.root.appendingPathComponent("a.rs"), encoding: .utf8) == "fn synthetic_source() {}\n")
        for file in try FileManager.default.contentsOfDirectory(at: try #require(service.dataDirectory), includingPropertiesForKeys: [.isRegularFileKey]) {
            if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                let bytes = try Data(contentsOf: file)
                #expect(bytes.range(of: Data(consent.original.utf8)) == nil)
                #expect(bytes.range(of: Data("Synthetic edited objective".utf8)) == nil)
            }
        }
        await model.shutdown()
    }

    @Test @MainActor func idleInvalidationAndSuccessorsJoinActualChild() async throws {
        for action in ["draft", "query", "policy", "settings", "profile", "configure", "select", "cancel", "queued", "quit"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let peer = try ModelReviewPeer(); defer { #expect(peer.stop()) }
            let (model, service, consent) = try await capture(fixture, peer: peer)
            let pid = try await begin(model, consent), challenge = try #require(model.retainedReview.challenge)
            switch action {
            case "draft": model.editPreparation(query: consent.query, original: "Changed synthetic original")
            case "query": model.editPreparation(query: "synthetic", original: consent.original)
            case "policy": model.stageSources([])
            case "settings": var s = consent.settings; s.enabled = false; model.refinementSettingsChanged(s)
            case "profile": var s = consent.settings; s.profiles[0].model = "changed-synthetic"; model.refinementSettingsChanged(s)
            case "configure": model.configure(executable: try #require(service.executable), dataDirectory: try #require(service.dataDirectory))
            case "select": model.select("alpha")
            case "queued": model.useRetainedOriginal(challenge); model.editPreparation(query: "synthetic", original: consent.original)
            case "quit": model.quit()
            default: model.cancel()
            }
            #expect(!model.retainedReviewVisible && !model.retainedActionsAvailable)
            model.useRetainedOriginal(challenge) // Revoked actions cannot enqueue.
            if action == "quit" { await model.shutdown() }
            else { model.refreshSelected(); await model.waitForOperation() }
            #expect(reaped(pid) && peer.count == 1 && model.retainedReview.challenge == nil)
            #expect(model.retainedReview.state != .approvedValue(.init(text: consent.original, choice: "use-original")))
            await model.shutdown()
        }
    }

    @Test @MainActor func closeRetainsIdlePauseDistinctQuitJoinsAndDeinitIsNotCyclic() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let peer = try ModelReviewPeer(); defer { #expect(peer.stop()) }
        var (model, _, consent): (CompanionModel?, ProcessService, RefinementConsent) = try await capture(fixture, peer: peer)
        let pid = try await begin(try #require(model), consent)
        model?.showManagement(); model?.closeManagement()
        #expect(model?.managementVisible == false && model?.closeExplanationShown == true)
        #expect(model?.retainedActionsAvailable == true && !reaped(pid))
        model?.togglePause()
        #expect(model?.retainedActionsAvailable == true)
        let lifetime = try #require(model?.retainedReview.ownedLifetime)
        weak let weakModel = model
        model = nil
        #expect(weakModel == nil)
        await lifetime.join()
        #expect(reaped(pid) && peer.count == 1)
    }

    @Test @MainActor func questionsSurviveEditAndFailureNeedsExplicitOriginal() async throws {
        for mode in ["questions", "failure"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let peer = try ModelReviewPeer(mode); defer { #expect(peer.stop()) }
            let (model, _, consent) = try await capture(fixture, peer: peer)
            let pid = try await begin(model, consent)
            if mode == "questions" {
                let questions = model.retainedReview.questions
                #expect(!questions.isEmpty && model.retainedReview.state == .needsInput)
                model.editRetainedReview(try #require(model.retainedReview.challenge), objective: "Synthetic edit", outputExpectations: "Synthetic checks")
                await model.waitForRetainedAction()
                model.useRetainedPrepared(try #require(model.retainedReview.challenge)); await model.waitForRetainedAction()
                #expect(model.retainedReview.questions == questions && model.retainedReview.state == .reviewRequired)
                model.cancel(); await model.waitForOperation()
            } else {
                #expect(model.retainedReview.state == .failed && model.retainedReview.proposed == nil && !reaped(pid))
                model.useRetainedOriginal(try #require(model.retainedReview.challenge)); await model.waitForRetainedAction()
                guard case .approvedValue(let value) = model.retainedReview.state else { Issue.record("Missing explicit original"); await model.shutdown(); continue }
                #expect(value.text.utf8.elementsEqual(consent.original.utf8) && value.delivery == "DeliveryNotAttempted")
            }
            #expect(reaped(pid) && peer.count == 1 && model.originalDraft.utf8.elementsEqual(consent.original.utf8))
            #expect(model.history?.history.last?.text == "Synthetic human history")
            await model.shutdown()
        }
    }

    @Test @MainActor func coreSourceSnapshotPolicyNamespaceInvalidateBothChoices() async throws {
        for (change, prepared) in [("source", false), ("snapshot", false), ("policy", false), ("namespace", false),
                                  ("source", true), ("snapshot", true), ("policy", true), ("namespace", true), ("failure-source", false)] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let peer = try ModelReviewPeer(change == "failure-source" ? "failure" : "valid"); defer { #expect(peer.stop()) }
            let (model, service, consent) = try await capture(fixture, peer: peer)
            let pid = try await begin(model, consent), challenge = try #require(model.retainedReview.challenge)
            if change == "source" || change == "failure-source" { try fixture.rewrite("fn changed_source() {}\n") }
            if change == "snapshot" { try fixture.rewrite("fn changed_source() {}\n"); _ = try await service.perform(.index("alpha")) }
            if change == "policy" { _ = try await service.perform(.setSources("alpha", [])) }
            if change == "namespace" {
                let p = consent.project
                guard case .string(let identity) = p.root_identity, let token = p.incarnation else { throw ServiceError.invalid }
                _ = try await service.perform(.removeProject(p.id, p.root, identity, token))
                _ = try await service.perform(.addProject(p.id, p.root, p.sources)); _ = try await service.perform(.index(p.id))
            }
            if prepared { model.useRetainedPrepared(challenge) } else { model.useRetainedOriginal(challenge) }
            await model.waitForRetainedAction()
            #expect(model.retainedReview.state == .failed && model.retainedReview.challenge == nil)
            #expect(reaped(pid) && peer.count == 1 && model.originalDraft.utf8.elementsEqual(consent.original.utf8))
            await model.shutdown()
        }
    }

    @Test @MainActor func noCallWithoutCurrentImmutableConsentAndCancelDuringStart() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let peer = try ModelReviewPeer("hold"); defer { #expect(peer.stop()) }
        let (model, _, consent) = try await capture(fixture, peer: peer)
        model.editPreparation(query: consent.query, original: "Different synthetic original")
        model.confirmRetainedRefinement(consent, settings: consent.settings)
        await model.waitForOperation()
        #expect(peer.count == 0 && model.retainedReview.ownedPID == nil)
        model.editPreparation(query: consent.query, original: consent.original)
        model.confirmRetainedRefinement(consent, settings: consent.settings) // Changing back cannot restore consent.
        await model.waitForOperation()
        #expect(peer.count == 0)
        model.requestRefinement(settings: consent.settings); await model.waitForOperation()
        let current = try #require(model.pendingRefinement)
        model.confirmRetainedRefinement(current, settings: current.settings)
        await peer.waitForRequest()
        let pid = try #require(model.retainedReview.ownedPID)
        model.editPreparation(query: "synthetic", original: current.original)
        model.prepareContext(); await model.waitForOperation()
        #expect(reaped(pid) && peer.count == 1 && model.preview != nil && !model.retainedReviewVisible)
        await model.shutdown()
    }

    @Test @MainActor func disabledChangedSettingsAndUnissuedConsentNeverInvoke() async throws {
        for change in ["disabled", "profile", "id", "byte-exact"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let peer = try ModelReviewPeer(); defer { #expect(peer.stop()) }
            let (model, _, consent) = try await capture(fixture, peer: peer)
            var settings = consent.settings
            if change == "disabled" { settings.enabled = false }
            if change == "profile" { settings.profiles[0].model = "changed-synthetic" }
            if change == "byte-exact" {
                model.editPreparation(query: consent.query, original: consent.original.precomposedStringWithCanonicalMapping)
            }
            let unissued = RefinementConsent(id: UUID(), project: consent.project, query: consent.query,
                original: consent.original, settings: consent.settings, profile: consent.profile,
                selection: consent.selection, generation: consent.generation, scopeRevision: consent.scopeRevision)
            model.confirmRetainedRefinement(change == "id" ? unissued : consent, settings: settings)
            await model.waitForOperation()
            #expect(peer.count == 0 && !model.retainedReviewVisible && model.retainedReview.ownedPID == nil)
            await model.shutdown()
        }
    }

    @Test @MainActor func nextPreflightAndSessionFollowPreviousIdleJoin() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let peer = try ModelReviewPeer(); defer { #expect(peer.stop()) }
        let (model, _, consent) = try await capture(fixture, peer: peer)
        let previousPID = try await begin(model, consent)
        model.requestRefinement(settings: consent.settings)
        #expect(!model.retainedReviewVisible && !model.retainedActionsAvailable)
        await model.waitForOperation()
        let successor = try #require(model.pendingRefinement)
        #expect(reaped(previousPID) && successor.id != consent.id && peer.count == 1)
        let nextPID = try await begin(model, successor)
        #expect(peer.count == 2 && nextPID != previousPID)
        model.quit(); await model.shutdown()
        #expect(reaped(nextPID))
    }
}
