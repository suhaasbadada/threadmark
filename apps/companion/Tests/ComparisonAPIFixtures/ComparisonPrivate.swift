// Must FAIL ordinary-import typechecking. Capture and registry stay module-owned.
import CompanionKit

@MainActor func bypass(_ model: CompanionModel, _ project: Project, _ history: ContextHistory) throws {
    _ = model.comparisonActive
    _ = model.ownedOperations
    _ = try HumanComparisonRequest(project: project, history: history, from: 1, to: 1)
}
