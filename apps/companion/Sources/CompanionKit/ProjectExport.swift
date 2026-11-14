import Foundation

/// Immutable pending disclosure, not transport execution authority.
public struct ProjectExportConfirmation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let project: Project
    let generation: UInt64
    let scopeRevision: UInt64
    let configurationGeneration: UInt64

    public static let disclosure = "Exports eligible source excerpts, relative paths, root identity, snapshot and lexical coverage metadata, and ALL saved local human history, including earlier edits and retired revisions. Human declarations remain context, not authorization or observed truth. Does not access credential stores or export app settings, absolute root/store paths, unsaved drafts or previews. Source excerpts and human text may themselves contain secrets: no secret scanning or sharing authorization is implied. A local folder can be cloud-synced or backed up: local storage is not an isolation, ACL, cloud or retention guarantee. Earlier exports, backups and displayed copies cannot be recalled by Forget or project removal; no forensic erasure is claimed. No automatic archive, provider call, upload, import or restore."

    func validate() throws { try ProjectExportDocument.validateBinding(project) }
}

/// Opaque transport authority minted only by the owned model operation after
/// confirmation and destination validation. Ordinary importers cannot construct
/// it from a pending disclosure. This is an API lifecycle fence, not in-process
/// authentication against arbitrary code in this module.
public final class ProjectExportExecution: @unchecked Sendable {
    let confirmation: ProjectExportConfirmation
    private let lock = NSLock()
    private var available = true

    init(_ confirmation: ProjectExportConfirmation) { self.confirmation = confirmation }
    func claim() throws -> ProjectExportConfirmation {
        lock.lock(); defer { lock.unlock() }
        guard available else { throw ServiceError.invalid }
        available = false
        return confirmation
    }
    func revoke() {
        lock.lock(); defer { lock.unlock() }
        available = false
    }
}

/// Validated original stdout bytes, not a provider-selected path or a re-encoding.
public struct ProjectExportDocument: Sendable {
    public static let limit = 1_048_576
    public let bytes: Data
    private init(bytes: Data) { self.bytes = bytes }

