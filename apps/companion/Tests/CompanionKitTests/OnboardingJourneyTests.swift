import Foundation
import Testing
@testable import CompanionKit

@Suite("Lane A synthetic onboarding through actual core")
struct OnboardingJourneyTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"] != nil))
    @MainActor func registerNoteBuildQueryPreviewCancelAndRecover() async throws {
        let binary = try #require(ProcessInfo.processInfo.environment["THREADMARK_CORE_TEST_BINARY"])
        let fm = FileManager.default
        let base = try StoreSelection.existingDirectory(fm.temporaryDirectory).appendingPathComponent("opencode/threadmark-onboarding-" + UUID().uuidString)
        try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fm.removeItem(at: base) }
        let root = base.appendingPathComponent("project")
        try fm.createDirectory(at: root, withIntermediateDirectories: false)
        let source = Data("fn synthetic_onboarding() {}\n".utf8)
        try source.write(to: root.appendingPathComponent("approved.rs"))
        try Data("synthetic_excluded\n".utf8).write(to: root.appendingPathComponent("excluded.rs"))
        let store = try StoreSelection.newDirectory(parent: base, name: "store")
        let model = CompanionModel()
        model.configure(executable: URL(fileURLWithPath: binary), dataDirectory: store)
        #expect(model.configured && !fm.fileExists(atPath: store.path))
        model.addProject(id: "synthetic", root: root.path, sources: ["../outside.rs"])
        #expect(model.lastError == .invalid && !fm.fileExists(atPath: store.path))
        model.addProject(id: "synthetic", root: root.path, sources: ["approved.rs"])
        await model.waitForOperation()
        #expect(model.lastError == nil && model.project?.sources == ["approved.rs"])
        let note = "Synthetic human policy: do not change permissions."
        model.writeContext(id: "memo", kind: "note", text: note, update: false)
        await model.waitForOperation()
        #expect(model.history?.history.last?.text == note)
        model.build(); await model.waitForOperation()
        #expect(model.lastError == nil && model.indexReport?.files == 1)
        model.query("synthetic_onboarding"); await model.waitForOperation()
        #expect(model.evidence?.currentness == "current-at-read")
        #expect(model.evidence?.results.map(\.path) == ["approved.rs"])
        model.query("synthetic_excluded"); await model.waitForOperation()
        #expect(model.evidence?.results.isEmpty == true)
        let original = "Keep synthetic_onboarding unchanged; do not change permissions."
        model.editPreparation(query: "synthetic_onboarding", original: original)
        model.prepareContext(); await model.waitForOperation()
        #expect(model.preview?.state == "ready-for-review" && model.preview?.original == original)
        model.dismissPreview()
        #expect(model.preview == nil && model.originalDraft == original)
        model.prepareContext(); model.cancel(); await model.waitForOperation()
        #expect(model.preview == nil && model.originalDraft == original)
        // Real dependency loss, not a fake success or automatic original submission.
        try fm.removeItem(at: root.appendingPathComponent("approved.rs"))
        model.build(); await model.waitForOperation()
        #expect(model.lastError != nil && model.indexReport == nil && model.originalDraft == original)
        try source.write(to: root.appendingPathComponent("approved.rs"))
        model.build(); await model.waitForOperation()
        #expect(model.lastError == nil && model.indexReport?.files == 1)
        model.openContext("memo"); await model.waitForOperation()
        #expect(model.history?.history.last?.text == note)
        // Unavailable roots must not leave formerly current evidence displayed.
        try fm.moveItem(at: root, to: base.appendingPathComponent("moved"))
        model.query("synthetic_onboarding"); await model.waitForOperation()
        #expect(model.evidence?.currentness == "stale-or-unindexed" && model.evidence?.results.isEmpty == true)
        #expect(model.originalDraft == original && model.automaticRefreshConsent == nil)
        await model.shutdown()
    }
}
