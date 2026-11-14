import Foundation

/// Dispatch may signal repeatedly while the main actor is occupied. Bound the
/// hop itself, not only the debounce task, to one pending delivery per watch set.
private final class PendingFileHint: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !pending else { return false }
        pending = true; return true
    }
    func release() { lock.lock(); pending = false; lock.unlock() }
}

/// Main-actor mutation; exclusive destruction also invalidates on owner loss.
/// Foundation permits invalidating a timer from another thread.
private final class OwnedRefreshTimer: @unchecked Sendable {
    var timer: Timer?
    deinit { timer?.invalidate() }
}

/// Exact approved-file metadata hints plus bounded full reconciliation fallback.
@MainActor
public protocol RefreshDriver: AnyObject {
    func start(consent: AutomaticRefreshConsent, service: any CoreService, interval: TimeInterval,
               ready: @escaping @MainActor @Sendable () -> Void,
               tick: @escaping @MainActor @Sendable () -> Void,
               failure: @escaping @MainActor @Sendable () -> Void) throws
    func stop()
    func shutdown() async
}

@MainActor
public final class TimerRefreshDriver: RefreshDriver {
    private let clock = OwnedRefreshTimer()
    var timer: Timer? { clock.timer }
    private let watches: AuthorizedFileWatches
    private var debounce: Task<Void, Never>?
    // One owned query, even if cancellation is ignored. Restarts replace the
    // desired request rather than creating tasks waiting on an unbounded chain.
    private var preflight: Task<Void, Never>?
    private struct Request {
        let consent: AutomaticRefreshConsent
        let service: any CoreService
        let interval: TimeInterval
        let token: UInt64
        let ready: @MainActor @Sendable () -> Void
        let tick: @MainActor @Sendable () -> Void
        let failure: @MainActor @Sendable () -> Void
    }
    private var request: Request?
    private var generation: UInt64 = 0
    private var watchGeneration: UInt64 = 0
    private let waitForDebounce: @Sendable () async throws -> Void
    var watchCount: Int { watches.count }
    public init() {
        watches = AuthorizedFileWatches()
        waitForDebounce = { try await Task.sleep(for: .milliseconds(300)) }
    }
    /// Deterministic cancellation boundary for tests; production delay is fixed.
    init(watches: AuthorizedFileWatches = AuthorizedFileWatches(),
         waitForDebounce: @escaping @Sendable () async throws -> Void = { try await Task.sleep(for: .milliseconds(300)) }) {
        self.watches = watches; self.waitForDebounce = waitForDebounce
    }
    public func start(consent: AutomaticRefreshConsent, service: any CoreService, interval: TimeInterval,
                      ready: @escaping @MainActor @Sendable () -> Void,
                      tick: @escaping @MainActor @Sendable () -> Void,
                      failure: @escaping @MainActor @Sendable () -> Void) throws {
        stop()
        precondition(interval >= 60)
        request = Request(consent: consent, service: service, interval: interval,
                          token: generation, ready: ready, tick: tick, failure: failure)
        authorize(initial: true)
    }
    public func stop() {
        generation &+= 1; watchGeneration &+= 1
        request = nil
        preflight?.cancel() // Retain until the actual operation returns.
        debounce?.cancel(); debounce = nil
        clock.timer?.invalidate(); clock.timer = nil
        watches.stop()
    }
    public func shutdown() async {
        stop()
        if let preflight { await preflight.value }
    }
    /// Test/embedding join of the current startup or reconciliation, not a timer wait.
    func waitForAuthorization() async {
        while let preflight { await preflight.value }
    }
    private func authorize(initial: Bool) {
        guard preflight == nil, let request else { return }
        debounce?.cancel(); debounce = nil
        watchGeneration &+= 1
        // Revocation/replacement reconciliation closes the old set BEFORE the
        // await. No metadata handle remains live while authority is unresolved.
        watches.stop()
        preflight = Task { @MainActor [weak self] in
            defer { self?.authorizationFinished(token: request.token) }
            do {
                try Task.checkCancellation()
                let reply = try await request.service.perform(.project(request.consent.projectID))
                try Task.checkCancellation()
                guard let self, self.generation == request.token else { return }
                guard case .project(let project) = reply,
                      request.consent.matches(project) else { throw ServiceError.scopeMismatch }
                // No suspension between the generation/authority checks and
                // opening descriptors. This is a preflight, not a remote lease;
                // indexBound still rechecks policy transactionally for content.
                try self.bind(request.consent, token: request.token, tick: request.tick, failure: request.failure)
                if initial {
                    let timer = Timer(timeInterval: request.interval, repeats: true) { [weak self] _ in
                        MainActor.assumeIsolated { self?.reconcile(request.consent, token: request.token, tick: request.tick, failure: request.failure) }
                    }
                    timer.tolerance = 5
                    self.clock.timer = timer
                    RunLoop.main.add(timer, forMode: .common)
                    request.ready()
                } else { request.tick() }
            } catch {
                if let self, self.generation == request.token {
                    self.stop(); request.failure()
                }
            }
        }
    }
    private func authorizationFinished(token: UInt64) {
        preflight = nil
        // A new start while an uncancellable query was draining owns no second
        // query. Only the latest still-active request can now start.
        if let request, request.token != token { authorize(initial: true) }
    }
    private func bind(_ consent: AutomaticRefreshConsent, token: UInt64,
                      tick: @escaping @MainActor @Sendable () -> Void,
                      failure: @escaping @MainActor @Sendable () -> Void) throws {
        watchGeneration &+= 1
        let watchToken = watchGeneration
        let pending = PendingFileHint()
        try watches.install(consent) { [weak self] in
            guard pending.claim() else { return }
            Task { @MainActor [weak self] in
                defer { pending.release() }
                guard let self, self.generation == token, self.watchGeneration == watchToken,
                      self.debounce == nil, self.preflight == nil else { return }
                // One pending trigger, not a sliding/unbounded queue. Busy work
                // skips this hint; periodic full reconciliation repairs it.
                let wait = self.waitForDebounce
                self.debounce = Task { @MainActor [weak self] in
                    do { try await wait() } catch { return }
                    guard let self, self.generation == token, self.watchGeneration == watchToken else { return }
                    self.reconcile(consent, token: token, tick: tick, failure: failure)
                }
            }
        }
    }
    private func reconcile(_ consent: AutomaticRefreshConsent, token: UInt64,
                           tick: @escaping @MainActor @Sendable () -> Void,
                           failure: @escaping @MainActor @Sendable () -> Void) {
        guard generation == token, preflight == nil else { return }
        authorize(initial: false)
    }
}

/// Session-only exact approval. Snapshot changes do not grant any new sources.
public struct AutomaticRefreshConsent: Equatable, Sendable {
    public let projectID: String
    public let root: String
    public let rootIdentity: String
    public let incarnation: String
    public let sources: [String]
    public let scopeRevision: UInt64
    func matches(_ project: Project) -> Bool {
        project.id == projectID && project.root == root &&
        project.root_identity == .string(rootIdentity) &&
        project.incarnation == incarnation && project.sources == sources
    }
}
