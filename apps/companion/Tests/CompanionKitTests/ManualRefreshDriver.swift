import Foundation
@testable import CompanionKit

@MainActor
final class ManualRefreshDriver: RefreshDriver {
    private var tick: (@MainActor @Sendable () -> Void)?
    private(set) var starts = 0
    private(set) var stops = 0
    private(set) var interval: TimeInterval?
    var active: Bool { tick != nil }
    func start(interval: TimeInterval, tick: @escaping @MainActor @Sendable () -> Void) {
        starts += 1; self.interval = interval; self.tick = tick
    }
    func stop() { stops += 1; tick = nil }
    func fire() { tick?() }
}
