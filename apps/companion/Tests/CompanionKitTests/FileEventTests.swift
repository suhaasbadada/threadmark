import Darwin
import Foundation
import Testing
@testable import CompanionKit

/// Synthetic authority implements the actual service boundary used by the real
/// driver. No production default authorizer or UI project is substituted.
actor WatchCoreService: CoreService {
    private let requestedID: String
    private var project: Project
    private var held = false
    private var release: CheckedContinuation<Void, Never>?
    private var began: CheckedContinuation<Void, Never>?
    private var started = false
    private var unavailable = false
    private(set) var calls = 0
    init(_ consent: AutomaticRefreshConsent) {
        requestedID = consent.projectID
        project = Project(id: consent.projectID, root: consent.root, sources: consent.sources,
                          rootIdentity: .string(consent.rootIdentity), incarnation: consent.incarnation)
    }
    func replace(_ project: Project) { self.project = project }
    func remove() { unavailable = true }
    func hold() { held = true; started = false }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { began = $0 }
    }
    func finish() { held = false; release?.resume(); release = nil }
    func perform(_ operation: CompanionKit.Operation) async throws -> Reply {
        if case .contexts(let id) = operation { return .contexts(ContextList(project: id, contexts: [])) }
        guard case .project(let id) = operation, id == requestedID else { throw ServiceError.invalid }
        calls += 1
        guard !unavailable else { throw ServiceError.unavailable }
        if held {
            started = true; began?.resume(); began = nil
            await withCheckedContinuation { release = $0 } // Deliberately ignores cancellation.
        }
        return .project(project)
    }
}

@MainActor
extension TimerRefreshDriver {
    func startAuthorized(consent: AutomaticRefreshConsent, interval: TimeInterval,
                         tick: @escaping @MainActor @Sendable () -> Void,
                         failure: @escaping @MainActor @Sendable () -> Void) async throws {
        try start(consent: consent, service: WatchCoreService(consent), interval: interval, ready: {}, tick: tick, failure: failure)
        await waitForAuthorization()
    }
}

