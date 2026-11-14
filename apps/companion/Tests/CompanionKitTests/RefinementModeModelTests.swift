import Combine
import Darwin
import Foundation
import Testing
@testable import CompanionKit

/// Synthetic, task-owned numeric-loopback peer. Counts all connections and
/// captures exact JSON bytes; bounded nonblocking I/O and explicit stop/join.
private final class ModeModelPeer: @unchecked Sendable {
    private let lock = NSLock()
    private let group = DispatchGroup()
    private let listener: Int32
    private var stopped = false
    private var closed = false
    private var calls = 0
    private var bodies: [Data] = []
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
        group.enter(); DispatchQueue.global().async { self.serve(); self.group.leave() }
    }
    var count: Int { lock.lock(); defer { lock.unlock() }; return calls }
    var requests: [Data] { lock.lock(); defer { lock.unlock() }; return bodies }
    private var live: Bool { lock.lock(); defer { lock.unlock() }; return !stopped }
    func waitForRequest() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if !bodies.isEmpty || stopped { lock.unlock(); continuation.resume() }
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
        var bytes = Data(), body: Data?
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
                if bytes.count >= end.upperBound + length { body = Data(bytes[end.upperBound..<(end.upperBound + length)]); break }
            }
            usleep(2_000)
        }
        guard let body else { return }
        lock.lock(); bodies.append(body); let pending = waiter; waiter = nil; lock.unlock(); pending?.resume()
        if mode == "hold" {
            while active() { var byte: UInt8 = 0; if Darwin.read(fd, &byte, 1) == 0 { return }; usleep(2_000) }
            return
        }
        let brief: [String: Any] = ["objective": "Inspect synthetic source.", "output_expectations": "Suggest checks.",
            "unknowns": [String](), "questions": mode == "questions" ? ["Synthetic question?"] : [String]()]
        guard let prose = try? JSONSerialization.data(withJSONObject: brief),
              let reply = try? JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": "stop", "message": ["role": "assistant", "content": String(decoding: prose, as: UTF8.self)]]]]) else { return }
        let response = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(reply.count)\r\nConnection: close\r\n\r\n".utf8) + reply
        var offset = 0
        while active() && offset < response.count {
            let wrote = response.withUnsafeBytes { Darwin.write(fd, $0.baseAddress!.advanced(by: offset), response.count - offset) }
            if wrote > 0 { offset += wrote }
            else if wrote < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { return }
            usleep(2_000)
        }
    }
}

/// Delay a real CLI selection after it returns, deliberately ignoring task
/// cancellation, to verify serialized predecessor joins and late-result rejection.
private actor ModePreflightCore: CoreService {
    let service: ProcessService
    var hold = false
    var queries = 0
    var held: CheckedContinuation<Void, Never>?
    var entered: CheckedContinuation<Void, Never>?
    var changedScope = false
    var scopeAlias = false
    init(_ service: ProcessService) { self.service = service }
    func arm() { hold = true }
    func changeScope() { changedScope = true }
    func aliasScope() { scopeAlias = true }
    func count() -> Int { queries }
    func waitForQuery() async { if queries > 0 { return }; await withCheckedContinuation { entered = $0 } }
    func release() { hold = false; held?.resume(); held = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        // This adversarial fixture projects a synthetic metadata root solely
        // for the Refine byte-equality gate. Supply its synthetic empty human
        // list too; forwarding that invented binding to real SQL must reject.
        if scopeAlias, case .contextsBound(let binding) = operation {
            return .contexts(ContextList(project: binding.project, contexts: []))
        }
        let reply = try await service.perform(operation)
        switch operation {
        case .queryBound, .queryTermsBound:
            queries += 1; entered?.resume(); entered = nil
            if hold { await withCheckedContinuation { held = $0 } }
        case .project:
            if scopeAlias, case .project(let p) = reply {
                // Controlled scope projection tests the native equality gate,
                // not a filesystem claim about macOS Unicode normalization.
                return .project(Project(id: p.id, root: p.root + (changedScope ? "/e\u{301}" : "/é"),
                    sources: p.sources, snapshot: p.snapshot,
                    rootIdentity: p.root_identity, incarnation: p.incarnation))
            }
        default: break
        }
        return reply
    }
}

