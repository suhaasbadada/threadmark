import Foundation
import Darwin

public struct ProcessLimits: Sendable {
    public var seconds: Double = 30
    public var stdoutBytes: Int = 1_048_576
    public var stderrBytes: Int = 16_384
    public var inputBytes: Int = 4096
    public init() {}
}

private final class Cancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    var canceled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

/// Owned only by the runner's I/O thread. No Foundation Process/dispatch reaper
/// exists for this child. An exited but unreaped child reserves its PID, so an
/// exit between waitpid(WNOHANG)==0 and kill cannot target a recycled identity.
struct OwnedChild {
    let pid: pid_t
    private(set) var finished = false
    private(set) var status: Int32?
    private var terminatedAt: Double?
    private var killed = false

    // Older Swift toolchains make the synthesized memberwise initializer private
    // because lifecycle fields are private. Only a fresh PID may be supplied.
    init(pid: pid_t) { self.pid = pid }

    mutating func step(now: Double, stopping: Bool,
                       wait: (pid_t, UnsafeMutablePointer<Int32>?, Int32) -> pid_t = { Darwin.waitpid($0, $1, $2) },
                       signal: (pid_t, Int32) -> Int32 = { Darwin.kill($0, $1) }) -> Bool {
        guard !finished else { return true }
        var value: Int32 = 0
        let result = wait(pid, &value, WNOHANG)
        if result == pid { status = value; finished = true; return true }
        if result < 0 {
            if errno == EINTR { return false }
            // ECHILD (or another unexpected wait error) means no retained
            // identity: stop ALL signaling, including a pending escalation.
            finished = true; return true
        }
        guard result == 0 else { finished = true; return true }
        if stopping {
            if terminatedAt == nil { _ = signal(pid, SIGTERM); terminatedAt = now }
            else if !killed, now - terminatedAt! >= 0.2 {
                killed = true; _ = signal(pid, SIGKILL)
            }
        }
        return false
    }
}

/// No shell, PATH search, inherited environment, credentials, listener, or sample fallback.
public struct ProcessService: CoreService {
    public let executable: URL?
    public let dataDirectory: URL?
    public var limits: ProcessLimits
    public init(executable: URL? = nil, dataDirectory: URL? = nil, limits: ProcessLimits = .init()) {
        self.executable = executable; self.dataDirectory = dataDirectory; self.limits = limits
    }

