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

struct PracticeGameSearchFilters {
    var nameQuery: String = ""
    var manufacturerQuery: String = ""
    var yearQuery: String = ""
    var selectedType: PracticeGameTypeFilter?

    var hasFilters: Bool {
        !nameQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !manufacturerQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !yearQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            selectedType != nil
    }
}

struct PracticeGameSearchIndex {
    static let empty = PracticeGameSearchIndex(
        results: [],
        resultByID: [:],
        manufacturerOptions: []
    )

    let results: [PracticeGameSearchResult]
    let resultByID: [String: PracticeGameSearchResult]
    let manufacturerOptions: [String]

    init(games: [PinballGame]) {
        let results = buildPracticeSearchResults(games)
        self.init(
            results: results,
            resultByID: Dictionary(uniqueKeysWithValues: results.map { ($0.canonicalGameID, $0) }),
            manufacturerOptions: Array(Set(results.compactMap(\.manufacturer)))
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        )
    }

    func manufacturerSuggestions(for query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let queryTokens = normalizedSearchTokens(trimmed)
        return manufacturerOptions.filter { option in
            matchesSearchTokens(queryTokens, haystackTokens: normalizedSearchTokens(option))
        }
        .prefix(8)
        .map { $0 }
    }

    func filteredResults(using filters: PracticeGameSearchFilters) -> [PracticeGameSearchResult] {
        let targetYear = Int(filters.yearQuery.trimmingCharacters(in: .whitespacesAndNewlines))
        let nameTokens = normalizedSearchTokens(filters.nameQuery)
        let manufacturerTokens = normalizedSearchTokens(
            filters.manufacturerQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        return results.filter { result in
            let matchesName = nameTokens.isEmpty ||
                matchesSearchTokens(nameTokens, haystackTokens: result.searchTokens)
            let matchesManufacturer = manufacturerTokens.isEmpty ||
                matchesSearchTokens(manufacturerTokens, haystackTokens: result.manufacturerTokens)
            let matchesYear = targetYear == nil || result.yearFields.contains(targetYear ?? 0)
            let matchesType = filters.selectedType == nil ||
                result.categoryFields.contains(filters.selectedType?.rawValue ?? "")
            return matchesName && matchesManufacturer && matchesYear && matchesType
        }
    }

    func recentResults(for recentGameIDs: [String]) -> [PracticeGameSearchResult] {
        recentGameIDs.compactMap { resultByID[$0] }
    }

    func metaLine(for result: PracticeGameSearchResult) -> String {
        var parts: [String] = [result.manufacturer ?? "-"]
        if let year = result.year {
            parts.append(String(year))
        }
        return parts.joined(separator: " • ")
    }

    private init(
        results: [PracticeGameSearchResult],
        resultByID: [String: PracticeGameSearchResult],
        manufacturerOptions: [String]
    ) {
        self.results = results
        self.resultByID = resultByID
        self.manufacturerOptions = manufacturerOptions
    }
}

enum PracticeGameSearchRecentStore {
    private static let defaultsKey = "practice-game-search-recents-v1"
    private static let maxCount = 20

    static func load() -> [String] {
        let values = UserDefaults.standard.array(forKey: defaultsKey) as? [String] ?? []
        return values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    @discardableResult
    static func remember(_ canonicalGameID: String) -> [String] {
        let trimmed = canonicalGameID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return load() }
        var values = load().filter { $0 != trimmed }
        values.insert(trimmed, at: 0)
        let updated = Array(values.prefix(maxCount))
        UserDefaults.standard.set(updated, forKey: defaultsKey)
        return updated
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
