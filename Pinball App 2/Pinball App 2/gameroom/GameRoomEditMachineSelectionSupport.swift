import Foundation

func gameRoomMachineMenuGroups(
    allMachines: [OwnedMachine],
    areaTitle: (UUID?) -> String,
    areaOrder: (UUID?) -> Int
) -> [GameRoomMachineMenuGroup] {
    let grouped = Dictionary(grouping: allMachines) { machine in
        machine.gameRoomAreaID?.uuidString ?? "no-area"
    }

    let sortedKeys = grouped.keys.sorted { lhs, rhs in
        let lhsArea = lhs == "no-area" ? nil : UUID(uuidString: lhs)
        let rhsArea = rhs == "no-area" ? nil : UUID(uuidString: rhs)

        let lhsOrder = areaOrder(lhsArea)
        let rhsOrder = areaOrder(rhsArea)
        if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }

        let lhsName = areaTitle(lhsArea)
        let rhsName = areaTitle(rhsArea)
        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
    }

    return sortedKeys.compactMap { key in
        guard let machines = grouped[key] else { return nil }
        let areaID = key == "no-area" ? nil : UUID(uuidString: key)
        let title = areaTitle(areaID)
        let sortedMachines = machines.sorted { lhs, rhs in
            if lhs.displayTitle != rhs.displayTitle {
                return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return GameRoomMachineMenuGroup(key: key, title: title, machines: sortedMachines)
    }
}

func gameRoomSelectedMachine(
    allMachines: [OwnedMachine],
    selectedMachineID: UUID?
) -> OwnedMachine? {
    guard let selectedMachineID else { return allMachines.first }
    return allMachines.first(where: { $0.id == selectedMachineID })
}

func gameRoomEnsuredSelectedMachineID(
    allMachines: [OwnedMachine],
    selectedMachineID: UUID?
) -> UUID? {
    if let selectedMachineID,
       allMachines.contains(where: { $0.id == selectedMachineID }) {
        return selectedMachineID
    }
    return allMachines.first?.id
}

func gameRoomShouldShowManufacturerSuggestions(
    filteredSuggestions: [String],
    query: String
) -> Bool {
    !filteredSuggestions.isEmpty &&
        !filteredSuggestions.contains(where: {
            $0.caseInsensitiveCompare(query.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        })
}

func gameRoomHasSearchFilters(
    searchText: String,
    manufacturerQuery: String,
    yearQuery: String,
    selectedType: GameRoomAddMachineTypeFilter?
) -> Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !manufacturerQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !yearQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        selectedType != nil
}

func gameRoomCurrentVariantLabel(_ draftDisplayVariant: String) -> String {
    let trimmed = draftDisplayVariant.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "None" : trimmed
}

func gameRoomResultMetaLine(for game: GameRoomCatalogGame) -> String {
    var parts: [String] = []
    if let manufacturer = game.manufacturer {
        parts.append(manufacturer)
    }
    if let year = game.year {
        parts.append(String(year))
    }
    return parts.isEmpty ? "Catalog match" : parts.joined(separator: " • ")
}

func gameRoomMachineMenuLabel(_ machine: OwnedMachine) -> String {
    let status = machine.status == .active ? nil : machine.status.rawValue.capitalized
    guard let status else { return machine.displayTitle }
    return "\(machine.displayTitle) (\(status))"
}

func gameRoomParsedOptionalInt(_ raw: String) -> Int? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return Int(trimmed)
}

func gameRoomParsedOptionalString(_ raw: String?) -> String? {
    let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
}

func gameRoomVariantOptions(
    for machine: OwnedMachine,
    catalogLoader: GameRoomCatalogLoader,
    draftDisplayVariant: String
) -> [String] {
    var variants = catalogLoader.variantOptions(for: machine.catalogGameID)
    if let current = gameRoomParsedOptionalString(draftDisplayVariant),
       !variants.contains(where: { $0.caseInsensitiveCompare(current) == .orderedSame }) {
        variants.insert(current, at: 0)
    }
    return variants
}

func gameRoomDistinctVariants(_ variantOptions: [String]) -> [String] {
    Array(NSOrderedSet(array: variantOptions)) as? [String] ?? variantOptions
}

func gameRoomSyncedVenueNameDraft(
    currentDraft: String,
    venueName: String
) -> String {
    let trimmed = currentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? venueName : currentDraft
}

func gameRoomIndexedManufacturers(
    from entries: [GameRoomCatalogSearchEntry]
) -> [String] {
    Array(
        Set(entries.compactMap { entry in
            let trimmed = entry.game.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed?.isEmpty == false) ? trimmed : nil
        })
    )
    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}
