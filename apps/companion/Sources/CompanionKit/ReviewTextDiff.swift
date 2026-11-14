import Foundation

/// Presentation only: no authority, normalization, persistence or semantic claims.
/// Linear byte scanning and shared-prefix/suffix comparison, never quadratic LCS.
/// The changed middle is deliberately NOT presented as an exact/minimal alignment.
struct ReviewTextDiff: Sendable {
    static let originalByteLimit = 4096
    static let proposedByteLimit = 8192
    static let lineBudget = 512 // combined old/new logical lines, including blank lines

    enum Kind: String, Sendable { case context = "Context", removed = "Removed", added = "Added" }
    enum Ending: String, Sendable { case lf = "LF", crlf = "CRLF", none = "No line ending" }
    struct Line: Sendable {
        let text: String
        let ending: Ending
        var bytes: [UInt8] {
            Array(text.utf8) + (ending == .crlf ? [13, 10] : ending == .lf ? [10] : [])
        }
        var hex: String { bytes.map { String(format: "%02X", $0) }.joined(separator: " ") }
    }
    struct Row: Sendable {
        let kind: Kind
        let oldLine: Int?
        let newLine: Int?
        let line: Line
        var label: String {
            "\(kind.rawValue) · old \(oldLine.map(String.init) ?? "—") · new \(newLine.map(String.init) ?? "—") · \(line.ending.rawValue)"
        }
    }
    enum Fallback: String, Sendable {
        case bytes = "Comparison byte budget exceeded (4096 original / 8192 proposed). Full texts above; no aligned diff computed."
        case lines = "Comparison line budget exceeded (512 combined lines). Full texts above; no aligned diff computed."
    }
    let original: String
    let proposed: String
    let rows: [Row]
    let fallback: Fallback?
    let identical: Bool

    init(original: String, proposed: String) {
        self.original = original; self.proposed = proposed
        // Prefix counts bound work even for out-of-contract inputs. Full strings
        // are retained without copying/truncation for the fallback presentation.
        guard original.utf8.prefix(Self.originalByteLimit + 1).count <= Self.originalByteLimit,
              proposed.utf8.prefix(Self.proposedByteLimit + 1).count <= Self.proposedByteLimit else {
            rows = []; fallback = .bytes; identical = false; return
        }
        identical = original.utf8.elementsEqual(proposed.utf8)
        let old = Self.lines(original), new = Self.lines(proposed)
        guard old.count + new.count <= Self.lineBudget else {
            rows = []; fallback = .lines; return
        }
        fallback = nil
        var prefix = 0, suffix = 0
        while prefix < min(old.count, new.count), old[prefix].bytes == new[prefix].bytes { prefix += 1 }
        while suffix < min(old.count, new.count) - prefix,
              old[old.count - suffix - 1].bytes == new[new.count - suffix - 1].bytes { suffix += 1 }
        var result: [Row] = []
        for i in 0..<prefix { result.append(Row(kind: .context, oldLine: i + 1, newLine: i + 1, line: old[i])) }
        for i in prefix..<(old.count - suffix) { result.append(Row(kind: .removed, oldLine: i + 1, newLine: nil, line: old[i])) }
        for i in prefix..<(new.count - suffix) { result.append(Row(kind: .added, oldLine: nil, newLine: i + 1, line: new[i])) }
        for i in 0..<suffix {
            let a = old.count - suffix + i, b = new.count - suffix + i
            result.append(Row(kind: .context, oldLine: a + 1, newLine: b + 1, line: old[a]))
        }
        rows = result
    }

    private static func lines(_ text: String) -> [Line] {
        let bytes = Array(text.utf8)
        var result: [Line] = [], start = 0
        for i in bytes.indices where bytes[i] == 10 {
            let crlf = i > start && bytes[i - 1] == 13
            result.append(Line(text: String(decoding: bytes[start..<(crlf ? i - 1 : i)], as: UTF8.self), ending: crlf ? .crlf : .lf))
            start = i + 1
        }
        if start < bytes.count { result.append(Line(text: String(decoding: bytes[start...], as: UTF8.self), ending: .none)) }
        return result // empty is zero lines; a final LF belongs to its preceding line
    }
}