    static func snapshotArgument(_ project: Project) throws -> String {
        if project.snapshot == nil || project.snapshot == .null { return "none" }
        guard case .string(let hash) = project.snapshot, hex(hash, count: 64) else { throw ServiceError.invalid }
        return hash
    }
    static func validateBinding(_ p: Project) throws {
        guard InputPolicy.identifier(p.id), case .string(let identity) = p.root_identity,
              InputPolicy.removal(root: p.root, identity: identity),
              p.incarnation.map(InputPolicy.incarnation) == true,
              p.sources.allSatisfy(InputPolicy.sourceMarker), InputPolicy.sources(p.sources) else { throw ServiceError.invalid }
        _ = try snapshotArgument(p)
    }
    static func exact(_ a: Project, _ b: Project) -> Bool {
        // Swift String equality folds canonically equivalent Unicode; approvals do not.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(a)) == (try? encoder.encode(b))
    }
    private static func hex(_ value: String, count: Int) -> Bool {
        value.utf8.count == count && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    public static func decode(_ data: Data, scope: Project) throws -> Self {
        try validateBinding(scope)
        guard data.count <= limit else { throw ServiceError.outputLimit }
        var parser = ExportJSONParser(data)
        let value = try parser.parse()
        func object(_ value: JSONValue, _ keys: Set<String>) throws -> [String: JSONValue] {
            guard case .object(let o) = value, Set(o.keys) == keys else { throw ServiceError.invalid }; return o
        }
        func string(_ value: JSONValue?) throws -> String {
            guard case .string(let s) = value else { throw ServiceError.invalid }; return s
        }
        func array(_ value: JSONValue?) throws -> [JSONValue] {
            guard case .array(let a) = value else { throw ServiceError.invalid }; return a
        }
        func integer(_ value: JSONValue?, _ range: ClosedRange<Int>) throws -> Int {
            guard case .number(let n) = value, n.isFinite, n.rounded() == n,
                  n >= Double(range.lowerBound), n <= Double(range.upperBound) else { throw ServiceError.invalid }; return Int(n)
        }
        func equal(_ value: JSONValue?, _ text: String) -> Bool {
            guard case .string(let s) = value else { return false }; return s.utf8.elementsEqual(text.utf8)
        }
        let o = try object(value, ["format", "version", "project", "snapshot", "currentness", "coverage", "evidence", "human_history"])
        guard equal(o["format"], "threadmark-project-export"), try integer(o["version"], 1...1) == 1 else { throw ServiceError.invalid }
        let p = try object(o["project"] ?? .null, ["id", "root_identity", "sources"])
        let paths = try array(p["sources"]).map { try string($0) }
        guard case .string(let identity) = scope.root_identity,
              equal(p["id"], scope.id), equal(p["root_identity"], identity),
              paths.count == scope.sources.count,
              zip(paths, scope.sources).allSatisfy({ $0.utf8.elementsEqual($1.utf8) }),
              o["snapshot"] == (scope.snapshot ?? .null) else { throw ServiceError.scopeMismatch }
        let current = try string(o["currentness"])
        guard ["current-at-read", "stale-or-unindexed"].contains(current),
              equal(o["coverage"], "lexical-lines-only; no semantic coverage; evidence current-at-read only; stale or unindexed evidence omitted"),
              current != "current-at-read" || (scope.snapshot != nil && scope.snapshot != .null) else { throw ServiceError.invalid }
        let evidence = try array(o["evidence"]), history = try array(o["human_history"])
        guard evidence.count <= 16384, history.count <= 4096,
              current == "current-at-read" || evidence.isEmpty else { throw ServiceError.invalid }
        var previousPath = "", previousLine = 0
        for row in evidence {
            let e = try object(row, ["project", "path", "line", "text", "source_hash", "producer", "kind", "currentness"])
            let path = try string(e["path"]), line = try integer(e["line"], 1...4096), text = try string(e["text"])
            guard equal(e["project"], scope.id), paths.contains(path), InputPolicy.sourceMarker(path),
                  path > previousPath || (path == previousPath && line > previousLine),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 1024, !text.contains("\0"),
                  hex(try string(e["source_hash"]), count: 64), InputPolicy.identifier(try string(e["producer"])),
                  equal(e["kind"], "observed-source-line"), equal(e["currentness"], "current-at-read") else { throw ServiceError.invalid }
            previousPath = path; previousLine = line
        }
        var previousID = "", revision = 0
        for row in history {
            let h = try object(row, ["id", "revision", "kind", "text", "retired", "producer", "authority"])
            let id = try string(h["id"]), next = try integer(h["revision"], 1...32), text = try string(h["text"])
            guard InputPolicy.identifier(id), id >= previousID, next == (id == previousID ? revision + 1 : 1),
                  InputPolicy.contextKinds.contains(try string(h["kind"])), !text.isEmpty, text.utf8.count <= 4096, !text.contains("\0"),
                  equal(h["producer"], "human-authored"), equal(h["authority"], "context-not-authorization-or-observed-truth"),
                  case .bool = h["retired"] else { throw ServiceError.invalid }
            previousID = id; revision = next
        }
        return Self(bytes: data)
    }
}

/// Small bounded JSON reader: closed schemas above, duplicate keys (including
/// escaped aliases) rejected here before Foundation can discard their meaning.
private struct ExportJSONParser {
    let bytes: [UInt8]
    var offset = 0
    init(_ data: Data) { bytes = Array(data) }
    mutating func whitespace() { while offset < bytes.count && [9, 10, 13, 32].contains(bytes[offset]) { offset += 1 } }
    mutating func take(_ byte: UInt8) -> Bool {
        whitespace(); guard offset < bytes.count, bytes[offset] == byte else { return false }; offset += 1; return true
    }
    mutating func parse() throws -> JSONValue {
        let value = try value(0); whitespace(); guard offset == bytes.count else { throw ServiceError.invalid }; return value
    }
    mutating func string() throws -> String {
        whitespace(); let start = offset
        guard take(34) else { throw ServiceError.invalid }
        while offset < bytes.count {
            let b = bytes[offset]; offset += 1
            if b == 92 { guard offset < bytes.count else { throw ServiceError.invalid }; offset += 1 }
            else if b == 34 { return try JSONDecoder().decode(String.self, from: Data(bytes[start..<offset])) }
        }
        throw ServiceError.invalid
    }
    mutating func value(_ depth: Int) throws -> JSONValue {
        guard depth <= 12 else { throw ServiceError.invalid }; whitespace()
        guard offset < bytes.count else { throw ServiceError.invalid }
        if bytes[offset] == 34 { return .string(try string()) }
        if take(123) {
            var result: [String: JSONValue] = [:]
            if take(125) { return .object(result) }
            repeat {
                let key = try string()
                guard result[key] == nil, take(58) else { throw ServiceError.invalid }
                result[key] = try value(depth + 1)
                if take(125) { return .object(result) }
            } while take(44)
            throw ServiceError.invalid
        }
        if take(91) {
            var result: [JSONValue] = []
            if take(93) { return .array(result) }
            repeat {
                result.append(try value(depth + 1))
                if take(93) { return .array(result) }
            } while take(44)
            throw ServiceError.invalid
        }
        let start = offset
        while offset < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[offset]) { offset += 1 }
        guard offset > start else { throw ServiceError.invalid }
        let scalar = try JSONDecoder().decode(JSONValue.self, from: Data(bytes[start..<offset]))
        switch scalar {
        case .number:
            guard bytes[start..<offset].allSatisfy({ (48...57).contains($0) }) else { throw ServiceError.invalid }
            return scalar
        case .bool, .null: return scalar
        default: throw ServiceError.invalid
        }
    }
}
