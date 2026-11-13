import Foundation
import Darwin

/// Opaque core-owned metadata; the shell does not infer freshness or authority from it.
public enum JSONValue: Codable, Equatable, Sendable, CustomStringConvertible {
    case string(String), number(Double), bool(Bool), array([JSONValue]), object([String: JSONValue]), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    public var description: String {
        guard let data = try? JSONEncoder().encode(self), let text = String(data: data, encoding: .utf8) else { return "Unknown" }
        if case .string(let value) = self { return value }
        return text
    }
}

public struct Project: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let root: String
    public let root_identity: JSONValue?
    public let sources: [String]
    public let snapshot: JSONValue?
    public init(id: String, root: String, sources: [String], snapshot: JSONValue? = nil) {
        self.id = id; self.root = root; self.sources = sources; self.snapshot = snapshot; root_identity = nil
    }
}
public struct IndexReport: Codable, Sendable {
    public let project: String
    public let snapshot: JSONValue
    public let files: Int
    public let anchors: Int
    public let coverage: JSONValue
    public let empty: Bool
}
public struct QueryReport: Codable, Sendable {
    public let project: String
    public let snapshot: JSONValue?
    public let currentness: String
    public let coverage: JSONValue
    public let results: [Evidence]
}
public struct Evidence: Codable, Sendable {
    public let project: String
    public let path: String
    public let line: Int
    public let text: String
    public let source_hash: String
    public let producer: String
    public let kind: String
    public let currentness: String
    public let coverage: JSONValue
}
public struct ContextList: Codable, Sendable {
    public let project: String
    public let contexts: [ContextEntry]
}
public struct ContextEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let revision: Int
    public let kind: String
    public let retired: Bool
    public let producer: String
    public let authority: JSONValue
}
public struct ContextHistory: Codable, Sendable {
    public let project: String
    public let id: String
    public let producer: String
    public let authority: JSONValue
    public let history: [ContextRevision]
}
public struct ContextRevision: Codable, Sendable {
    public let revision: Int
    public let kind: String
    public let text: String
    public let retired: Bool
}

public enum ServiceError: String, Error, Sendable, LocalizedError {
    case invalid, unavailable, canceled, scopeMismatch, stale, timedOut, outputLimit, failed
    public var errorDescription: String? {
        switch self {
        case .invalid: "Invalid input or core response. Review the selected configuration."
        case .unavailable: "Core unavailable. Select an exact executable and private data directory."
        case .canceled: "Canceled. Refresh before trusting persisted state."
        case .scopeMismatch: "Project or source scope mismatch. Resolve explicitly and refresh."
        case .stale: "Stale evidence. Build understanding explicitly."
        case .timedOut: "Core operation exceeded its time limit. Refresh before retrying."
        case .outputLimit: "Core response exceeded the output limit."
        case .failed: "Core operation failed. Check permissions and refresh to recover."
        }
    }
}

public enum Operation: Sendable {
    case projects, project(String), addProject(String, String, [String]), setSources(String, [String])
    case index(String), query(String, String), contexts(String), context(String, String)
    case writeContext(String, String, String, String, update: Bool), retireContext(String, String)
}
public enum Reply: Sendable {
    case projects([Project]), project(Project), indexed(IndexReport), query(QueryReport)
    case contexts(ContextList), context(ContextHistory), acknowledged
}
/// Exactly one explicit local-owner operation; IDs are not authentication.
public protocol CoreService: Sendable {
    func perform(_ operation: Operation) async throws -> Reply
}

public enum InputPolicy {
    public static let contextKinds = ["note", "decision", "constraint", "correction", "pitfall"]
    public static func identifier(_ value: String) -> Bool {
        !value.isEmpty && !value.hasPrefix("-") && value.utf8.count <= 128 && value.utf8.allSatisfy {
            (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
        }
    }
    public static func sources(_ values: [String]) -> Bool {
        values.count <= 64 && Set(values).count == values.count && values.allSatisfy { path in
            !path.isEmpty && !path.hasPrefix("/") && !path.hasPrefix("-") && path.utf8.count <= 1024 &&
            !path.contains("\0") && !path.contains("\n") && !path.contains("\r") &&
            path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." } &&
            !path.contains("*") && !path.contains("?")
        }
    }
}

public enum StoreSelection {
    /// Foundation may shorten /private/var to its /var symlink even after
    /// resolvingSymlinksInPath. Core rejects symlink ancestors; use realpath.
    public static func existingDirectory(_ url: URL) throws -> URL {
        var isDirectory: ObjCBool = false
        guard url.isFileURL, url.path.hasPrefix("/"),
              FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue,
              let resolved = realpath(url.path, nil) else { throw ServiceError.invalid }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
    }
    /// Resolves explicit first-run intent without creating a directory or file.
    /// Core creates/validates its own private store on the next explicit action.
    public static func newDirectory(parent: URL, name: String) throws -> URL {
        guard InputPolicy.identifier(name) else { throw ServiceError.invalid }
        let target = try existingDirectory(parent).appendingPathComponent(name, isDirectory: true)
        var metadata = stat()
        guard lstat(target.path, &metadata) == -1, errno == ENOENT else { throw ServiceError.invalid }
        return target
    }
}
