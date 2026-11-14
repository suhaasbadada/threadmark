import CompanionKit
@MainActor func controls(_ model: CompanionModel) {
    model.setHumanSearchKindFilter(["note", "decision"])
    model.searchHumanContext("synthetic")
    _ = model.humanSearchSelectedKinds
    _ = HumanContextSearchView(model: model)
    model.setHumanSearchKindFilter(nil)
}
