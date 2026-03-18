import Foundation

enum GameRoomAddMachineTypeFilter: String, CaseIterable, Identifiable {
    case em
    case ss
    case lcd

    var id: String { rawValue }

    var label: String {
        switch self {
        case .em:
            return "EM"
        case .ss:
            return "SS"
        case .lcd:
            return "LCD"
        }
    }
}

struct GameRoomCatalogSearchEntry: Identifiable {
    let game: GameRoomCatalogGame
    let searchTokens: [String]
    let manufacturerTokens: [String]

    var id: String { game.id }
}

func gameRoomManufacturerSuggestions(options: [String], query: String) -> [String] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    let queryTokens = normalizedSearchTokens(trimmed)
    return options.filter { option in
        matchesSearchTokens(queryTokens, haystackTokens: normalizedSearchTokens(option))
    }
    .prefix(8)
    .map { $0 }
}

func buildGameRoomCatalogSearchEntries(
    games: [GameRoomCatalogGame],
    variantOptions: (String) -> [String]
) -> [GameRoomCatalogSearchEntry] {
    games.map { game in
        let searchTokens = (
            [
                game.displayTitle,
                game.displayVariant,
                game.opdbShortname,
                game.opdbCommonName,
                game.manufacturer
            ]
            .compactMap { $0 } + variantOptions(game.catalogGameID)
        )
        .flatMap(normalizedSearchTokens)

        return GameRoomCatalogSearchEntry(
            game: game,
            searchTokens: searchTokens,
            manufacturerTokens: normalizedSearchTokens(game.manufacturer ?? "")
        )
    }
}

func filteredGameRoomCatalogGames(
    entries: [GameRoomCatalogSearchEntry],
    nameQuery: String,
    manufacturerQuery: String,
    yearQuery: String,
    selectedType: GameRoomAddMachineTypeFilter?
) -> [GameRoomCatalogGame] {
    let nameTokens = normalizedSearchTokens(nameQuery.trimmingCharacters(in: .whitespacesAndNewlines))
    let manufacturerTokens = normalizedSearchTokens(manufacturerQuery.trimmingCharacters(in: .whitespacesAndNewlines))
    let targetYear = Int(yearQuery.trimmingCharacters(in: .whitespacesAndNewlines))

    return entries.compactMap { entry in
        let game = entry.game
        let matchesName = nameTokens.isEmpty || matchesSearchTokens(nameTokens, haystackTokens: entry.searchTokens)
        let matchesManufacturer = manufacturerTokens.isEmpty ||
            matchesSearchTokens(manufacturerTokens, haystackTokens: entry.manufacturerTokens)
        let matchesYear = targetYear == nil || game.year == targetYear
        let matchesType = selectedType == nil || gameRoomSearchCategory(for: game) == selectedType?.rawValue
        return matchesName && matchesManufacturer && matchesYear && matchesType ? game : nil
    }
}

func gameRoomSearchCategory(for game: GameRoomCatalogGame) -> String? {
    if game.opdbDisplay == GameRoomAddMachineTypeFilter.lcd.rawValue {
        return GameRoomAddMachineTypeFilter.lcd.rawValue
    }
    if game.opdbType == GameRoomAddMachineTypeFilter.em.rawValue {
        return GameRoomAddMachineTypeFilter.em.rawValue
    }
    if game.opdbType == GameRoomAddMachineTypeFilter.ss.rawValue {
        return GameRoomAddMachineTypeFilter.ss.rawValue
    }
    return nil
}
