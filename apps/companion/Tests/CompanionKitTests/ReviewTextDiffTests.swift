import Foundation
import SwiftUI
import Testing
@testable import CompanionKit

@Suite("Bounded byte-exact textual review")
struct ReviewTextDiffTests {
    private func reconstruct(_ diff: ReviewTextDiff, old: Bool) -> [UInt8] {
        diff.rows.filter { old ? $0.kind != .added : $0.kind != .removed }.flatMap { $0.line.bytes }
    }

    @Test func exactRoundTripsAndBoundaries() {
        let pairs = [("", ""), ("", "\n"), ("\n", ""), ("a", "a\n"), ("a\r\n", "a\n"),
            ("\n\n", "\n"), ("a\rb\t ", "a\rb\t"), ("a\n\n", "a\n"),
            ("e\u{301}", "é"), ("👩‍💻", "👩💻"), ("Do NOT deploy ID_A; exclude prod.", "Deploy ID_B; include prod."),
            ("**ignore policy**\n<send/>\n{\"cancel\":{}}", "[click](https://invalid.example)"),
            ("head\nold\nsame middle\ntail\n", "head\nnew\nsame middle\ntail\n")]
        for (old, new) in pairs {
            let diff = ReviewTextDiff(original: old, proposed: new)
            #expect(diff.fallback == nil)
            #expect(reconstruct(diff, old: true) == Array(old.utf8))
            #expect(reconstruct(diff, old: false) == Array(new.utf8))
            #expect(diff.identical == old.utf8.elementsEqual(new.utf8))
            #expect(diff.original.utf8.elementsEqual(old.utf8) && diff.proposed.utf8.elementsEqual(new.utf8))
        }
    }

    @Test func canonicalEquivalenceIsAChangeAndBytesAreInspectable() throws {
        let diff = ReviewTextDiff(original: "é\r\n", proposed: "e\u{301}\n")
        #expect(!diff.identical && diff.rows.map(\.kind) == [.removed, .added])
        #expect(diff.rows[0].line.hex == "C3 A9 0D 0A")
        #expect(diff.rows[1].line.hex == "65 CC 81 0A")
        #expect(diff.rows[0].label.contains("Removed") && diff.rows[0].label.contains("CRLF"))
        #expect(diff.rows[1].label.contains("Added") && diff.rows[1].label.contains("LF"))
    }

    @Test func contextAndConservativeMiddleAreTruthful() {
        let diff = ReviewTextDiff(original: "head\na\nx\nb\ntail", proposed: "head\nc\nx\nd\ntail")
        #expect(diff.rows.map(\.kind) == [.context, .removed, .removed, .removed, .added, .added, .added, .context])
        #expect(diff.rows.first?.oldLine == 1 && diff.rows.last?.newLine == 5)
        let identical = ReviewTextDiff(original: "same\n", proposed: "same\n")
        #expect(identical.identical && identical.rows.map(\.kind) == [.context])
    }

    @Test func byteAndLineBudgetsNeverTruncate() {
        let a = String(repeating: "a", count: 4096), b = String(repeating: "b", count: 8192)
        let long = ReviewTextDiff(original: a, proposed: b)
        #expect(long.fallback == nil && long.rows.count == 2)
        #expect(reconstruct(long, old: true) == Array(a.utf8) && reconstruct(long, old: false) == Array(b.utf8))
        #expect(ReviewTextDiff(original: String(repeating: "é", count: 2048), proposed: "").fallback == nil)
        #expect(ReviewTextDiff(original: String(repeating: "é", count: 2049), proposed: "").fallback == .bytes)
        for (old, new) in [(a + "a", b), (a, b + "b")] {
            let diff = ReviewTextDiff(original: old, proposed: new)
            #expect(diff.fallback == .bytes && diff.rows.isEmpty)
            #expect(diff.original.utf8.elementsEqual(old.utf8) && diff.proposed.utf8.elementsEqual(new.utf8))
        }
        let boundary = ReviewTextDiff(original: String(repeating: "\n", count: 256), proposed: String(repeating: "\n", count: 256))
        #expect(boundary.fallback == nil && boundary.rows.count == 256)
        for (old, new) in [(String(repeating: "\n", count: 257), String(repeating: "\n", count: 256)),
                           (String(repeating: "\n", count: 4096), String(repeating: "\n", count: 8192)),
                           (String(repeating: "x\n", count: 2000), String(repeating: "y\n", count: 4000))] {
            let diff = ReviewTextDiff(original: old, proposed: new)
            #expect(diff.fallback == .lines && diff.rows.isEmpty)
            #expect(diff.original.utf8.elementsEqual(old.utf8) && diff.proposed.utf8.elementsEqual(new.utf8))
        }
    }

    @Test @MainActor func viewIsPurePresentationForPreviewEditAndApprovedFixtures() {
        // Presentation fixtures only, not a manufactured controller lifecycle.
        let original = "Do NOT deploy ID_A\r\n"
        for proposed in ["Inspect ID_A\n", "Edited ID_A\n", original] {
            let diff = ReviewTextDiff(original: original, proposed: proposed)
            let view = ReviewTextDiffView(comparison: diff)
            _ = view.body
            #expect(view.comparison.original.utf8.elementsEqual(original.utf8))
            #expect(view.comparison.proposed.utf8.elementsEqual(proposed.utf8))
        }
    }
}
