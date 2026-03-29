import Foundation
import Combine

@MainActor
final class PinballLibraryViewModel: ObservableObject {
    @Published private(set) var games: [PinballGame] = []
    @Published private(set) var sources: [PinballLibrarySource] = []
    @Published var selectedSourceID: String = ""
    @Published var query: String = "" {
        didSet {
            if query != oldValue {
                resetVisibleGameLimit()
            }
        }
    }
    @Published var sortOption: PinballLibrarySortOption = .area {
        didSet {
            if sortOption != oldValue {
                resetVisibleGameLimit()
                persistSelectedSort()
            }
        }
    }
    @Published var yearSortDescending: Bool = false {
        didSet {
            if yearSortDescending != oldValue {
                resetVisibleGameLimit()
                persistSelectedSort()
            }
        }
    }
    @Published var selectedBank: Int? {
        didSet {
            if selectedBank != oldValue {
                resetVisibleGameLimit()
                persistSelectedBank()
            }
        }
    }
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false

    private var didLoad = false
    private var sourceState: PinballLibrarySourceState = .empty
    private let initialVisibleGameCount = 48
    private let visibleGamePageSize = 36
    @Published private(set) var visibleGameLimit = 48
    private var browsingState: PinballLibraryBrowsingState {
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

    private func applySelection(_ selection: PinballLibrarySelectionResolution) {
        selectedSourceID = selection.selectedSourceID
        sortOption = selection.sortOption
        yearSortDescending = selection.yearSortDescending
        selectedBank = selection.selectedBank
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadGames()
    }

    func refresh() async {
        await loadGames()
    }

    func selectSource(_ sourceID: String) {
        PinballLibrarySourceStateStore.setSelectedSourceID(sourceID)
        sourceState.selectedSourceID = canonicalLibrarySourceID(sourceID)
        if let source = sources.first(where: { $0.id == sourceID }) {
            let selection = resolveLibrarySelectionForSource(
                source: source,
                games: games,
                sourceState: sourceState
            )
            applySelection(selection)
        } else {
            selectedSourceID = sourceID
            selectedBank = nil
        }
        resetVisibleGameLimit()
    }

    func selectSortOption(_ option: PinballLibrarySortOption) {
        if option == .year, sortOption == .year {
            yearSortDescending.toggle()
            return
        }
        sortOption = option
        if option == .year {
            yearSortDescending = false
        }
    }

    func menuLabel(for option: PinballLibrarySortOption) -> String {
        browsingState.menuLabel(for: option)
    }

    func loadMoreGamesIfNeeded(currentGameID: String?) {
        guard hasMoreVisibleGames else { return }
        guard let currentGameID else {
            visibleGameLimit += visibleGamePageSize
            return
        }
        let thresholdIndex = max(0, visibleSortedFilteredGames.count - 12)
        guard let currentIndex = visibleSortedFilteredGames.firstIndex(where: { $0.id == currentGameID }),
              currentIndex >= thresholdIndex else {
            return
        }
        visibleGameLimit += visibleGamePageSize
    }

    private func resetVisibleGameLimit() {
        visibleGameLimit = initialVisibleGameCount
    }

    private func loadGames() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let extraction = try await loadLibraryExtraction()
            let payload = extraction.payload
            games = payload.games
            sources = payload.sources
            sourceState = extraction.state
            resetVisibleGameLimit()
            if let selection = resolveLibrarySelection(
                payload: payload,
                sourceState: extraction.state,
                currentSelectedSourceID: selectedSourceID
            ) {
                applySelection(selection)
                PinballLibrarySourceStateStore.setSelectedSourceID(selection.selectedSourceID)
                sourceState.selectedSourceID = selection.selectedSourceID
            }
            errorMessage = nil
        } catch {
            games = []
            sources = []
            sourceState = .empty
            errorMessage = "Failed to load pinball library: \(error.localizedDescription)"
        }
    }

    private func persistSelectedSort() {
        guard let selectedSource else { return }
        let persistedValue: String
        if sortOption == .year && yearSortDescending {
            persistedValue = "YEAR_DESC"
        } else {
            persistedValue = sortOption.rawValue
        }
        PinballLibrarySourceStateStore.setSelectedSort(sourceID: selectedSource.id, sortName: persistedValue)
        sourceState.selectedSortBySource[selectedSource.id] = persistedValue
    }

    private func persistSelectedBank() {
        guard let selectedSource else { return }
        PinballLibrarySourceStateStore.setSelectedBank(sourceID: selectedSource.id, bank: selectedBank)
        if let selectedBank {
            sourceState.selectedBankBySource[selectedSource.id] = selectedBank
        } else {
            sourceState.selectedBankBySource.removeValue(forKey: selectedSource.id)
        }
    }
}
