import Foundation
import Testing
@testable import CompanionKit

@Suite("Actual CLI native confirmed local export", .serialized)
struct LiveProjectExportTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func consentPrivateCompleteHistoryAndStaleBindingsFailWithoutFile() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fm = FileManager.default
        let base = try StoreSelection.existingDirectory(fm.temporaryDirectory).appendingPathComponent("opencode/export-X-live-" + UUID().uuidString)
        try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: base) }
        let root = base.appendingPathComponent("source"), output = base.appendingPathComponent("output"), store = base.appendingPathComponent("store")
        for d in [root, output] { try fm.createDirectory(at: d, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]) }
        let source = Data("fn synthetic_export_source() {}\n".utf8)
        try source.write(to: root.appendingPathComponent("a.rs"))
        let service = ProcessService(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        _ = try await service.perform(.addProject("alpha", root.path, ["a.rs"]))
        _ = try await service.perform(.writeContext("alpha", "memo", "note", "Synthetic original human edit", update: false))
        _ = try await service.perform(.writeContext("alpha", "memo", "decision", "Synthetic second human edit", update: true))
        _ = try await service.perform(.retireContext("alpha", "memo"))
        _ = try await service.perform(.index("alpha"))
        let m = CompanionModel(service: service, configured: true)
        m.select("alpha"); await m.waitForOperation()
        m.requestProjectExport(); let canceled = try #require(m.pendingProjectExport)
        m.cancelProjectExport(); m.completeProjectExportSelection(canceled, destination: output.appendingPathComponent("cancel.json"))
        #expect(try fm.contentsOfDirectory(atPath: output.path).isEmpty)
        m.requestProjectExport(); let c = try #require(m.pendingProjectExport)
        _ = try #require(m.confirmProjectExport(c))
        let destination = output.appendingPathComponent("complete.json")
        m.completeProjectExportSelection(c, destination: destination); await m.waitForOperation()
        #expect(m.lastError == nil)
        let bytes = try Data(contentsOf: destination)
        _ = try ProjectExportDocument.decode(bytes, scope: c.project)
        let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let history = try #require(object["human_history"] as? [[String: Any]])
        #expect(history.count == 3 && history.last?["retired"] as? Bool == true)
        #expect(history.map { $0["text"] as? String } == ["Synthetic original human edit", "Synthetic second human edit", "Synthetic second human edit"])
        #expect((object["evidence"] as? [[String: Any]])?.count == 1)
        #expect(!String(decoding: bytes, as: UTF8.self).contains(root.path))
        #expect(try Data(contentsOf: root.appendingPathComponent("a.rs")) == source)
        for change in ["snapshot", "policy", "nonce", "root"] {
            // Each independent peer-change probe starts with explicit selection.
            // V's cached Refresh must not adopt the prior probe's replacement
            // registration by local ID alone.
            m.select("alpha"); await m.waitForOperation()
            m.requestProjectExport(); let old = try #require(m.pendingProjectExport)
            _ = try #require(m.confirmProjectExport(old))
            if change == "snapshot" {
                try Data("fn synthetic_changed_source() {}\n".utf8).write(to: root.appendingPathComponent("a.rs"))
                _ = try await service.perform(.index("alpha"))
            } else if change == "policy" { _ = try await service.perform(.setSources("alpha", [])) }
            else {
                guard case .string(let identity) = old.project.root_identity, let token = old.project.incarnation else { throw ServiceError.invalid }
                _ = try await service.perform(.removeProject("alpha", old.project.root, identity, token))
                let replacement = change == "root" ? base.appendingPathComponent("replacement") : root
                if change == "root" { try fm.createDirectory(at: replacement, withIntermediateDirectories: false) }
                _ = try await service.perform(.addProject("alpha", replacement.path, []))
            }
            let target = output.appendingPathComponent(change + ".json")
            m.completeProjectExportSelection(old, destination: target); await m.waitForOperation()
            #expect(m.lastError != nil && !fm.fileExists(atPath: target.path))
        }
        #expect(try fm.contentsOfDirectory(atPath: output.path) == ["complete.json"])
        await m.shutdown()
    }
}
