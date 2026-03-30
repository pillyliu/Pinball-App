import SwiftUI

struct GameRoomEditMachinesView: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let onShowSaveFeedback: (String) -> Void
    @State private var viewState = GameRoomEditMachinesViewState()

    var body: some View {
        GameRoomEditMachinesShell(
            editMachinesTitle: editMachinesPanelTitle,
            isNameExpanded: $viewState.panelExpansion.isNameExpanded,
            isAddMachineExpanded: $viewState.panelExpansion.isAddMachineExpanded,
            isAreasExpanded: $viewState.panelExpansion.isAreasExpanded,
            isEditMachinesExpanded: $viewState.panelExpansion.isEditMachinesExpanded,
            venueNameDraft: $viewState.venueNameDraft,
            onSaveVenueName: saveVenueNameDraft,
            addMachineSearchText: $viewState.addMachineFilters.searchText,
            addMachineManufacturerQuery: $viewState.addMachineFilters.manufacturerQuery,
            addMachineYearQuery: $viewState.addMachineFilters.yearQuery,
            addMachineSelectedType: $viewState.addMachineFilters.selectedType,
            isAddMachineAdvancedExpanded: $viewState.addMachineFilters.isAdvancedExpanded,
            catalogErrorMessage: catalogLoader.errorMessage,
            isCatalogLoading: catalogLoader.isLoading,
            hasSearchFilters: hasSearchFilters,
            filteredGameCount: filteredCatalogGames.count,
            filteredCatalogGames: filteredCatalogGames,
            filteredManufacturerSuggestions: filteredManufacturerSuggestions,
            showManufacturerSuggestions: shouldShowManufacturerSuggestions,
            pendingVariantPickerGameID: viewState.pendingVariantPicker.gameID,
            pendingVariantPickerTitle: viewState.pendingVariantPicker.title,
            pendingVariantPickerOptions: viewState.pendingVariantPicker.options,
            onSelectManufacturer: { viewState.addMachineFilters.manufacturerQuery = $0 },
            onSelectType: { viewState.addMachineFilters.selectedType = $0 },
            onClearFilters: clearAddMachineFilters,
            onBeginAddMachineSelection: beginAddMachineSelection(for:),
            onDismissVariantPicker: clearPendingVariantPicker,
            onSelectPendingVariant: { option in
                completeAddMachineSelection(catalogGameID: viewState.pendingVariantPicker.gameID, variant: option)
            },
            resultMetaLine: gameRoomResultMetaLine(for:),
            newAreaName: $viewState.areaDraft.name,
            newAreaOrder: $viewState.areaDraft.areaOrder,
            areas: store.state.areas,
            onSaveArea: saveAreaDraftWithFeedback,
            onEditArea: editArea,
            onDeleteArea: deleteAreaWithFeedback,
            allMachines: allMachines,
            machineMenuGroups: machineMenuGroups,
            selectedMachine: selectedMachine,
            currentVariantLabel: currentVariantLabel,
            variantOptions: selectedMachineVariantOptions,
            selectedMachineID: $viewState.selectedMachineID,
            draftAreaID: $viewState.machineDraft.areaID,
            draftStatus: $viewState.machineDraft.status,
            draftGroup: $viewState.machineDraft.group,
            draftPosition: $viewState.machineDraft.position,
            draftPurchaseSource: $viewState.machineDraft.purchaseSource,
            draftSerialNumber: $viewState.machineDraft.serialNumber,
            draftOwnershipNotes: $viewState.machineDraft.ownershipNotes,
            machineMenuLabel: gameRoomMachineMenuLabel,
            onClearVariant: { viewState.machineDraft.displayVariant = "" },
            onSelectVariant: { viewState.machineDraft.displayVariant = $0 },
            onSaveMachine: persistMachineEditsWithFeedback,
            onDeleteMachine: deleteMachine,
            onArchiveMachine: archiveMachine
        )
        .onAppear {
            handleAppear()
        }
        .onChange(of: store.state.ownedMachines.map(\.id)) { _, _ in
            syncMachineSelectionState()
        }
        .onChange(of: viewState.selectedMachineID) { _, _ in
            syncDraftFromSelection()
        }
        .onChange(of: catalogLoader.games) { _, _ in
            rebuildCatalogSearchIndex()
        }
        .onChange(of: catalogLoader.variantOptionsByCatalogGameID) { _, _ in
            rebuildCatalogSearchIndex()
        }
    }

    private var selectedMachineVariantOptions: [String] {
        selectedMachine.map { machine in
                gameRoomVariantOptions(
                    for: machine,
                    catalogLoader: catalogLoader,
                    draftDisplayVariant: viewState.machineDraft.displayVariant
                )
        } ?? []
    }

    private var allMachines: [OwnedMachine] {
        store.activeMachines + store.archivedMachines
    }

    private var machineMenuGroups: [GameRoomMachineMenuGroup] {
        gameRoomMachineMenuGroups(
            allMachines: allMachines,
            areaTitle: areaTitle(for:),
            areaOrder: { areaID in store.area(for: areaID)?.areaOrder ?? Int.max }
        )
    }

    private var editMachinesPanelTitle: String {
        "Edit Machines (\(store.activeMachines.count))"
    }

    private func handleAppear() {
        syncMachineSelectionState()
        rebuildCatalogSearchIndex()
    }

    private func areaTitle(for areaID: UUID?) -> String {
        guard let areaID, let area = store.area(for: areaID) else { return "No Area" }
        return area.name
    }

    private func saveAreaDraft() {
        store.upsertArea(
            id: viewState.areaDraft.selectedAreaID,
            name: viewState.areaDraft.name,
            areaOrder: max(1, viewState.areaDraft.areaOrder)
        )
        clearAreaDraft()
    }

    private func saveAreaDraftWithFeedback() {
        saveAreaDraft()
        onShowSaveFeedback("Area saved")
    }

    private func saveVenueNameDraft() {
        store.updateVenueName(viewState.venueNameDraft)
        viewState.venueNameDraft = store.venueName
        onShowSaveFeedback("GameRoom name saved")
    }

    private func editArea(_ area: GameRoomArea) {
        viewState.areaDraft = gameRoomAreaDraftState(for: area)
    }

    private func deleteArea(_ area: GameRoomArea) {
        if viewState.machineDraft.areaID == area.id {
            viewState.machineDraft.areaID = nil
        }
        if viewState.areaDraft.selectedAreaID == area.id {
            clearAreaDraft()
        }
        store.deleteArea(id: area.id)
    }

    private func deleteAreaWithFeedback(_ area: GameRoomArea) {
        deleteArea(area)
        onShowSaveFeedback("Area deleted")
    }

    private func clearAreaDraft() {
        viewState.areaDraft = .empty
    }

    private func deleteMachine(_ machine: OwnedMachine) {
        store.deleteMachine(id: machine.id)
        onShowSaveFeedback("Machine deleted")
    }

    private func persistMachineEditsWithFeedback(for machine: OwnedMachine) {
        persistMachineEdits(for: machine)
        onShowSaveFeedback("Machine details saved")
    }

    private func archiveMachine(_ machine: OwnedMachine) {
        persistMachineEdits(for: machine, status: .archived)
        viewState.machineDraft.status = .archived
        onShowSaveFeedback("Machine archived")
    }

    private var selectedMachine: OwnedMachine? {
        gameRoomSelectedMachine(
            allMachines: allMachines,
            selectedMachineID: viewState.selectedMachineID
        )
    }

    private var manufacturerOptions: [String] {
        viewState.indexedManufacturers
    }

    private var filteredManufacturerSuggestions: [String] {
        gameRoomManufacturerSuggestions(
            options: manufacturerOptions,
            query: viewState.addMachineFilters.manufacturerQuery
        )
    }

    private var shouldShowManufacturerSuggestions: Bool {
        gameRoomShouldShowManufacturerSuggestions(
            filteredSuggestions: filteredManufacturerSuggestions,
            query: viewState.addMachineFilters.manufacturerQuery
        )
    }

    private var hasSearchFilters: Bool {
        gameRoomHasSearchFilters(
            searchText: viewState.addMachineFilters.searchText,
            manufacturerQuery: viewState.addMachineFilters.manufacturerQuery,
            yearQuery: viewState.addMachineFilters.yearQuery,
            selectedType: viewState.addMachineFilters.selectedType
        )
    }

    private var currentVariantLabel: String {
        viewState.machineDraft.currentVariantLabel
    }

    private var filteredCatalogGames: [GameRoomCatalogGame] {
        filteredGameRoomCatalogGames(
            entries: viewState.indexedCatalogSearchEntries,
            nameQuery: viewState.addMachineFilters.searchText,
            manufacturerQuery: viewState.addMachineFilters.manufacturerQuery,
            yearQuery: viewState.addMachineFilters.yearQuery,
            selectedType: viewState.addMachineFilters.selectedType
        )
    }

    private func clearAddMachineFilters() {
        viewState.addMachineFilters.clear()
    }

    private func syncMachineSelectionState() {
        let syncedState = gameRoomSyncedEditMachineSelectionState(
            currentVenueNameDraft: viewState.venueNameDraft,
            venueName: store.venueName,
            allMachines: allMachines,
            selectedMachineID: viewState.selectedMachineID
        )
        viewState.venueNameDraft = syncedState.venueNameDraft
        viewState.selectedMachineID = syncedState.selectedMachineID
    }

    private func syncDraftFromSelection() {
        viewState.machineDraft = gameRoomMachineEditDraft(for: selectedMachine)
    }

    private func beginAddMachineSelection(for game: GameRoomCatalogGame) {
        switch gameRoomAddMachineSelectionAction(for: game, catalogLoader: catalogLoader) {
        case .presentVariantPicker(let picker):
            viewState.pendingVariantPicker = picker
        case .complete(let catalogGameID, let variant):
            completeAddMachineSelection(catalogGameID: catalogGameID, variant: variant)
        }
    }

    private func completeAddMachineSelection(catalogGameID: String?, variant: String?) {
        switch gameRoomCompleteAddMachineSelection(
            store: store,
            catalogLoader: catalogLoader,
            catalogGameID: catalogGameID,
            variant: variant
        ) {
        case .unresolved:
            break
        case .duplicate(let message):
            onShowSaveFeedback(message)
        case .added(let nextSelectedMachineID):
            viewState.selectedMachineID = nextSelectedMachineID
            syncDraftFromSelection()
        }
        clearPendingVariantPicker()
    }

    private func persistMachineEdits(for machine: OwnedMachine, status: OwnedMachineStatus? = nil) {
        gameRoomPersistMachineEdits(
            store: store,
            catalogLoader: catalogLoader,
            machine: machine,
            draft: viewState.machineDraft,
            status: status
        )
    }

    private func clearPendingVariantPicker() {
        viewState.pendingVariantPicker.clear()
    }

    private func rebuildCatalogSearchIndex() {
        let searchIndex = gameRoomCatalogSearchIndexState(
            games: catalogLoader.games,
            variantOptions: catalogLoader.variantOptions(for:)
        )
        viewState.indexedCatalogSearchEntries = searchIndex.entries
        viewState.indexedManufacturers = searchIndex.manufacturers
    }
}
