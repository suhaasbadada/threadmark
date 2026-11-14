import Foundation

/// Session-only copied intent. Human declarations, never source truth or authority.
public struct BatchEntry: Identifiable, Sendable {
    public let id: String
    public let operation: String
    public let expectedRevision: Int
    public let kind: String
    public let text: String
    public let capturedHistory: ContextHistory
    let historyGeneration: UInt64
}

/// Read-only disclosure; deliberately not executable transport authority.
public struct BatchReview: Identifiable, Sendable {
    public let id: UUID
    public let entries: [BatchEntry]
    let binding: HumanContextReadBinding
    let generation: UInt64
    let configuration: UInt64
    let planGeneration: UInt64
}

struct BatchPlan: Sendable {
    let binding: HumanContextReadBinding
    let entries: [BatchEntry]
    func encoded() throws -> Data {
        try binding.validate()
        guard (2...8).contains(entries.count), Set(entries.map(\.id)).count == entries.count else { throw ServiceError.invalid }
        var total = 0
        let actions: [JSONValue] = try entries.map { e in
            try e.capturedHistory.validate(project: binding.project, id: e.id)
            guard e.expectedRevision == e.capturedHistory.history.count, (1...31).contains(e.expectedRevision),
                  InputPolicy.identifier(e.id), InputPolicy.contextKinds.contains(e.kind),
                  !e.text.isEmpty, !e.text.contains("\0"), e.text.utf8.count <= 4096,
                  ["update", "retire"].contains(e.operation) else { throw ServiceError.invalid }
            total += e.text.utf8.count
            var o: [String: JSONValue] = ["operation": .string(e.operation), "id": .string(e.id), "expected_revision": .number(Double(e.expectedRevision))]
            if e.operation == "update" { o["kind"] = .string(e.kind); o["text"] = .string(e.text) }
            else {
                guard let latest = e.capturedHistory.history.last,
                      latest.kind == e.kind, latest.text.utf8.elementsEqual(e.text.utf8) else { throw ServiceError.invalid }
            }
            return .object(o)
        }
        guard total <= 32768 else { throw ServiceError.invalid }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(JSONValue.object(["version": .string("human-context-batch-edit-v1"), "actions": .array(actions)]))
        guard data.count <= 65536 else { throw ServiceError.invalid }
        return data
    }
}

/// API lifecycle guardrail, not authentication against malicious in-module code.
public final class BatchExecution: @unchecked Sendable {
    private let lock = NSLock()
    private var available = true
    private let plan: BatchPlan
    init(_ plan: BatchPlan) { self.plan = plan }
    func claim() throws -> BatchPlan {
        lock.lock(); defer { lock.unlock() }
        guard available else { throw ServiceError.invalid }
        available = false; return plan
    }
    func revoke() { lock.lock(); available = false; lock.unlock() }
}

public struct BatchReceipt: Sendable {
    public let count: Int
    let bytes: Data
    static func decode(_ data: Data, plan: BatchPlan) throws -> Self {
        _ = try plan.encoded()
        guard data.count <= 8192, data.last == 10 else { throw ServiceError.outputLimit }
        var parser = BatchJSONParser(data)
        guard case .object(let o) = try parser.parse(), Set(o.keys) == ["version", "project", "count", "actions"],
              o["version"] == .string("human-context-batch-edit-v1"),
              o["project"] == .string(plan.binding.project), o["count"] == .number(Double(plan.entries.count)),
              case .array(let actions) = o["actions"], actions.count == plan.entries.count else { throw ServiceError.invalid }
        for (value, e) in zip(actions, plan.entries.sorted(by: { $0.id < $1.id })) {
            guard case .object(let a) = value, Set(a.keys) == ["id", "operation", "old_revision", "new_revision"],
                  a["id"] == .string(e.id), a["operation"] == .string(e.operation),
                  a["old_revision"] == .number(Double(e.expectedRevision)),
                  a["new_revision"] == .number(Double(e.expectedRevision + 1)) else { throw ServiceError.invalid }
        }
        return Self(count: actions.count, bytes: data)
    }
}

/// Closed bounded metadata parser: duplicate decoded keys and noninteger tokens fail.
private struct BatchJSONParser {
    let bytes: [UInt8]
    var offset = 0
    init(_ data: Data) { bytes = Array(data) }
    mutating func whitespace() { while offset < bytes.count && [9, 10, 13, 32].contains(bytes[offset]) { offset += 1 } }
    mutating func take(_ b: UInt8) -> Bool {
        whitespace(); guard offset < bytes.count, bytes[offset] == b else { return false }; offset += 1; return true
    }
    mutating func parse() throws -> JSONValue {
        let v = try value(0); whitespace(); guard offset == bytes.count else { throw ServiceError.invalid }; return v
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
        guard depth <= 4 else { throw ServiceError.invalid }; whitespace()
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
                guard a.count < 8 else { throw ServiceError.invalid }; a.append(try value(depth + 1))
                if take(93) { return .array(a) }
            } while take(44)
            throw ServiceError.invalid
        }
        let start = offset
        while offset < bytes.count && (48...57).contains(bytes[offset]) { offset += 1 }
        guard offset > start, offset - start <= 2, bytes[start] != 48,
              let n = Int(String(decoding: bytes[start..<offset], as: UTF8.self)), (1...32).contains(n) else { throw ServiceError.invalid }
        return .number(Double(n))
    }
}
