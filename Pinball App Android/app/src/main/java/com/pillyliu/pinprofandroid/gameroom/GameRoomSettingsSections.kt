package com.pillyliu.pinprofandroid.gameroom
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppControlCard
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.SectionTitle
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors

internal data class GameRoomEditSettingsContext(
    val store: GameRoomStore,
    val catalogLoader: GameRoomCatalogLoader,
    val nameExpanded: Boolean,
    val onNameExpandedChange: (Boolean) -> Unit,
    val venueNameDraft: String,
    val onVenueNameDraftChange: (String) -> Unit,
    val onSaveVenueName: () -> Unit,
    val onShowSaveFeedback: (String) -> Unit,
    val addMachineExpanded: Boolean,
    val onAddMachineExpandedChange: (Boolean) -> Unit,
    val catalogIsLoading: Boolean,
    val catalogErrorMessage: String?,
    val areasExpanded: Boolean,
    val onAreasExpandedChange: (Boolean) -> Unit,
    val areaNameDraft: String,
    val onAreaNameDraftChange: (String) -> Unit,
    val areaOrderDraft: String,
    val onAreaOrderDraftChange: (String) -> Unit,
    val onSaveArea: () -> Unit,
    val onResetAreaDraft: () -> Unit,
    val onEditArea: (GameRoomArea) -> Unit,
    val onDeleteArea: (String) -> Unit,
    val editMachinesExpanded: Boolean,
    val onEditMachinesExpandedChange: (Boolean) -> Unit,
    val allMachines: List<OwnedMachine>,
    val selectedEditMachine: OwnedMachine?,
    val onSelectedEditMachineChange: (String) -> Unit,
    val variantOptions: List<String>,
    val draftVariant: String,
    val onDraftVariantChange: (String) -> Unit,
    val draftAreaID: String?,
    val onDraftAreaIDChange: (String?) -> Unit,
    val draftStatus: String,
    val onDraftStatusChange: (String) -> Unit,
    val draftGroup: String,
    val onDraftGroupChange: (String) -> Unit,
    val draftPosition: String,
    val onDraftPositionChange: (String) -> Unit,
    val draftPurchaseSource: String,
    val onDraftPurchaseSourceChange: (String) -> Unit,
    val draftSerialNumber: String,
    val onDraftSerialNumberChange: (String) -> Unit,
    val draftOwnershipNotes: String,
    val onDraftOwnershipNotesChange: (String) -> Unit,
    val onSaveMachine: () -> Unit,
    val onDeleteMachine: () -> Unit,
    val onArchiveMachine: (() -> Unit)?,
)

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun GameRoomImportSettingsSection(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    importSourceInput: String,
    onImportSourceInputChange: (String) -> Unit,
    importIsLoading: Boolean,
    importErrorMessage: String?,
    importResultMessage: String?,
    importRows: List<ImportDraftRow>,
    importReviewFilter: ImportReviewFilter,
    onImportReviewFilterChange: (ImportReviewFilter) -> Unit,
    onFetchCollection: () -> Unit,
    onUpdateImportPurchaseDate: (String, String) -> Unit,
    onUpdateImportMatch: (String, String?) -> Unit,
    onUpdateImportVariant: (String, String?) -> Unit,
    onPerformImport: () -> Unit,
) {
    OutlinedTextField(
        value = importSourceInput,
        onValueChange = onImportSourceInputChange,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        label = { Text("Pinside username or public collection URL") },
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Go),
        keyboardActions = KeyboardActions(
            onGo = {
                if (!importIsLoading && importSourceInput.trim().isNotBlank()) {
                    onFetchCollection()
                }
            },
        ),
    )
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AppPrimaryButton(
            onClick = onFetchCollection,
            modifier = Modifier.fillMaxWidth(),
            enabled = !importIsLoading && importSourceInput.trim().isNotEmpty(),
        ) {
            Text(if (importIsLoading) "Fetching..." else "Fetch Collection")
        }
    }
    if (importIsLoading) {
        AppInlineTaskStatus(text = "Fetching collection…", showsProgress = true)
    } else if (importErrorMessage != null) {
        AppInlineTaskStatus(text = importErrorMessage, isError = true)
    }
    if (importRows.isNotEmpty()) {
        GameRoomImportReviewContent(
            store = store,
            catalogLoader = catalogLoader,
            importRows = importRows,
            importReviewFilter = importReviewFilter,
            onImportReviewFilterChange = onImportReviewFilterChange,
            onUpdateImportPurchaseDate = onUpdateImportPurchaseDate,
            onUpdateImportMatch = onUpdateImportMatch,
            onUpdateImportVariant = onUpdateImportVariant,
            onPerformImport = onPerformImport,
        )
    }
    if (importResultMessage != null) {
        Text(
            text = importResultMessage,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    Text(
        text = "Import records stored: ${store.state.importRecords.size}",
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
internal fun GameRoomEditSettingsSection(
    context: GameRoomEditSettingsContext,
) {
    GameRoomVenueNameSettingsCard(context)
    GameRoomAddMachineSettingsCard(context)
    GameRoomAreaSettingsCard(context)
    GameRoomEditMachinesSettingsCard(context)
}

@Composable
internal fun GameRoomArchiveSettingsSection(
    store: GameRoomStore,
    archiveFilter: GameRoomArchiveFilter,
    onArchiveFilterChange: (GameRoomArchiveFilter) -> Unit,
    onOpenMachineView: (String) -> Unit,
) {
    val filteredArchivedMachines = when (archiveFilter) {
        GameRoomArchiveFilter.All -> store.archivedMachines
        GameRoomArchiveFilter.Sold -> store.archivedMachines.filter { it.status == OwnedMachineStatus.sold }
        GameRoomArchiveFilter.Traded -> store.archivedMachines.filter { it.status == OwnedMachineStatus.traded }
        GameRoomArchiveFilter.Archived -> store.archivedMachines.filter { it.status == OwnedMachineStatus.archived }
    }

    CardContainer {
        SectionTitle("Machine Archive")
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            GameRoomArchiveFilter.entries.forEachIndexed { index, filter ->
                SegmentedButton(
                    selected = archiveFilter == filter,
                    onClick = { onArchiveFilterChange(filter) },
                    colors = pinballSegmentedButtonColors(),
                    icon = {},
                    shape = SegmentedButtonDefaults.itemShape(
                        index = index,
                        count = GameRoomArchiveFilter.entries.size,
                    ),
                    label = { Text(filter.label, maxLines = 1) },
                )
            }
        }

        if (filteredArchivedMachines.isEmpty()) {
            AppPanelEmptyCard(text = "No archived machines for this filter.")
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                filteredArchivedMachines.forEachIndexed { index, machine ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onOpenMachineView(machine.id) }
                            .padding(horizontal = 10.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = machine.displayTitle,
                                color = MaterialTheme.colorScheme.onSurface,
                                fontWeight = androidx.compose.ui.text.font.FontWeight.Medium,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            Text(
                                text = machine.status.name.replaceFirstChar { it.uppercase() },
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                        Icon(
                            imageVector = Icons.Outlined.ChevronRight,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(start = 8.dp),
                        )
                    }
                    if (index != filteredArchivedMachines.lastIndex) {
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                    }
                }
            }
        }

        Text(
            text = "Archived machines: ${filteredArchivedMachines.size}",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
