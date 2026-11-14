import Foundation

/// A rendered Query membership token, not a path picker or permission grant.
public struct SourceInspectionRow: Identifiable, Sendable {
    public let id: UUID
    public let anchor: Evidence
    let readID: UUID
    init(anchor: Evidence, readID: UUID) {
        id = UUID(); self.anchor = anchor; self.readID = readID
    }
}

/// Immutable admitted read. Only the model captures Query membership. The raw
/// query/mode/filter remain in memory and never enter the inspect-set transport.
public struct SourceInspectionSetRequest: Sendable {
    public let project: Project
    public let anchors: [Evidence]
    public let radius: Int
    public let query: String
    public let mode: SourceRetrievalMode
    public let selectedPaths: [String]?
    let readID: UUID

    init(project: Project, anchors: [Evidence], radius: Int, query: String,
         mode: SourceRetrievalMode, selectedPaths: [String]?, readID: UUID) throws {
        guard (2...8).contains(anchors.count) else { throw ServiceError.invalid }
        self.project = project; self.radius = radius; self.query = query
        self.mode = mode; self.selectedPaths = selectedPaths; self.readID = readID
        // Validate before looking up policy positions; never normalize path bytes.
        for anchor in anchors { _ = try SourceInspectionRequest(project: project, anchor: anchor, radius: radius) }
        self.anchors = anchors.sorted { a, b in
            let ai = project.sources.firstIndex { $0.utf8.elementsEqual(a.path.utf8) }!
            let bi = project.sources.firstIndex { $0.utf8.elementsEqual(b.path.utf8) }!
            return ai == bi ? a.line < b.line : ai < bi
        }
        try validate()
    }
    func validate() throws {
        guard (2...8).contains(anchors.count), !query.isEmpty, query.utf8.count <= 256,
              !query.contains("\0") else { throw ServiceError.invalid }
        if mode == .rankedTerms { _ = try FileQueryRequest.terms(query) }
        if let selectedPaths {
            let filter = try FileQueryRequest(project: project, query: query, mode: mode, selectedPaths: selectedPaths)
            guard zip(selectedPaths, filter.selectedPaths).allSatisfy({ $0.utf8.elementsEqual($1.utf8) }) else { throw ServiceError.invalid }
            guard anchors.allSatisfy({ a in selectedPaths.contains { $0.utf8.elementsEqual(a.path.utf8) } }) else { throw ServiceError.invalid }
        }
        var previous: (Int, Int)?
        for a in anchors {
            _ = try SourceInspectionRequest(project: project, anchor: a, radius: radius)
            guard let index = project.sources.firstIndex(where: { $0.utf8.elementsEqual(a.path.utf8) }),
                  previous == nil || index > previous!.0 || (index == previous!.0 && a.line > previous!.1) else { throw ServiceError.invalid }
            previous = (index, a.line)
        }
    }
    func encoded() throws -> Data {
        try validate()
        struct Anchor: Encodable { let path: String; let line: Int; let source_hash: String }
        struct Input: Encodable { let version = "source-inspection-set-v1"; let anchors: [Anchor] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(Input(anchors: anchors.map { Anchor(path: $0.path, line: $0.line, source_hash: $0.source_hash) }))
        guard data.count <= 65536 else { throw ServiceError.invalid }
        return data
    }
}

/// Complete all-or-error AQ frame. No public initializer/decoder/publication.
public struct SourceInspectionSetDocument: Sendable {
    public struct Line: Codable, Sendable {
        public let number: Int
        public let text: String
        public let isAnchor: Bool
    }
    public struct Window: Codable, Sendable {
        public let path: String
        public let sourceHash: String
        public let producer: String
        public let anchorLine: Int
        public let lines: [Line]
    }
    public let project: Project
    public let radius: Int
    public let windows: [Window]
    let bytes: Data

