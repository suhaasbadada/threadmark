import Foundation

/// Output candidate selection, never a reduced source authorization policy.
public struct FileQueryRequest: Sendable {
    public let project: Project
    public let query: String
    public let mode: SourceRetrievalMode
    public let selectedPaths: [String]

    public init(project: Project, query: String, mode: SourceRetrievalMode, selectedPaths: [String]) throws {
        self.project = project; self.query = query; self.mode = mode
        guard !selectedPaths.isEmpty, selectedPaths.count <= 64,
              Set(selectedPaths).count == selectedPaths.count,
              selectedPaths.allSatisfy({ project.sources.contains($0) }) else { throw ServiceError.invalid }
        self.selectedPaths = project.sources.filter { selectedPaths.contains($0) }
        try validate()
    }
    func validate() throws {
        try ProjectExportDocument.validateBinding(project)
        guard !query.isEmpty, query.utf8.count <= 256, !query.contains("\0"),
              !selectedPaths.isEmpty, selectedPaths.count <= 64,
              project.sources.allSatisfy(InputPolicy.sourceMarker),
              selectedPaths == project.sources.filter({ selectedPaths.contains($0) }),
              Set(selectedPaths).count == selectedPaths.count else { throw ServiceError.invalid }
        if mode == .rankedTerms { _ = try Self.terms(query) }
    }
    var wireMode: String { mode == .literal ? "literal" : "ranked-any-terms" }
    static func whitespace(_ scalar: Unicode.Scalar) -> Bool {
        (9...13).contains(scalar.value) || [32, 133, 160, 5760, 8232, 8233, 8239, 8287, 12288].contains(scalar.value) || (8192...8202).contains(scalar.value)
    }
    static func terms(_ query: String) throws -> [String] {
        guard !query.unicodeScalars.contains(where: { $0.value <= 31 || (127...159).contains($0.value) }) else { throw ServiceError.invalid }
        let words = query.unicodeScalars.split(whereSeparator: whitespace).map { String(String.UnicodeScalarView($0)).lowercased() }
        var terms: [String] = []
        for word in words where !terms.contains(where: { $0.utf8.elementsEqual(word.utf8) }) { terms.append(word) }
        guard (1...8).contains(terms.count), terms.allSatisfy({ $0.utf8.count <= 64 }) else { throw ServiceError.invalid }
        return terms
    }
}

/// Whole closed AK frame retained separately from its display projection.
public struct FilteredQuery: Sendable {
    public let report: QueryReport
    public let selectedPaths: [String]
    let bytes: Data

