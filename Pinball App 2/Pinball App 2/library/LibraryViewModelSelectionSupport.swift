import Foundation

extension PinballLibraryViewModel {
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

    func persistSelectedSort() {
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

    func persistSelectedBank() {
        guard let selectedSource else { return }
        PinballLibrarySourceStateStore.setSelectedBank(sourceID: selectedSource.id, bank: selectedBank)
        if let selectedBank {
            sourceState.selectedBankBySource[selectedSource.id] = selectedBank
        } else {
            sourceState.selectedBankBySource.removeValue(forKey: selectedSource.id)
        }
    }
}