    static func decode(_ data: Data, request: SourceInspectionSetRequest) throws -> Self {
        try request.validate()
        guard data.count + (data.last == 10 ? 0 : 1) <= 8192 else { throw ServiceError.outputLimit }
        var parser = SourceInspectionSetJSONParser(data)
        guard case .object(let o) = try parser.parse(), Set(o.keys) == ["format", "version", "project", "root_identity", "incarnation", "snapshot", "radius", "currentness", "inspections"] else { throw ServiceError.invalid }
        func equal(_ key: String, _ expected: String) -> Bool {
            guard case .string(let value) = o[key] else { return false }
            return value.utf8.elementsEqual(expected.utf8)
        }
        func integer(_ value: JSONValue?, _ range: ClosedRange<Int>) throws -> Int {
            guard case .number(let n) = value, n.isFinite, n.rounded() == n,
                  n >= Double(range.lowerBound), n <= Double(range.upperBound) else { throw ServiceError.invalid }
            return Int(n)
        }
        let p = request.project
        guard case .string(let identity) = p.root_identity, let nonce = p.incarnation,
              case .string(let snapshot) = p.snapshot,
              equal("project", p.id), equal("root_identity", identity), equal("incarnation", nonce),
              equal("snapshot", snapshot) else { throw ServiceError.scopeMismatch }
        guard equal("format", "threadmark-source-inspection-set"), try integer(o["version"], 1...1) == 1,
              equal("currentness", "current-at-read"), try integer(o["radius"], 0...3) == request.radius,
              case .array(let records) = o["inspections"], records.count == request.anchors.count else { throw ServiceError.invalid }
        var windows: [Window] = []
        for (record, a) in zip(records, request.anchors) {
            guard case .object(let w) = record, Set(w.keys) == ["path", "source_hash", "producer", "anchor_line", "lines"],
                  case .string(let path) = w["path"], path.utf8.elementsEqual(a.path.utf8),
                  case .string(let hash) = w["source_hash"], hash.utf8.elementsEqual(a.source_hash.utf8),
                  case .string(let producer) = w["producer"], producer.utf8.elementsEqual(a.producer.utf8),
                  try integer(w["anchor_line"], 1...4096) == a.line,
                  case .array(let rows) = w["lines"], !rows.isEmpty, rows.count <= request.radius * 2 + 1 else { throw ServiceError.invalid }
            let first = max(1, a.line - request.radius)
            var lines: [Line] = []
            for (offset, row) in rows.enumerated() {
                guard case .object(let l) = row, Set(l.keys) == ["line", "text", "is_anchor", "kind"],
                      case .string(let text) = l["text"], text.utf8.count <= 1024,
                      !text.contains("\0"), !text.contains("\n"),
                      case .bool(let center) = l["is_anchor"], case .string(let kind) = l["kind"] else { throw ServiceError.invalid }
                let number = try integer(l["line"], first...min(4096, a.line + request.radius))
                guard number == first + offset, center == (number == a.line),
                      kind == (center ? "indexed-anchor" : "observed-source-text"),
                      !center || text.utf8.elementsEqual(a.text.utf8) else { throw ServiceError.invalid }
                lines.append(Line(number: number, text: text, isAnchor: center))
            }
            guard lines.filter(\.isAnchor).count == 1 else { throw ServiceError.invalid }
            windows.append(Window(path: path, sourceHash: hash, producer: producer, anchorLine: a.line, lines: lines))
        }
        return Self(project: p, radius: request.radius, windows: windows, bytes: data)
    }
    func validate(request: SourceInspectionSetRequest) throws {
        let decoded = try Self.decode(bytes, request: request)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard ProjectExportDocument.exact(project, decoded.project), radius == decoded.radius,
              try encoder.encode(windows) == encoder.encode(decoded.windows) else { throw ServiceError.invalid }
    }
}

/// Separate deeper bounded parser; the original single-anchor grammar is unchanged.
private struct SourceInspectionSetJSONParser {
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
        guard depth <= 6 else { throw ServiceError.invalid }; whitespace()
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