struct ApprovedWatchFixture {
    let root: URL
    init() throws {
        root = try StoreSelection.existingDirectory(FileManager.default.temporaryDirectory)
            .appendingPathComponent("opencode/threadmark-watch-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try rewrite("initial")
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
    func rewrite(_ text: String, name: String = "a.rs", atomic: Bool = false) throws {
        try Data(text.utf8).write(to: root.appendingPathComponent(name), options: atomic ? .atomic : [])
    }
    func consent(_ paths: [String] = ["a.rs"], identity: String? = nil) throws -> AutomaticRefreshConsent {
        var info = stat()
        guard lstat(root.path, &info) == 0 else { throw ServiceError.failed }
        return AutomaticRefreshConsent(projectID: "alpha", root: root.path,
            rootIdentity: identity ?? "\(info.st_dev):\(info.st_ino)",
            incarnation: "0123456789abcdef0123456789abcdef", sources: paths, scopeRevision: 0)
    }
}

/// Event-driven bounded expectations, not polling a driver or sleeping until
/// assumed delivery. The only clock is a generous delivery/quiet deadline.
func watchEvent(_ stream: AsyncStream<Bool>, timeout: Duration = .seconds(5)) async -> Bool {
    await withTaskGroup(of: Bool.self) { group in
        group.addTask { for await value in stream { return value }; return false }
        group.addTask { do { try await Task.sleep(for: timeout) } catch { }; return false }
        let result = await group.next() ?? false
        group.cancelAll()
        return result
    }
}

/// Observe the owned close syscall itself: checking F_GETFD afterward would
/// race unrelated parallel tests reusing the released descriptor number.
private final class DescriptorCloseTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var opened: [Int32] = []
    private var closed: [Int32] = []
    private var failures = 0
    func open(_ fd: Int32) { lock.lock(); opened.append(fd); lock.unlock() }
    func close(_ fd: Int32, _ result: Int32) {
        lock.lock(); closed.append(fd); if result != 0 { failures += 1 }; lock.unlock()
    }
    var balanced: Bool {
        lock.lock(); defer { lock.unlock() }
        return !opened.isEmpty && opened.sorted() == closed.sorted() && failures == 0
    }
}

private actor DeferredDebounce {
    let started: AsyncStream<Bool>.Continuation
    private var continuation: CheckedContinuation<Void, Never>?
    init(_ started: AsyncStream<Bool>.Continuation) { self.started = started }
    func wait() async {
        started.yield(true)
        // Deliberately ignore cancellation to exercise the generation guard.
        await withCheckedContinuation { continuation = $0 }
    }
    func release() { continuation?.resume(); continuation = nil }
}

@Suite("Exact approved-file native metadata events")
@MainActor
struct FileEventTests {
    @Test(arguments: ["initial", "resume", "event", "periodic"], ["incarnation", "sources", "root", "identity", "id", "missing"])
    func authoritativePolicyMismatchNeverInstallsOrOpens(trigger: String, mismatch: String) async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let consent = try fixture.consent()
        let service = WatchCoreService(consent)
        var installs = 0, opens = 0, ready = 0, ticks = 0, failures = 0
        let watches = AuthorizedFileWatches(willInstall: { installs += 1 }, opened: { _ in opens += 1 })
        let driver = TimerRefreshDriver(watches: watches)
        defer { driver.stop() }
        let (failed, continuation) = AsyncStream<Bool>.makeStream()
        func start() throws {
            try driver.start(consent: consent, service: service, interval: 60, ready: { ready += 1 }, tick: { ticks += 1 }, failure: {
                failures += 1; continuation.yield(true)
            })
        }
        if trigger != "initial" {
            try start(); await driver.waitForAuthorization()
            #expect(ready == 1 && installs == 1 && opens == 1)
            if trigger == "resume" { driver.stop() }
        }
        await service.replace(Project(id: mismatch == "id" ? "beta" : consent.projectID,
            root: mismatch == "root" ? consent.root + "-other" : consent.root,
            sources: mismatch == "sources" ? [] : consent.sources,
            rootIdentity: .string(mismatch == "identity" ? "0:0" : consent.rootIdentity),
            incarnation: mismatch == "incarnation" ? "fedcba9876543210fedcba9876543210" : consent.incarnation))
        if mismatch == "missing" { await service.remove() }
        let beforeInstalls = installs, beforeOpens = opens
        switch trigger {
        case "initial", "resume": try start()
        case "periodic": try #require(driver.timer).fire()
        default: try fixture.rewrite("synthetic revoked event")
        }
        #expect(await watchEvent(failed))
        #expect(installs == beforeInstalls && opens == beforeOpens)
        #expect(ticks == 0 && failures == 1 && driver.watchCount == 0 && driver.timer == nil)
        #expect(ready == (trigger == "initial" ? 0 : 1))
        await driver.shutdown()
    }

