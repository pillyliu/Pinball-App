package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.ui.draw.clip
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppSelectionPill
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors
import kotlin.math.max
import kotlin.math.min

internal data class GameRoomEditSettingsContext(
    val store: GameRoomStore,
    val catalogLoader: GameRoomCatalogLoader,
    val nameExpanded: Boolean,
    val onNameExpandedChange: (Boolean) -> Unit,
    val venueNameDraft: String,
    val onVenueNameDraftChange: (String) -> Unit,
    val onSaveVenueName: () -> Unit,
    val addMachineExpanded: Boolean,
    val onAddMachineExpandedChange: (Boolean) -> Unit,
    val addQuery: String,
    val onAddQueryChange: (String) -> Unit,
    val selectedManufacturerText: String,
    val modernManufacturers: List<GameRoomCatalogManufacturerOption>,
    val classicPopularManufacturers: List<GameRoomCatalogManufacturerOption>,
    val otherManufacturers: List<GameRoomCatalogManufacturerOption>,
    val onSelectManufacturer: (String?) -> Unit,
    val catalogIsLoading: Boolean,
    val catalogErrorMessage: String?,
    val resultWindowLabel: String,
    val displayedCatalogGames: List<GameRoomCatalogGame>,
    val filteredCatalogGamesSize: Int,
    val hasPreviousFilteredResults: Boolean,
    val hasNextFilteredResults: Boolean,
    val safeResultWindowStart: Int,
    val safeResultWindowEnd: Int,
    val resultPageSize: Int,
    val maxRenderedResults: Int,
    val pendingResultRestoreTick: Int,
    val pendingResultRestoreGameID: String?,
    val onClearPendingResultRestoreGameID: () -> Unit,
    val onShowPreviousResults: (String?) -> Unit,
    val onShowNextResults: (String?) -> Unit,
    val onAddMachine: (GameRoomCatalogGame) -> Unit,
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
    val filteredImportRows = importRows.filter { row ->
        when (importReviewFilter) {
            ImportReviewFilter.All -> true
            ImportReviewFilter.NeedsReview -> needsImportReview(row, store, catalogLoader)
        }
    }

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
        Button(
            onClick = onFetchCollection,
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
        Text(
            text = "Review matches (${importRows.size})",
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.SemiBold,
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ImportReviewFilter.entries.forEach { filter ->
                val selected = filter == importReviewFilter
                AppSelectionPill(
                    text = filter.label,
                    selected = selected,
                    modifier = Modifier.weight(1f),
                    onClick = { onImportReviewFilterChange(filter) },
                )
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            filteredImportRows.forEach { row ->
                val duplicateWarning = duplicateWarningMessage(row, store, catalogLoader)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(10.dp))
                        .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp))
                        .padding(10.dp),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = row.rawTitle,
                                color = MaterialTheme.colorScheme.onSurface,
                                fontWeight = FontWeight.SemiBold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.weight(1f),
                            )
                            MatchConfidenceBadge(row.matchConfidence)
                        }
                        if (!row.rawVariant.isNullOrBlank()) {
                            Text(
                                text = "Variant: ${row.rawVariant}",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        OutlinedTextField(
                            value = row.rawPurchaseDateText.orEmpty(),
                            onValueChange = { updatedRaw -> onUpdateImportPurchaseDate(row.id, updatedRaw) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            label = { Text("Purchase date (raw import text)") },
                        )
                        if (row.normalizedPurchaseDateMs != null) {
                            Text(
                                text = "Normalized: ${formatDate(row.normalizedPurchaseDateMs, "—")}",
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        if (duplicateWarning != null) {
                            Text(
                                text = duplicateWarning,
                                color = Color(0xFFD18A3D),
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                        AnchoredDropdownFilter(
                            selectedText = row.selectedCatalogGameID?.let { selectedID ->
                                catalogLoader.game(selectedID)?.displayTitle
                            } ?: "No Match Selected",
                            options = buildList {
                                row.suggestions.forEach { suggestionID ->
                                    val suggestion = catalogLoader.game(suggestionID) ?: return@forEach
                                    add(DropdownOption(value = suggestion.catalogGameID, label = suggestion.displayTitle))
                                }
                                add(DropdownOption(value = "__none__", label = "No Match Selected"))
                            },
                            onSelect = { selection ->
                                onUpdateImportMatch(row.id, selection.takeUnless { it == "__none__" })
                            },
                        )
                        val selectedCatalogID = row.selectedCatalogGameID
                        if (!selectedCatalogID.isNullOrBlank()) {
                            val variants = catalogLoader.variantOptions(selectedCatalogID)
                            if (variants.isNotEmpty()) {
                                AnchoredDropdownFilter(
                                    selectedText = row.selectedVariant ?: "None",
                                    options = buildList {
                                        add(DropdownOption(value = "__none__", label = "None"))
                                        variants.forEach { variant ->
                                            add(DropdownOption(value = variant, label = variant))
                                        }
                                    },
                                    onSelect = { variantSelection ->
                                        onUpdateImportVariant(row.id, variantSelection.takeUnless { it == "__none__" })
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
        Button(
            onClick = onPerformImport,
            enabled = importRows.isNotEmpty(),
        ) {
            Text("Import Selected Matches")
        }
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
    CardContainer {
        SectionHeader(
            title = "Name",
            expanded = context.nameExpanded,
            onToggle = { context.onNameExpandedChange(!context.nameExpanded) },
        )
        if (context.nameExpanded) {
            OutlinedTextField(
                value = context.venueNameDraft,
                onValueChange = context.onVenueNameDraftChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("GameRoom Name") },
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = context.onSaveVenueName) {
                    Text("Save")
                }
            }
        }
    }

    CardContainer {
        SectionHeader(
            title = "Add Machine",
            expanded = context.addMachineExpanded,
            onToggle = { context.onAddMachineExpandedChange(!context.addMachineExpanded) },
        )
        if (context.addMachineExpanded) {
            OutlinedTextField(
                value = context.addQuery,
                onValueChange = context.onAddQueryChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("Search by title") },
            )
            ManufacturerFilterDropdown(
                selectedText = context.selectedManufacturerText,
                modernOptions = context.modernManufacturers,
                classicPopularOptions = context.classicPopularManufacturers,
                otherOptions = context.otherManufacturers,
                onSelect = context.onSelectManufacturer,
            )
            if (context.catalogIsLoading) {
                AppInlineTaskStatus(text = "Loading catalog data…", showsProgress = true)
            } else {
                AppInlineTaskStatus(text = context.resultWindowLabel)
            }
            context.catalogErrorMessage?.let { errorMessage ->
                AppInlineTaskStatus(text = errorMessage, isError = true)
            }
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 260.dp)
                    .background(MaterialTheme.colorScheme.surfaceContainerLow, RoundedCornerShape(10.dp))
                    .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp)),
            ) {
                val resultsListState = rememberLazyListState()

                LaunchedEffect(
                    context.pendingResultRestoreTick,
                    context.pendingResultRestoreGameID,
                    context.displayedCatalogGames.map { it.catalogGameID },
                    context.hasPreviousFilteredResults,
                ) {
                    val targetGameID = context.pendingResultRestoreGameID ?: return@LaunchedEffect
                    val gameIndex = context.displayedCatalogGames.indexOfFirst { it.catalogGameID == targetGameID }
                    if (gameIndex >= 0) {
                        val targetIndex = gameIndex + if (context.hasPreviousFilteredResults) 1 else 0
                        resultsListState.scrollToItem(targetIndex)
                    }
                    context.onClearPendingResultRestoreGameID()
                }

                val resolveTopVisibleGameID: () -> String? = {
                    if (context.displayedCatalogGames.isEmpty()) {
                        null
                    } else {
                        val firstVisibleIndex = resultsListState.firstVisibleItemIndex
                        val gameStartIndex = if (context.hasPreviousFilteredResults) 1 else 0
                        val relativeGameIndex = firstVisibleIndex - gameStartIndex
                        when {
                            relativeGameIndex < 0 -> context.displayedCatalogGames.first().catalogGameID
                            relativeGameIndex >= context.displayedCatalogGames.size -> context.displayedCatalogGames.last().catalogGameID
                            else -> context.displayedCatalogGames[relativeGameIndex].catalogGameID
                        }
                    }
                }

                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(8.dp),
                    state = resultsListState,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    if (context.hasPreviousFilteredResults) {
                        item(key = "show_previous_25") {
                            TextButton(
                                onClick = { context.onShowPreviousResults(resolveTopVisibleGameID()) },
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text("Show Previous 25")
                            }
                        }
                    }

                    items(
                        items = context.displayedCatalogGames,
                        key = { it.catalogGameID },
                    ) { game ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(MaterialTheme.colorScheme.surfaceContainerHigh, RoundedCornerShape(8.dp))
                                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(8.dp))
                                .padding(horizontal = 10.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = game.displayTitle,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    fontWeight = FontWeight.Medium,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                Text(
                                    text = listOfNotNull(game.displayVariant, game.manufacturer, game.year?.toString()).joinToString(" • "),
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                            }
                            Button(onClick = { context.onAddMachine(game) }) {
                                Icon(
                                    imageVector = Icons.Outlined.Add,
                                    contentDescription = "Add machine",
                                )
                            }
                        }
                    }

                    if (context.hasNextFilteredResults) {
                        item(key = "show_next_25") {
                            TextButton(
                                onClick = { context.onShowNextResults(resolveTopVisibleGameID()) },
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text("Show Next 25")
                            }
                        }
                    }
                }
            }
        }
    }

    CardContainer {
        SectionHeader(
            title = "Areas",
            expanded = context.areasExpanded,
            onToggle = { context.onAreasExpandedChange(!context.areasExpanded) },
        )
        if (context.areasExpanded) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = context.areaNameDraft,
                    onValueChange = context.onAreaNameDraftChange,
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    label = { Text("Area Name") },
                )
                OutlinedTextField(
                    value = context.areaOrderDraft,
                    onValueChange = context.onAreaOrderDraftChange,
                    modifier = Modifier.width(120.dp),
                    singleLine = true,
                    label = { Text("Area Order") },
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = context.onSaveArea) { Text("Save") }
                Button(onClick = context.onResetAreaDraft) { Text("Edit") }
            }
            context.store.state.areas.forEach { area ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { context.onEditArea(area) }
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "${area.name} (${area.areaOrder})",
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(
                        onClick = { context.onDeleteArea(area.id) },
                        modifier = Modifier
                            .size(32.dp)
                            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(8.dp))
                            .clip(RoundedCornerShape(8.dp)),
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.Delete,
                            contentDescription = "Delete area",
                            tint = MaterialTheme.colorScheme.error,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }
            }
        }
    }

    CardContainer {
        SectionHeader(
            title = "Edit Machines (${context.store.activeMachines.size})",
            expanded = context.editMachinesExpanded,
            onToggle = { context.onEditMachinesExpandedChange(!context.editMachinesExpanded) },
        )
        if (context.editMachinesExpanded) {
            if (context.selectedEditMachine == null) {
                AnchoredDropdownFilter(
                    selectedText = "Select Machine",
                    options = context.allMachines.map { DropdownOption(value = it.id, label = it.displayTitle) },
                    onSelect = context.onSelectedEditMachineChange,
                )
            }
            if (context.selectedEditMachine != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    AnchoredDropdownFilter(
                        selectedText = context.selectedEditMachine.displayTitle,
                        options = context.allMachines.map { DropdownOption(value = it.id, label = it.displayTitle) },
                        onSelect = context.onSelectedEditMachineChange,
                        modifier = Modifier.weight(1f),
                    )
                    VariantPillDropdown(
                        selectedLabel = context.draftVariant,
                        options = context.variantOptions,
                        onSelect = context.onDraftVariantChange,
                        modifier = Modifier.weight(0.52f),
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AnchoredDropdownFilter(
                        selectedText = context.store.area(context.draftAreaID)?.name ?: "No area",
                        options = buildList {
                            add(DropdownOption(value = "", label = "No area"))
                            addAll(context.store.state.areas.map { DropdownOption(it.id, it.name) })
                        },
                        onSelect = { context.onDraftAreaIDChange(it.ifBlank { null }) },
                        modifier = Modifier.weight(1f),
                    )
                    AnchoredDropdownFilter(
                        selectedText = context.draftStatus.replaceFirstChar { it.uppercase() },
                        options = OwnedMachineStatus.entries.map {
                            DropdownOption(it.name, it.name.replaceFirstChar { ch -> ch.uppercase() })
                        },
                        onSelect = context.onDraftStatusChange,
                        modifier = Modifier.weight(1f),
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = context.draftGroup,
                        onValueChange = context.onDraftGroupChange,
                        label = { Text("Group") },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                    )
                    OutlinedTextField(
                        value = context.draftPosition,
                        onValueChange = context.onDraftPositionChange,
                        label = { Text("Position") },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                    )
                }
                OutlinedTextField(
                    value = context.draftPurchaseSource,
                    onValueChange = context.onDraftPurchaseSourceChange,
                    label = { Text("Purchase Source") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = context.draftSerialNumber,
                    onValueChange = context.onDraftSerialNumberChange,
                    label = { Text("Serial Number") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = context.draftOwnershipNotes,
                    onValueChange = context.onDraftOwnershipNotesChange,
                    label = { Text("Ownership Notes") },
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = context.onSaveMachine) { Text("Save") }
                    Button(onClick = context.onDeleteMachine) { Text("Delete") }
                    if (context.onArchiveMachine != null) {
                        Button(onClick = context.onArchiveMachine) { Text("Archive") }
                    }
                }
            }
        }
    }
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
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            GameRoomArchiveFilter.entries.forEachIndexed { index, filter ->
                SegmentedButton(
                    selected = archiveFilter == filter,
                    onClick = { onArchiveFilterChange(filter) },
                    colors = pinballSegmentedButtonColors(),
                    shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(
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
                                fontWeight = FontWeight.Medium,
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
                        androidx.compose.material3.Icon(
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
