import Testing
import Foundation
import Darwin
import SwiftUI
@testable import CompanionKit

private func profileSettings() throws -> ProviderSettings {
    var settings = ProviderSettings()
    try settings.configure(ProviderProfile(id: "synthetic", endpoint: "http://127.0.0.1:8080/v1/chat/completions", model: "synthetic-model", locality: .local))
    return settings
}

private func profileDirectory() throws -> URL {
    let pointer = try #require(realpath(FileManager.default.temporaryDirectory.path, nil))
    defer { free(pointer) }
    let url = URL(fileURLWithPath: String(cString: pointer)).appendingPathComponent("threadmark-profile-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    return url
}

private func profileFixture(_ bytes: Data, _ url: URL, mode: mode_t = 0o600) throws {
    try bytes.write(to: url); #expect(chmod(url.path, mode) == 0)
}

@Suite("Explicit companion profile files")
struct ProviderProfileFileTests {
    @Test func privateRoundTripAndNoOverwrite() throws {
        let directory = try profileDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("profile.json")
        var settings = try profileSettings(); settings.enabled = true
        try ProviderProfileFile.save(settings, to: file)
        let bytes = try Data(contentsOf: file)
        let loaded = try ProviderProfileFile.load(file)
        #expect(!loaded.enabled)
        #expect(loaded.profiles == settings.profiles && loaded.selectedProfileID == "synthetic")
        #expect(throws: (any Error).self) { try ProviderProfileFile.save(ProviderSettings(), to: file) }
        #expect(try Data(contentsOf: file) == bytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["profile.json"])
        #expect(bytes.count <= ProviderProfileFile.limit)
    }

    @Test func canonicalOnlyRejectsDuplicateAmbiguousAndOversize() throws {
        let settings = try profileSettings()
        let valid = try ProviderProfileFile.encode(settings)
        let json = String(decoding: valid, as: UTF8.self)
        let bad = [
            Data("{".utf8), Data(repeating: 32, count: 65537),
            Data((" " + json).utf8),
            Data(json.replacingOccurrences(of: "\"enabled\":false", with: "\"enabled\":true,\"enabled\":false").utf8),
            Data(json.replacingOccurrences(of: "\"enabled\":false", with: "\"en\\u0061bled\":true,\"enabled\":false").utf8),
            Data(json.replacingOccurrences(of: "\"enabled\":false", with: "\"secret\":\"synthetic\",\"enabled\":false").utf8),
            Data(json.replacingOccurrences(of: "\"selectedProfileID\":\"synthetic\"", with: "\"selectedProfileID\":\"absent\"").utf8)
        ]
        for bytes in bad { #expect(throws: (any Error).self) { try ProviderProfileFile.decode(bytes) } }
        var duplicate = settings; duplicate.profiles += settings.profiles
        #expect(throws: (any Error).self) { try ProviderProfileFile.encode(duplicate) }
        var invalid = settings; invalid.profiles.append(ProviderProfile(id: "bad", endpoint: "https://localhost/", model: "m", locality: .remote))
        #expect(throws: (any Error).self) { try ProviderProfileFile.encode(invalid) }
        var tooMany = settings
        tooMany.profiles = (0..<17).map { ProviderProfile(id: "p\($0)", endpoint: "http://127.0.0.1/", model: "m", locality: .local) }
        #expect(throws: (any Error).self) { try ProviderProfileFile.encode(tooMany) }
        // An externally authored canonical file with enabled=true still loads OFF.
        let enabled = Data(json.replacingOccurrences(of: "\"enabled\":false", with: "\"enabled\":true").utf8)
        #expect(try !ProviderProfileFile.decode(enabled).enabled)
    }

    @Test func rejectLinksPermissionsDirectoriesReadonlyAndOversize() throws {
        let directory = try profileDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("valid.json")
        try ProviderProfileFile.save(profileSettings(), to: file)
        let alias = directory.appendingPathComponent("alias.json")
        #expect(symlink(file.path, alias.path) == 0)
        #expect(throws: (any Error).self) { try ProviderProfileFile.load(alias) }
        #expect(throws: (any Error).self) { try ProviderProfileFile.save(profileSettings(), to: alias) }
        let hard = directory.appendingPathComponent("hard.json")
        #expect(link(file.path, hard.path) == 0)
        #expect(throws: (any Error).self) { try ProviderProfileFile.load(file) }
        try FileManager.default.removeItem(at: hard)
        for mode: mode_t in [0o644, 0o660, 0o400, 0o1600] {
            #expect(chmod(file.path, mode) == 0)
            #expect(throws: (any Error).self) { try ProviderProfileFile.load(file) }
        }
        #expect(chmod(file.path, 0o600) == 0)
        let fifo = directory.appendingPathComponent("fifo")
        #expect(mkfifo(fifo.path, 0o600) == 0)
        #expect(throws: (any Error).self) { try ProviderProfileFile.load(fifo) }
        #expect(throws: (any Error).self) { try ProviderProfileFile.load(directory) }
        #expect(chmod(directory.path, 0o755) == 0)
        #expect(throws: (any Error).self) { try ProviderProfileFile.load(file) }
        #expect(throws: (any Error).self) { try ProviderProfileFile.save(profileSettings(), to: directory.appendingPathComponent("new")) }
        #expect(chmod(directory.path, 0o700) == 0)
        try profileFixture(Data(repeating: 32, count: 65537), file)
        #expect(throws: (any Error).self) { try ProviderProfileFile.load(file) }
        let sub = directory.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let linkedParent = directory.appendingPathComponent("linked")
        #expect(symlink(sub.path, linkedParent.path) == 0)
        #expect(throws: (any Error).self) { try ProviderProfileFile.save(profileSettings(), to: linkedParent.appendingPathComponent("new")) }
    }

    @Test func aclRejected() throws {
        let directory = try profileDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("profile.json")
        try ProviderProfileFile.save(profileSettings(), to: file)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+a", "everyone allow read", file.path]
        try process.run(); process.waitUntilExit(); #expect(process.terminationStatus == 0)
        #expect(throws: (any Error).self) { try ProviderProfileFile.load(file) }
        let parentACL = Process(); parentACL.executableURL = URL(fileURLWithPath: "/bin/chmod")
        parentACL.arguments = ["+a", "everyone allow read", directory.path]
        try parentACL.run(); parentACL.waitUntilExit(); #expect(parentACL.terminationStatus == 0)
        #expect(throws: (any Error).self) { try ProviderProfileFile.save(profileSettings(), to: directory.appendingPathComponent("new.json")) }
    }

    @Test func competingAtomicPublishHasExactlyOneWinner() async throws {
        let directory = try profileDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("race.json"), settings = try profileSettings()
        let winners = await withTaskGroup(of: Int.self) { group in
            for _ in 0..<8 {
                group.addTask { do { try ProviderProfileFile.save(settings, to: file); return 1 } catch { return 0 } }
            }
            var total = 0; for await value in group { total += value }; return total
        }
        #expect(winners == 1)
        #expect(try ProviderProfileFile.load(file) == settings)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["race.json"])
    }

    @Test @MainActor func mountedBindingInvalidatesNotDraftsAndLoadCannotEnable() throws {
        let model = CompanionModel()
        model.editPreparation(query: "synthetic", original: "Keep original; do not send.")
        var invalidations = 0
        let session = CompanionProviderSession { invalidations += 1; model.dismissPreview() }
        let binding = session.binding
        _ = ProviderConfigurationView(settings: binding)
        #expect(!binding.wrappedValue.enabled)
        var settings = try profileSettings(); binding.wrappedValue = settings
        #expect(session.settings == settings && invalidations == 1)
        settings.enabled = true; binding.wrappedValue = settings
        #expect(try session.settings.selectedProfile().model == "synthetic-model")
        #expect(invalidations == 2)
        let directory = try profileDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("profile.json")
        let beforeCancel = session.settings, beforeStatus = session.status
        session.save(to: nil); session.load(from: nil)
        #expect(session.settings == beforeCancel && session.status == beforeStatus && invalidations == 2)
        session.save(to: file)
        #expect(session.settings.enabled && invalidations == 2)
        let savedBytes = try Data(contentsOf: file)
        session.save(to: file)
        #expect(session.settings == beforeCancel && invalidations == 2 && session.status.contains("failed"))
        #expect(try Data(contentsOf: file) == savedBytes)
        session.load(from: file)
        #expect(!session.settings.enabled && invalidations == 3)
        #expect(session.status.contains("OFF"))
        let adopted = session.settings
        try profileFixture(Data("{\"enabled\":true}".utf8), file)
        session.load(from: file)
        #expect(session.settings == adopted && invalidations == 3 && session.status.contains("rejected"))
        #expect(chmod(file.path, 0o400) == 0)
        session.load(from: file)
        #expect(session.settings == adopted && invalidations == 3 && session.status.contains("rejected"))
        var remote = settings
        try remote.configure(ProviderProfile(id: "remote", endpoint: "https://example.invalid/v1/chat/completions", model: "remote-model", locality: .remote))
        remote.enabled = true; binding.wrappedValue = remote
        #expect(!session.settings.enabled) // changing profile never carries enablement
        #expect(session.settings.selectedProfileID == "remote")
        #expect(model.originalDraft == "Keep original; do not send.")
        #expect(!model.busy && model.preview == nil && !model.configured)
    }

    @Test func rustEndpointBoundaryParity() throws {
        for endpoint in ["HTTP://127.0.0.1/", "http://127.0.0.1:/", "http://127.0.0.1:0/", "http://127.0.0.1:65536/", "http://127.0.0.1", "http://user@127.0.0.1/", "http://127.0.0.1/%61", "http://127.0.0.1/?x", "http://[::1]extra/"] {
            #expect(throws: (any Error).self) { try ProviderProfile(id: "p", endpoint: endpoint, model: "m", locality: .local).validate() }
        }
        for host in ["localhost", "foo.localhost", "127.0.0.2", "0.0.0.0", "255.255.255.255", "224.0.0.1", "239.255.255.255", "[::1]", "-bad.invalid", "bad..invalid"] {
            #expect(throws: (any Error).self) { try ProviderProfile(id: "p", endpoint: "https://\(host)/", model: "m", locality: .remote).validate() }
        }
        for endpoint in ["http://127.0.0.1/", "http://[::1]:8080/v1/chat/completions"] {
            try ProviderProfile(id: "p", endpoint: endpoint, model: "m", locality: .local).validate()
        }
        try ProviderProfile(id: "p", endpoint: "https://example.invalid/v1/chat/completions", model: "m", locality: .remote).validate()
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func actualCorePreviewInvalidationPreservesOriginalAndHumanHistory() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let directory = try profileDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        try Data("fn synthetic_profile_evidence() {}\n".utf8).write(to: root.appendingPathComponent("approved.rs"))
        let model = CompanionModel()
        model.configure(executable: URL(fileURLWithPath: binary), dataDirectory: directory.appendingPathComponent("store"))
        model.addProject(id: "synthetic", root: root.path, sources: ["approved.rs"])
        await model.waitForOperation()
        #expect(model.lastError == nil)
        model.writeContext(id: "note", kind: "note", text: "Synthetic human policy; never send.", update: false)
        await model.waitForOperation()
        model.build(); await model.waitForOperation()
        let original = "Keep synthetic_profile_evidence; do not change permissions or send."
        model.editPreparation(query: "synthetic_profile_evidence", original: original)
        model.prepareContext(); await model.waitForOperation()
        #expect(model.preview?.state == "ready-for-review")
        let session = CompanionProviderSession { model.dismissPreview() }
        let file = directory.appendingPathComponent("profile.json")
        // Canceled panels and Save never invalidate an existing preview/draft.
        session.save(to: nil); session.load(from: nil); session.save(to: file)
        #expect(model.preview?.original == original)
        session.load(from: directory.appendingPathComponent("missing"))
        #expect(model.preview?.original == original && session.status.contains("rejected"))
        session.binding.wrappedValue = try profileSettings()
        #expect(model.preview == nil && model.originalDraft == original)
        #expect(!session.settings.enabled && !model.busy)
        model.prepareContext(); await model.waitForOperation()
        #expect(model.preview?.original == original)
        session.load(from: file)
        #expect(model.preview == nil && model.originalDraft == original && !session.settings.enabled)
        model.openContext("note"); await model.waitForOperation()
        #expect(model.history?.history.last?.text == "Synthetic human policy; never send.")
        await model.shutdown()
    }
}
