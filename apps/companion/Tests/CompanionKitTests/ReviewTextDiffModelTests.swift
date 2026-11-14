import Darwin
import Foundation
import Testing
@testable import CompanionKit

/// One bounded synthetic numeric-loopback response, task-owned and joined.
private final class DiffReviewPeer: @unchecked Sendable {
    private let lock = NSLock()
    private let group = DispatchGroup()
    private let listener: Int32
    private var stopped = false
    private var calls = 0
    let endpoint: String
    init(questions: Bool) throws {
        let listener = socket(AF_INET, SOCK_STREAM, 0)
        self.listener = listener
        guard listener >= 0 else { throw ServiceError.unavailable }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET); address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(listener, 1) == 0, fcntl(listener, F_SETFL, O_NONBLOCK) == 0 else {
            close(listener); throw ServiceError.unavailable
        }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &length) }
        }
        guard named == 0 else { close(listener); throw ServiceError.unavailable }
        endpoint = "http://127.0.0.1:\(UInt16(bigEndian: address.sin_port))/v1/chat/completions"
        group.enter(); DispatchQueue.global().async { self.serve(questions: questions); self.group.leave() }
    }
    var count: Int { lock.lock(); defer { lock.unlock() }; return calls }
    private var live: Bool { lock.lock(); defer { lock.unlock() }; return !stopped }
    func stop() -> Bool {
        lock.lock(); stopped = true; lock.unlock()
        guard group.wait(timeout: .now() + 3) == .success else { return false }
        close(listener); return true
    }
    private func serve(questions: Bool) {
        let deadline = ProcessInfo.processInfo.systemUptime + 20
        func active() -> Bool { live && ProcessInfo.processInfo.systemUptime < deadline }
        var fd: Int32 = -1
        while active() {
            fd = accept(listener, nil, nil)
            if fd >= 0 { break }; usleep(2_000)
        }
        guard fd >= 0 else { return }
        defer { close(fd) }
        lock.lock(); calls += 1; lock.unlock()
        var one: Int32 = 1
        guard fcntl(fd, F_SETFL, O_NONBLOCK) == 0,
              setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size)) == 0 else { return }
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
                      let size = Int(field.dropFirst(15).trimmingCharacters(in: .whitespaces)), (0...65536).contains(size) else { return }
                if bytes.count >= end.upperBound + size { complete = true; break }
            }
            usleep(2_000)
        }
        guard complete else { return }
        let brief: [String: Any] = ["objective": "Inspect ID_A; do NOT deploy.", "output_expectations": "Suggest checks.",
            "unknowns": [String](), "questions": questions ? ["Synthetic permission question?"] : [String]()]
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

@Suite("Text comparison on actual model review lifecycle", .serialized,
       .enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
struct ReviewTextDiffModelTests {
    @Test @MainActor func previewEditQuestionsAndActualApprovedValues() async throws {
        for questions in [false, true] {
            let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
            let peer = try DiffReviewPeer(questions: questions); defer { #expect(peer.stop()) }
            try fixture.rewrite("fn synthetic_source() {}\n")
            let service = ProcessService(executable: URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])),
                dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "diff-store"))
            let model = CompanionModel(service: service, configured: true)
            model.addProject(id: "alpha", root: fixture.root.path, sources: ["a.rs"]); await model.waitForOperation()
            model.build(); await model.waitForOperation()
            let original = "Do NOT deploy ID_A; exclude prod. e\u{301}\r\n"
            model.editPreparation(query: "fn", original: original)
            model.requestRefinement(settings: try refinementSettings(peer.endpoint)); await model.waitForOperation()
            let consent = try #require(model.pendingRefinement)
            model.confirmRetainedRefinement(consent, settings: consent.settings); await model.waitForRetainedPreparation()
            let first = try #require(model.retainedReview.challenge)
            let initial = ReviewTextDiff(original: model.retainedReview.original, proposed: try #require(model.retainedReview.proposed))
            #expect(initial.original.utf8.elementsEqual(original.utf8) && !initial.identical)
            let questionList = model.retainedReview.questions
            model.editRetainedReview(first, objective: "Do NOT deploy ID_B; exclude staging. é", outputExpectations: "Show ID_B checks.")
            await model.waitForRetainedAction()
            let next = try #require(model.retainedReview.challenge)
            let edited = ReviewTextDiff(original: model.retainedReview.original, proposed: try #require(model.retainedReview.proposed))
            #expect(next != first && !edited.proposed.utf8.elementsEqual(initial.proposed.utf8))
            #expect(edited.proposed.contains("ID_B") && edited.original.utf8.elementsEqual(original.utf8))
            #expect(model.originalDraft.utf8.elementsEqual(original.utf8) && model.retainedReview.questions == questionList)
            #expect(peer.count == 1) // Comparing and Edit do not start inference.
            if questions {
                model.useRetainedPrepared(next); await model.waitForRetainedAction()
                #expect(model.retainedReview.state == .reviewRequired && !questionList.isEmpty)
                model.useRetainedOriginal(next)
            } else {
                model.useRetainedPrepared(first); await model.waitForRetainedAction()
                #expect(model.retainedReview.state == .reviewRequired)
                model.useRetainedPrepared(next)
            }
            await model.waitForRetainedAction()
            guard case .approvedValue(let value) = model.retainedReview.state else {
                Issue.record("Missing explicit actual engine value"); await model.shutdown(); continue
            }
            let approved = ReviewTextDiff(original: model.retainedReview.original, proposed: value.text)
            #expect(approved.proposed.utf8.elementsEqual((questions ? original : edited.proposed).utf8))
            #expect(approved.identical == questions && value.delivery == "DeliveryNotAttempted")
            #expect(model.originalDraft.utf8.elementsEqual(original.utf8) && peer.count == 1)
            await model.shutdown()
        }
    }
}
