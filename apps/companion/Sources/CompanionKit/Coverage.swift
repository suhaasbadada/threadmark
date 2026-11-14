import Foundation

/// An ordinary explicit metadata read, not consent or additional source authority.
public struct CoverageRequest: Sendable {
    public let project: Project
    public init(project: Project) throws { self.project = project; try validate() }
    func validate() throws { try ProjectExportDocument.validateBinding(project) }
}

/// Whole AD response. Construction/publication remain module-owned.
public struct CoverageDocument: Sendable {
    public struct File: Sendable {
        public let path: String
        public let baselineExists: Bool
        public let storedAnchorRecords: Int
        public let baselineMatches: Bool
        public let status: String
        public let byteCount: Int?
        public let lineCount: Int?
        public let observedHash: String?
    }
    public let baselineSnapshot: String?
    public let files: [File]
    public let readableFiles: Int
    public let matchingFiles: Int
    public let storedAnchorRecords: Int
    public let projectSnapshotCurrent: Bool
    public let needsBuild: Bool?
    public let needsReadabilityReview: Bool
    let bytes: Data

    static func decode(_ data: Data, request: CoverageRequest) throws -> Self {
        try request.validate()
        guard data.count + (data.last == 10 ? 0 : 1) <= 65536 else { throw ServiceError.outputLimit }
        var parser = CoverageJSONParser(data)
        func object(_ value: JSONValue?, _ keys: Set<String>) throws -> [String: JSONValue] {
            guard case .object(let o) = value, Set(o.keys) == keys else { throw ServiceError.invalid }; return o
        }
        func string(_ value: JSONValue?) throws -> String {
            guard case .string(let s) = value else { throw ServiceError.invalid }; return s
        }
        func bool(_ value: JSONValue?) throws -> Bool {
            guard case .bool(let b) = value else { throw ServiceError.invalid }; return b
        }
        func integer(_ value: JSONValue?, _ range: ClosedRange<Int>) throws -> Int {
            guard case .number(let n) = value, n.isFinite, n.rounded() == n,
                  n >= Double(range.lowerBound), n <= Double(range.upperBound) else { throw ServiceError.invalid }; return Int(n)
        }
        func equal(_ value: JSONValue?, _ expected: String) -> Bool {
            guard case .string(let s) = value else { return false }; return s.utf8.elementsEqual(expected.utf8)
        }
        let o = try object(parser.parse(), ["format", "version", "project", "root_identity", "incarnation", "baseline_snapshot", "coverage", "semantic_completeness", "review_scope", "files", "summary"])
        let p = request.project
        guard case .string(let identity) = p.root_identity, let token = p.incarnation,
              equal(o["project"], p.id), equal(o["root_identity"], identity), equal(o["incarnation"], token),
              o["baseline_snapshot"] == (p.snapshot ?? .null) else { throw ServiceError.scopeMismatch }
        guard equal(o["format"], "threadmark-coverage-report"), try integer(o["version"], 1...1) == 1,
              equal(o["coverage"], "lexical-only"), equal(o["semantic_completeness"], "not-assessed"),
              equal(o["review_scope"], "explicit-approved-files-only"),
              case .array(let rows) = o["files"], rows.count == p.sources.count, rows.count <= 64 else { throw ServiceError.invalid }
        let baseline: String?
        if case .string(let hash) = o["baseline_snapshot"] { baseline = hash } else { baseline = nil }
        var files: [File] = [], readable = 0, matching = 0, anchors = 0, totalBytes = 0
        for (index, row) in rows.enumerated() {
            let f = try object(row, ["path", "baseline_exists", "stored_anchor_record_count", "current_metadata", "baseline_matches", "status"])
            guard equal(f["path"], p.sources[index]) else { throw ServiceError.scopeMismatch }
            let exists = try bool(f["baseline_exists"]), matches = try bool(f["baseline_matches"])
            let count = try integer(f["stored_anchor_record_count"], 0...4096), status = try string(f["status"])
            guard exists == (baseline != nil), exists || count == 0 else { throw ServiceError.invalid }
            anchors += count
            guard anchors <= 16384 else { throw ServiceError.invalid }
            var bytes: Int?, lines: Int?, hash: String?
            if f["current_metadata"] == .null {
                guard status == "unavailable-or-unsafe", !matches else { throw ServiceError.invalid }
            } else {
                let m = try object(f["current_metadata"], ["byte_count", "line_count", "hash"])
                let b = try integer(m["byte_count"], 0...65536), l = try integer(m["line_count"], 0...4096), h = try string(m["hash"])
                guard SourceInspectionRequest.hash(h), (b == 0) == (l == 0), l <= b,
                      b != 0 || h == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                      !matches || count <= l else { throw ServiceError.invalid }
                totalBytes += b
                guard totalBytes <= 1_048_576 else { throw ServiceError.invalid }
                switch status {
                case "current": guard exists, matches, b > 0 else { throw ServiceError.invalid }
                case "readable-empty": guard b == 0, matches == exists else { throw ServiceError.invalid }
                case "changed", "replaced": guard exists, !matches else { throw ServiceError.invalid }
                case "unindexed": guard !exists, !matches, b > 0 else { throw ServiceError.invalid }
                default: throw ServiceError.invalid
                }
                readable += 1; matching += matches ? 1 : 0
                bytes = b; lines = l; hash = h
            }
            files.append(File(path: p.sources[index], baselineExists: exists, storedAnchorRecords: count,
                              baselineMatches: matches, status: status, byteCount: bytes, lineCount: lines, observedHash: hash))
        }
        let s = try object(o["summary"], ["approved_file_count", "readable_file_count", "unavailable_file_count", "matching_file_count", "stored_anchor_record_count", "project_snapshot_current", "needs_build", "needs_readability_review"])
        let current = baseline != nil && matching == files.count
        let needsBuild: Bool? = baseline == nil || matching < readable ? true : (readable < files.count ? nil : false)
        let encodedNeedsBuild: JSONValue = needsBuild.map { .bool($0) } ?? .null
        guard try integer(s["approved_file_count"], 0...64) == files.count,
              try integer(s["readable_file_count"], 0...64) == readable,
              try integer(s["unavailable_file_count"], 0...64) == files.count - readable,
              try integer(s["matching_file_count"], 0...64) == matching,
              try integer(s["stored_anchor_record_count"], 0...16384) == anchors,
              try bool(s["project_snapshot_current"]) == current,
              s["needs_build"] == encodedNeedsBuild,
              try bool(s["needs_readability_review"]) == (readable != files.count) else { throw ServiceError.invalid }
        return Self(baselineSnapshot: baseline, files: files, readableFiles: readable, matchingFiles: matching,
                    storedAnchorRecords: anchors, projectSnapshotCurrent: current, needsBuild: needsBuild,
                    needsReadabilityReview: readable != files.count, bytes: data)
    }
}

/// Closed, bounded, duplicate-rejecting JSON, including escaped duplicate keys.
private struct CoverageJSONParser {
    let bytes: [UInt8]
    var offset = 0
    init(_ data: Data) { bytes = Array(data) }
    mutating func whitespace() { while offset < bytes.count && [9, 10, 13, 32].contains(bytes[offset]) { offset += 1 } }
    mutating func take(_ byte: UInt8) -> Bool {
        whitespace(); guard offset < bytes.count, bytes[offset] == byte else { return false }; offset += 1; return true
    }
    mutating func parse() throws -> JSONValue {
        let result = try value(0); whitespace(); guard offset == bytes.count else { throw ServiceError.invalid }; return result
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
    mutating func value(_ depth: Int) throws -> JSONValue {
        guard depth <= 4 else { throw ServiceError.invalid }; whitespace()
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
            guard bytes[start..<offset].allSatisfy({ (48...57).contains($0) }) else { throw ServiceError.invalid }; return scalar
        case .bool, .null: return scalar
        default: throw ServiceError.invalid
        }
    }
}
