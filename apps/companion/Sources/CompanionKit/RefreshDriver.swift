import Foundation

/// One owned, low-frequency driver. Tests inject ticks, never wall-clock sleeps.
@MainActor
public protocol RefreshDriver: AnyObject {
    func start(interval: TimeInterval, tick: @escaping @MainActor @Sendable () -> Void)
    func stop()
}

@MainActor
public final class TimerRefreshDriver: RefreshDriver {
    private(set) var timer: Timer?
    public init() {}
    public func start(interval: TimeInterval, tick: @escaping @MainActor @Sendable () -> Void) {
        stop()
        precondition(interval >= 60)
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { tick() }
        }
        timer.tolerance = 5
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    public func stop() { timer?.invalidate(); timer = nil }
}

/// Session-only exact approval. Snapshot changes do not grant any new sources.
public struct AutomaticRefreshConsent: Equatable, Sendable {
    public let projectID: String
    public let root: String
    public let rootIdentity: String
    public let sources: [String]
    public let scopeRevision: UInt64
}
