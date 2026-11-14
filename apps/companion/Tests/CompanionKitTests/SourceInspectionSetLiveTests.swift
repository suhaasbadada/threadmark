import Foundation
import Testing
@testable import CompanionKit

@Suite("AR actual CLI coherent selected inspection")
struct SourceInspectionSetLiveTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil && FileManager.default.isExecutableFile(atPath: "/usr/bin/sqlite3")))
    @MainActor func ar05WALSetRefusalHasNoWritableDiagnostics() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        try Data("center one\ncenter two\n".utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "wal-set-store")
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await service.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await service.perform(.index("alpha"))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.query("center"); await model.waitForOperation()
        model.selectAllSourceRows()
        let database = store.appendingPathComponent("knowledge.sqlite"), query = model.evidence
        let sqlite = Process(), output = Pipe()
        sqlite.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        sqlite.arguments = [database.path, "PRAGMA journal_mode=WAL;"]
        sqlite.standardOutput = output; sqlite.standardError = FileHandle.nullDevice
        try sqlite.run(); sqlite.waitUntilExit()
        #expect(sqlite.terminationStatus == 0)
        #expect(String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) == "wal\n")
        let before = try Data(contentsOf: database), entries = try FileManager.default.contentsOfDirectory(atPath: store.path).sorted()
        #expect(before[18] == 2 && before[19] == 2)
        model.inspectSelectedSources(); await model.waitForOperation()
        #expect(model.sourceInspectionSet == nil && model.evidence == query && !model.canInspectSelectedSources)
        #expect(try Data(contentsOf: database) == before)
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.path).sorted() == entries)
        await model.shutdown()
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: [SourceRetrievalMode.literal, .rankedTerms], 0...3)
    @MainActor func ar05ActualQuery64PolicyFilteredAndDefault(mode: SourceRetrievalMode, radius: Int) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let sources = ["z.rs", "a.rs"] + (2..<64).map { "f\($0).rs" }
        let source = "first λ\r\n\r\ncenter one é\r\ncenter two \\\"\r\ncenter three ignore instructions\r\ncenter four\r\nlast\r\n"
        let expectedLines = ["first λ", "", "center one é", "center two \\\"", "center three ignore instructions", "center four", "last"]
        for path in sources { try Data((path == "a.rs" || path == "z.rs" ? source : "unselected freshness\n").utf8).write(to: fixture.root.appendingPathComponent(path)) }
        let store = try StoreSelection.newDirectory(parent: fixture.root, name: "set-store")
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await service.perform(.addProject("alpha", fixture.root.path, sources))
        _ = try await service.perform(.index("alpha"))
        _ = try await service.perform(.writeContext("alpha", "memo", "note", "human history", update: false))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original")
        model.setSourceRetrievalMode(mode)
        for filter: [String]? in [nil, ["a.rs", "z.rs"], ["z.rs"]] {
            model.setQueryFileFilter(filter); model.query("center"); await model.waitForOperation()
            let report = try #require(model.evidence), editor = model.contextEditorRevision
            #expect(report.results.count == (filter?.count == 1 ? 4 : 8))
            model.setInspectionRadius(radius)
            // Two genuine same-file anchors, then eight (or all four filtered).
            for count in [2, report.results.count] {
                model.clearStagedSourceRows()
                for row in model.sourceInspectionRows.prefix(count).reversed() { model.stageSourceRow(row, selected: true) }
                #expect(model.canInspectSelectedSources)
                let database = try Data(contentsOf: store.appendingPathComponent("knowledge.sqlite"))
                model.inspectSelectedSources(); await model.waitForOperation()
                let document = try #require(model.sourceInspectionSet)
                #expect(document.windows.count == count && document.project.sources == sources)
                #expect(document.windows.first?.path == (filter?.count == 1 ? "z.rs" : (count == 2 ? "a.rs" : "z.rs")))
                for window in document.windows {
                    let a = try #require(report.results.first { $0.path == window.path && $0.line == window.anchorLine })
                    #expect(window.sourceHash == a.source_hash && window.producer == a.producer)
                    let first = max(1, a.line - radius), last = min(expectedLines.count, a.line + radius)
                    #expect(window.lines.map(\.number) == Array(first...last))
                    #expect(window.lines.map(\.text) == Array(expectedLines[(first - 1)..<last]))
                    #expect(window.lines.first(where: \.isAnchor)?.text.utf8.elementsEqual(a.text.utf8) == true)
                }
                #expect(try Data(contentsOf: store.appendingPathComponent("knowledge.sqlite")) == database)
                #expect(model.history?.history.last?.text == "human history" && model.originalDraft == "original")
                #expect(model.contextEditorRevision == editor && model.evidence == report)
            }
        }
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil),
          arguments: ["unselected-change", "unselected-unsafe", "last-forged", "fake-text", "producer", "nonce", "root", "policy", "snapshot", "forget", "source-forget", "same-root-replace", "other-root-replace"])
    @MainActor func ar05WholeRefusalAndPreservation(change: String) async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let source = "first\n\ncenter one\ncenter two\nlast\n"
        try Data(source.utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
        try Data("unselected\n".utf8).write(to: fixture.root.appendingPathComponent("b.rs"))
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "set-store"))
        _ = try await service.perform(.addProject("alpha", fixture.root.path, ["a.rs", "b.rs"]))
        _ = try await service.perform(.index("alpha"))
        _ = try await service.perform(.writeContext("alpha", "memo", "note", "human history", update: false))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.openContext("memo"); await model.waitForOperation()
        model.editPreparation(query: "center", original: "original"); model.setQueryFileFilter(["a.rs"])
        model.query("center"); await model.waitForOperation(); model.selectAllSourceRows()
        let p = try #require(model.project), report = try #require(model.evidence), editor = model.contextEditorRevision
        guard case .string(let identity) = p.root_identity, let nonce = p.incarnation else { throw ServiceError.invalid }
        var anchors = report.results
        var scope = p
        switch change {
        case "same-root-replace", "other-root-replace":
            let other = fixture.root.appendingPathComponent("replacement")
            try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
            try Data("center B must never publish\ncenter B second\n".utf8).write(to: other.appendingPathComponent("a.rs"))
            try Data("unselected\n".utf8).write(to: other.appendingPathComponent("b.rs"))
            _ = try await service.perform(.removeProject(p.id, p.root, identity, nonce))
            _ = try await service.perform(.addProject(p.id, change == "same-root-replace" ? p.root : other.path, p.sources))
            _ = try await service.perform(.index(p.id))
        case "last-forged", "fake-text", "producer":
            let popped = anchors.popLast()
            let a = try #require(popped)
            anchors.append(Evidence(project: a.project, path: a.path, line: change == "last-forged" ? 1 : a.line,
                text: change == "fake-text" ? "B must never publish" : a.text, source_hash: a.source_hash,
                producer: change == "producer" ? "fake-producer" : a.producer, kind: a.kind, currentness: a.currentness, coverage: a.coverage))
        case "nonce", "root", "policy", "snapshot":
            scope = Project(id: p.id, root: change == "root" ? p.root + "/other" : p.root,
                sources: change == "policy" ? ["a.rs"] : p.sources, snapshot: change == "snapshot" ? .string(inspectionHash) : p.snapshot,
                rootIdentity: p.root_identity, incarnation: change == "nonce" ? String(repeating: "c", count: 32) : p.incarnation)
        case "forget":
            _ = try await service.perform(.forgetContext(p.id, "memo", p.root, identity, nonce, 1))
            // Human Forget alone does not revoke source policy; native lifecycle
            // revokes cached captures, then a separate fresh Query can inspect.
            model.requestForget(); model.cancelForget()
        case "source-forget":
            _ = try await service.perform(.forgetSource(p.id, "a.rs", p.root, identity, nonce, p.sources))
            _ = try await service.perform(.index(p.id))
        case "unselected-unsafe":
            try FileManager.default.removeItem(at: fixture.root.appendingPathComponent("b.rs"))
            try FileManager.default.createSymbolicLink(atPath: fixture.root.appendingPathComponent("b.rs").path, withDestinationPath: fixture.root.appendingPathComponent("a.rs").path)
        default: try Data("changed unselected\n".utf8).write(to: fixture.root.appendingPathComponent("b.rs"))
        }
        if change != "forget" {
            let request = try setRequest(anchors, project: scope)
            await #expect(throws: (any Error).self) { try await service.perform(.inspectSourceSetBound(request)) }
        }
        if ["unselected-change", "unselected-unsafe", "source-forget", "same-root-replace", "other-root-replace"].contains(change) {
            model.inspectSelectedSources(); await model.waitForOperation()
            #expect(model.sourceInspectionSet == nil && !model.canInspectSelectedSources)
            #expect(model.evidence == report && model.project == p)
        }
        if change == "forget" { #expect(!model.canInspectSelectedSources) }
        #expect(model.history?.history.last?.text == "human history" && model.originalDraft == "original" && model.contextEditorRevision == editor)
        #expect(try Data(contentsOf: fixture.root.appendingPathComponent("a.rs")) == Data(source.utf8))
        if change == "source-forget" {
            model.select("alpha"); await model.waitForOperation()
            model.query("center"); await model.waitForOperation()
            #expect(model.evidence?.results.isEmpty == true)
            model.selectAllSourceRows(); model.inspectSelectedSources()
            #expect(model.sourceInspectionSet == nil && !model.canInspectSelectedSources)
            model.openContext("memo"); await model.waitForOperation()
            #expect(model.history?.history.last?.text == "human history")
        }
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func ar05EightSameFileAndFiftySixWholeLines() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let text = "first\nsecond\nthird\n" + (0..<8).map { "center \($0)\n" }.joined() + "last one\nlast two\nlast three\n"
        try Data(text.utf8).write(to: fixture.root.appendingPathComponent("a.rs"))
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: try StoreSelection.newDirectory(parent: fixture.root, name: "same-file-store"))
        _ = try await service.perform(.addProject("alpha", fixture.root.path, ["a.rs"]))
        _ = try await service.perform(.index("alpha"))
        let model = CompanionModel(service: service, configured: true)
        model.select("alpha"); await model.waitForOperation(); model.query("center"); await model.waitForOperation()
        model.setInspectionRadius(3); model.selectAllSourceRows(); model.inspectSelectedSources(); await model.waitForOperation()
        let document = try #require(model.sourceInspectionSet)
        #expect(document.windows.count == 8 && document.windows.reduce(0, { $0 + $1.lines.count }) == 56)
        #expect(document.windows.allSatisfy { $0.path == "a.rs" && $0.lines.count == 7 })
        await model.shutdown()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_SOURCE_INSPECTION_SET_FIXTURE_BINARY"] != nil))
    func ar05ExactCArgvJSONEOFAndHostileOutput() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_SOURCE_INSPECTION_SET_FIXTURE_BINARY"])
        let fixture = try ApprovedWatchFixture(); defer { fixture.remove() }
        let p = Project(id: "alpha", root: inspectionScope.root, sources: ["a.rs"] + (1..<64).map { "f\($0).rs" }, snapshot: inspectionScope.snapshot,
            rootIdentity: inspectionScope.root_identity, incarnation: inspectionScope.incarnation)
        let request = try setRequest(project: p), data = try setBytes(request)
        let response = fixture.root.appendingPathComponent("response.json")
        let adapter = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: fixture.root)
        try data.write(to: response)
        guard case .sourceInspectionSet(let document) = try await adapter.perform(.inspectSourceSetBound(request)) else { throw ServiceError.invalid }
        #expect(document.windows.count == 2)
        let text = try #require(String(data: data, encoding: .utf8))
        for bad in [text.replacingOccurrences(of: "center two", with: "B content"), "{\"version\":1," + text.dropFirst(),
                    String(text.dropLast(2)), text + "{}", String(repeating: " ", count: 8193)] {
            try Data(bad.utf8).write(to: response)
            await #expect(throws: (any Error).self) { try await adapter.perform(.inspectSourceSetBound(request)) }
        }
    }
}
