import Darwin
import Foundation

/// Single-slot mailbox. The I/O worker is the sole pipe and child/reaper owner.
private final class RetainedReviewMailbox: @unchecked Sendable {
    struct Work {
        let frame: Data
        let reply: CheckedContinuation<RetainedReviewEvent, any Error>
    }
    private let lock = NSLock()
    private var queued: Work?
    private var occupied = false
    private var stopped = false
    private var ended = false
    private var reason: ServiceError = .failed
    private var childPID: pid_t?

    func record(pid: pid_t) { lock.lock(); childPID = pid; lock.unlock() }
    var pid: pid_t? { lock.lock(); defer { lock.unlock() }; return childPID }

    func enqueue(_ work: Work) {
        lock.lock()
        if stopped || ended || occupied {
            let error: ServiceError = stopped ? .canceled : (ended ? reason : .invalid)
            if occupied { stopped = true } // Backpressure overflow fails closed.
            lock.unlock(); work.reply.resume(throwing: error); return
        }
        occupied = true; queued = work; lock.unlock()
    }
    func take() -> Work? {
        lock.lock(); defer { lock.unlock() }
        let work = queued; queued = nil; return work
    }
    func release() { lock.lock(); occupied = false; lock.unlock() }
    func cancel() { lock.lock(); stopped = true; lock.unlock() }
    var canceled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func finish(_ error: ServiceError?) {
        lock.lock(); ended = true; reason = error ?? .failed
        let work = queued; queued = nil; occupied = false; lock.unlock()
        work?.reply.resume(throwing: error ?? ServiceError.failed)
    }
}

/// One finite private-pipe J child. No shell, inherited environment or Foundation
/// Process. `cancelAndJoin` returns only after the worker closes all fds and reaps.
final class RetainedReviewProcess: Sendable {
    private let mailbox: RetainedReviewMailbox
    private let worker: Task<ServiceError?, Never>

    init(executable: URL, store: URL, consent: RefinementConsent, seconds: Double = 300) throws {
        try consent.validate()
        guard executable.isFileURL, executable.path.hasPrefix("/"), !executable.path.contains("\0"),
              FileManager.default.isExecutableFile(atPath: executable.path),
              seconds > 0, seconds <= 300 else { throw ServiceError.invalid }
        let store = try StoreSelection.existingDirectory(store)
        guard case .string(let identity) = consent.project.root_identity,
              case .string(let snapshot) = consent.project.snapshot, let incarnation = consent.project.incarnation else { throw ServiceError.invalid }
        let arguments = ["--data-dir", store.path, "refine", "review", consent.project.id, consent.query,
            "--profile", consent.profile.id, "--model", consent.profile.model, "--endpoint", consent.profile.endpoint,
            "--expected-root", consent.project.root, "--expected-root-identity", identity,
            "--expected-incarnation", incarnation, "--expected-snapshot", snapshot, "--confirm-local-inference"]
        let mailbox = RetainedReviewMailbox(); self.mailbox = mailbox
        worker = Task.detached {
            let result: ServiceError?
            do { try Self.run(executable: executable, store: store, arguments: arguments, consent: consent, seconds: seconds, mailbox: mailbox); result = nil }
            catch let failure as ServiceError { result = failure }
            catch { result = .failed }
            mailbox.finish(result); return result
        }
    }

    deinit { mailbox.cancel() }

    func exchange(_ command: RetainedReviewCommand) async throws -> RetainedReviewEvent {
        let frame = try command.frame()
        return try await withTaskCancellationHandler {
            if Task.isCancelled { throw ServiceError.canceled }
            return try await withCheckedThrowingContinuation { mailbox.enqueue(.init(frame: frame, reply: $0)) }
        } onCancel: { mailbox.cancel() }
    }
    func cancel() { mailbox.cancel() }
    var pid: pid_t? { mailbox.pid }
    func join() async -> ServiceError? { await worker.value }
    var completion: Task<ServiceError?, Never> { worker }
    func cancelAndJoin() async { mailbox.cancel(); _ = await worker.value }

