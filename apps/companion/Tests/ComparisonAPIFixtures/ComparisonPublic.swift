// Typecheck only with ordinary import; never execute this fixture.
import CompanionKit

@MainActor func explicitRead(_ model: CompanionModel) {
    model.openHumanComparison()
    model.chooseHumanComparison(from: 1, to: 1)
    _ = model.canCompareHumanContext
    _ = model.humanComparisonRevisions
    model.compareHumanContext()
    if let result = model.humanComparison {
        _ = result.request.from.revision
        _ = result.removed
    }
    model.cancelHumanComparison()
}
