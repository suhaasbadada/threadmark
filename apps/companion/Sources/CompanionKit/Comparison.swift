import Foundation

/// Immutable explicit pair from one validated loaded history. Not edit authority.
public struct HumanComparisonRequest: Sendable {
    public let binding: HumanContextReadBinding
    public let contextID: String
    public let from: ContextRevision
    public let to: ContextRevision

    init(project: Project, history: ContextHistory, from: Int, to: Int) throws {
        try history.validate(project: project.id, id: history.id)
        guard history.authority == .string("context-not-authorization-or-observed-truth"),
              (1...32).contains(from), (from...32).contains(to), to <= history.history.count else { throw ServiceError.invalid }
        binding = try HumanContextReadBinding(project: project)
        contextID = history.id
        self.from = history.history[from - 1]; self.to = history.history[to - 1]
    }
    func validate() throws {
        try binding.validate()
        guard InputPolicy.identifier(contextID), (1...32).contains(from.revision),
              (from.revision...32).contains(to.revision), [from, to].allSatisfy({
                  InputPolicy.contextKinds.contains($0.kind) && !$0.text.isEmpty &&
                  $0.text.utf8.count <= 4096 && !$0.text.contains("\0")
              }) else { throw ServiceError.invalid }
    }
}

/// Validated, read-only textual review. No apply, resolution, or send capability.
public struct HumanComparison: Sendable {
    public let request: HumanComparisonRequest
    public let prefix: String
    public let removed: String
    public let added: String
    public let suffix: String
    public let textChanged: Bool
    public let kindChanged: Bool
    public let retirementChanged: Bool
    // Retain original bounded frame so model adoption independently revalidates.
    let bytes: Data

    static func decode(_ data: Data, request: HumanComparisonRequest) throws -> Self {
        try request.validate()
        guard data.count <= 65536 else { throw ServiceError.outputLimit }
        // Count the required stdout newline even for a synthetic missing-newline frame.
        guard data.last == 10 else { throw ServiceError.invalid }
        var parser = ComparisonJSONParser(Data(data.dropLast()))
        let value = try parser.parse()
        func object(_ value: JSONValue?, _ keys: Set<String>) throws -> [String: JSONValue] {
            guard case .object(let o) = value, Set(o.keys) == keys else { throw ServiceError.invalid }; return o
        }
        func text(_ value: JSONValue?) throws -> String {
            guard case .string(let s) = value else { throw ServiceError.invalid }; return s
        }
        func exact(_ value: JSONValue?, _ s: String) -> Bool {
            guard case .string(let v) = value else { return false }; return v.utf8.elementsEqual(s.utf8)
        }
        func flag(_ value: JSONValue?, _ expected: Bool) throws -> Bool {
            guard case .bool(let b) = value, b == expected else { throw ServiceError.invalid }; return b
        }
        let o = try object(value, ["version", "project", "id", "producer", "authority", "from", "to", "text_changed", "kind_changed", "retirement_changed", "delta"])
        guard exact(o["version"], "human-context-comparison-v1"), exact(o["project"], request.binding.project),
              exact(o["id"], request.contextID), exact(o["producer"], "human-authored"),
              exact(o["authority"], "context-not-authorization-or-observed-truth") else { throw ServiceError.invalid }
        for (key, entry) in [("from", request.from), ("to", request.to)] {
            let m = try object(o[key], ["revision", "kind", "retired"])
            guard m["revision"] == .number(Double(entry.revision)), exact(m["kind"], entry.kind),
                  m["retired"] == .bool(entry.retired) else { throw ServiceError.invalid }
        }
        let d = try object(o["delta"], ["algorithm", "prefix", "from", "to", "suffix"])
        guard exact(d["algorithm"], "common-prefix-suffix-logical-lines-not-minimal") else { throw ServiceError.invalid }
        let prefix = try text(d["prefix"]), removed = try text(d["from"]), added = try text(d["to"]), suffix = try text(d["suffix"])
        let expected = delta(request.from.text, request.to.text)
        guard zip([prefix, removed, added, suffix], expected).allSatisfy({ $0.utf8.elementsEqual($1.utf8) }),
              (prefix + removed + suffix).utf8.elementsEqual(request.from.text.utf8),
              (prefix + added + suffix).utf8.elementsEqual(request.to.text.utf8) else { throw ServiceError.invalid }
        return Self(request: request, prefix: prefix, removed: removed, added: added, suffix: suffix,
                    textChanged: try flag(o["text_changed"], !request.from.text.utf8.elementsEqual(request.to.text.utf8)),
                    kindChanged: try flag(o["kind_changed"], !request.from.kind.utf8.elementsEqual(request.to.kind.utf8)),
                    retirementChanged: try flag(o["retirement_changed"], request.from.retired != request.to.retired), bytes: data)
    }
    /// LF-inclusive byte segments, not Swift Character splitting (CRLF is one Character).
    static func delta(_ from: String, _ to: String) -> [String] {
        func lines(_ text: String) -> [Data] {
            let bytes = Array(text.utf8)
            var result: [Data] = [], start = 0
            for i in bytes.indices where bytes[i] == 10 { result.append(Data(bytes[start...i])); start = i + 1 }
            if start < bytes.count { result.append(Data(bytes[start...])) }
            return result
        }
        let a = lines(from), b = lines(to)
        var p = 0, s = 0
        while p < min(a.count, b.count), a[p] == b[p] { p += 1 }
        while s < min(a.count - p, b.count - p), a[a.count - 1 - s] == b[b.count - 1 - s] { s += 1 }
        func joined(_ values: ArraySlice<Data>) -> String { String(decoding: values.reduce(into: Data()) { $0.append($1) }, as: UTF8.self) }
        return [joined(a[..<p]), joined(a[p..<(a.count - s)]), joined(b[p..<(b.count - s)]), joined(a[(a.count - s)...])]
    }
}

/// Comparison-only bounded closed object parser. Reject duplicate decoded keys
/// before a dictionary/JSONDecoder can silently collapse them; reject extra frames.
private struct ComparisonJSONParser {
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
                let key = try string()
                guard o[key] == nil, take(58) else { throw ServiceError.invalid }
                o[key] = try value(depth + 1)
                if take(125) { return .object(o) }
            } while take(44)
            throw ServiceError.invalid
        }
        let start = offset
        while offset < bytes.count && ![9, 10, 13, 32, 44, 125].contains(bytes[offset]) { offset += 1 }
        guard offset > start else { throw ServiceError.invalid }
        let scalar = try JSONDecoder().decode(JSONValue.self, from: Data(bytes[start..<offset]))
        switch scalar {
        case .number:
            guard bytes[start..<offset].allSatisfy({ (48...57).contains($0) }) else { throw ServiceError.invalid }; return scalar
        case .bool: return scalar
        default: throw ServiceError.invalid
        }
    }
}
