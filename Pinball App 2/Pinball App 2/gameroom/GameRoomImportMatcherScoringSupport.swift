import Foundation

extension ImportMatcher {
    func matchLabel(for game: GameRoomCatalogGame) -> String {
        if let year = game.year {
            return "\(game.displayTitle) (\(year))"
        }
        return game.displayTitle
    }

    func scoredSuggestions(for machine: PinsideImportedMachine) -> [(game: GameRoomCatalogGame, score: Int)] {
        let normalizedRawTitle = normalized(machine.rawTitle)
        let normalizedVariant = normalized(machine.rawVariant ?? "")
        let slugMatch = catalogLoader.slugMatch(for: machine.slug)
        let candidates = catalogLoader.games.map { game -> (GameRoomCatalogGame, Int) in
            let normalizedGameTitle = normalized(game.displayTitle)
            var score = 0

            if let slugMatch,
               slugMatch.catalogGameID.caseInsensitiveCompare(game.catalogGameID) == .orderedSame {
                score += 400
            }

            if normalizedRawTitle == normalizedGameTitle {
                score += 120
            } else if normalizedGameTitle.contains(normalizedRawTitle) || normalizedRawTitle.contains(normalizedGameTitle) {
                score += 80
            } else {
                score += tokenOverlapScore(lhs: normalizedRawTitle, rhs: normalizedGameTitle)
            }

            if !normalizedVariant.isEmpty {
                let variants = catalogLoader.variantOptions(for: game.catalogGameID).map(normalized)
                if variants.contains(normalizedVariant) {
                    score += 20
                }
            }

            score += metadataScore(machine: machine, game: game)

            return (game, score)
        }

        return candidates
            .filter { $0.1 > 0 }
            .sorted(by: {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                let lhsMetadata = metadataScore(machine: machine, game: $0.0)
                let rhsMetadata = metadataScore(machine: machine, game: $1.0)
                if lhsMetadata != rhsMetadata { return lhsMetadata > rhsMetadata }
                return $0.0.displayTitle.localizedCaseInsensitiveCompare($1.0.displayTitle) == .orderedAscending
            })
            .prefix(3)
            .map { $0 }
    }

    func confidence(for score: Int) -> MachineImportMatchConfidence {
        if score >= 120 { return .high }
        if score >= 80 { return .medium }
        if score > 0 { return .low }
        return .manual
    }
}
