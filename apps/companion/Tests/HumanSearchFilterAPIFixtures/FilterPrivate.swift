import CompanionKit
@MainActor func bypass(_ model: CompanionModel, _ binding: HumanContextReadBinding) throws {
    model.humanSearchSelectedKinds = ["note"]
    _ = model.humanSearchGeneration
    _ = model.ownedOperations
    _ = try HumanSearchKindRequest(binding: binding, query: "synthetic", kinds: ["note"])
}
