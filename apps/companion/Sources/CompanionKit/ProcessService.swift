import Foundation
import Darwin

public struct ProcessLimits: Sendable {
    public var seconds: Double = 30
    public var stdoutBytes: Int = 1_048_576
    public var stderrBytes: Int = 16_384
    public var inputBytes: Int = 16_384
    public init() {}
}

private final class Cancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    var canceled: Bool { lock.lock(); defer { lock.unlock() }; return value }
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
              FileManager.default.isExecutableFile(atPath: executable.path) else { throw ServiceError.unavailable }
        let (arguments, input) = try command(operation)
        guard input.count <= limits.inputBytes, limits.seconds > 0,
              limits.seconds <= 300, limits.stdoutBytes > 0, limits.stdoutBytes <= 1_048_576,
              limits.stderrBytes > 0, limits.stderrBytes <= 16_384,
              limits.inputBytes > 0, limits.inputBytes <= 16_384 else { throw ServiceError.invalid }
        let cancellation = Cancellation()
        var operationLimits = limits
        if case .query = operation { operationLimits.stdoutBytes = min(limits.stdoutBytes, 8192) }
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
            case .projects:
                let projects = try decoder.decode([Project].self, from: data)
                guard projects.count <= 256, Set(projects.map(\.id)).count == projects.count,
                      projects.allSatisfy({ InputPolicy.identifier($0.id) && InputPolicy.sources($0.sources) }) else { throw ServiceError.invalid }
                return .projects(projects)
            case .project(let id):
                let result = try decoder.decode(Project.self, from: data)
                guard result.id == id else { throw ServiceError.scopeMismatch }
                guard InputPolicy.sources(result.sources) else { throw ServiceError.invalid }
                return .project(result)
            case .index(let id):
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
        case .projects: args = ["project", "list"]
        case .project(let p): args = ["project", "show", try id(p)]
        case .addProject(let p, let root, let files):
            guard root.hasPrefix("/"), !root.contains("\0"), root.utf8.count <= 4096 else { throw ServiceError.invalid }
            args = ["project", "add", try id(p), root] + (try sources(files))
        case .setSources(let p, let files): args = ["project", "sources", try id(p)] + (try sources(files))
        case .index(let p): args = ["index", try id(p)]
        case .query(let p, let text):
            guard !text.isEmpty, text.utf8.count <= 4096, !text.contains("\0") else { throw ServiceError.invalid }
            args = ["query", try id(p), text]
        case .contexts(let p): args = ["context", "list", try id(p)]
        case .context(let p, let c): args = ["context", "show", try id(p), try id(c)]
        case .retireContext(let p, let c): args = ["context", "retire", try id(p), try id(c)]
        case .writeContext(let p, let c, let kind, let text, let update):
            guard ["note", "decision", "constraint", "pitfall"].contains(kind), !text.isEmpty else { throw ServiceError.invalid }
            args = ["context", update ? "update" : "add", try id(p), try id(c), kind]
            input = Data(text.utf8) // Never in argv or diagnostics.
        }
        return (args, input)
    }

    private static func run(executable: URL, directory: URL, arguments: [String], input: Data,
                            limits: ProcessLimits, cancellation: Cancellation) throws -> Data {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ["LANG": "en_US.UTF-8", "LC_ALL": "en_US.UTF-8"]
        process.currentDirectoryURL = directory
        let out = Pipe(), err = Pipe(), stdin = Pipe()
        process.standardOutput = out; process.standardError = err; process.standardInput = stdin
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
        do { try process.run() } catch { throw ServiceError.unavailable }
        try? out.fileHandleForWriting.close(); try? err.fileHandleForWriting.close(); try? stdin.fileHandleForReading.close()
        let deadline = ProcessInfo.processInfo.systemUptime + limits.seconds
        var failure: ServiceError?
        var stoppedAt: Double?
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
            if !process.isRunning { break }
            if failure != nil {
                if stoppedAt == nil { process.terminate(); stoppedAt = now }
                else if now - stoppedAt! >= 0.2 { _ = Darwin.kill(process.processIdentifier, SIGKILL) }
            }
            usleep(5_000)
        }
        process.waitUntilExit()
        drain(stdoutFD, stdout: true); drain(stderrFD, stdout: false)
        if let failure { throw failure }
        guard process.terminationStatus == 0 else { throw ServiceError.failed }
        return output
    }
}
