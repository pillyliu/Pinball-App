import Foundation

func gameRoomResolvedOPDBID(
    for machine: OwnedMachine,
    allCatalogGames: [GameRoomCatalogGame],
    gamesByCatalogGameID: [String: [GameRoomCatalogGame]],
    gamesByNormalizedCatalogGameID: [String: [GameRoomCatalogGame]]
) -> String? {
    if let existing = machine.opdbID?.trimmingCharacters(in: .whitespacesAndNewlines),
       !existing.isEmpty,
       gameRoomCatalogGameForExactOPDBID(existing, allCatalogGames: allCatalogGames) != nil {
        return existing
    }

    let resolvedTitle = catalogResolvedDisplayTitle(title: machine.displayTitle, explicitVariant: machine.displayVariant)
    let resolvedVariant = catalogResolvedVariantLabel(title: machine.displayTitle, explicitVariant: machine.displayVariant)
    let normalizedTitle = GameRoomCatalogLoader.normalizedCatalogIdentifier(resolvedTitle)
    let normalizedVariant = GameRoomCatalogLoader.normalizedVariant(resolvedVariant)
    let grouped = gameRoomCatalogGames(
        for: machine.catalogGameID,
        gamesByCatalogGameID: gamesByCatalogGameID,
        gamesByNormalizedCatalogGameID: gamesByNormalizedCatalogGameID
    )

    if let normalizedTitle, let normalizedVariant,
       let exact = grouped.first(where: {
           GameRoomCatalogLoader.normalizedCatalogIdentifier($0.displayTitle) == normalizedTitle &&
           GameRoomCatalogLoader.normalizedVariant($0.displayVariant) == normalizedVariant
       }) {
        return exact.opdbID
    }

    if let normalizedVariant,
       let exactVariantMatch = grouped.first(where: {
           GameRoomCatalogLoader.exactVariantMatchesSelection(candidate: $0.displayVariant, selected: normalizedVariant)
       }) {
        return exactVariantMatch.opdbID
    }

    if let normalizedVariant,
       let variantMatch = grouped.first(where: {
           GameRoomCatalogLoader.variantMatchesSelection(candidate: $0.displayVariant, selected: normalizedVariant)
       }) {
        return variantMatch.opdbID
    }

    if let normalizedTitle,
       let titleMatch = grouped.first(where: {
           GameRoomCatalogLoader.normalizedCatalogIdentifier($0.displayTitle) == normalizedTitle
       }) {
        return titleMatch.opdbID
    }

    if let identityMatch = allCatalogGames.first(where: { $0.canonicalPracticeIdentity == machine.canonicalPracticeIdentity }) {
        return identityMatch.opdbID
    }

    return grouped.first?.opdbID
}

func gameRoomNormalizedCatalogGame(
    for machine: OwnedMachine,
    allCatalogGames: [GameRoomCatalogGame],
    gamesByCatalogGameID: [String: [GameRoomCatalogGame]],
    gamesByNormalizedCatalogGameID: [String: [GameRoomCatalogGame]]
) -> GameRoomCatalogGame? {
    guard let exact = gameRoomResolvedOPDBID(
        for: machine,
        allCatalogGames: allCatalogGames,
        gamesByCatalogGameID: gamesByCatalogGameID,
        gamesByNormalizedCatalogGameID: gamesByNormalizedCatalogGameID
    ) else {
        return nil
    }
    return gameRoomCatalogGameForExactOPDBID(exact, allCatalogGames: allCatalogGames)
}

func gameRoomCatalogGames(
    for catalogGameID: String,
    gamesByCatalogGameID: [String: [GameRoomCatalogGame]],
    gamesByNormalizedCatalogGameID: [String: [GameRoomCatalogGame]]
) -> [GameRoomCatalogGame] {
    if let grouped = gamesByCatalogGameID[catalogGameID], !grouped.isEmpty {
        return grouped.sorted(by: GameRoomCatalogLoader.sortGames)
    }
    if let grouped = gamesByNormalizedCatalogGameID[GameRoomCatalogLoader.normalizedCatalogGameID(catalogGameID)], !grouped.isEmpty {
        return grouped.sorted(by: GameRoomCatalogLoader.sortGames)
    }
    return []
}

func gameRoomCatalogGameForExactOPDBID(
    _ opdbID: String,
    allCatalogGames: [GameRoomCatalogGame]
) -> GameRoomCatalogGame? {
    let normalized = GameRoomCatalogLoader.normalizedCatalogGameID(opdbID)
    guard !normalized.isEmpty else { return nil }
    return allCatalogGames.first { GameRoomCatalogLoader.normalizedCatalogGameID($0.opdbID) == normalized }
}
