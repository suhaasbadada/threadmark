import Foundation

/// Equality guard issued by the retained Rust engine; not an authorization token.
public struct RetainedReviewChallenge: Codable, Equatable, Sendable {
    public let revision: UInt64
    public let digest: String
}

public struct RetainedReviewEditable: Codable, Equatable, Sendable {
    public let objective: String
    public let output_expectations: String
}

public struct RetainedReviewHandoff: Equatable, Sendable {
    public let text: String
    public let choice: String
    public let delivery = "DeliveryNotAttempted"
}

/// Closed local-review-stdio-v1 event, never persisted or logged.
struct RetainedReviewEvent: Decodable, Sendable {
    let version: Int
    let event: String
    let terminal: Bool
    let delivery: String
    let downstream: String?
    let code: String?
    let revision: UInt64?
    let digest: String?
    let proposed: String?
    let changed: Bool?
    let editable: RetainedReviewEditable?
    let material_questions: [String]?
    let coverage: String?
    let provider: RefinementPreview.Provider?
    let text: String?
    let choice: String?

    var challenge: RetainedReviewChallenge? {
        guard let revision, let digest else { return nil }
        return .init(revision: revision, digest: digest)
    }

    static func decode(_ frame: Data, consent: RefinementConsent) throws -> Self {
        guard frame.count <= 8192, frame.last == 10 else { throw ServiceError.outputLimit }
        var scanner = PreviewJSON(frame); try scanner.validate()
        guard let object = try JSONSerialization.jsonObject(with: frame) as? [String: Any] else { throw ServiceError.invalid }
        let value = try JSONDecoder().decode(Self.self, from: frame)
        let base: Set<String> = ["version", "event", "terminal", "delivery"]
        let bound: Set<String> = ["revision", "digest", "downstream"]
        let codes: Set<String> = ["Invalid", "Overflow", "Unavailable", "ScopeMismatch", "Stale", "InferenceNotAuthorized", "Budget", "Deadline", "Canceled", "Superseded", "ProviderFailed", "InvalidBrief", "ReviewRequired"]
        guard value.version == 1, value.delivery == "DeliveryNotAttempted" else { throw ServiceError.invalid }
        if let digest = value.digest {
            guard value.revision != nil, value.revision! > 0, digest.utf8.count == 64,
                  digest.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw ServiceError.invalid }
        } else if value.revision != nil { throw ServiceError.invalid }
        if let downstream = value.downstream {
            guard downstream == "clipboard-draft-send-execution-not-attempted" else { throw ServiceError.invalid }
        }
        let keys = Set(object.keys)
        switch value.event {
        case "preview", "needsinput":
            guard keys == base.union(bound).union(["code", "proposed", "changed", "editable", "material_questions", "coverage", "provider"]),
                  !value.terminal, value.challenge != nil, value.code == nil,
                  let proposed = value.proposed, prose(proposed, limit: 8192),
                  value.changed == !proposed.utf8.elementsEqual(consent.original.utf8),
                  let editable = value.editable,
                  prose(editable.objective, limit: 4096), prose(editable.output_expectations, limit: 4096),
                  let editObject = object["editable"] as? [String: Any], Set(editObject.keys) == ["objective", "output_expectations"],
                  let questions = value.material_questions, questions.count <= 16,
                  questions.allSatisfy({ prose($0, limit: 1024) }),
                  (value.event == "needsinput") == (!questions.isEmpty || consent.selection.results.isEmpty),
                  value.coverage == consent.selection.coverage.description + (consent.selection.truncated == true ? "; bounded selection omits additional matches" : ""),
                  let provider = value.provider,
                  let providerObject = object["provider"] as? [String: Any],
                  Set(providerObject.keys) == ["profile", "model", "endpoint", "locality", "max_calls", "max_tokens", "deadline_seconds", "output_byte_budget", "data_scope"],
                  provider.profile == consent.profile.id, provider.model == consent.profile.model,
                  provider.endpoint == consent.profile.endpoint, provider.locality == "local",
                  provider.max_calls == 1, provider.max_tokens == 1024, provider.deadline_seconds == 30,
                  provider.output_byte_budget == 8192, provider.data_scope == "request-and-selected-evidence"
            else { throw ServiceError.invalid }
        case "failure", "canceled":
            guard let code = value.code, codes.contains(code),
                  (value.event == "canceled") == (code == "Canceled") else { throw ServiceError.invalid }
            if value.terminal {
                guard keys == base.union(["code"]), code != "ReviewRequired" else { throw ServiceError.invalid }
            } else if code == "ReviewRequired" {
                guard keys == base.union(["code"]) else { throw ServiceError.invalid }
            } else {
                guard code == "ProviderFailed", keys == base.union(bound).union(["code"]), value.challenge != nil else { throw ServiceError.invalid }
            }
        case "handoff":
            guard keys == base.union(bound).union(["text", "choice"]), value.terminal,
                  value.challenge != nil, let text = value.text, prose(text, limit: 8192),
                  ["use-prepared", "use-original"].contains(value.choice) else { throw ServiceError.invalid }
        default: throw ServiceError.invalid
        }
        return value
    }

    private static func prose(_ value: String, limit: Int) -> Bool {
        !value.isEmpty && value.utf8.count <= limit && !value.contains("\0")
    }
}

enum RetainedReviewCommand: Sendable {
    case capture(String)
    case edit(RetainedReviewChallenge, String, String)
    case prepared(RetainedReviewChallenge)
    case original(RetainedReviewChallenge)
    case cancel

    func frame() throws -> Data {
        let object: [String: Any]
        func binding(_ challenge: RetainedReviewChallenge) -> [String: Any] {
            ["revision": challenge.revision, "digest": challenge.digest]
        }
        switch self {
        case .capture(let original): object = ["version": 1, "original": original]
        case .edit(let challenge, let objective, let output):
            guard !objective.isEmpty, !output.isEmpty, objective.utf8.count <= 4096, output.utf8.count <= 4096,
                  !objective.contains("\0"), !output.contains("\0") else { throw ServiceError.invalid }
            var fields = binding(challenge); fields["objective"] = objective; fields["output_expectations"] = output
            object = ["edit": fields]
        case .prepared(let challenge): object = ["use-prepared": binding(challenge)]
        case .original(let challenge): object = ["use-original": binding(challenge)]
        case .cancel: object = ["cancel": [String: String]()]
        }
        let data = try JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes]) + Data([10])
        guard data.count <= 8192 else { throw ServiceError.outputLimit }
        return data
    }
}
