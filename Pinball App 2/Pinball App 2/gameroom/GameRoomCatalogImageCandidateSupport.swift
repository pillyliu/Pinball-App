import Foundation

func gameRoomCatalogImageCandidates(
    for machine: OwnedMachine,
    allCatalogGames: [GameRoomCatalogGame],
    gamesByCatalogGameID: [String: [GameRoomCatalogGame]],
    gamesByNormalizedCatalogGameID: [String: [GameRoomCatalogGame]]
) -> [URL] {
    var rawCandidates: [String] = []
    let resolvedTitle = catalogResolvedDisplayTitle(title: machine.displayTitle, explicitVariant: machine.displayVariant)
    let resolvedVariant = catalogResolvedVariantLabel(title: machine.displayTitle, explicitVariant: machine.displayVariant)
    let normalizedTitle = GameRoomCatalogLoader.normalizedCatalogIdentifier(resolvedTitle)
    let normalizedVariant = GameRoomCatalogLoader.normalizedVariant(resolvedVariant)

    let normalizedExactOPDBID = GameRoomCatalogLoader.normalizedCatalogGameID(
        gameRoomResolvedOPDBID(
            for: machine,
            allCatalogGames: allCatalogGames,
            gamesByCatalogGameID: gamesByCatalogGameID,
            gamesByNormalizedCatalogGameID: gamesByNormalizedCatalogGameID
        ) ?? ""
    )
    if !normalizedExactOPDBID.isEmpty {
        let exactMachineMatches = allCatalogGames.filter {
            GameRoomCatalogLoader.normalizedCatalogGameID($0.opdbID) == normalizedExactOPDBID
        }
        rawCandidates.append(contentsOf: exactMachineMatches.compactMap(\.primaryImageURL))
    }

    let grouped = gameRoomCatalogGames(
        for: machine.catalogGameID,
        gamesByCatalogGameID: gamesByCatalogGameID,
        gamesByNormalizedCatalogGameID: gamesByNormalizedCatalogGameID
    )

    if let normalizedTitle, let normalizedVariant {
        let exactVariantMatches = allCatalogGames.filter {
            GameRoomCatalogLoader.normalizedCatalogIdentifier($0.displayTitle) == normalizedTitle &&
            GameRoomCatalogLoader.normalizedVariant($0.displayVariant) == normalizedVariant
        }
        rawCandidates.append(contentsOf: exactVariantMatches.compactMap(\.primaryImageURL))
    }

    if let normalizedVariant {
        let exactVariantMatches = grouped.filter {
            GameRoomCatalogLoader.exactVariantMatchesSelection(candidate: $0.displayVariant, selected: normalizedVariant)
        }
        rawCandidates.append(contentsOf: exactVariantMatches.compactMap(\.primaryImageURL))
    }

    if let normalizedVariant {
        let variantMatches = grouped.filter {
            GameRoomCatalogLoader.variantMatchesSelection(candidate: $0.displayVariant, selected: normalizedVariant)
        }
        rawCandidates.append(contentsOf: variantMatches.compactMap(\.primaryImageURL))
    }

    if let exactIdentity = allCatalogGames.first(where: { $0.canonicalPracticeIdentity == machine.canonicalPracticeIdentity }) {
        rawCandidates.append(contentsOf: [exactIdentity.primaryImageURL].compactMap { $0 })
    }

    rawCandidates.append(contentsOf: grouped.compactMap(\.primaryImageURL))

    let titleMatches = allCatalogGames.filter {
        $0.displayTitle.caseInsensitiveCompare(machine.displayTitle) == .orderedSame
    }
    rawCandidates.append(contentsOf: titleMatches.compactMap(\.primaryImageURL))

    var seen = Set<String>()
    return rawCandidates.compactMap { raw in
        let key = raw.lowercased()
        guard !seen.contains(key) else { return nil }
        seen.insert(key)
        return GameRoomCatalogLoader.resolveURL(pathOrURL: raw)
    }
}
