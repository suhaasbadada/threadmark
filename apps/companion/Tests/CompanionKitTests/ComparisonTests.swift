import Foundation
import Testing
@testable import CompanionKit

let comparisonProject = Project(id: "alpha", root: "/synthetic/alpha", sources: [], rootIdentity: .string("r1"), incarnation: String(repeating: "a", count: 32))
func comparisonHistory(_ texts: [String] = ["head\nold\r\ntail", "head\nnew\ntail"], id: String = "memo") -> ContextHistory {
    ContextHistory(project: "alpha", id: id, producer: "human-authored", authority: .string("context-not-authorization-or-observed-truth"),
        history: texts.enumerated().map { ContextRevision(revision: $0.offset + 1, kind: "note", text: $0.element, retired: false) })
}
func comparisonFrame(_ request: HumanComparisonRequest) throws -> Data {
    let d = HumanComparison.delta(request.from.text, request.to.text)
    let value: [String: Any] = ["version": "human-context-comparison-v1", "project": request.binding.project, "id": request.contextID,
        "producer": "human-authored", "authority": "context-not-authorization-or-observed-truth",
        "from": ["revision": request.from.revision, "kind": request.from.kind, "retired": request.from.retired],
        "to": ["revision": request.to.revision, "kind": request.to.kind, "retired": request.to.retired],
        "text_changed": !request.from.text.utf8.elementsEqual(request.to.text.utf8), "kind_changed": request.from.kind != request.to.kind,
        "retirement_changed": request.from.retired != request.to.retired,
        "delta": ["algorithm": "common-prefix-suffix-logical-lines-not-minimal", "prefix": d[0], "from": d[1], "to": d[2], "suffix": d[3]]]
    var data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes]); data.append(10); return data
}

@Suite("Native human comparison strict contract")
struct ComparisonTests {
    @Test func logicalLinesAreByteExactAndNonminimal() throws {
        let cases: [(String, String, [String])] = [
            ("head\nold\r\ntail", "head\nnew\ntail", ["head\n", "old\r\n", "new\n", "tail"]),
            ("é\n", "e\u{301}\n", ["", "é\n", "e\u{301}\n", ""]),
            ("x\r\n", "x\n", ["", "x\r\n", "x\n", ""]),
            ("x", "x\n", ["", "x", "x\n", ""]),
            ("a\nb\nc\nd", "a\nB\nc\nD", ["a\n", "b\nc\nd", "B\nc\nD", ""]),
            ("a\n\n", "a\n\n", ["a\n\n", "", "", ""])
        ]
        for (a, b, expected) in cases {
            let actual = HumanComparison.delta(a, b)
            #expect(zip(actual, expected).allSatisfy { $0.utf8.elementsEqual($1.utf8) })
            let request = try HumanComparisonRequest(project: comparisonProject, history: comparisonHistory([a, b]), from: 1, to: 2)
            let result = try HumanComparison.decode(comparisonFrame(request), request: request)
            #expect((result.prefix + result.removed + result.suffix).utf8.elementsEqual(a.utf8))
            #expect((result.prefix + result.added + result.suffix).utf8.elementsEqual(b.utf8))
            #expect(result.textChanged == !a.utf8.elementsEqual(b.utf8))
        }
    }
    @Test func equalityKindRetirementAndReactivationFlags() throws {
        let entries = [ContextRevision(revision: 1, kind: "note", text: "Synthetic same\n", retired: false),
                       ContextRevision(revision: 2, kind: "decision", text: "Synthetic same\n", retired: false),
                       ContextRevision(revision: 3, kind: "decision", text: "Synthetic same\n", retired: true),
                       ContextRevision(revision: 4, kind: "decision", text: "Synthetic same\n", retired: false)]
        let history = ContextHistory(project: "alpha", id: "memo", producer: "human-authored", authority: .string("context-not-authorization-or-observed-truth"), history: entries)
        for (a, b) in [(1, 1), (1, 2), (2, 3), (3, 4)] {
            let request = try HumanComparisonRequest(project: comparisonProject, history: history, from: a, to: b)
            let result = try HumanComparison.decode(comparisonFrame(request), request: request)
            #expect(!result.textChanged && result.removed.isEmpty && result.added.isEmpty)
            #expect(result.kindChanged == (a == 1 && b == 2))
            #expect(result.retirementChanged == (a >= 2 && a != b))
        }
    }
    @Test func invalidPairAndUnvalidatedHistoryNeverCapture() throws {
        let history = comparisonHistory()
        for (a, b) in [(0, 1), (2, 1), (1, 3), (1, 33), (-1, 2)] {
            #expect(throws: ServiceError.invalid) { try HumanComparisonRequest(project: comparisonProject, history: history, from: a, to: b) }
        }
        let bad = ContextHistory(project: "alpha", id: "memo", producer: "human-authored", authority: .null, history: history.history)
        #expect(throws: ServiceError.invalid) { try HumanComparisonRequest(project: comparisonProject, history: bad, from: 1, to: 2) }
    }
    @Test func malformedFramesNeverAdopt() throws {
        let request = try HumanComparisonRequest(project: comparisonProject, history: comparisonHistory(), from: 1, to: 2)
        let good = try comparisonFrame(request)
        let original = try #require(JSONSerialization.jsonObject(with: good) as? [String: Any])
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["project"] = "other" }, { $0["id"] = "other" }, { $0["version"] = "future" },
            { $0["producer"] = "source" }, { $0["authority"] = "authorized" }, { $0["extra"] = true },
            { $0["text_changed"] = false }, { $0["kind_changed"] = true }, { $0["retirement_changed"] = true },
            { $0["text_changed"] = 1 }, { $0["from"] = ["revision": 2, "kind": "note", "retired": false] },
            { $0["to"] = ["revision": 2, "kind": "decision", "retired": false] },
            { $0["to"] = ["revision": 2, "kind": "note", "retired": true] },
            { $0["delta"] = ["algorithm": "minimal", "prefix": "", "from": "", "to": "", "suffix": ""] },
            { $0["delta"] = ["algorithm": "common-prefix-suffix-logical-lines-not-minimal", "prefix": "head", "from": "\nold\r\n", "to": "\nnew\n", "suffix": "tail"] }
        ]
        for mutate in mutations {
            var o = original; mutate(&o)
            var bytes = try JSONSerialization.data(withJSONObject: o); bytes.append(10)
            #expect(throws: (any Error).self) { try HumanComparison.decode(bytes, request: request) }
        }
        let text = try #require(String(data: good, encoding: .utf8))
        for bad in [Data(("{\"project\":\"alpha\"," + text.dropFirst()).utf8),
                    Data(("{\"pro\\u006aect\":\"alpha\"," + text.dropFirst()).utf8),
                    Data(text.replacingOccurrences(of: "\"delta\":{", with: "\"delta\":{\"prefix\":\"\",").utf8),
                    good + good, Data(good.dropLast()), Data(good.prefix(good.count / 2)),
                    good + Data(repeating: 32, count: 65536)] {
            #expect(throws: (any Error).self) { try HumanComparison.decode(bad, request: request) }
        }
        // Boundary includes final newline; whitespace cannot hide an extra frame.
        var exact = Data(good.dropLast()); exact.append(Data(repeating: 32, count: 65536 - good.count)); exact.append(10)
        #expect(exact.count == 65536)
        _ = try HumanComparison.decode(exact, request: request)
        exact.insert(32, at: exact.count - 1)
        #expect(throws: ServiceError.outputLimit) { try HumanComparison.decode(exact, request: request) }
    }
}
