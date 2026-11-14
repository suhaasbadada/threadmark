import Foundation
import Testing
@testable import CompanionKit

@Suite("Bound comparison process argv and whole-frame admission")
struct ComparisonProcessTests {
    private func adapter(_ mode: String, root: URL, seconds: Double = 30) throws -> ProcessService {
        let directory = root.appendingPathComponent("human-comparison-" + mode)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var limits = ProcessLimits(); limits.seconds = seconds
        return ProcessService(executable: package.appendingPathComponent(".build/debug/CompanionTestProcess"), dataDirectory: directory, limits: limits)
    }
    @Test func exactClosedArgvEmptyStdinAndInclusiveNewlineBudget() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let request = try HumanComparisonRequest(project: comparisonProject, history: comparisonHistory(), from: 1, to: 2)
        for mode in ["valid", "limit"] {
            guard case .humanComparison(let result) = try await adapter(mode, root: fixture.root).perform(.compareHumanContextBound(request)) else { throw ServiceError.invalid }
            #expect(result.removed == "old\r\n" && result.added == "new\n")
            if mode == "limit" { #expect(result.bytes.count == 65536) }
        }
    }
    @Test(arguments: ["duplicate", "wrongpair", "wrongdelta", "wrongflags", "unexpected", "frames", "partial", "no-newline", "overflow"])
    func malformedSubprocessResponsesAreContentFreeFailures(mode: String) async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let request = try HumanComparisonRequest(project: comparisonProject, history: comparisonHistory(), from: 1, to: 2)
        let process = try adapter(mode, root: fixture.root)
        await #expect(throws: mode == "overflow" ? ServiceError.outputLimit : .invalid) {
            try await process.perform(.compareHumanContextBound(request))
        }
    }
    @Test func boundedTimeoutHasNoResponseAdoption() async throws {
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let request = try HumanComparisonRequest(project: comparisonProject, history: comparisonHistory(), from: 1, to: 2)
        let process = try adapter("hang", root: fixture.root, seconds: 0.1)
        await #expect(throws: ServiceError.timedOut) { try await process.perform(.compareHumanContextBound(request)) }
    }
}
