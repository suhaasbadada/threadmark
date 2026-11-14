import Foundation

/// Normal explicit read, not consent or source authorization. Transport callers
/// must supply the complete Z binding; only the model admits query membership.
public struct SourceInspectionRequest: Sendable {
    public let project: Project
    public let anchor: Evidence
    public let radius: Int

    public init(project: Project, anchor: Evidence, radius: Int) throws {
        self.project = project; self.anchor = anchor; self.radius = radius
        try validate()
    }
    func validate() throws {
        try ProjectExportDocument.validateBinding(project)
        guard case .string(let snapshot) = project.snapshot, Self.hash(snapshot),
              (0...3).contains(radius), (1...4096).contains(anchor.line),
              anchor.project.utf8.elementsEqual(project.id.utf8),
              project.sources.contains(where: { $0.utf8.elementsEqual(anchor.path.utf8) }),
              InputPolicy.sourceMarker(anchor.path), Self.hash(anchor.source_hash),
              InputPolicy.identifier(anchor.producer), anchor.kind == "observed-source-line",
              anchor.currentness == "current-at-read", !anchor.text.isEmpty,
              anchor.text.utf8.count <= 1024, !anchor.text.contains("\0"),
              !anchor.text.contains("\n") else { throw ServiceError.invalid }
    }
    static func hash(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    static func exact(_ a: Evidence, _ b: Evidence) -> Bool {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(a)) == (try? encoder.encode(b))
    }
}

/// A whole validated Z response. No child-selected commands, prompts or locations.
public struct SourceInspectionDocument: Sendable {
    public struct Line: Sendable {
        public let number: Int
        public let text: String
        public let isAnchor: Bool
    }
    public let path: String
    public let sourceHash: String
    public let snapshot: String
    public let producer: String
    public let radius: Int
    public let lines: [Line]
    let bytes: Data

    static func decode(_ data: Data, request: SourceInspectionRequest) throws -> Self {
        try request.validate()
        // Reserve the CLI newline even for a direct transport without one.
        guard data.count + (data.last == 10 ? 0 : 1) <= 8192 else { throw ServiceError.outputLimit }
        var parser = InspectionJSONParser(data)
        guard case .object(let o) = try parser.parse(), Set(o.keys) == ["format", "version", "project", "root_identity", "incarnation", "snapshot", "path", "source_hash", "producer", "anchor_line", "radius", "currentness", "lines"] else { throw ServiceError.invalid }
        func equal(_ key: String, _ expected: String) -> Bool {
            guard case .string(let s) = o[key] else { return false }
            return s.utf8.elementsEqual(expected.utf8)
        }
        func integer(_ value: JSONValue?, _ range: ClosedRange<Int>) throws -> Int {
            guard case .number(let n) = value, n.isFinite, n.rounded() == n,
                  n >= Double(range.lowerBound), n <= Double(range.upperBound) else { throw ServiceError.invalid }
            return Int(n)
        }
        let p = request.project, a = request.anchor
        guard case .string(let identity) = p.root_identity, let token = p.incarnation,
              case .string(let snapshot) = p.snapshot,
              equal("project", p.id), equal("root_identity", identity), equal("incarnation", token),
              equal("snapshot", snapshot), equal("path", a.path), equal("source_hash", a.source_hash),
              equal("producer", a.producer) else { throw ServiceError.scopeMismatch }
        guard equal("format", "threadmark-source-anchor-inspection"),
              try integer(o["version"], 1...1) == 1, equal("currentness", "current-at-read"),
              try integer(o["anchor_line"], 1...4096) == a.line,
              try integer(o["radius"], 0...3) == request.radius,
              case .array(let rows) = o["lines"], !rows.isEmpty, rows.count <= request.radius * 2 + 1 else { throw ServiceError.invalid }
        let first = max(1, a.line - request.radius)
        var lines: [Line] = []
        for (offset, row) in rows.enumerated() {
            guard case .object(let l) = row, Set(l.keys) == ["line", "text", "is_anchor", "kind"],
                  case .string(let text) = l["text"], !text.contains("\0"),
                  !text.contains("\n"),
                  case .bool(let center) = l["is_anchor"], case .string(let kind) = l["kind"] else { throw ServiceError.invalid }
            let number = try integer(l["line"], first...min(4096, a.line + request.radius))
            guard number == first + offset, center == (number == a.line),
                  kind == (center ? "indexed-anchor" : "observed-source-text"),
                  !center || text.utf8.elementsEqual(a.text.utf8) else { throw ServiceError.invalid }
            lines.append(Line(number: number, text: text, isAnchor: center))
        }
        guard lines.filter(\.isAnchor).count == 1 else { throw ServiceError.invalid }
        return Self(path: a.path, sourceHash: a.source_hash, snapshot: snapshot,
                    producer: a.producer, radius: request.radius, lines: lines, bytes: data)
    }
}

/// Bounded duplicate-rejecting reader, following the existing export parser.
private struct InspectionJSONParser {
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
            guard bytes[start..<offset].allSatisfy({ (48...57).contains($0) }) else { throw ServiceError.invalid }
            return scalar
        case .bool, .null: return scalar
        default: throw ServiceError.invalid
        }
    }
}