    static func decode(_ data: Data, request: FileQueryRequest) throws -> Self {
        try request.validate()
        guard data.count <= 8192 else { throw ServiceError.outputLimit }
        guard data.last == 10 else { throw ServiceError.invalid }
        var parser = QueryFilterJSONParser(Data(data.dropLast()))
        guard case .object(let o) = try parser.parse() else { throw ServiceError.invalid }
        let ranked = request.mode == .rankedTerms
        var keys: Set<String> = ["format", "version", "project", "root_identity", "incarnation", "snapshot", "selected_paths", "mode", "currentness", "coverage", "selection", "truncated", "matching_anchors", "scanned_anchors", "results", "limitations"]
        if ranked { keys.insert("terms") }
        guard Set(o.keys) == keys else { throw ServiceError.invalid }
        func equal(_ key: String, _ value: String) -> Bool {
            guard case .string(let s) = o[key] else { return false }; return s.utf8.elementsEqual(value.utf8)
        }
        func integer(_ value: JSONValue?, _ range: ClosedRange<Int>) throws -> Int {
            guard case .number(let n) = value, n.isFinite, n.rounded() == n,
                  n >= Double(range.lowerBound), n <= Double(range.upperBound) else { throw ServiceError.invalid }; return Int(n)
        }
        let p = request.project
        guard case .string(let identity) = p.root_identity, equal("project", p.id), equal("root_identity", identity),
              o["incarnation"] == p.incarnation.map(JSONValue.string), o["snapshot"] == (p.snapshot ?? .null),
              o["selected_paths"] == .array(request.selectedPaths.map(JSONValue.string)),
              equal("mode", request.wireMode) else { throw ServiceError.scopeMismatch }
        let coverage = ranked ? "indexed-source-lines-only; any-term literal text matches; no semantic/symbol coverage" : "lexical-lines-only; no semantic coverage"
        let selection = ranked ? "distinct-matched-terms-desc,total-nonoverlap-occurrences-desc,path-line-asc" : "bounded-path-line-prefix"
        let limitations = ranked ? "Unicode lowercase only; no stemming or normalization; no notes/history, inference or permission from content; current-at-read is not a filesystem lock" : "SQLite ASCII lowercase substring only; full approved policy freshness reads; current-at-read is not a filesystem lock"
        guard equal("format", "threadmark-file-scoped-retrieval"), try integer(o["version"], 1...1) == 1,
              equal("coverage", coverage), equal("selection", selection), equal("limitations", limitations),
              case .string(let current) = o["currentness"], ["current-at-read", "stale-or-unindexed"].contains(current),
              case .bool(let truncated) = o["truncated"], case .array(let rows) = o["results"], rows.count <= 8 else { throw ServiceError.invalid }
        let scanned = try integer(o["scanned_anchors"], 0...(request.selectedPaths.count * 4096))
        let matched = try integer(o["matching_anchors"], 0...scanned)
        guard matched >= rows.count, truncated == (matched > rows.count),
              current == "current-at-read" || (rows.isEmpty && matched == 0 && !truncated),
              current != "current-at-read" || (p.snapshot != nil && p.snapshot != .null) else { throw ServiceError.invalid }
        let terms = ranked ? try FileQueryRequest.terms(request.query) : []
        if ranked {
            guard case .array(let supplied) = o["terms"], supplied.count == terms.count,
                  zip(supplied, terms).allSatisfy({ value, term in
                      guard case .string(let text) = value else { return false }
                      return text.utf8.elementsEqual(term.utf8)
                  }) else { throw ServiceError.invalid }
        }
        var evidence: [Evidence] = []
        var previous: (matched: Int, occurrences: Int, path: String, line: Int)?
        for row in rows {
            guard case .object(let e) = row else { throw ServiceError.invalid }
            var entryKeys: Set<String> = ["project", "path", "line", "text", "source_hash", "producer", "kind", "currentness", "coverage"]
            if ranked { entryKeys.formUnion(["matched_terms", "occurrences"]) }
            guard Set(e.keys) == entryKeys else { throw ServiceError.invalid }
            let encoder = JSONEncoder()
            let anchor = try JSONDecoder().decode(Evidence.self, from: encoder.encode(row))
            _ = try SourceInspectionRequest(project: p, anchor: anchor, radius: 0)
            guard request.selectedPaths.contains(anchor.path), anchor.coverage == .string("lexical-only") else { throw ServiceError.invalid }
            let distinct: Int, occurrences: Int
            if ranked {
                let counts = terms.map { Self.count(Array(anchor.text.lowercased().utf8), Array($0.utf8)) }
                distinct = counts.filter { $0 > 0 }.count; occurrences = counts.reduce(0, +)
                guard distinct > 0, try integer(e["matched_terms"], 1...8) == distinct,
                      try integer(e["occurrences"], 1...8192) == occurrences else { throw ServiceError.invalid }
            } else {
                func ascii(_ s: String) -> [UInt8] { s.utf8.map { (65...90).contains($0) ? $0 + 32 : $0 } }
                guard Self.count(ascii(anchor.text), ascii(request.query)) > 0 else { throw ServiceError.invalid }
                distinct = 1; occurrences = 1
            }
            if let previous {
                let ordered = distinct < previous.matched || (distinct == previous.matched && (occurrences < previous.occurrences || (occurrences == previous.occurrences && (anchor.path > previous.path || (anchor.path == previous.path && anchor.line > previous.line)))))
                guard ordered else { throw ServiceError.invalid }
            }
            guard !evidence.contains(where: { $0.path == anchor.path && $0.line == anchor.line }) else { throw ServiceError.invalid }
            previous = (distinct, occurrences, anchor.path, anchor.line); evidence.append(anchor)
        }
        let report = QueryReport(project: p.id, snapshot: p.snapshot ?? .null, currentness: current,
            coverage: .string(coverage), results: evidence, truncated: truncated, selection: selection, terms: ranked ? terms : nil)
        return Self(report: report, selectedPaths: request.selectedPaths, bytes: data)
    }
    func validate(request: FileQueryRequest) throws {
        let checked = try Self.decode(bytes, request: request)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard selectedPaths == checked.selectedPaths, try encoder.encode(report) == encoder.encode(checked.report) else { throw ServiceError.invalid }
    }
    private static func count(_ text: [UInt8], _ term: [UInt8]) -> Int {
        guard !term.isEmpty, text.count >= term.count else { return 0 }
        var offset = 0, count = 0
        while offset <= text.count - term.count {
            if text[offset..<(offset + term.count)].elementsEqual(term) { count += 1; offset += term.count }
            else { offset += 1 }
        }
        return count
    }
}

/// Frame-bounded, depth-bounded, decoded-duplicate-key rejecting parser.
private struct QueryFilterJSONParser {
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
            let b = bytes[offset]; offset += 1
            if b == 92 { guard offset < bytes.count else { throw ServiceError.invalid }; offset += 1 }
            else if b == 34 { return try JSONDecoder().decode(String.self, from: Data(bytes[start..<offset])) }
        }
        throw ServiceError.invalid
    }
    mutating func value(_ depth: Int) throws -> JSONValue {
        guard depth <= 3 else { throw ServiceError.invalid }; whitespace()
        guard offset < bytes.count else { throw ServiceError.invalid }
        if bytes[offset] == 34 { return .string(try string()) }
        if take(123) {
            var o: [String: JSONValue] = [:]
            if take(125) { return .object(o) }
            repeat {
                let key = try string(); guard o[key] == nil, take(58) else { throw ServiceError.invalid }
                o[key] = try value(depth + 1)
                if take(125) { return .object(o) }
            } while take(44)
            throw ServiceError.invalid
        }
        if take(91) {
            var a: [JSONValue] = []
            if take(93) { return .array(a) }
            repeat {
                a.append(try value(depth + 1)); guard a.count <= 64 else { throw ServiceError.invalid }
                if take(93) { return .array(a) }
            } while take(44)
            throw ServiceError.invalid
        }
        let start = offset
        while offset < bytes.count && ![9, 10, 13, 32, 44, 125, 93].contains(bytes[offset]) { offset += 1 }
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
