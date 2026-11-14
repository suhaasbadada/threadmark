import Foundation

/// Independent of source Query, Context, Refine and retained retrieval modes.
public enum HumanSearchMode: String, CaseIterable, Sendable {
    case literal, rankedAnyTerms
    public var label: String { self == .literal ? "Literal" : "Ranked any terms" }
}

/// Immutable local capture. Raw query is sent only for this explicit read, never persisted.
public struct RankedHumanSearchRequest: Sendable {
    public let binding: HumanContextReadBinding
    public let query: String
    public let terms: [String]
    public let kinds: [String]

    public init(binding: HumanContextReadBinding, query: String, kinds: [String]) throws {
        self.binding = binding; self.query = query; self.kinds = kinds.sorted()
        terms = try RefinementConsent.rankedTerms(query)
        try validate()
    }
    func validate() throws {
        try binding.validate()
        guard InputPolicy.humanSearch(query), !kinds.isEmpty, kinds.count <= 5,
              kinds == kinds.sorted(), Set(kinds).count == kinds.count,
              kinds.allSatisfy(InputPolicy.contextKinds.contains),
              Self.exact(terms, try RefinementConsent.rankedTerms(query)) else { throw ServiceError.invalid }
    }
    static func exact(_ a: [String], _ b: [String]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { $0.utf8.elementsEqual($1.utf8) }
    }
}

/// AO's distinct closed wire, never decoded as the literal/AE envelope.
public struct RankedHumanSearch: Sendable {
    public struct Entry: Codable, Identifiable, Sendable {
        public let id: String
        public let revision: Int
        public let kind: String
        public let text: String
        public let producer: String
        public let status: String
        public let matched_terms: [String]
        public let occurrences: Int
    }
    public struct Document: Codable, Sendable {
        public let version: String
        public let project: String
        public let root_identity: String
        public let incarnation: String
        public let selected_kinds: [String]
        public let terms: [String]
        public let producer: String
        public let status: String
        public let authority: String
        public let coverage: String
        public let selection: String
        public let limitations: String
        public let matched_entries: Int
        public let omitted_entries: Int
        public let truncated: Bool
        public let results: [Entry]
    }
    public let document: Document
    let bytes: Data
    let readID = UUID()
    public static let coverageLabel = "human-text-only; any distinct Unicode-lowercase whitespace term; no normalization, source, semantic or historical search"
    public static let selectionLabel = "distinct-matched-terms-descending-occurrences-descending-id-byte-order-ascending; max-8; max-8192-JSON-bytes-including-newline; whole-entry-omission; later-fitting-candidates-allowed"
    public static let limitationsLabel = "Human declarations, not observed truth or authorization; per-term nonoverlapping occurrences; distinct-term overlaps counted independently; no relevance-quality claim; current-at-read registration, not atomic revocation."

