import Foundation

extension GameRoomCatalogLoader {
    static func makeGame(_ machine: CatalogMachineRecord) -> GameRoomCatalogGame {
        let parsedName = parsedCatalogName(title: machine.name, explicitVariant: machine.variant)
        let opdbID = machine.opdbMachineID ?? machine.opdbGroupID ?? machine.practiceIdentity
        return GameRoomCatalogGame(
            id: opdbID,
            catalogGameID: machine.practiceIdentity,
            opdbID: opdbID,
            canonicalPracticeIdentity: machine.practiceIdentity,
            displayTitle: parsedName.title,
            displayVariant: parsedName.variant,
            manufacturerID: machine.manufacturerID,
            manufacturer: machine.manufacturerName,
            year: machine.year,
            primaryImageURL: machine.primaryImage?.mediumURL ?? machine.primaryImage?.largeURL,
            opdbType: machine.opdbType,
            opdbDisplay: machine.opdbDisplay,
            opdbShortname: machine.opdbShortname,
            opdbCommonName: machine.opdbCommonName
        )
    }

    static func dedupedGames(from games: [GameRoomCatalogGame]) -> [GameRoomCatalogGame] {
        let grouped = Dictionary(grouping: games, by: \.catalogGameID)
        return grouped.values
            .compactMap { preferredGame(in: $0) }
            .sorted(by: sortGames)
    }

    static func variantOptionsMap(from machines: [CatalogMachineRecord]) -> [String: [String]] {
        var buckets: [String: Set<String>] = [:]

        for machine in machines {
            let catalogGameID = machine.practiceIdentity
            guard let variant = parsedCatalogName(title: machine.name, explicitVariant: machine.variant).variant else { continue }
            buckets[catalogGameID, default: []].insert(variant)
        }

        var map: [String: [String]] = [:]
        for (key, values) in buckets {
            map[key] = sanitizedVariantOptions(Array(values)).sorted { lhs, rhs in
                let lhsRank = variantPreferenceRank(lhs)
                let rhsRank = variantPreferenceRank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
        }
        return map
    }

    static func preferredGame(in group: [GameRoomCatalogGame]) -> GameRoomCatalogGame? {
        group.min { lhs, rhs in
            let lhsYear = lhs.year ?? Int.max
            let rhsYear = rhs.year ?? Int.max
            if lhsYear != rhsYear { return lhsYear < rhsYear }

            let lhsRank = variantPreferenceRank(lhs.displayVariant)
            let rhsRank = variantPreferenceRank(rhs.displayVariant)
            if lhsRank != rhsRank { return lhsRank < rhsRank }

            let lhsHasImage = lhs.primaryImageURL != nil
            let rhsHasImage = rhs.primaryImageURL != nil
            if lhsHasImage != rhsHasImage { return lhsHasImage && !rhsHasImage }

            return lhs.id < rhs.id
        }
    }

    static func sortGames(lhs: GameRoomCatalogGame, rhs: GameRoomCatalogGame) -> Bool {
        let lhsName = lhs.displayTitle.localizedLowercase
        let rhsName = rhs.displayTitle.localizedLowercase
        if lhsName != rhsName { return lhsName < rhsName }

        let lhsVariant = lhs.displayVariant?.localizedLowercase ?? ""
        let rhsVariant = rhs.displayVariant?.localizedLowercase ?? ""
        if lhsVariant != rhsVariant { return lhsVariant < rhsVariant }

        let lhsManufacturer = lhs.manufacturer?.localizedLowercase ?? ""
        let rhsManufacturer = rhs.manufacturer?.localizedLowercase ?? ""
        if lhsManufacturer != rhsManufacturer { return lhsManufacturer < rhsManufacturer }

        let lhsYear = lhs.year ?? Int.max
        let rhsYear = rhs.year ?? Int.max
        if lhsYear != rhsYear { return lhsYear < rhsYear }

        return lhs.id < rhs.id
    }

    static func normalizedCatalogGameID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }

    static func normalizedCatalogIdentifier(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed.localizedLowercase
    }
}
