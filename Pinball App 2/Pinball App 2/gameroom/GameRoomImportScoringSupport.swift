import Foundation

extension ImportMatcher {
    func tokenOverlapScore(lhs: String, rhs: String) -> Int {
        let lhsSet = Set(lhs.split(separator: " ").map(String.init))
        let rhsSet = Set(rhs.split(separator: " ").map(String.init))
        guard !lhsSet.isEmpty, !rhsSet.isEmpty else { return 0 }
        let intersection = lhsSet.intersection(rhsSet).count
        if intersection == 0 { return 0 }
        return Int((Double(intersection) / Double(max(lhsSet.count, rhsSet.count))) * 70.0)
    }

    func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func metadataScore(machine: PinsideImportedMachine, game: GameRoomCatalogGame) -> Int {
        manufacturerMatchScore(imported: machine.manufacturerLabel, catalog: game.manufacturer) +
            yearMatchScore(imported: machine.manufactureYear, catalog: game.year)
    }

    func manufacturerMatchScore(imported: String?, catalog: String?) -> Int {
        let importedLabel = canonicalManufacturerLabel(imported)
        let catalogLabel = canonicalManufacturerLabel(catalog)
        guard !importedLabel.isEmpty, !catalogLabel.isEmpty else { return 0 }
        if importedLabel == catalogLabel { return 35 }

        let importedTokens = Set(importedLabel.split(separator: " ").map(String.init))
        let catalogTokens = Set(catalogLabel.split(separator: " ").map(String.init))
        let sharedTokens = importedTokens.intersection(catalogTokens).count
        if sharedTokens > 0 {
            return max(10, Int((Double(sharedTokens) / Double(max(importedTokens.count, catalogTokens.count))) * 24.0))
        }
        return -12
    }

    func yearMatchScore(imported: Int?, catalog: Int?) -> Int {
        guard let imported, let catalog else { return 0 }
        let difference = abs(imported - catalog)
        switch difference {
        case 0:
            return 25
        case 1:
            return 16
        case 2:
            return 10
        case 3:
            return 4
        default:
            return -12
        }
    }

    func canonicalManufacturerLabel(_ value: String?) -> String {
        let normalizedValue = normalized(value ?? "")
        guard !normalizedValue.isEmpty else { return "" }

        let ignoredTokens: Set<String> = [
            "co",
            "company",
            "corp",
            "corporation",
            "inc",
            "ltd",
            "limited",
            "manufacturing",
            "pinball"
        ]
        let filteredTokens = normalizedValue
            .split(separator: " ")
            .map(String.init)
            .filter { !ignoredTokens.contains($0) }
        if filteredTokens.isEmpty {
            return normalizedValue
        }
        return filteredTokens.joined(separator: " ")
    }
}
