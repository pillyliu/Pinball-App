package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect

internal data class GameRoomScreenSelections(
    val activeMachines: List<OwnedMachine>,
    val selectedMachineFromAll: OwnedMachine?,
    val selectedMachine: OwnedMachine?,
    val allMachines: List<OwnedMachine>,
    val selectedEditMachine: OwnedMachine?,
)

@Composable
internal fun rememberGameRoomScreenSelections(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    selectedMachineID: String?,
    onSelectedMachineIDChange: (String?) -> Unit,
    selectedEditMachineID: String?,
    onSelectedEditMachineIDChange: (String?) -> Unit,
    draftAreaID: String?,
    onDraftAreaIDChange: (String?) -> Unit,
    onDraftGroupChange: (String) -> Unit,
    onDraftPositionChange: (String) -> Unit,
    onDraftStatusChange: (String) -> Unit,
    onDraftVariantChange: (String) -> Unit,
    onDraftPurchaseSourceChange: (String) -> Unit,
    onDraftSerialNumberChange: (String) -> Unit,
    onDraftOwnershipNotesChange: (String) -> Unit,
    venueNameDraft: String,
    onVenueNameDraftChange: (String) -> Unit,
    activeInputSheet: GameRoomInputSheet?,
    onInputDateDraftChange: (String) -> Unit,
    onIssueDraftAttachmentsChange: (List<IssueInputAttachmentDraft>) -> Unit,
): GameRoomScreenSelections {
    val activeMachines = store.activeMachines
    val selectedMachineFromAll = store.state.ownedMachines.firstOrNull { it.id == selectedMachineID }
    val selectedMachine = activeMachines.firstOrNull { it.id == selectedMachineID } ?: activeMachines.firstOrNull()
    val allMachines = store.activeMachines + store.archivedMachines
    val selectedEditMachine = allMachines.firstOrNull { it.id == selectedEditMachineID }

    LaunchedEffect(Unit) {
        store.loadIfNeeded()
        catalogLoader.loadIfNeeded()
        store.migrateOwnedMachineOpdbIds(catalogLoader)
    }

    LaunchedEffect(activeMachines.map { it.id }) {
        if (selectedMachineID == null || activeMachines.none { it.id == selectedMachineID }) {
            onSelectedMachineIDChange(activeMachines.firstOrNull()?.id)
        }
    }

    LaunchedEffect(allMachines.map { it.id }) {
        if (selectedEditMachineID == null || allMachines.none { it.id == selectedEditMachineID }) {
            onSelectedEditMachineIDChange(allMachines.firstOrNull()?.id)
        }
    }

    LaunchedEffect(selectedEditMachineID) {
        val machine = selectedEditMachine
        if (machine == null) {
            if (draftAreaID != null) onDraftAreaIDChange(null)
            onDraftGroupChange("")
            onDraftPositionChange("")
            onDraftStatusChange(OwnedMachineStatus.active.name)
            onDraftVariantChange("None")
            onDraftPurchaseSourceChange("")
            onDraftSerialNumberChange("")
            onDraftOwnershipNotesChange("")
            return@LaunchedEffect
        }
        onDraftAreaIDChange(machine.gameRoomAreaID)
        onDraftGroupChange(machine.groupNumber?.toString().orEmpty())
        onDraftPositionChange(machine.position?.toString().orEmpty())
        onDraftStatusChange(machine.status.name)
        onDraftVariantChange(machine.displayVariant ?: "None")
        onDraftPurchaseSourceChange(machine.purchaseSource.orEmpty())
        onDraftSerialNumberChange(machine.serialNumber.orEmpty())
        onDraftOwnershipNotesChange(machine.ownershipNotes.orEmpty())
    }

    LaunchedEffect(store.venueName) {
        if (venueNameDraft.isBlank()) {
            onVenueNameDraftChange(store.venueName)
        }
    }

    LaunchedEffect(activeInputSheet) {
        if (activeInputSheet != null) {
            onInputDateDraftChange(todayIsoDate())
            if (activeInputSheet == GameRoomInputSheet.LogIssue) {
                onIssueDraftAttachmentsChange(emptyList())
            }
        }
    }

    return GameRoomScreenSelections(
        activeMachines = activeMachines,
        selectedMachineFromAll = selectedMachineFromAll,
        selectedMachine = selectedMachine,
        allMachines = allMachines,
        selectedEditMachine = selectedEditMachine,
    )
}
