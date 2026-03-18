import Foundation

enum PracticeGameTypeFilter: String, CaseIterable, Identifiable {
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

struct PracticeGameSearchResult: Identifiable {
    let canonicalGameID: String
    let displayName: String
    let manufacturer: String?
    let year: Int?
    let searchTokens: [String]
    let manufacturerTokens: [String]
    let categoryFields: [String]
    let yearFields: [Int]

    var id: String { canonicalGameID }
}

enum PracticeGameSearchRecentStore {
    private static let defaultsKey = "practice-game-search-recents-v1"
    private static let maxCount = 20

    static func load() -> [String] {
        let values = UserDefaults.standard.array(forKey: defaultsKey) as? [String] ?? []
        return values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func remember(_ canonicalGameID: String) {
        let trimmed = canonicalGameID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var values = load().filter { $0 != trimmed }
        values.insert(trimmed, at: 0)
        UserDefaults.standard.set(Array(values.prefix(maxCount)), forKey: defaultsKey)
    }
}

func practiceSearchManufacturerSuggestions(options: [String], query: String) -> [String] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    let queryTokens = normalizedSearchTokens(trimmed)
    return options.filter { option in
        matchesSearchTokens(queryTokens, haystackTokens: normalizedSearchTokens(option))
    }
    .prefix(8)
    .map { $0 }
}

func filteredPracticeSearchResults(
    results: [PracticeGameSearchResult],
    nameQuery: String,
    manufacturerQuery: String,
    yearQuery: String,
    selectedType: PracticeGameTypeFilter?
) -> [PracticeGameSearchResult] {
    let targetYear = Int(yearQuery.trimmingCharacters(in: .whitespacesAndNewlines))
    let nameTokens = normalizedSearchTokens(nameQuery)
    let manufacturerTokens = normalizedSearchTokens(manufacturerQuery.trimmingCharacters(in: .whitespacesAndNewlines))

    return results.filter { result in
        let matchesName = nameTokens.isEmpty ||
            matchesSearchTokens(nameTokens, haystackTokens: result.searchTokens)
        let matchesManufacturer = manufacturerTokens.isEmpty ||
            matchesSearchTokens(manufacturerTokens, haystackTokens: result.manufacturerTokens)
        let matchesYear = targetYear == nil || result.yearFields.contains(targetYear ?? 0)
        let matchesType = selectedType == nil || result.categoryFields.contains(selectedType?.rawValue ?? "")
        return matchesName && matchesManufacturer && matchesYear && matchesType
    }
}

func buildPracticeSearchResults(_ games: [PinballGame]) -> [PracticeGameSearchResult] {
    Dictionary(grouping: games, by: \.canonicalPracticeKey)
        .compactMap { canonicalGameID, groupedGames in
            guard !canonicalGameID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let displayName = practiceDisplayTitleForGames(groupedGames)
            let manufacturer = practiceSearchManufacturer(for: groupedGames)
            let year = practiceSearchYear(for: groupedGames)
            let searchTokens = groupedGames
                .flatMap { game in
                    [
                        displayName,
                        game.name,
                        game.opdbName,
                        game.opdbShortname,
                        game.opdbCommonName,
                        game.opdbGroupShortname
                    ]
                }
                .flatMap { normalizedSearchTokens($0 ?? "") }
            let manufacturerTokens = groupedGames
                .compactMap(\.manufacturer)
                .flatMap(normalizedSearchTokens)
            let categoryFields = Array(Set(groupedGames.compactMap(practiceSearchCategory(for:))))
            let yearFields = groupedGames.compactMap { game in
                game.year ?? practiceSearchYear(from: game.opdbManufactureDate)
            }
            return PracticeGameSearchResult(
                canonicalGameID: canonicalGameID,
                displayName: displayName,
                manufacturer: manufacturer,
                year: year,
                searchTokens: searchTokens,
                manufacturerTokens: manufacturerTokens,
                categoryFields: categoryFields,
                yearFields: yearFields
            )
        }
        .sorted { lhs, rhs in
            let nameCompare = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if nameCompare != .orderedSame {
                return nameCompare == .orderedAscending
            }
            return lhs.canonicalGameID.localizedCaseInsensitiveCompare(rhs.canonicalGameID) == .orderedAscending
        }
}

func practiceSearchMetaLine(for result: PracticeGameSearchResult) -> String {
    var parts: [String] = [result.manufacturer ?? "-"]
    if let year = result.year {
        parts.append(String(year))
    }
    return parts.joined(separator: " • ")
}

private func practiceSearchManufacturer(for games: [PinballGame]) -> String? {
    let normalized = games.compactMap { $0.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    return normalized.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.first
}

private func practiceSearchYear(for games: [PinballGame]) -> Int? {
    if let year = games.compactMap(\.year).sorted().first {
        return year
    }
    return games.compactMap { practiceSearchYear(from: $0.opdbManufactureDate) }.sorted().first
}

private func practiceSearchYear(from manufactureDate: String?) -> Int? {
    guard let prefix = manufactureDate?.prefix(4), prefix.count == 4 else { return nil }
    return Int(prefix)
}

private func practiceSearchCategory(for game: PinballGame) -> String? {
    if game.opdbDisplay == PracticeGameTypeFilter.lcd.rawValue {
        return PracticeGameTypeFilter.lcd.rawValue
    }
    if game.opdbType == PracticeGameTypeFilter.em.rawValue {
        return PracticeGameTypeFilter.em.rawValue
    }
    if game.opdbType == PracticeGameTypeFilter.ss.rawValue {
        return PracticeGameTypeFilter.ss.rawValue
    }
    return nil
}
