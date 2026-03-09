import Foundation

struct PinballLibraryPayload {
    let games: [PinballGame]
    let sources: [PinballLibrarySource]
}

private struct PinballLibraryRoot: Decodable {
    let games: [PinballGame]?
    let items: [PinballGame]?
    let sources: [PinballLibrarySourcePayload]?
    let libraries: [PinballLibrarySourcePayload]?
}

private struct PinballLibrarySourcePayload: Decodable {
    let id: String?
    let libraryID: String?
    let name: String?
    let libraryName: String?
    let type: String?
    let libraryType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case libraryID = "library_id"
        case name
        case libraryName = "library_name"
        case type
        case libraryType = "library_type"
    }
}

func decodeLibraryPayload(data: Data) throws -> PinballLibraryPayload {
    try decodeLibraryPayloadWithState(data: data).payload
}

nonisolated func libraryInferSources(from games: [PinballGame]) -> [PinballLibrarySource] {
    var seen: [PinballLibrarySource] = []
    var ids = Set<String>()
    for game in games {
        if ids.contains(game.sourceId) { continue }
        ids.insert(game.sourceId)
        seen.append(PinballLibrarySource(id: game.sourceId, name: game.sourceName, type: game.sourceType))
    }
    if seen.isEmpty {
        seen.append(PinballLibrarySource(id: "the-avenue", name: "The Avenue", type: .venue))
    }
    return seen
}

nonisolated func libraryParseSourceType(_ raw: String?) -> PinballLibrarySourceType {
    let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized == "manufacturer" {
        return .manufacturer
    }
    if normalized == "category" {
        return .category
    }
    if normalized == "tournament" {
        return .tournament
    }
    return .venue
}

nonisolated func librarySlugifySourceID(_ value: String) -> String {
    let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if lower.isEmpty { return "the-avenue" }
    let mapped = lower
        .replacingOccurrences(of: "&", with: "and")
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return mapped.isEmpty ? "the-avenue" : mapped
}