    public func perform(_ operation: Operation) async throws -> Reply {
        guard let executable, let dataDirectory,
              executable.isFileURL, dataDirectory.isFileURL,
              executable.path.hasPrefix("/"), dataDirectory.path.hasPrefix("/"),
              !executable.path.contains("\0"), !dataDirectory.path.contains("\0"),
              FileManager.default.isExecutableFile(atPath: executable.path) else { throw ServiceError.unavailable }
        let (arguments, input) = try command(operation)
        guard input.count <= limits.inputBytes, limits.seconds > 0,
              limits.seconds <= 300, limits.stdoutBytes > 0, limits.stdoutBytes <= 1_048_576,
              limits.stderrBytes > 0, limits.stderrBytes <= 16_384,
              limits.inputBytes > 0, limits.inputBytes <= 4096 else { throw ServiceError.invalid }
        let cancellation = Cancellation()
        var operationLimits = limits
        if case .query = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .prepareContext = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
        if case .removeProject = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 1024) }
        let boundedLimits = operationLimits
        let data = try await withTaskCancellationHandler {
            guard !Task.isCancelled else { throw ServiceError.canceled }
            return try await Task.detached {
                try Self.run(executable: executable, directory: dataDirectory,
                             arguments: ["--data-dir", dataDirectory.path] + arguments,
                             input: input, limits: boundedLimits, cancellation: cancellation)
            }.value
        } onCancel: { cancellation.cancel() }
        guard !Task.isCancelled else { throw ServiceError.canceled }
        do {
            let decoder = JSONDecoder()
            switch operation {
            case .removeProject(let id, _, _):
                guard data.count <= 1024 else { throw ServiceError.outputLimit }
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      Set(object.keys) == ["project", "removed", "retention_limits"] else { throw ServiceError.invalid }
                let result = try decoder.decode(RemovedProject.self, from: data)
                try result.validate(project: id)
                return .removed(result)
            case .prepareContext(let id, _, let original):
                guard data.count <= 8192 else { throw ServiceError.outputLimit }
                let result = try decoder.decode(ContextPreview.self, from: data)
                try result.validate(project: id, original: original)
                return .preview(result)
            case .projects:
                let projects = try decoder.decode([Project].self, from: data)
                guard projects.count <= 64, Set(projects.map(\.id)).count == projects.count,
                      projects.allSatisfy({ InputPolicy.identifier($0.id) && InputPolicy.sources($0.sources) }) else { throw ServiceError.invalid }
                return .projects(projects)
            case .project(let id):
                let result = try decoder.decode(Project.self, from: data)
                guard result.id == id else { throw ServiceError.scopeMismatch }
                guard InputPolicy.sources(result.sources) else { throw ServiceError.invalid }
                return .project(result)
            case .index(let id), .indexBound(let id, _, _, _):
                let result = try decoder.decode(IndexReport.self, from: data)
                guard result.project == id else { throw ServiceError.scopeMismatch }
                guard result.files >= 0, result.files <= 64, result.anchors >= 0 else { throw ServiceError.invalid }
                return .indexed(result)
            case .query(let id, _):
                guard data.count <= 8192 else { throw ServiceError.outputLimit }
                let result = try decoder.decode(QueryReport.self, from: data)
                guard result.project == id, result.results.allSatisfy({ $0.project == id }) else { throw ServiceError.scopeMismatch }
                guard result.results.count <= 8, Self.currentness(result.currentness), result.results.allSatisfy({
                    $0.line > 0 && $0.kind == "observed-source-line" && Self.currentness($0.currentness) && InputPolicy.sources([$0.path])
                }) else { throw ServiceError.invalid }
                return .query(result)
            case .contexts(let id):
                let result = try decoder.decode(ContextList.self, from: data)
                guard result.project == id else { throw ServiceError.scopeMismatch }
                guard result.contexts.allSatisfy({ $0.producer == "human-authored" && $0.revision > 0 }) else { throw ServiceError.invalid }
                return .contexts(result)
            case .context(let id, let context):
                let result = try decoder.decode(ContextHistory.self, from: data)
                guard result.project == id, result.id == context else { throw ServiceError.scopeMismatch }
                guard result.producer == "human-authored", result.history.allSatisfy({ $0.revision > 0 }) else { throw ServiceError.invalid }
                return .context(result)
            default:
                _ = try decoder.decode(JSONValue.self, from: data)
                return .acknowledged
            }
        } catch let error as ServiceError { throw error }
        catch { throw ServiceError.invalid }
    }

    private static func currentness(_ value: String) -> Bool {
        value == "current-at-read" || value == "stale-or-unindexed"
    }
    private func command(_ operation: Operation) throws -> ([String], Data) {
        func id(_ value: String) throws -> String {
            guard InputPolicy.identifier(value) else { throw ServiceError.invalid }; return value
        }
        func sources(_ values: [String]) throws -> [String] {
            guard InputPolicy.sources(values) else { throw ServiceError.invalid }; return values
        }
        var args: [String]
        var input = Data()
        switch operation {
        case .removeProject(let p, let root, let identity):
            guard InputPolicy.removal(root: root, identity: identity) else { throw ServiceError.invalid }
            args = ["project", "remove", try id(p), "--confirm-remove-local-data", "--expected-root", root, "--expected-root-identity", identity]
        case .prepareContext(let p, let query, let original):
            guard InputPolicy.preparation(query: query, original: original) else { throw ServiceError.invalid }
            args = ["context", "prepare", try id(p), query]
            input = Data(original.utf8) // Original is ONLY stdin, never argv.
        case .projects: args = ["project", "list"]
        case .project(let p): args = ["project", "show", try id(p)]
        case .addProject(let p, let root, let files):
            guard root.hasPrefix("/"), !root.contains("\0"), root.utf8.count <= 4096 else { throw ServiceError.invalid }
            args = ["project", "add", try id(p), root] + (try sources(files))
        case .setSources(let p, let files): args = ["project", "sources", try id(p)] + (try sources(files))
        case .index(let p): args = ["index", try id(p)]
        case .indexBound(let p, let root, let identity, let files):
            guard InputPolicy.removal(root: root, identity: identity), !files.isEmpty else { throw ServiceError.invalid }
            args = ["index", try id(p), "--expected-root", root, "--expected-root-identity", identity, "--expected-sources"] + (try sources(files))
        case .query(let p, let text):
            guard !text.isEmpty, text.utf8.count <= 256, !text.contains("\0") else { throw ServiceError.invalid }
            args = ["query", try id(p), text]
        case .contexts(let p): args = ["context", "list", try id(p)]
        case .context(let p, let c): args = ["context", "show", try id(p), try id(c)]
        case .retireContext(let p, let c): args = ["context", "retire", try id(p), try id(c)]
        case .writeContext(let p, let c, let kind, let text, let update):
            guard InputPolicy.contextKinds.contains(kind), !text.isEmpty else { throw ServiceError.invalid }
            args = ["context", update ? "update" : "add", try id(p), try id(c), kind]
            input = Data(text.utf8) // Never in argv or diagnostics.
        }
        return (args, input)
    }

    private static func run(executable: URL, directory: URL, arguments: [String], input: Data,
                            limits: ProcessLimits, cancellation: Cancellation) throws -> Data {
        let out = Pipe(), err = Pipe(), stdin = Pipe()
        defer {
            for handle in [out.fileHandleForReading, out.fileHandleForWriting, err.fileHandleForReading,
                           err.fileHandleForWriting, stdin.fileHandleForReading, stdin.fileHandleForWriting] { try? handle.close() }
        }
        let stdoutFD = out.fileHandleForReading.fileDescriptor
        let stderrFD = err.fileHandleForReading.fileDescriptor
        let inputFD = stdin.fileHandleForWriting.fileDescriptor
        for fd in [stdoutFD, stderrFD, inputFD] {
            let flags = fcntl(fd, F_GETFL)
            guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else { throw ServiceError.unavailable }
        }
        // Suppress SIGPIPE for only this owned pipe, never change a global signal handler.
        guard fcntl(inputFD, F_SETNOSIGPIPE, 1) == 0 else { throw ServiceError.unavailable }
        guard !cancellation.canceled else { throw ServiceError.canceled }
        // Core, not the shell, creates a new store with mode 0700. Spawn in its
        // existing parent until that first explicit core operation creates it.
        let cwd = FileManager.default.fileExists(atPath: directory.path) ? directory : directory.deletingLastPathComponent()
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else { throw ServiceError.unavailable }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawnattr_init(&attributes) == 0 else { throw ServiceError.unavailable }
        defer { posix_spawnattr_destroy(&attributes) }
        guard posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT)) == 0,
              posix_spawn_file_actions_adddup2(&actions, stdin.fileHandleForReading.fileDescriptor, STDIN_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, out.fileHandleForWriting.fileDescriptor, STDOUT_FILENO) == 0,
              posix_spawn_file_actions_adddup2(&actions, err.fileHandleForWriting.fileDescriptor, STDERR_FILENO) == 0,
              posix_spawn_file_actions_addchdir_np(&actions, cwd.path) == 0 else { throw ServiceError.unavailable }
        // strdup-backed vectors stay alive through spawn; no ambient environ.
        let argv = ([executable.path] + arguments).map { $0.withCString { strdup($0) } } + [nil]
        let environmentValues: [String] = ["LANG=en_US.UTF-8", "LC_ALL=en_US.UTF-8"]
        let env = environmentValues.map { $0.withCString { strdup($0) } } + [nil]
        defer { for pointer in argv + env { free(pointer) } }
        guard argv.dropLast().allSatisfy({ $0 != nil }), env.dropLast().allSatisfy({ $0 != nil }) else { throw ServiceError.unavailable }
        var pid: pid_t = 0
        let spawned = argv.withUnsafeBufferPointer { args in
            env.withUnsafeBufferPointer { environment in
                posix_spawn(&pid, executable.path, &actions, &attributes, args.baseAddress!, environment.baseAddress!)
            }
        }
        guard spawned == 0 else { throw ServiceError.unavailable }
        var child = OwnedChild(pid: pid)
        try? out.fileHandleForWriting.close(); try? err.fileHandleForWriting.close(); try? stdin.fileHandleForReading.close()
        let deadline = ProcessInfo.processInfo.systemUptime + limits.seconds
        var failure: ServiceError?
        var output = Data(), stderrCount = 0, inputOffset = 0, inputClosed = false
        func drain(_ fd: Int32, stdout: Bool) {
            var buffer = [UInt8](repeating: 0, count: 4096)
            // Bound each pass even if a malicious child keeps writing forever.
            for _ in 0..<32 {
                let count = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, $0.count) }
                if count <= 0 { break }
                if stdout {
                    if output.count + count > limits.stdoutBytes { failure = failure ?? .outputLimit; break }
                    output.append(contentsOf: buffer.prefix(count))
                } else {
                    stderrCount += count
                    if stderrCount > limits.stderrBytes { failure = failure ?? .outputLimit; break }
                }
            }
        }
        while true {
            let now = ProcessInfo.processInfo.systemUptime
            if cancellation.canceled { failure = .canceled }
            if now >= deadline { failure = failure ?? .timedOut }
            drain(stdoutFD, stdout: true); drain(stderrFD, stdout: false)
            if !inputClosed {
                if inputOffset < input.count && failure == nil {
                    let written = input.withUnsafeBytes { Darwin.write(inputFD, $0.baseAddress!.advanced(by: inputOffset), input.count - inputOffset) }
                    if written > 0 { inputOffset += written }
                    else if written < 0 && errno != EAGAIN && errno != EINTR { failure = .failed }
                }
                if inputOffset == input.count || failure != nil {
                    try? stdin.fileHandleForWriting.close(); inputClosed = true
                }
            }
            if child.step(now: now, stopping: failure != nil) { break }
            usleep(5_000)
        }
        drain(stdoutFD, stdout: true); drain(stderrFD, stdout: false)
        if let failure { throw failure }
        guard child.status == 0 else { throw ServiceError.failed }
        return output
    }
}
