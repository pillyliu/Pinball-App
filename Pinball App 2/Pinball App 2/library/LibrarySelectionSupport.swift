import Foundation

struct PinballLibrarySelectionResolution {
    let selectedSourceID: String
    let sortOption: PinballLibrarySortOption
    let yearSortDescending: Bool
    let selectedBank: Int?
}

func resolvePreferredLibrarySource(
    sources: [PinballLibrarySource],
    selectedSourceID: String?,
    currentSelectedSourceID: String? = nil
) -> PinballLibrarySource? {
    let preferredSourceID = [selectedSourceID, currentSelectedSourceID]
        .compactMap { canonicalLibrarySourceID($0) }
        .first(where: { id in sources.contains(where: { $0.id == id }) })
    return sources.first(where: { $0.id == preferredSourceID }) ?? sources.first
}

func resolveLibrarySelection(
    payload: PinballLibraryPayload,
    sourceState: PinballLibrarySourceState,
    currentSelectedSourceID: String
) -> PinballLibrarySelectionResolution? {
    let chosenSource = resolvePreferredLibrarySource(
        sources: payload.sources,
        selectedSourceID: sourceState.selectedSourceID,
        currentSelectedSourceID: currentSelectedSourceID
    )
    return chosenSource.map { source in
        resolveLibrarySelectionForSource(
            source: source,
            games: payload.games,
            sourceState: sourceState
        )
    }
}

func resolveLibrarySelectionForSource(
    source: PinballLibrarySource,
    games: [PinballGame],
    sourceState: PinballLibrarySourceState
) -> PinballLibrarySelectionResolution {
    let sourceGames = games.filter { $0.sourceId == source.id }
    let options = librarySortOptions(for: source, games: sourceGames)
    let persistedSort = sourceState.selectedSortBySource[source.id]

    let selection: (sortOption: PinballLibrarySortOption, yearSortDescending: Bool)
    if source.type == .manufacturer {
        selection = (.year, true)
    } else if persistedSort == "YEAR_DESC", options.contains(.year) {
        selection = (.year, true)
    } else if let persistedSort,
              let sortOption = PinballLibrarySortOption(rawValue: persistedSort),
              options.contains(sortOption) {
        selection = (sortOption, false)
    } else {
        let defaultSort = libraryPreferredDefaultSortOption(for: source, games: sourceGames)
        let resolvedSort = options.contains(defaultSort) ? defaultSort : (options.first ?? .alphabetical)
        selection = (
            resolvedSort,
            resolvedSort == .year ? libraryPreferredDefaultYearSortDescending(for: source, games: sourceGames) : false
        )
    }

    let selectedBank: Int?
    if source.type == .venue, sourceGames.contains(where: { ($0.bank ?? 0) > 0 }) {
        selectedBank = sourceState.selectedBankBySource[source.id]
    } else {
        selectedBank = nil
    }

    return PinballLibrarySelectionResolution(
        selectedSourceID: source.id,
        sortOption: selection.sortOption,
        yearSortDescending: selection.yearSortDescending,
        selectedBank: selectedBank
    )
}

func librarySortOptions(
    for source: PinballLibrarySource,
    games: [PinballGame]
) -> [PinballLibrarySortOption] {
    switch source.type {
    case .category, .manufacturer, .tournament:
        return [.year, .alphabetical]
    case .venue:
        let hasBank = games.contains { ($0.bank ?? 0) > 0 }
        var options: [PinballLibrarySortOption] = [.area]
        if hasBank { options.append(.bank) }
        options.append(.alphabetical)
        options.append(.year)
        return options
    }
}

func libraryPreferredDefaultSortOption(
    for source: PinballLibrarySource,
    games: [PinballGame]
) -> PinballLibrarySortOption {
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
        let hasPosition = games.contains { ($0.group ?? 0) > 0 || ($0.pos ?? 0) > 0 }
        return (hasArea || hasPosition) ? .area : .alphabetical
    }
}

func libraryPreferredDefaultYearSortDescending(
    for source: PinballLibrarySource,
    games: [PinballGame]
) -> Bool {
    source.type == .manufacturer && libraryPreferredDefaultSortOption(for: source, games: games) == .year
}