    private static func run(executable: URL, store: URL, arguments: [String], consent: RefinementConsent,
                            seconds: Double, mailbox: RetainedReviewMailbox) throws {
        let input = Pipe(), output = Pipe(), diagnostics = Pipe()
        let handles = [input.fileHandleForReading, input.fileHandleForWriting, output.fileHandleForReading,
                       output.fileHandleForWriting, diagnostics.fileHandleForReading, diagnostics.fileHandleForWriting]
        defer { for handle in handles { try? handle.close() } }
        let inputFD = input.fileHandleForWriting.fileDescriptor
        let outputFD = output.fileHandleForReading.fileDescriptor
        let errorFD = diagnostics.fileHandleForReading.fileDescriptor
        for fd in [inputFD, outputFD, errorFD] {
            let flags = fcntl(fd, F_GETFL)
            guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else { throw ServiceError.unavailable }
        }
        guard fcntl(inputFD, F_SETNOSIGPIPE, 1) == 0 else { throw ServiceError.unavailable }
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { throw ServiceError.unavailable }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawnattr_init(&attributes) == 0 else { throw ServiceError.unavailable }
        defer { posix_spawnattr_destroy(&attributes) }
        guard posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0,
              posix_spawn_file_actions_adddup2(&actions, input.fileHandleForReading.fileDescriptor, STDIN_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, output.fileHandleForWriting.fileDescriptor, STDOUT_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, diagnostics.fileHandleForWriting.fileDescriptor, STDERR_FILENO) == 0,
              posix_spawn_file_actions_addchdir_np(&actions, store.path) == 0 else { throw ServiceError.unavailable }
        let argv = ([executable.path] + arguments).map { $0.withCString { strdup($0) } } + [nil]
        let env = ["LANG=en_US.UTF-8", "LC_ALL=en_US.UTF-8"].map { $0.withCString { strdup($0) } } + [nil]
        defer { for pointer in argv + env { free(pointer) } }
        guard argv.dropLast().allSatisfy({ $0 != nil }), env.dropLast().allSatisfy({ $0 != nil }), !mailbox.canceled else { throw ServiceError.canceled }
        var pid: pid_t = 0
        let spawned = argv.withUnsafeBufferPointer { args in
            env.withUnsafeBufferPointer { environment in
                posix_spawn(&pid, executable.path, &actions, &attributes, args.baseAddress!, environment.baseAddress!)
            }
        }
        guard spawned == 0 else { throw ServiceError.unavailable }
        mailbox.record(pid: pid)
        var child = OwnedChild(pid: pid)
        try? input.fileHandleForReading.close(); try? output.fileHandleForWriting.close(); try? diagnostics.fileHandleForWriting.close()
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        var failure: ServiceError?
        var active: RetainedReviewMailbox.Work?
        var offset = 0, sentFrames = 0, sentBytes = 0, receivedFrames = 0, receivedBytes = 0, errorBytes = 0
        var buffer = Data(), terminal: RetainedReviewEvent?, terminalDeadline: Double?
        var inputClosed = false, eof = false
        func closeInput() { if !inputClosed { try? input.fileHandleForWriting.close(); inputClosed = true } }
        func drainOutput() {
            var bytes = [UInt8](repeating: 0, count: 4096)
            for _ in 0..<4 {
                let count = bytes.withUnsafeMutableBytes { Darwin.read(outputFD, $0.baseAddress, $0.count) }
                if count == 0 { eof = true; return }
                if count < 0 {
                    if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { failure = failure ?? .failed }
                    return
                }
                receivedBytes += count
                guard receivedBytes <= 65536 else { failure = .outputLimit; return }
                guard failure == nil else { return } // Never publish after cancellation/failure.
                buffer.append(contentsOf: bytes.prefix(count))
                while let end = buffer.firstIndex(of: 10) {
                    let frame = Data(buffer[...end]); buffer.removeSubrange(...end)
                    receivedFrames += 1
                    guard receivedFrames <= 8, frame.count <= 8192, terminal == nil,
                          let work = active, offset == work.frame.count else { failure = .invalid; return }
                    do {
                        let event = try RetainedReviewEvent.decode(frame, consent: consent)
                        if event.terminal {
                            terminal = event; terminalDeadline = ProcessInfo.processInfo.systemUptime + 1
                            closeInput()
                        } else {
                            active = nil; mailbox.release(); work.reply.resume(returning: event)
                        }
                    } catch { failure = .invalid; return }
                }
                if buffer.count >= 8192 { failure = .outputLimit; return }
            }
        }
        while true {
            let now = ProcessInfo.processInfo.systemUptime
            if mailbox.canceled { failure = .canceled }
            if now >= deadline { failure = failure ?? .timedOut }
            if let terminalDeadline, now >= terminalDeadline { failure = failure ?? .timedOut }
            if failure == nil && terminal == nil && active == nil, let work = mailbox.take() {
                active = work; offset = 0; sentFrames += 1; sentBytes += work.frame.count
                if sentFrames > 8 || sentBytes > 65536 { failure = .outputLimit }
            }
            if failure == nil && !inputClosed, let work = active, offset < work.frame.count {
                let written = work.frame.withUnsafeBytes { Darwin.write(inputFD, $0.baseAddress!.advanced(by: offset), work.frame.count - offset) }
                if written > 0 { offset += written }
                else if written < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { failure = .failed }
            }
            drainOutput()
            var diagnostic = [UInt8](repeating: 0, count: 1024)
            for _ in 0..<4 {
                let count = diagnostic.withUnsafeMutableBytes { Darwin.read(errorFD, $0.baseAddress, $0.count) }
                if count <= 0 { break }; errorBytes += count
                if errorBytes > 16384 { failure = .outputLimit; break }
            }
            if eof && terminal == nil { failure = failure ?? .failed }
            if failure != nil { closeInput() }
            if child.step(now: now, stopping: failure != nil) { break }
            usleep(2_000)
        }
        drainOutput(); closeInput()
        if mailbox.canceled { failure = .canceled }
        if !buffer.isEmpty { failure = failure ?? .invalid }
        if let terminal, terminal.event == "handoff", child.status != 0 { failure = failure ?? .failed }
        // No reply (including terminal/cancellation) precedes descriptor teardown.
        for handle in handles { try? handle.close() }
        if let failure { active?.reply.resume(throwing: failure); throw failure }
        guard let terminal, let work = active else {
            active?.reply.resume(throwing: ServiceError.failed); throw ServiceError.failed
        }
        mailbox.release(); work.reply.resume(returning: terminal)
    }
}
