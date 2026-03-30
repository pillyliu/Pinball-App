import SwiftUI

struct GameRoomEditMachinesShell: View {
    let editMachinesTitle: String
    @Binding var isNameExpanded: Bool
    @Binding var isAddMachineExpanded: Bool
    @Binding var isAreasExpanded: Bool
    @Binding var isEditMachinesExpanded: Bool

    @Binding var venueNameDraft: String
    let onSaveVenueName: () -> Void

    @Binding var addMachineSearchText: String
    @Binding var addMachineManufacturerQuery: String
    @Binding var addMachineYearQuery: String
    @Binding var addMachineSelectedType: GameRoomAddMachineTypeFilter?
    @Binding var isAddMachineAdvancedExpanded: Bool
    let catalogErrorMessage: String?
    let isCatalogLoading: Bool
    let hasSearchFilters: Bool
    let filteredGameCount: Int
    let filteredCatalogGames: [GameRoomCatalogGame]
    let filteredManufacturerSuggestions: [String]
    let showManufacturerSuggestions: Bool
    let pendingVariantPickerGameID: String?
    let pendingVariantPickerTitle: String
    let pendingVariantPickerOptions: [String]
    let onSelectManufacturer: (String) -> Void
    let onSelectType: (GameRoomAddMachineTypeFilter?) -> Void
    let onClearFilters: () -> Void
    let onBeginAddMachineSelection: (GameRoomCatalogGame) -> Void
    let onDismissVariantPicker: () -> Void
    let onSelectPendingVariant: (String?) -> Void
    let resultMetaLine: (GameRoomCatalogGame) -> String

    @Binding var newAreaName: String
    @Binding var newAreaOrder: Int
    let areas: [GameRoomArea]
    let onSaveArea: () -> Void
    let onEditArea: (GameRoomArea) -> Void
    let onDeleteArea: (GameRoomArea) -> Void

    let allMachines: [OwnedMachine]
    let machineMenuGroups: [GameRoomMachineMenuGroup]
    let selectedMachine: OwnedMachine?
    let currentVariantLabel: String
    let variantOptions: [String]
    @Binding var selectedMachineID: UUID?
    @Binding var draftAreaID: UUID?
    @Binding var draftStatus: OwnedMachineStatus
    @Binding var draftGroup: String
    @Binding var draftPosition: String
    @Binding var draftPurchaseSource: String
    @Binding var draftSerialNumber: String
    @Binding var draftOwnershipNotes: String
    let machineMenuLabel: (OwnedMachine) -> String
    let onClearVariant: () -> Void
    let onSelectVariant: (String) -> Void
    let onSaveMachine: (OwnedMachine) -> Void
    let onDeleteMachine: (OwnedMachine) -> Void
    let onArchiveMachine: (OwnedMachine) -> Void

    var body: some View {
        GameRoomEditMachinePanelStack(
            editMachinesTitle: editMachinesTitle,
            isNameExpanded: $isNameExpanded,
            isAddMachineExpanded: $isAddMachineExpanded,
            isAreasExpanded: $isAreasExpanded,
            isEditMachinesExpanded: $isEditMachinesExpanded,
            namePanel: { venueNamePanel },
            addMachinePanel: { addMachinePanel },
            areaPanel: { areaManagementPanel },
            editMachinesPanel: { machineManagementPanel }
        )
    }

    private var addMachinePanel: some View {
        GameRoomAddMachinePanel(
            searchText: $addMachineSearchText,
            manufacturerQuery: $addMachineManufacturerQuery,
            yearQuery: $addMachineYearQuery,
            selectedType: $addMachineSelectedType,
            isAdvancedExpanded: $isAddMachineAdvancedExpanded,
            catalogErrorMessage: catalogErrorMessage,
            isCatalogLoading: isCatalogLoading,
            hasSearchFilters: hasSearchFilters,
            filteredGameCount: filteredGameCount,
            filteredCatalogGames: filteredCatalogGames,
            filteredManufacturerSuggestions: filteredManufacturerSuggestions,
            showManufacturerSuggestions: showManufacturerSuggestions,
            pendingVariantPickerGameID: pendingVariantPickerGameID,
            pendingVariantPickerTitle: pendingVariantPickerTitle,
            pendingVariantPickerOptions: pendingVariantPickerOptions,
            onSelectManufacturer: onSelectManufacturer,
            onSelectType: onSelectType,
            onClearFilters: onClearFilters,
            onBeginAddMachineSelection: onBeginAddMachineSelection,
            onDismissVariantPicker: onDismissVariantPicker,
            onSelectPendingVariant: onSelectPendingVariant,
            resultMetaLine: resultMetaLine
        )
    }

    private var venueNamePanel: some View {
        GameRoomVenueNamePanel(
            venueNameDraft: $venueNameDraft,
            onSave: onSaveVenueName
        )
    }

    private var areaManagementPanel: some View {
        GameRoomAreaManagementPanel(
            newAreaName: $newAreaName,
            newAreaOrder: $newAreaOrder,
            areas: areas,
            onSave: onSaveArea,
            onEditArea: onEditArea,
            onDeleteArea: onDeleteArea
        )
    }

    private var machineManagementPanel: some View {
        GameRoomMachineManagementPanel(
            allMachines: allMachines,
            machineMenuGroups: machineMenuGroups,
            selectedMachine: selectedMachine,
            currentVariantLabel: currentVariantLabel,
            variantOptions: variantOptions,
            areas: areas,
            selectedMachineID: $selectedMachineID,
            draftAreaID: $draftAreaID,
            draftStatus: $draftStatus,
            draftGroup: $draftGroup,
            draftPosition: $draftPosition,
            draftPurchaseSource: $draftPurchaseSource,
            draftSerialNumber: $draftSerialNumber,
            draftOwnershipNotes: $draftOwnershipNotes,
            machineMenuLabel: machineMenuLabel,
            onClearVariant: onClearVariant,
            onSelectVariant: onSelectVariant,
            onSaveMachine: onSaveMachine,
            onDeleteMachine: onDeleteMachine,
            onArchiveMachine: onArchiveMachine
        )
    }
}
