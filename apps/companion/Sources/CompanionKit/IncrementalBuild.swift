import Foundation

/// Explicit complete AG capture, not a source authorization or a refresh mode.
public struct IncrementalBuildRequest: Sendable {
    public let project: Project
    public init(project: Project) throws { self.project = project; try validate() }
    func validate() throws { try ProjectExportDocument.validateBinding(project) }
}

/// SQL row accounting only. Every approved source was read and lexically checked.
public struct IncrementalBuildReport: Sendable {
    public let snapshot: String
    public let files: Int
    public let anchors: Int
    public let reusedFiles: Int
    public let reindexedFiles: Int
    public let reusedAnchors: Int
    public let writtenAnchors: Int
    public let deletedAnchors: Int
    public let snapshotUpdated: Bool
    public let persistentWrites: Bool
    public let empty: Bool
    let bytes: Data

    static func decode(_ data: Data, request: IncrementalBuildRequest) throws -> Self {
        try request.validate()
        guard data.count <= 65536, data.last == 10 else { throw ServiceError.outputLimit }
        var parser = IncrementalBuildJSONParser(data)
        guard case .object(let o) = try parser.parse(), Set(o.keys) == [
            "format", "version", "project", "baseline_snapshot", "snapshot", "coverage", "files", "anchors",
            "reused_files", "reindexed_files", "reused_anchors", "written_anchors", "deleted_anchors",
            "snapshot_updated", "persistent_writes", "empty"
        ] else { throw ServiceError.invalid }
        func integer(_ key: String, _ range: ClosedRange<Int>) throws -> Int {
            guard case .number(let n) = o[key], n.isFinite, n.rounded() == n,
                  n >= Double(range.lowerBound), n <= Double(range.upperBound) else { throw ServiceError.invalid }
            return Int(n)
        }
        func boolean(_ key: String) throws -> Bool {
            guard case .bool(let b) = o[key] else { throw ServiceError.invalid }; return b
        }
        guard o["format"] == .string("threadmark-incremental-lexical-index"),
              try integer("version", 1...1) == 1,
              case .string(let id) = o["project"], id.utf8.elementsEqual(request.project.id.utf8),
              o["baseline_snapshot"] == (request.project.snapshot ?? .null),
              case .string(let snapshot) = o["snapshot"], SourceInspectionRequest.hash(snapshot),
              o["coverage"] == .string("lexical-lines-only; no semantic coverage") else { throw ServiceError.scopeMismatch }
        let files = try integer("files", 0...64), anchors = try integer("anchors", 0...16384)
        let reused = try integer("reused_files", 0...64), reindexed = try integer("reindexed_files", 0...64)
        let kept = try integer("reused_anchors", 0...16384), written = try integer("written_anchors", 0...16384)
        let deleted = try integer("deleted_anchors", 0...16384)
        let updated = try boolean("snapshot_updated"), writes = try boolean("persistent_writes"), empty = try boolean("empty")
        let hasBaseline = request.project.snapshot != nil && request.project.snapshot != .null
        guard files == request.project.sources.count, reused + reindexed == files,
              kept + written == anchors, empty == (anchors == 0), anchors <= files * 4096,
              kept <= reused * 4096, written <= reindexed * 4096, deleted <= reindexed * 4096,
              updated == (request.project.snapshot != .string(snapshot)),
              writes == (updated || reindexed != 0),
              hasBaseline || (reused == 0 && kept == 0 && deleted == 0 && updated),
              reindexed != 0 || (written == 0 && deleted == 0),
              reused != files || !hasBaseline || !updated else { throw ServiceError.invalid }
        return Self(snapshot: snapshot, files: files, anchors: anchors, reusedFiles: reused,
                    reindexedFiles: reindexed, reusedAnchors: kept, writtenAnchors: written,
                    deletedAnchors: deleted, snapshotUpdated: updated, persistentWrites: writes, empty: empty, bytes: data)
    }

    /// Post-write metadata must be the old registration/policy with only AG's reported snapshot.
    func validateAdoption(_ fresh: Project, request: IncrementalBuildRequest) throws {
        let p = request.project
        let expected = Project(id: p.id, root: p.root, sources: p.sources, snapshot: .string(snapshot),
                               rootIdentity: p.root_identity, incarnation: p.incarnation)
        guard ProjectExportDocument.exact(fresh, expected) else { throw ServiceError.mutationUncertain }
    }
}

/// Private closed parser; never publishes a partial frame or silently coalesces duplicate keys.
private struct IncrementalBuildJSONParser {
    let bytes: [UInt8]
    var offset = 0
    init(_ data: Data) { bytes = Array(data) }
    mutating func whitespace() { while offset < bytes.count && [9, 10, 13, 32].contains(bytes[offset]) { offset += 1 } }
    mutating func take(_ byte: UInt8) -> Bool {
        whitespace(); guard offset < bytes.count, bytes[offset] == byte else { return false }; offset += 1; return true
    }
    mutating func parse() throws -> JSONValue {
        let result = try value(); whitespace(); guard offset == bytes.count else { throw ServiceError.invalid }; return result
    }
    mutating func string() throws -> String {
        whitespace(); let start = offset
        guard take(34) else { throw ServiceError.invalid }
        while offset < bytes.count {
            let byte = bytes[offset]; offset += 1
            if byte == 92 { guard offset < bytes.count else { throw ServiceError.invalid }; offset += 1 }
            else if byte == 34 { return try JSONDecoder().decode(String.self, from: Data(bytes[start..<offset])) }
        }
        throw ServiceError.invalid
    }
    mutating func value(objectAllowed: Bool = true) throws -> JSONValue {
        whitespace(); guard offset < bytes.count else { throw ServiceError.invalid }
        if bytes[offset] == 34 { return .string(try string()) }
        if objectAllowed && take(123) {
            var result: [String: JSONValue] = [:]
            if take(125) { return .object(result) }
            repeat {
                let key = try string()
                guard result[key] == nil, take(58) else { throw ServiceError.invalid }
                result[key] = try value(objectAllowed: false)
                if take(125) { return .object(result) }
            } while take(44)
            throw ServiceError.invalid
        }
        let start = offset
        while offset < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[offset]) { offset += 1 }
        guard offset > start else { throw ServiceError.invalid }
        let scalar = try JSONDecoder().decode(JSONValue.self, from: Data(bytes[start..<offset]))
        switch scalar {
        case .number:
            guard bytes[start..<offset].allSatisfy({ (48...57).contains($0) }) else { throw ServiceError.invalid }; return scalar
        case .bool, .null: return scalar
        default: throw ServiceError.invalid
        }
    }
}