    @Test(arguments: ["stop", "restart", "latest", "shutdown"])
    func heldAuthorityIsOwnedCoalescedAndLateCompletionCannotOpen(action: String) async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let consent = try fixture.consent()
        let service = WatchCoreService(consent)
        var installs = 0, opens = 0, callbacks = 0
        let driver = TimerRefreshDriver(watches: AuthorizedFileWatches(willInstall: { installs += 1 }, opened: { _ in opens += 1 }))
        defer { driver.stop() }
        func start() throws {
            try driver.start(consent: consent, service: service, interval: 60, ready: { callbacks += 1 }, tick: { callbacks += 1 }, failure: { callbacks += 1 })
        }
        try start(); await driver.waitForAuthorization()
        #expect(installs == 1 && opens == 1 && callbacks == 1)
        await service.hold()
        let timer = try #require(driver.timer)
        timer.fire()
        #expect(driver.watchCount == 0) // Close BEFORE suspension/query.
        await service.waitUntilStarted()
        for _ in 0..<50 { timer.fire() }
        #expect(await service.calls == 2)
        var joined = false
        let shutdown: Task<Void, Never>?
        if action == "shutdown" {
            let (began, beganContinuation) = AsyncStream<Bool>.makeStream()
            shutdown = Task { beganContinuation.yield(true); await driver.shutdown(); joined = true }
            #expect(await watchEvent(began))
            #expect(!joined)
        } else {
            shutdown = nil
            driver.stop()
            if action == "restart" || action == "latest" {
                for _ in 0..<50 { try start() }
                #expect(await service.calls == 2) // No queued tasks/overlapping queries.
                if action == "restart" { driver.stop() } // Invalidate the latest request too.
            }
        }
        #expect(installs == 1 && opens == 1)
        await service.finish()
        await driver.waitForAuthorization()
        await shutdown?.value
        #expect(action != "shutdown" || joined)
        let expected = action == "latest" ? 2 : 1
        #expect(installs == expected && opens == expected && callbacks == expected)
        #expect(driver.watchCount == (action == "latest" ? 1 : 0))
        #expect(await service.calls == expected + 1)
        // Recovery joins the old query and uses the actual service again.
        try start(); await driver.waitForAuthorization()
        #expect(installs == expected + 1 && opens == expected + 1 && callbacks == expected + 1)
        #expect(await service.calls == expected + 2)
        await driver.shutdown()
    }

    @Test(arguments: ["pause", "project", "configure", "quit"])
    func modelPendingReadinessInvalidationAndShutdownJoin(action: String) async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let consent = try fixture.consent()
        let service = WatchCoreService(consent)
        var opens = 0
        let driver = TimerRefreshDriver(watches: AuthorizedFileWatches(willInstall: { opens += 1 }))
        let model = CompanionModel(service: service, configured: true, refreshDriver: driver)
        // This service also supplies a bounded empty context list for selection.
        model.select(consent.projectID); await model.waitForOperation()
        await service.hold()
        model.enableAutomaticRefresh(try #require(model.automaticRefreshProposal))
        await service.waitUntilStarted()
        #expect(model.status == "Checking approved policy — monitoring not yet enabled" && opens == 0)
        #expect(model.automaticRefreshSummary == "File-event + periodic refresh: approved")
        #expect(!model.automaticRefreshSummary.contains("enabled"))
        var joined = false
        var shutdown: Task<Void, Never>?
        switch action {
        case "pause": model.togglePause()
        case "project": model.select(nil)
        case "configure": model.configure(executable: URL(fileURLWithPath: "/synthetic/core"), dataDirectory: URL(fileURLWithPath: "/synthetic/store"))
        default:
            let (began, continuation) = AsyncStream<Bool>.makeStream()
            shutdown = Task { continuation.yield(true); await model.shutdown(); joined = true }
            #expect(await watchEvent(began)); #expect(!joined)
        }
        await service.finish(); await driver.waitForAuthorization(); await shutdown?.value
        #expect(opens == 0 && driver.watchCount == 0 && driver.timer == nil)
        #expect(!model.status.contains("refresh enabled"))
        #expect(action != "quit" || joined)
        await model.shutdown()
    }

    @Test func realBurstsDebounceAndRebindAtomicReplacementThenFurtherEdit() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let driver = TimerRefreshDriver(); defer { driver.stop() }
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        var ticks = 0
        var began = ContinuousClock.now
        var firstElapsed: Duration?
        try await driver.startAuthorized(consent: fixture.consent(), interval: 60) {
            if firstElapsed == nil { firstElapsed = ContinuousClock.now - began }
            ticks += 1; continuation.yield(true)
        } failure: { Issue.record("Unexpected watch failure") }
        began = ContinuousClock.now
        for n in 0..<40 { try fixture.rewrite("synthetic burst \(n)") }
        #expect(await watchEvent(stream))
        #expect(ticks == 1)
        #expect(try #require(firstElapsed) >= .milliseconds(300))
        #expect(!(await watchEvent(stream, timeout: .milliseconds(800))))
        // Separate quiet expectation detects duplicate callbacks, not just the
        // first fulfillment. A fresh stream is used after every bounded wait.
        let (quiet, quietContinuation) = AsyncStream<Bool>.makeStream()
        try await driver.startAuthorized(consent: fixture.consent(), interval: 60) {
            ticks += 1; quietContinuation.yield(true)
        } failure: { Issue.record("Unexpected watch failure") }
        try fixture.rewrite("atomic replacement", atomic: true)
        #expect(await watchEvent(quiet))
        #expect(ticks == 2 && driver.watchCount == 1)
        // Do not restart: the callback remains the same, proving the driver
        // rebound the replacement descriptor itself.
        try fixture.rewrite("further in-place edit")
        // The same stream can consume another value after a successful wait.
        #expect(await watchEvent(quiet))
        #expect(ticks == 3)
        #expect(!(await watchEvent(quiet, timeout: .milliseconds(800))))
        driver.stop()
        #expect(driver.watchCount == 0 && driver.timer == nil)
    }

    @Test func omittedChangesStopAndOldScopeCannotTrigger() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        try fixture.rewrite("omitted", name: "b.rs")
        let driver = TimerRefreshDriver(); defer { driver.stop() }
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        var ticks = 0
        try await driver.startAuthorized(consent: fixture.consent(), interval: 60) {
            ticks += 1; continuation.yield(true)
        } failure: { Issue.record("Unexpected watch failure") }
        try fixture.rewrite("unapproved edit", name: "b.rs")
        #expect(!(await watchEvent(stream, timeout: .milliseconds(800))))
        // Queue an actual kernel event and stop before its main-actor block.
        try fixture.rewrite("old event")
        let oldTimer = driver.timer
        driver.stop()
        let (newScope, newContinuation) = AsyncStream<Bool>.makeStream()
        try await driver.startAuthorized(consent: fixture.consent(["b.rs"]), interval: 60) {
            ticks += 1; newContinuation.yield(true)
        } failure: { Issue.record("Unexpected watch failure") }
        try fixture.rewrite("old scope edit again")
        oldTimer?.fire()
        #expect(!(await watchEvent(newScope, timeout: .milliseconds(800))))
        #expect(ticks == 0)
    }

    @Test func deletedFileStopsWithoutPartialCoverageOrFallback() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let driver = TimerRefreshDriver(); defer { driver.stop() }
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        var ticks = 0, failures = 0
        try await driver.startAuthorized(consent: fixture.consent(), interval: 60) { ticks += 1 } failure: {
            failures += 1; continuation.yield(true)
        }
        try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("a.rs"))
        #expect(await watchEvent(stream))
        #expect(failures == 1 && ticks == 0 && driver.watchCount == 0 && driver.timer == nil)
    }

    @Test func periodicFallbackRebindsEvenWithoutDeliveredHint() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let driver = TimerRefreshDriver(); defer { driver.stop() }
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        var ticks = 0
        try await driver.startAuthorized(consent: fixture.consent(), interval: 60) {
            ticks += 1; continuation.yield(true)
        } failure: { Issue.record("Unexpected watch failure") }
        let timer = try #require(driver.timer)
        try fixture.rewrite("replacement before event dispatch", atomic: true)
        timer.fire() // Main actor has not yielded: simulate a missed event.
        await driver.waitForAuthorization()
        #expect(ticks == 1)
        #expect(await watchEvent(stream))
        try fixture.rewrite("subsequent edit")
        #expect(await watchEvent(stream))
        #expect(ticks == 2)
    }

    @Test func secureSetupRejectsUnsafePathsAndClosesAllOwnedDescriptors() throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let fm = FileManager.default
        try fixture.rewrite("hard linked", name: "hard.rs")
        try fm.linkItem(at: fixture.root.appendingPathComponent("hard.rs"), to: fixture.root.appendingPathComponent("alias.rs"))
        try fm.createSymbolicLink(atPath: fixture.root.appendingPathComponent("symlink.rs").path,
                                 withDestinationPath: fixture.root.appendingPathComponent("a.rs").path)
        #expect(mkfifo(fixture.root.appendingPathComponent("pipe.rs").path, 0o600) == 0)
        let nested = fixture.root.appendingPathComponent("nested")
        try fm.createDirectory(at: nested, withIntermediateDirectories: false)
        try fixture.rewrite("submodule marker", name: "nested/.git")
        try fixture.rewrite("nested source", name: "nested/a.rs")
        try fm.createSymbolicLink(atPath: fixture.root.appendingPathComponent("external").path, withDestinationPath: nested.path)
        for path in ["symlink.rs", "hard.rs", "pipe.rs", "nested/a.rs", "external/a.rs", "../a.rs", "/a.rs", "nested", "missing.rs"] {
            let tracker = DescriptorCloseTracker()
            let watches = AuthorizedFileWatches(opened: { tracker.open($0) }, didClose: { tracker.close($0, $1) })
            #expect(throws: (any Error).self) { try watches.install(fixture.consent(["a.rs", path])) {} }
            #expect(watches.count == 0)
            if InputPolicy.sources(["a.rs", path]) { #expect(tracker.balanced) }
        }
        let watches = AuthorizedFileWatches()
        #expect(throws: ServiceError.scopeMismatch) { try watches.install(fixture.consent(identity: "0:0")) {} }
        #expect(watches.count == 0)
        var paths: [String] = []
        for n in 0..<65 { let path = "file\(n).rs"; try fixture.rewrite("bounded", name: path); paths.append(path) }
        let tracker = DescriptorCloseTracker()
        let bounded = AuthorizedFileWatches(opened: { tracker.open($0) }, didClose: { tracker.close($0, $1) })
        try bounded.install(fixture.consent(Array(paths.prefix(64)))) {}
        #expect(bounded.count == 64)
        bounded.stop()
        #expect(tracker.balanced)
        #expect(throws: (any Error).self) { try bounded.install(fixture.consent(paths)) {} }
        #expect(bounded.count == 0)
    }

    @Test func replacedRootIdentityAndSymlinkedAbsoluteAncestorFailClosed() throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let consent = try fixture.consent()
        let moved = fixture.root.appendingPathExtension("moved")
        defer { try? FileManager.default.removeItem(at: moved) }
        try FileManager.default.moveItem(at: fixture.root, to: moved)
        try FileManager.default.createDirectory(at: fixture.root, withIntermediateDirectories: false)
        try fixture.rewrite("replacement root")
        let watches = AuthorizedFileWatches()
        #expect(throws: ServiceError.scopeMismatch) { try watches.install(consent) {} }
        #expect(watches.count == 0)
        let alias = fixture.root.appendingPathExtension("alias")
        defer { try? FileManager.default.removeItem(at: alias) }
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: fixture.root)
        let actual = try fixture.consent()
        let viaAlias = AutomaticRefreshConsent(projectID: actual.projectID, root: alias.path,
            rootIdentity: actual.rootIdentity, incarnation: actual.incarnation, sources: actual.sources, scopeRevision: actual.scopeRevision)
        #expect(throws: (any Error).self) { try watches.install(viaAlias) {} }
    }

    @Test func ownerLossClosesDescriptors() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let tracker = DescriptorCloseTracker()
        var watches: AuthorizedFileWatches? = AuthorizedFileWatches(opened: { tracker.open($0) }, didClose: { tracker.close($0, $1) })
        try watches?.install(fixture.consent()) {}
        #expect(watches?.count == 1)
        watches = nil
        #expect(tracker.balanced)
        var driver: TimerRefreshDriver? = TimerRefreshDriver()
        weak var weakDriver = driver
        try await driver?.startAuthorized(consent: fixture.consent(), interval: 60) {} failure: { Issue.record("Unexpected watch failure") }
        let timer = try #require(driver?.timer)
        driver = nil
        #expect(weakDriver == nil && !timer.isValid)
        // Swift 6.1 requires weak var; newer compilers warn if it is never
        // mutated. Clear the observer only after checking owner teardown.
        weakDriver = nil
    }

    @Test(arguments: [false, true]) func stoppedOrChangedScopeRejectsLateDebounceEvenIfWaitIgnoresCancellation(changeScope: Bool) async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        try fixture.rewrite("new scope", name: "b.rs")
        let (started, startedContinuation) = AsyncStream<Bool>.makeStream()
        let gate = DeferredDebounce(startedContinuation)
        let driver = TimerRefreshDriver(waitForDebounce: { await gate.wait() })
        defer { driver.stop() }
        let (callbacks, callbackContinuation) = AsyncStream<Bool>.makeStream()
        var ticks = 0
        try await driver.startAuthorized(consent: fixture.consent(), interval: 60) {
            ticks += 1; callbackContinuation.yield(true)
        } failure: { Issue.record("Unexpected watch failure") }
        try fixture.rewrite("real event enters pending debounce")
        #expect(await watchEvent(started))
        driver.stop()
        if changeScope {
            try await driver.startAuthorized(consent: fixture.consent(["b.rs"]), interval: 60) {
                ticks += 1; callbackContinuation.yield(true)
            } failure: { Issue.record("Unexpected watch failure") }
        }
        await gate.release()
        #expect(!(await watchEvent(callbacks, timeout: .milliseconds(800))))
        #expect(ticks == 0 && driver.watchCount == (changeScope ? 1 : 0))
    }
}