@Suite("Explicit mounted Refine retrieval mode", .serialized,
       .enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
struct RefinementModeModelTests {
    private let original = "Do NOT deploy e\u{301} 👋\r\n{\"cancel\":{}}"
    private func reaped(_ pid: Int32) -> Bool {
        var status: Int32 = 0
        return waitpid(pid, &status, WNOHANG) == -1 && errno == ECHILD
    }
    @MainActor private func setup(_ fixture: ApprovedWatchFixture) async throws -> (CompanionModel, ProcessService) {
        try fixture.rewrite("// synthetic_gap_blue blue\n")
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let service = ProcessService(executable: URL(fileURLWithPath: binary),
            dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "mode-model-store"))
        let model = CompanionModel(service: service, configured: true)
        model.addProject(id: "alpha", root: fixture.root.path, sources: ["a.rs"]); await model.waitForOperation()
        model.build(); await model.waitForOperation()
        model.writeContext(id: "memo", kind: "note", text: "Synthetic preserved history", update: false); await model.waitForOperation()
        model.editPreparation(query: "synthetic blue", original: original)
        return (model, service)
    }
    @MainActor private func capture(_ model: CompanionModel, _ settings: ProviderSettings) async throws -> RefinementConsent {
        model.requestRefinement(settings: settings); await model.waitForOperation()
        return try #require(model.pendingRefinement)
    }
    @MainActor private func begin(_ model: CompanionModel, _ consent: RefinementConsent) async throws -> Int32 {
        model.confirmRetainedRefinement(consent, settings: consent.settings); await model.waitForRetainedPreparation()
        #expect(model.retainedReviewVisible && !model.busy)
        #expect(model.retainedReview.binding?.retrievalMode == consent.retrievalMode)
        return try #require(model.retainedReview.ownedPID)
    }
    @MainActor private func waitForAction(_ model: CompanionModel) async {
        // Observe the public model completion signal, not internal controller
        // actions or its task handle. No polling or manufactured review state.
        for await busy in model.$retainedActionBusy.values { if !busy { return } }
    }
    @MainActor private func preservation(_ model: CompanionModel, _ service: ProcessService, _ fixture: ApprovedWatchFixture) async throws {
        #expect(model.originalDraft.utf8.elementsEqual(original.utf8))
        #expect(model.history?.history.last?.text == "Synthetic preserved history")
        guard case .context(let history) = try await service.perform(.context("alpha", "memo")) else { throw ServiceError.invalid }
        #expect(history.history.count == 1 && history.history.last?.text == "Synthetic preserved history")
        #expect(try String(contentsOf: fixture.root.appendingPathComponent("a.rs"), encoding: .utf8) == "// synthetic_gap_blue blue\n")
        for file in try FileManager.default.contentsOfDirectory(at: try #require(service.dataDirectory), includingPropertiesForKeys: [.isRegularFileKey]) {
            if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                let bytes = try Data(contentsOf: file)
                #expect(bytes.range(of: Data(original.utf8)) == nil)
                #expect(bytes.range(of: Data("Synthetic ranked edit".utf8)) == nil)
            }
        }
    }

    @Test @MainActor func defaultOffLiteralAndIndependentSelectorsFreezeExactSelection() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let peer = try ModeModelPeer(); defer { #expect(peer.stop()) }
        let (model, service) = try await setup(fixture)
        #expect(model.refinementRetrievalMode == .literal && model.sourceRetrievalMode == .literal)
        model.requestRefinement(settings: ProviderSettings()); await model.waitForOperation()
        #expect(model.pendingRefinement == nil && peer.count == 0)
        model.setSourceRetrievalMode(.rankedTerms)
        let literal = try await capture(model, refinementSettings(peer.endpoint))
        #expect(literal.retrievalMode == .literal && literal.selection.results.isEmpty && literal.selection.terms == nil)
        model.setRefinementRetrievalMode(.rankedTerms)
        #expect(model.pendingRefinement == nil && model.sourceRetrievalMode == .rankedTerms)
        model.setSourceRetrievalMode(.literal)
        let ranked = try await capture(model, literal.settings)
        #expect(ranked.retrievalMode == .rankedTerms && ranked.selection.results.count == 1 && ranked.selection.terms == ["synthetic", "blue"])
        #expect(model.sourceRetrievalMode == .literal && peer.count == 0)
        let pid = try await begin(model, ranked)
        let request = try #require(peer.requests.first)
        let envelope = try #require(JSONSerialization.jsonObject(with: request) as? [String: Any])
        let messages = try #require(envelope["messages"] as? [[String: Any]])
        let content = try #require(messages.last?["content"] as? String)
        let payload = try #require(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any])
        #expect((payload["original"] as? String)?.utf8.elementsEqual(original.utf8) == true)
        let evidence = try #require(payload["evidence"] as? [[String: Any]])
        let entry = try #require(evidence.first), anchor = try #require(ranked.selection.results.first)
        #expect(evidence.count == 1 && entry["path"] as? String == anchor.path && entry["text"] as? String == anchor.text)
        #expect(entry["source_hash"] as? String == anchor.source_hash && entry["producer"] as? String == anchor.producer)
        let first = try #require(model.retainedReview.challenge)
        model.editRetainedReview(first, objective: "Synthetic ranked edit", outputExpectations: "Synthetic checks")
        await waitForAction(model)
        let next = try #require(model.retainedReview.challenge), proposed = try #require(model.retainedReview.proposed)
        #expect(next.revision == first.revision + 1 && next.digest != first.digest)
        model.useRetainedPrepared(first); await waitForAction(model)
        #expect(model.retainedReview.state == .reviewRequired && model.retainedReview.challenge == next)
        model.useRetainedPrepared(next); await waitForAction(model)
        guard case .approvedValue(let value) = model.retainedReview.state else { throw ServiceError.invalid }
        #expect(value.text.utf8.elementsEqual(proposed.utf8) && value.delivery == "DeliveryNotAttempted")
        #expect(peer.count == 1 && reaped(pid))
        try await preservation(model, service, fixture)
        await model.shutdown()
    }

    @Test @MainActor func pendingModeChangeBackRevokesBothConfirmationPathsAndNoFallback() async throws {
        for finite in [false, true] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let peer = try ModeModelPeer(); defer { #expect(peer.stop()) }
            let (model, service) = try await setup(fixture)
            model.setRefinementRetrievalMode(.rankedTerms)
            let consent = try await capture(model, refinementSettings(peer.endpoint))
            model.setRefinementRetrievalMode(.literal); model.setRefinementRetrievalMode(.rankedTerms)
            #expect(model.pendingRefinement == nil && !model.retainedActionsAvailable)
            if finite { model.confirmRefinement(consent, settings: consent.settings) }
            else { model.confirmRetainedRefinement(consent, settings: consent.settings) }
            await model.waitForOperation()
            #expect(peer.count == 0 && model.refinementPreview == nil && model.retainedReview.ownedPID == nil)
            model.editPreparation(query: "a b c d e f g h i", original: original)
            model.requestRefinement(settings: consent.settings); await model.waitForOperation()
            #expect(model.pendingRefinement == nil && model.lastError != nil && peer.count == 0)
            model.editPreparation(query: "synthetic blue", original: original)
            try await preservation(model, service, fixture)
            await model.shutdown()
        }
    }

    @Test @MainActor func preparingIdleAndQueuedModeChangeBackJoinBeforeSuccessor() async throws {
        for phase in ["preparing", "idle", "queued"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let peer = try ModeModelPeer(phase == "preparing" ? "hold" : "valid"); defer { #expect(peer.stop()) }
            let (model, service) = try await setup(fixture)
            model.setRefinementRetrievalMode(.rankedTerms)
            let consent = try await capture(model, refinementSettings(peer.endpoint))
            let pid: Int32
            if phase == "preparing" {
                model.confirmRetainedRefinement(consent, settings: consent.settings)
                await peer.waitForRequest()
                pid = try #require(model.retainedReview.ownedPID)
            } else {
                pid = try await begin(model, consent)
                if phase == "queued" { model.useRetainedOriginal(try #require(model.retainedReview.challenge)) }
            }
            model.setRefinementRetrievalMode(.literal); model.setRefinementRetrievalMode(.rankedTerms)
            #expect(!model.retainedReviewVisible && !model.retainedActionsAvailable)
            let successor = try await capture(model, consent.settings)
            #expect(reaped(pid) && successor.id != consent.id && successor.retrievalMode == .rankedTerms)
            #expect(model.retainedReview.challenge == nil && peer.count == 1)
            try await preservation(model, service, fixture)
            if phase != "preparing" {
                let nextPID = try await begin(model, successor)
                #expect(nextPID != pid && peer.count == 2)
                model.cancelRefinement(); await model.waitForOperation(); #expect(reaped(nextPID))
            }
            await model.shutdown()
        }
    }

    @Test @MainActor func finiteCompatibilityUsesFrozenModeLiteralDefaultAndRankedExplicit() async throws {
        for mode in SourceRetrievalMode.allCases {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let peer = try ModeModelPeer(); defer { #expect(peer.stop()) }
            let (model, service) = try await setup(fixture)
            model.setRefinementRetrievalMode(mode)
            let consent = try await capture(model, refinementSettings(peer.endpoint))
            model.confirmRefinement(consent, settings: consent.settings); await model.waitForOperation()
            let preview = try #require(model.refinementPreview)
            #expect(preview.state == (mode == .literal ? "needs-input" : "ready-for-review"))
            #expect(preview.coverage == consent.reviewCoverage && preview.original.utf8.elementsEqual(original.utf8))
            #expect(peer.count == 1 && preview.delivery == "not-attempted")
            try await preservation(model, service, fixture)
            await model.shutdown()
        }
    }

    @Test @MainActor func rankedQuestionsSurviveEditAndExactOriginalOnlyExplicitly() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let peer = try ModeModelPeer("questions"); defer { #expect(peer.stop()) }
        let (model, service) = try await setup(fixture)
        model.setRefinementRetrievalMode(.rankedTerms)
        let consent = try await capture(model, refinementSettings(peer.endpoint)), pid = try await begin(model, consent)
        let questions = model.retainedReview.questions
        #expect(model.retainedReview.state == .needsInput && !questions.isEmpty)
        model.editRetainedReview(try #require(model.retainedReview.challenge), objective: "Synthetic ranked edit", outputExpectations: "Checks")
        await waitForAction(model)
        let next = try #require(model.retainedReview.challenge)
        model.useRetainedPrepared(next); await waitForAction(model)
        #expect(model.retainedReview.questions == questions && model.retainedReview.state == .reviewRequired)
        model.useRetainedOriginal(next); await waitForAction(model)
        guard case .approvedValue(let value) = model.retainedReview.state else { throw ServiceError.invalid }
        #expect(value.text.utf8.elementsEqual(original.utf8) && value.choice == "use-original" && value.delivery == "DeliveryNotAttempted")
        #expect(reaped(pid) && peer.count == 1)
        try await preservation(model, service, fixture)
        await model.shutdown()
    }

    @Test @MainActor func latestCoreMismatchBeforeInferenceAndAfterEditBlocksBothChoices() async throws {
        for phase in ["before-retained", "before-finite", "after-prepared", "after-original"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let peer = try ModeModelPeer(); defer { #expect(peer.stop()) }
            let (model, service) = try await setup(fixture)
            model.setRefinementRetrievalMode(.rankedTerms)
            let consent = try await capture(model, refinementSettings(peer.endpoint))
            if phase.hasPrefix("before") {
                try fixture.rewrite("// changed synthetic source\n"); _ = try await service.perform(.index("alpha"))
                if phase == "before-finite" { model.confirmRefinement(consent, settings: consent.settings); await model.waitForOperation() }
                else { model.confirmRetainedRefinement(consent, settings: consent.settings); await model.waitForRetainedPreparation() }
                #expect(peer.count == 0 && model.refinementPreview == nil && model.retainedReview.challenge == nil)
            } else {
                let pid = try await begin(model, consent)
                model.editRetainedReview(try #require(model.retainedReview.challenge), objective: "Synthetic ranked edit", outputExpectations: "Checks")
                await waitForAction(model)
                let challenge = try #require(model.retainedReview.challenge)
                try fixture.rewrite("// changed synthetic source\n")
                if phase == "after-prepared" { model.useRetainedPrepared(challenge) } else { model.useRetainedOriginal(challenge) }
                await waitForAction(model)
                #expect(model.retainedReview.state == .failed && model.retainedReview.challenge == nil && reaped(pid) && peer.count == 1)
            }
            #expect(model.originalDraft.utf8.elementsEqual(original.utf8) && model.history?.history.count == 1)
            await model.shutdown()
        }
    }

    @Test @MainActor func lateActualPreflightCannotRestoreConsentAndSuccessorWaitsForJoin() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let peer = try ModeModelPeer(); defer { #expect(peer.stop()) }
        let (seed, service) = try await setup(fixture)
        let core = ModePreflightCore(service), model = CompanionModel(service: core, configured: true)
        model.select("alpha"); await model.waitForOperation()
        model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "synthetic blue", original: original)
        model.setRefinementRetrievalMode(.rankedTerms)
        await core.arm()
        let settings = try refinementSettings(peer.endpoint)
        model.requestRefinement(settings: settings); await core.waitForQuery()
        model.setRefinementRetrievalMode(.literal); model.setRefinementRetrievalMode(.rankedTerms)
        model.requestRefinement(settings: settings)
        #expect(model.pendingRefinement == nil && model.busy)
        #expect(await core.count() == 1)
        await core.release(); await model.waitForOperation()
        let consent = try #require(model.pendingRefinement)
        #expect(consent.retrievalMode == .rankedTerms && consent.selection.results.count == 1 && peer.count == 0)
        #expect(await core.count() == 2)
        try await preservation(model, service, fixture)
        await model.shutdown(); await seed.shutdown()
    }

    @Test @MainActor func exactScopeBytesRejectedBeforeActualSelection() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let (seed, service) = try await setup(fixture)
        let core = ModePreflightCore(service), model = CompanionModel(service: core, configured: true)
        await core.aliasScope()
        model.select("alpha"); await model.waitForOperation()
        model.editPreparation(query: "synthetic blue", original: original)
        model.setRefinementRetrievalMode(.rankedTerms)
        await core.changeScope()
        model.requestRefinement(settings: try refinementSettings()); await model.waitForOperation()
        #expect(model.pendingRefinement == nil && model.lastError == .readRequiresRefresh)
        #expect(await core.count() == 0)
        await model.shutdown(); await seed.shutdown()
    }

    @Test @MainActor func byteExactSettingsDraftQueryAndUnissuedModeCannotAuthorize() async throws {
        for change in ["settings-setter", "settings-confirm", "original-back", "query-back", "unissued-mode"] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let peer = try ModeModelPeer(); defer { #expect(peer.stop()) }
            let (model, _) = try await setup(fixture)
            var settings = try refinementSettings(peer.endpoint)
            // The selected profile remains valid ASCII. An unselected profile
            // still belongs to the complete settings binding.
            settings.profiles.append(ProviderProfile(id: "unused", endpoint: peer.endpoint, model: "é", locality: .local))
            model.editPreparation(query: "synthetic e\u{301}", original: original)
            model.setRefinementRetrievalMode(.rankedTerms)
            let consent = try await capture(model, settings)
            var confirmation = consent
            if change.hasPrefix("settings") {
                settings.profiles[1].model = "e\u{301}"
                #expect(settings == consent.settings) // Canonical equality is insufficient here.
                if change == "settings-setter" { model.refinementSettingsChanged(settings); #expect(model.pendingRefinement == nil) }
            }
            if change == "original-back" {
                model.editPreparation(query: consent.query, original: original.precomposedStringWithCanonicalMapping)
                model.editPreparation(query: consent.query, original: original)
            }
            if change == "query-back" {
                model.editPreparation(query: "synthetic é", original: original)
                model.editPreparation(query: consent.query, original: original)
            }
            if change == "unissued-mode" {
                confirmation = RefinementConsent(id: consent.id, project: consent.project, query: consent.query,
                    original: consent.original, settings: settings, profile: consent.profile, selection: consent.selection,
                    generation: consent.generation, scopeRevision: consent.scopeRevision) // Literal cannot impersonate ranked.
            }
            model.confirmRetainedRefinement(confirmation, settings: settings); await model.waitForOperation()
            #expect(peer.count == 0 && model.retainedReview.ownedPID == nil && !model.retainedReviewVisible)
            await model.shutdown()
        }
    }
}