    static func decode(_ data: Data, request: RankedHumanSearchRequest) throws -> Self {
        try request.validate()
        guard data.count <= 8192 else { throw ServiceError.outputLimit }
        guard data.last == 10 else { throw ServiceError.invalid }
        var parser = RankedHumanSearchJSONParser(Data(data.dropLast()))
        guard case .object(let object) = try parser.parse(),
              Set(object.keys) == ["version", "project", "root_identity", "incarnation", "selected_kinds", "terms", "producer", "status", "authority", "coverage", "selection", "limitations", "matched_entries", "omitted_entries", "truncated", "results"],
              case .array(let rows) = object["results"], rows.allSatisfy({ row in
                  guard case .object(let entry) = row else { return false }
                  return Set(entry.keys) == ["id", "revision", "kind", "text", "producer", "status", "matched_terms", "occurrences"]
              }) else { throw ServiceError.invalid }
        let d = try JSONDecoder().decode(Document.self, from: data)
        guard d.project.utf8.elementsEqual(request.binding.project.utf8),
              d.root_identity.utf8.elementsEqual(request.binding.rootIdentity.utf8),
              d.incarnation.utf8.elementsEqual(request.binding.incarnation.utf8) else { throw ServiceError.namespaceChanged }
        guard d.version == "human-search-ranked-v1",
              RankedHumanSearchRequest.exact(d.selected_kinds, request.kinds),
              RankedHumanSearchRequest.exact(d.terms, request.terms),
              d.producer == "human-authored", d.status == "active-latest-at-read",
              d.authority == "context-not-authorization-or-observed-truth",
              d.coverage == coverageLabel, d.selection == selectionLabel, d.limitations == limitationsLabel,
              (0...4096).contains(d.matched_entries), d.results.count <= 8,
              d.matched_entries >= d.results.count, d.omitted_entries == d.matched_entries - d.results.count,
              d.truncated == (d.omitted_entries != 0), Set(d.results.map(\.id)).count == d.results.count else { throw ServiceError.invalid }
        for row in d.results {
            guard InputPolicy.identifier(row.id), (1...32).contains(row.revision), request.kinds.contains(row.kind),
                  !row.text.isEmpty, row.text.utf8.count <= 4096, !row.text.contains("\0"),
                  row.producer == "human-authored", row.status == "active" else { throw ServiceError.invalid }
            // Byte substring matching, not Swift's canonically equivalent String matching.
            let lowered = Array(row.text.lowercased(with: Locale(identifier: "und")).utf8)
            var matched: [String] = [], count = 0
            for term in request.terms {
                let needle = Array(term.utf8)
                var offset = 0, occurrences = 0
                while offset + needle.count <= lowered.count {
                    if lowered[offset..<(offset + needle.count)].elementsEqual(needle) {
                        occurrences += 1; offset += needle.count
                    } else { offset += 1 }
                }
                if occurrences > 0 { matched.append(term); count += occurrences }
            }
            guard count > 0, row.occurrences == count,
                  RankedHumanSearchRequest.exact(row.matched_terms, matched) else { throw ServiceError.invalid }
        }
        for (a, b) in zip(d.results, d.results.dropFirst()) {
            guard a.matched_terms.count > b.matched_terms.count ||
                (a.matched_terms.count == b.matched_terms.count && (a.occurrences > b.occurrences ||
                 (a.occurrences == b.occurrences && a.id.utf8.lexicographicallyPrecedes(b.id.utf8)))) else { throw ServiceError.invalid }
        }
        return Self(document: d, bytes: data)
    }
    func validate(request: RankedHumanSearchRequest, scope: Project) throws {
        guard try HumanContextReadBinding(project: scope) == request.binding else { throw ServiceError.namespaceChanged }
        let checked = try Self.decode(bytes, request: request)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard try encoder.encode(document) == encoder.encode(checked.document) else { throw ServiceError.invalid }
    }
}

/// Local strict parser rejects decoded duplicate keys at every depth and non-integer
/// number syntax before Codable can coerce booleans, floats or overflowing doubles.
private struct RankedHumanSearchJSONParser {
    indirect enum Value { case object([String: Value]), array([Value]), string, integer, bool }
    let bytes: [UInt8]
    var offset = 0
    init(_ data: Data) { bytes = Array(data) }
    mutating func whitespace() { while offset < bytes.count && [9, 10, 13, 32].contains(bytes[offset]) { offset += 1 } }
    mutating func take(_ byte: UInt8) -> Bool {
        whitespace(); guard offset < bytes.count, bytes[offset] == byte else { return false }; offset += 1; return true
    }
    mutating func parse() throws -> Value {
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
    mutating func value(_ depth: Int) throws -> Value {
        guard depth <= 4 else { throw ServiceError.invalid }; whitespace()
        guard offset < bytes.count else { throw ServiceError.invalid }
        if bytes[offset] == 34 { _ = try string(); return .string }
        if take(123) {
            var object: [String: Value] = [:]
            if take(125) { return .object(object) }
            repeat {
                let key = try string()
                guard object[key] == nil, take(58) else { throw ServiceError.invalid }
                object[key] = try value(depth + 1)
                if take(125) { return .object(object) }
            } while take(44)
            throw ServiceError.invalid
        }
        if take(91) {
            var array: [Value] = []
            if take(93) { return .array(array) }
            repeat {
                array.append(try value(depth + 1))
                guard array.count <= 8 else { throw ServiceError.invalid }
                if take(93) { return .array(array) }
            } while take(44)
            throw ServiceError.invalid
        }
        let start = offset
        while offset < bytes.count && ![9, 10, 13, 32, 44, 125, 93].contains(bytes[offset]) { offset += 1 }
        guard offset > start else { throw ServiceError.invalid }
        let token = String(decoding: bytes[start..<offset], as: UTF8.self)
        if token == "true" || token == "false" { return .bool }
        guard bytes[start..<offset].allSatisfy({ (48...57).contains($0) }),
              token == "0" || !token.hasPrefix("0"), Int(token) != nil else { throw ServiceError.invalid }
        return .integer
    }
}
