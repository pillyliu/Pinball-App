import SwiftUI

struct GameRoomMachineManagementPanel: View {
    let allMachines: [OwnedMachine]
    let machineMenuGroups: [GameRoomMachineMenuGroup]
    let selectedMachine: OwnedMachine?
    let currentVariantLabel: String
    let variantOptions: [String]
    let areas: [GameRoomArea]
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
        VStack(alignment: .leading, spacing: 10) {
            if allMachines.isEmpty {
                AppPanelEmptyCard(text: "No machines in the collection yet. Add a machine above to start organizing the GameRoom.")
            } else {
                GameRoomMachineSelectionRow(
                    machineMenuGroups: machineMenuGroups,
                    selectedMachineTitle: selectedMachine?.displayTitle ?? "Select Machine",
                    currentVariantLabel: currentVariantLabel,
                    variantOptions: variantOptions,
                    machineMenuLabel: machineMenuLabel,
                    onSelectMachine: { selectedMachineID = $0 },
                    onClearVariant: onClearVariant,
                    onSelectVariant: onSelectVariant
                )

                if let selectedMachine {
                    GameRoomMachineEditorFields(
                        selectedMachine: selectedMachine,
                        areas: areas,
                        draftAreaID: $draftAreaID,
                        draftStatus: $draftStatus,
                        draftGroup: $draftGroup,
                        draftPosition: $draftPosition,
                        draftPurchaseSource: $draftPurchaseSource,
                        draftSerialNumber: $draftSerialNumber,
                        draftOwnershipNotes: $draftOwnershipNotes,
                        onSaveMachine: onSaveMachine,
                        onDeleteMachine: onDeleteMachine,
                        onArchiveMachine: onArchiveMachine
                    )
                }
            }
        }
    }
}
