import Foundation

/// One immutable, memory-only inference permission. Not engine approval or delivery.
public struct RefinementConsent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let project: Project
    public let query: String
    public let original: String
    public let settings: ProviderSettings
    public let profile: ProviderProfile
    public let selection: QueryReport
    let generation: UInt64
    let scopeRevision: UInt64

    public static let disclosure = "One local HTTP inference call; up to 1024 generated tokens, 8192 output bytes and 30 seconds. Only this original request and the selected source evidence below, no attachments or whole-project upload. A local server may forward data elsewhere: loopback is NOT a sandbox or network-isolation guarantee. Preview only: no approval, clipboard, host draft or Send."

    func validate() throws {
        guard try settings.selectedProfile() == profile, profile.locality == .local,
              InputPolicy.identifier(project.id), InputPolicy.preparation(query: query, original: original),
              case .string(let identity) = project.root_identity,
              InputPolicy.removal(root: project.root, identity: identity),
              let token = project.incarnation, InputPolicy.incarnation(token),
              case .string(let snapshot) = project.snapshot, Self.hash(snapshot),
              selection.project == project.id, selection.snapshot == project.snapshot,
              selection.currentness == "current-at-read", selection.results.count <= 8,
              selection.results.allSatisfy({
                  $0.project == project.id && project.sources.contains($0.path) && $0.line > 0 &&
                  $0.kind == "observed-source-line" && $0.currentness == "current-at-read" &&
                  $0.producer == "lexical-lines-v1" && Self.hash($0.source_hash)
              }) else { throw ServiceError.invalid }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
        guard try encoder.encode(selection).count + 1 <= 8192 else { throw ServiceError.outputLimit }
    }
    private static func hash(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}

/// F's finite CLI exits after preview; this value carries no retained approval.
public struct RefinementPreview: Codable, Equatable, Sendable {
    public struct Provider: Codable, Equatable, Sendable {
        public let profile: String
        public let model: String
        public let endpoint: String
        public let locality: String
        public let data_scope: String
        public let max_calls: Int
        public let max_tokens: Int
        public let deadline_seconds: Int
        public let output_byte_budget: Int
    }
    public let project: String
    public let snapshot: String
    public let root: String
    public let root_identity: String
    public let incarnation: String
    public let query: String
    public let mode: String
    public let state: String
    public let original: String
    public let proposed: String
    public let changed: Bool
    public let material_questions: [String]
    public let coverage: String
    public let approval: String
    public let delivery: String
    public let provider: Provider

    public func validate(consent: RefinementConsent) throws {
        try consent.validate()
        guard project == consent.project.id, .string(snapshot) == consent.project.snapshot,
              root == consent.project.root, .string(root_identity) == consent.project.root_identity,
              incarnation == consent.project.incarnation, query.utf8.elementsEqual(consent.query.utf8),
              mode == "refinement-preview", ["ready-for-review", "needs-input"].contains(state),
              original.utf8.elementsEqual(consent.original.utf8),
              !proposed.isEmpty, proposed.utf8.count <= 8192, !proposed.contains("\0"),
              changed == !original.utf8.elementsEqual(proposed.utf8),
              material_questions.count <= 16,
              material_questions.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 1024 && !$0.contains("\0") }),
              (state == "needs-input") == (!material_questions.isEmpty || consent.selection.results.isEmpty),
              coverage == consent.selection.coverage.description + (consent.selection.truncated == true ? "; bounded selection omits additional matches" : ""),
              approval == "not-requested", delivery == "not-attempted",
              provider.profile == consent.profile.id, provider.model == consent.profile.model,
              provider.endpoint == consent.profile.endpoint, provider.locality == "local",
              provider.data_scope == "request-and-selected-evidence", provider.max_calls == 1,
              provider.max_tokens == 1024, provider.deadline_seconds == 30,
              provider.output_byte_budget == 8192 else { throw ServiceError.invalid }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.withoutEscapingSlashes]
        guard try encoder.encode(self).count + 1 <= 8192 else { throw ServiceError.outputLimit }
    }

    static func decode(_ data: Data, consent: RefinementConsent) throws -> Self {
        guard data.count <= 8192 else { throw ServiceError.outputLimit }
        var scanner = PreviewJSON(data)
        try scanner.validate()
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["project", "snapshot", "root", "root_identity", "incarnation", "query", "mode", "state", "original", "proposed", "changed", "material_questions", "coverage", "approval", "delivery", "provider"],
              let provider = object["provider"] as? [String: Any],
              Set(provider.keys) == ["profile", "model", "endpoint", "locality", "data_scope", "max_calls", "max_tokens", "deadline_seconds", "output_byte_budget"],
              object["material_questions"] is [String] else { throw ServiceError.invalid }
        let result = try JSONDecoder().decode(Self.self, from: data)
        try result.validate(consent: consent)
        return result
    }
}

/// Preview-only duplicate-member gate, including escaped key aliases. Foundation
/// otherwise silently keeps one value. JSONDecoder still owns syntax/type checks.
private struct PreviewJSON {
    let bytes: [UInt8]
    var position = 0
    init(_ data: Data) { bytes = Array(data) }
    mutating func whitespace() {
        while position < bytes.count && [9, 10, 13, 32].contains(bytes[position]) { position += 1 }
    }
    mutating func take(_ byte: UInt8) -> Bool {
        whitespace()
        guard position < bytes.count, bytes[position] == byte else { return false }
        position += 1; return true
    }
    mutating func string() throws -> String {
        whitespace(); let start = position
        guard take(34) else { throw ServiceError.invalid }
        while position < bytes.count {
            let byte = bytes[position]; position += 1
            if byte == 92 { guard position < bytes.count else { throw ServiceError.invalid }; position += 1 }
            else if byte == 34 { return try JSONDecoder().decode(String.self, from: Data(bytes[start..<position])) }
        }
        throw ServiceError.invalid
    }
    mutating func value(depth: Int) throws {
        guard depth <= 8 else { throw ServiceError.invalid }
        whitespace()
        if take(123) {
            var keys = Set<String>()
            if take(125) { return }
            repeat {
                let key = try string()
                guard keys.insert(key).inserted, take(58) else { throw ServiceError.invalid }
                try value(depth: depth + 1)
                if take(125) { return }
            } while take(44)
            throw ServiceError.invalid
        } else if take(91) {
            if take(93) { return }
            repeat { try value(depth: depth + 1); if take(93) { return } } while take(44)
            throw ServiceError.invalid
        } else if position < bytes.count, bytes[position] == 34 { _ = try string() }
        else {
            let start = position
            while position < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[position]) { position += 1 }
            guard position > start else { throw ServiceError.invalid }
        }
    }
    mutating func validate() throws {
        try value(depth: 0); whitespace()
        guard position == bytes.count else { throw ServiceError.invalid }
    }
}