nonisolated func libraryNormalizedOptionalString(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

struct PinballGroupSection {
    let locationKey: String?
    let groupKey: Int?
    var games: [PinballGame]
}

struct PinballLibraryBrowsingState {
    let games: [PinballGame]
    let sources: [PinballLibrarySource]
    let selectedSourceID: String
    let query: String
    let sortOption: PinballLibrarySortOption
    let yearSortDescending: Bool
    let selectedBank: Int?
    let visibleGameLimit: Int
    let pinnedSourceIDs: [String]

    var selectedSource: PinballLibrarySource? {
        sources.first(where: { $0.id == selectedSourceID }) ?? sources.first
    }

    var visibleSources: [PinballLibrarySource] {
        let pinned = pinnedSourceIDs.compactMap { id in
            sources.first(where: { $0.id == id })
        }
        var visible = pinned
        if let selectedSource, !visible.contains(where: { $0.id == selectedSource.id }) {
            visible.append(selectedSource)
        }
        if let gameRoomSource = sources.first(where: { $0.id == "venue--gameroom" }),
           !visible.contains(where: { $0.id == gameRoomSource.id }) {
            visible.append(gameRoomSource)
        }
        return visible.isEmpty ? sources : visible
    }

    var sourceScopedGames: [PinballGame] {
        guard let selectedSource else { return games }
        return games.filter { $0.sourceId == selectedSource.id }
    }

    var sortOptions: [PinballLibrarySortOption] {
        guard let selectedSource else {
            return [.area, .alphabetical]
        }
        switch selectedSource.type {
        case .category, .manufacturer, .tournament:
            return [.year, .alphabetical]
        case .venue:
            let hasBank = sourceScopedGames.contains { ($0.bank ?? 0) > 0 }
            var options: [PinballLibrarySortOption] = [.area]
            if hasBank { options.append(.bank) }
            options.append(.alphabetical)
            options.append(.year)
            return options
        }
    }

    var supportsBankFilter: Bool {
        guard let selectedSource else { return false }
        return selectedSource.type == .venue && sourceScopedGames.contains { ($0.bank ?? 0) > 0 }
    }

    var bankOptions: [Int] {
        guard supportsBankFilter else { return [] }
        return Array(Set(sourceScopedGames.compactMap(\.bank).filter { $0 > 0 })).sorted()
    }

    var selectedBankLabel: String {
        if let selectedBank {
            return "Bank \(selectedBank)"
        }
        return "All banks"
    }

    var selectedSortLabel: String {
        menuLabel(for: sortOption)
    }

    var filteredGames: [PinballGame] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let effectiveBank = supportsBankFilter ? selectedBank : nil

        return sourceScopedGames.filter { game in
            let matchesQuery: Bool
            if trimmed.isEmpty {
                matchesQuery = true
            } else {
                let haystack = "\(game.name) \(game.manufacturer ?? "") \(game.year.map(String.init) ?? "")".lowercased()
                matchesQuery = haystack.contains(trimmed)
            }

            let matchesBank = effectiveBank == nil || game.bank == effectiveBank
            return matchesQuery && matchesBank
        }
    }

    var sortedFilteredGames: [PinballGame] {
        switch sortOption {
        case .area:
            return filteredGames.sorted {
                byOptionalAscending($0.areaOrder, $1.areaOrder)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? false
            }
        case .bank:
            return filteredGames.sorted {
                byOptionalAscending($0.bank, $1.bank)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? false
            }
        case .alphabetical:
            return filteredGames.sorted {
                byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? false
            }
        case .year:
            if yearSortDescending {
                return filteredGames.sorted {
                    byOptionalDescending($0.year, $1.year)
                        ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                        ?? false
                }
            } else {
                return filteredGames.sorted {
                    byOptionalAscending($0.year, $1.year)
                        ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                        ?? false
                }
            }
        }
    }

    var visibleSortedFilteredGames: [PinballGame] {
        Array(sortedFilteredGames.prefix(visibleGameLimit))
    }

    var hasMoreVisibleGames: Bool {
        visibleSortedFilteredGames.count < sortedFilteredGames.count
    }

    var showGroupedView: Bool {
        let effectiveBank = supportsBankFilter ? selectedBank : nil
        return effectiveBank == nil && (sortOption == .area || sortOption == .bank)
    }

    var sections: [PinballGroupSection] {
        var out: [PinballGroupSection] = []
        let groupingKey: (PinballGame) -> (String?, Int?) = {
            switch sortOption {
            case .area:
                return { (nil, $0.group) }
            case .bank:
                return { (nil, $0.bank) }
            case .alphabetical, .year:
                return { _ in (nil, nil) }
            }
        }()

        for game in visibleSortedFilteredGames {
            let (locationKey, groupKey) = groupingKey(game)
            if let last = out.last, last.locationKey == locationKey, last.groupKey == groupKey {
                var mutable = last
                mutable.games.append(game)
                out[out.count - 1] = mutable
            } else {
                out.append(PinballGroupSection(locationKey: locationKey, groupKey: groupKey, games: [game]))
            }
        }

        return out
    }

    func menuLabel(for option: PinballLibrarySortOption) -> String {
        if option == .year {
            return yearSortDescending ? "Sort: Year (New-Old)" : "Sort: Year (Old-New)"
        }
        return option.menuLabel
    }

    func preferredDefaultSortOption(for source: PinballLibrarySource, games: [PinballGame]) -> PinballLibrarySortOption {
        switch source.type {
        case .manufacturer:
            return .year
        case .category, .tournament:
            return .alphabetical
        case .venue:
            let hasArea = games.contains {
                guard let area = $0.area?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
                return !area.isEmpty && area.lowercased() != "null"
            }
            return hasArea ? .area : .alphabetical
        }
    }

    func preferredDefaultYearSortDescending(for source: PinballLibrarySource, games: [PinballGame]) -> Bool {
        preferredDefaultSortOption(for: source, games: games) == .year && source.type == .manufacturer
    }

    private func byOptionalAscending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        switch (lhs, rhs) {
        case let (l?, r?):
            return byAscending(l, r)
        case (nil, nil):
            return nil
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
    }

    private func byAscending<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool? {
        if lhs == rhs { return nil }
        return lhs < rhs
    }

    private func byOptionalDescending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        switch (lhs, rhs) {
        case let (l?, r?):
            return byDescending(l, r)
        case (nil, nil):
            return nil
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
    }

    private func byDescending<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool? {
        if lhs == rhs { return nil }
        return lhs > rhs
    }
}
