import Foundation
@testable import CompanionKit

@MainActor
final class ManualRefreshDriver: RefreshDriver {
    private var tick: (@MainActor @Sendable () -> Void)?
    private(set) var starts = 0
    private(set) var stops = 0
    private(set) var interval: TimeInterval?
    var active: Bool { tick != nil }
    func start(consent: AutomaticRefreshConsent, service: any CoreService, interval: TimeInterval,
               ready: @escaping @MainActor @Sendable () -> Void,
               tick: @escaping @MainActor @Sendable () -> Void,
               failure: @escaping @MainActor @Sendable () -> Void) throws {
        starts += 1; self.interval = interval; self.tick = tick
        ready()
    }
    func stop() { stops += 1; tick = nil }
    func shutdown() async { stop() }
    func fire() { tick?() }
}
