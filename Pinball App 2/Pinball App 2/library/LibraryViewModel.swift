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

    var didLoad = false
    var sourceState: PinballLibrarySourceState = .empty
    let initialVisibleGameCount = 48
    let visibleGamePageSize = 36
    @Published private(set) var visibleGameLimit = 48

    func applySelection(_ selection: PinballLibrarySelectionResolution) {
        selectedSourceID = selection.selectedSourceID
        sortOption = selection.sortOption
        yearSortDescending = selection.yearSortDescending
        selectedBank = selection.selectedBank
    }

    func loadGames() async {
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

    func resetVisibleGameLimit() {
        visibleGameLimit = initialVisibleGameCount
    }
}
