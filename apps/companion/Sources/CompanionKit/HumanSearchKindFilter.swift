import Foundation

/// Immutable, explicitly selected human kinds. No edit or source authority.
public struct HumanSearchKindRequest: Sendable {
    public let binding: HumanContextReadBinding
    public let query: String
    public let kinds: [String]

    init(binding: HumanContextReadBinding, query: String, kinds: [String]) throws {
        self.binding = binding; self.query = query
        self.kinds = kinds.sorted()
        try validate()
    }
    func validate() throws {
        try binding.validate()
        guard InputPolicy.humanSearch(query), !kinds.isEmpty, kinds.count <= InputPolicy.contextKinds.count,
              kinds == kinds.sorted(), Set(kinds).count == kinds.count,
              kinds.allSatisfy({ InputPolicy.contextKinds.contains($0) }) else { throw ServiceError.invalid }
    }
}

/// Distinct closed wire contract; the old search decoder is not widened.
public struct FilteredHumanSearch: Sendable {
    public let selectedKinds: [String]
    public let search: HumanContextSearch
    let bytes: Data

    static func decode(_ data: Data, request: HumanSearchKindRequest) throws -> Self {
        try request.validate()
        guard data.count <= 8192 else { throw ServiceError.outputLimit }
        guard data.last == 10 else { throw ServiceError.invalid }
        var parser = FilteredSearchJSONParser(Data(data.dropLast()))
        guard case .object(var object) = try parser.parse(),
              Set(object.keys) == ["version", "selected_kinds", "project", "root_identity", "incarnation", "producer", "status", "authority", "coverage", "selection", "matched_entries", "omitted_entries", "truncated", "results"],
              object.removeValue(forKey: "version") == .string("human-search-kind-filter-v1"),
              object.removeValue(forKey: "selected_kinds") == .array(request.kinds.map { .string($0) }) else { throw ServiceError.invalid }
        let projectionEncoder = JSONEncoder(); projectionEncoder.outputFormatting = [.withoutEscapingSlashes]
        let search = try HumanContextSearch.decode(projectionEncoder.encode(JSONValue.object(object)), project: request.binding.project)
        guard search.project.utf8.elementsEqual(request.binding.project.utf8),
              search.root_identity.utf8.elementsEqual(request.binding.rootIdentity.utf8),
              search.incarnation?.utf8.elementsEqual(request.binding.incarnation.utf8) == true else { throw ServiceError.namespaceChanged }
        guard search.results.allSatisfy({ request.kinds.contains($0.kind) }) else { throw ServiceError.invalid }
        return Self(selectedKinds: request.kinds, search: search, bytes: data)
    }
    func validate(request: HumanSearchKindRequest, scope: Project) throws {
        let checked = try Self.decode(bytes, request: request)
        try checked.search.validate(scope: scope)
        try search.validate(scope: scope)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard selectedKinds == request.kinds, try encoder.encode(search) == encoder.encode(checked.search) else { throw ServiceError.invalid }
    }
}

/// Filter-only bounded parser; detects decoded duplicate keys before collapse.
private struct FilteredSearchJSONParser {
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
            var object: [String: JSONValue] = [:]
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
            var array: [JSONValue] = []
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
        let scalar = try JSONDecoder().decode(JSONValue.self, from: Data(bytes[start..<offset]))
        switch scalar {
        case .number:
            guard bytes[start..<offset].allSatisfy({ (48...57).contains($0) }) else { throw ServiceError.invalid }; return scalar
        case .bool: return scalar
        default: throw ServiceError.invalid
        }
    }
}
