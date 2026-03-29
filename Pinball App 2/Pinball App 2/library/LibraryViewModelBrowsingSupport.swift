import Foundation

extension PinballLibraryViewModel {
    var browsingState: PinballLibraryBrowsingState {
        PinballLibraryBrowsingState(
            games: games,
            sources: sources,
            selectedSourceID: selectedSourceID,
            query: query,
            sortOption: sortOption,
            yearSortDescending: yearSortDescending,
            selectedBank: selectedBank,
            visibleGameLimit: visibleGameLimit,
            pinnedSourceIDs: sourceState.pinnedSourceIDs
        )
    }

    var selectedSource: PinballLibrarySource? {
        browsingState.selectedSource
    }

    var visibleSources: [PinballLibrarySource] {
        browsingState.visibleSources
    }

    var sourceScopedGames: [PinballGame] {
        browsingState.sourceScopedGames
    }

    var sortOptions: [PinballLibrarySortOption] {
        browsingState.sortOptions
    }

    var supportsBankFilter: Bool {
        browsingState.supportsBankFilter
    }

    var bankOptions: [Int] {
        browsingState.bankOptions
    }

    var selectedBankLabel: String {
        browsingState.selectedBankLabel
    }

    var selectedSortLabel: String {
        browsingState.selectedSortLabel
    }

    var filteredGames: [PinballGame] {
        browsingState.filteredGames
    }

    var sortedFilteredGames: [PinballGame] {
        browsingState.sortedFilteredGames
    }

    var visibleSortedFilteredGames: [PinballGame] {
        browsingState.visibleSortedFilteredGames
    }

    var hasMoreVisibleGames: Bool {
        browsingState.hasMoreVisibleGames
    }

    var showGroupedView: Bool {
        browsingState.showGroupedView
    }

    var sections: [PinballGroupSection] {
        browsingState.sections
    }

    func menuLabel(for option: PinballLibrarySortOption) -> String {
        browsingState.menuLabel(for: option)
    }
}
