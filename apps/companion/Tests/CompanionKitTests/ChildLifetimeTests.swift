import Darwin
import Foundation
import Testing
@testable import CompanionKit

@Suite("Sole-reaper child identity regression")
struct ChildLifetimeTests {
    @Test func exitBetweenWaitAndEscalationRetainsIdentityUntilReap() {
        var child = OwnedChild(pid: 123) // Synthetic PID; injected calls only.
        var signals: [Int32] = []
        var exited = false, reaped = false
        let send: (pid_t, Int32) -> Int32 = { _, signal in
            #expect(!reaped)
            signals.append(signal); return 0
        }
        let initial = child.step(now: 0, stopping: true, wait: { _, _, _ in 0 }, signal: send)
        #expect(!initial)
        // Child exits immediately after waitpid returned 0. It is a zombie:
        // the PID cannot be recycled because nobody else reaps this child.
        let escalating = child.step(now: 0.21, stopping: true, wait: { _, _, _ in exited = true; return 0 }, signal: send)
        #expect(!escalating)
        #expect(exited && signals == [SIGTERM, SIGKILL])
        // No repeated KILL while waiting for exit/reap.
        let awaitingReap = child.step(now: 0.3, stopping: true, wait: { _, _, _ in 0 }, signal: send)
        #expect(!awaitingReap)
        #expect(signals == [SIGTERM, SIGKILL])
        let justReaped = child.step(now: 0.4, stopping: true, wait: { pid, status, _ in
            status?.pointee = 0; reaped = true; return pid
        }, signal: send)
        #expect(justReaped)
        let afterReap = child.step(now: 1, stopping: true, wait: { _, _, _ in
            Issue.record("Never wait on a reaped/reusable PID"); return 0
        }, signal: send)
        #expect(afterReap)
        #expect(signals == [SIGTERM, SIGKILL])
    }
    @Test func reapedOrLostIdentityImmediatelySuppressesEscalation() {
        for lost in [false, true] {
            var child = OwnedChild(pid: 123)
            var signals: [Int32] = []
            let send: (pid_t, Int32) -> Int32 = { _, signal in signals.append(signal); return 0 }
            let initial = child.step(now: 0, stopping: true, wait: { _, _, _ in 0 }, signal: send)
            #expect(!initial)
            let finished = child.step(now: 0.21, stopping: true, wait: { pid, status, _ in
                if lost { errno = ECHILD; return -1 }
                status?.pointee = 0; return pid
            }, signal: send)
            #expect(finished)
            let later = child.step(now: 0.5, stopping: true, wait: { _, _, _ in 0 }, signal: send)
            #expect(later)
            #expect(signals == [SIGTERM])
        }
    }
}
