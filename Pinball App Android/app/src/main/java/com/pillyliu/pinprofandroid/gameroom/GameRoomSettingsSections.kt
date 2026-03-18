package com.pillyliu.pinprofandroid.gameroom
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.ui.draw.clip
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppCardTitle
import com.pillyliu.pinprofandroid.ui.AppControlCard
import com.pillyliu.pinprofandroid.ui.AppCompactIconButton
import com.pillyliu.pinprofandroid.ui.AppDestructiveButton
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.AppSelectionPill
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.DropdownOptionGroup
import com.pillyliu.pinprofandroid.ui.GroupedAnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.SectionTitle
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors
import kotlin.math.max

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
        AppCardSubheading(text = "Review matches (${importRows.size})")
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
                AppControlCard {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            AppCardTitle(
                                text = row.rawTitle,
                                maxLines = 1,
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
                                catalogLoader.game(selectedID)?.let(::importSuggestionLabel)
                            } ?: "No Match Selected",
                            options = buildList {
                                row.suggestions.forEach { suggestionID ->
                                    val suggestion = catalogLoader.game(suggestionID) ?: return@forEach
                                    add(
                                        DropdownOption(
                                            value = suggestion.catalogGameID,
                                            label = importSuggestionLabel(suggestion),
                                        ),
                                    )
                                }
                                add(DropdownOption(value = "__none__", label = "No Match Selected"))
                            },
                            onSelect = { selection ->
                                onUpdateImportMatch(row.id, selection.takeUnless { it == "__none__" })
                            },
                        )
                        val selectedCatalogID = row.selectedCatalogGameID
                        if (!selectedCatalogID.isNullOrBlank()) {
                            val variants = importVariantOptions(row, catalogLoader)
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
        AppPrimaryButton(
            onClick = onPerformImport,
            modifier = Modifier.fillMaxWidth(),
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
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                AppPrimaryButton(
                    onClick = {
                        context.onSaveVenueName()
                        context.onShowSaveFeedback("GameRoom name saved")
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
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
            var nameQuery by rememberSaveable { mutableStateOf("") }
            var manufacturerQuery by rememberSaveable { mutableStateOf("") }
            var yearQuery by rememberSaveable { mutableStateOf("") }
            var selectedType by rememberSaveable { mutableStateOf<GameRoomAddMachineTypeFilter?>(null) }
            var advancedExpanded by rememberSaveable { mutableStateOf(false) }
            var pendingVariantCatalogGameID by rememberSaveable { mutableStateOf<String?>(null) }
            var pendingVariantTitle by rememberSaveable { mutableStateOf("") }
            var pendingVariantOptions by rememberSaveable { mutableStateOf<List<String>>(emptyList()) }

            val manufacturerOptions = remember(context.catalogLoader.manufacturerOptions) {
                context.catalogLoader.manufacturerOptions.map { it.name }
            }
            val manufacturerSuggestions = remember(manufacturerOptions, manufacturerQuery) {
                gameRoomManufacturerSuggestions(manufacturerOptions, manufacturerQuery)
            }
            val hasSearchFilters = nameQuery.trim().isNotEmpty() ||
                manufacturerQuery.trim().isNotEmpty() ||
                yearQuery.trim().isNotEmpty() ||
                selectedType != null
            val catalogSearchEntries = remember(
                context.catalogLoader.games,
                context.catalogLoader.variantOptionsByCatalogGameID,
            ) {
                buildGameRoomCatalogSearchEntries(
                    games = context.catalogLoader.games,
                    variantOptions = context.catalogLoader::variantOptions,
                )
            }
            val filteredCatalogGames = remember(
                catalogSearchEntries,
                nameQuery,
                manufacturerQuery,
                yearQuery,
                selectedType,
            ) {
                filterGameRoomCatalogGames(
                    entries = catalogSearchEntries,
                    nameQuery = nameQuery,
                    manufacturerQuery = manufacturerQuery,
                    yearQuery = yearQuery,
                    selectedType = selectedType,
                )
            }

            fun clearPendingVariantPicker() {
                pendingVariantCatalogGameID = null
                pendingVariantTitle = ""
                pendingVariantOptions = emptyList()
            }

            fun completeAddSelection(catalogGameID: String?, variant: String?) {
                val resolvedGame = catalogGameID?.let { context.catalogLoader.game(it, variant) }
                if (resolvedGame == null) {
                    clearPendingVariantPicker()
                    return
                }
                val resolvedVariant = variant?.trim()?.ifBlank { null } ?: resolvedGame.displayVariant
                val existing = context.store.existingOwnedMachine(resolvedGame.catalogGameID, resolvedVariant)
                if (existing != null) {
                    val label = existing.displayVariant?.let { "${existing.displayTitle} ($it)" } ?: existing.displayTitle
                    context.onShowSaveFeedback("$label is already in GameRoom")
                    clearPendingVariantPicker()
                    return
                }

                val machineID = context.store.addOwnedMachine(
                    catalogGameID = resolvedGame.catalogGameID,
                    canonicalPracticeIdentity = resolvedGame.canonicalPracticeIdentity,
                    displayTitle = resolvedGame.displayTitle,
                    displayVariant = resolvedVariant,
                    manufacturer = resolvedGame.manufacturer,
                    year = resolvedGame.year,
                )
                context.onSelectedEditMachineChange(machineID)
                context.onShowSaveFeedback(
                    resolvedVariant?.let { "Added ${resolvedGame.displayTitle} ($it)" } ?: "Added ${resolvedGame.displayTitle}",
                )
                clearPendingVariantPicker()
            }

            fun beginAddSelection(game: GameRoomCatalogGame) {
                val variants = context.catalogLoader.variantOptions(game.catalogGameID).distinct()
                if (variants.size > 1) {
                    pendingVariantCatalogGameID = game.catalogGameID
                    pendingVariantTitle = game.displayTitle
                    pendingVariantOptions = variants
                } else {
                    completeAddSelection(game.catalogGameID, variants.firstOrNull())
                }
            }

            OutlinedTextField(
                value = nameQuery,
                onValueChange = { nameQuery = it },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("Game name") },
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { advancedExpanded = !advancedExpanded },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Advanced Filters",
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    imageVector = Icons.Outlined.ChevronRight,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
            }

            if (advancedExpanded) {
                OutlinedTextField(
                    value = manufacturerQuery,
                    onValueChange = { manufacturerQuery = it },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("Manufacturer") },
                )

                if (manufacturerSuggestions.isNotEmpty() &&
                    manufacturerSuggestions.none { it.equals(manufacturerQuery.trim(), ignoreCase = true) }) {
                    Row(
                        modifier = Modifier.horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        manufacturerSuggestions.forEach { suggestion ->
                            AppSecondaryButton(onClick = { manufacturerQuery = suggestion }) {
                                Text(suggestion, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                        }
                    }
                }

                OutlinedTextField(
                    value = yearQuery,
                    onValueChange = { updated -> yearQuery = updated.filter { it.isDigit() }.take(4) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text("Year") },
                )

                AnchoredDropdownFilter(
                    selectedText = selectedType?.label ?: "Any type",
                    options = listOf(DropdownOption(value = "", label = "Any type")) +
                        GameRoomAddMachineTypeFilter.entries.map { DropdownOption(it.rawValue, it.label) },
                    onSelect = { raw ->
                        selectedType = GameRoomAddMachineTypeFilter.entries.firstOrNull { it.rawValue == raw }
                    },
                    label = "Game type",
                )

                if (hasSearchFilters) {
                    AppSecondaryButton(
                        onClick = {
                            nameQuery = ""
                            manufacturerQuery = ""
                            yearQuery = ""
                            selectedType = null
                        },
                    ) {
                        Text("Clear filters")
                    }
                }
            }

            context.catalogErrorMessage?.let { errorMessage ->
                AppInlineTaskStatus(text = errorMessage, isError = true)
            }

            if (context.catalogIsLoading) {
                AppInlineTaskStatus(text = "Loading catalog data…", showsProgress = true)
            } else if (!hasSearchFilters) {
                AppPanelEmptyCard(text = "Search by game name, shortname, or common name. Open Advanced Filters for manufacturer, year, and game type.")
            } else {
                AppInlineTaskStatus(text = "${filteredCatalogGames.size} matches")
                if (filteredCatalogGames.isEmpty()) {
                    AppPanelEmptyCard(
                        text = "No titles match the current search.",
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 260.dp)
                            .background(MaterialTheme.colorScheme.surfaceContainerLow, RoundedCornerShape(10.dp))
                            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(10.dp)),
                    ) {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(8.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            items(
                                items = filteredCatalogGames,
                                key = { it.catalogGameID },
                            ) { game ->
                                AppControlCard {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
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
                                                text = listOfNotNull(
                                                    game.manufacturer?.takeUnless { it.equals("null", ignoreCase = true) || it.isBlank() },
                                                    game.year?.toString(),
                                                ).joinToString(" • "),
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis,
                                            )
                                        }
                                        AppSecondaryButton(onClick = { beginAddSelection(game) }) {
                                            Icon(
                                                imageVector = Icons.Outlined.Add,
                                                contentDescription = "Add machine",
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if (pendingVariantCatalogGameID != null && pendingVariantOptions.isNotEmpty()) {
                AlertDialog(
                    onDismissRequest = { clearPendingVariantPicker() },
                    title = { Text("Choose Variant") },
                    text = {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Choose the variant for $pendingVariantTitle.")
                            pendingVariantOptions.forEach { option ->
                                AppSecondaryButton(
                                    onClick = { completeAddSelection(pendingVariantCatalogGameID, option) },
                                    modifier = Modifier.fillMaxWidth(),
                                ) {
                                    Text(option)
                                }
                            }
                        }
                    },
                    confirmButton = {},
                    dismissButton = {
                        TextButton(onClick = { clearPendingVariantPicker() }) {
                            Text("Cancel")
                        }
                    },
                )
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
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                AppPrimaryButton(
                    onClick = {
                        context.onSaveArea()
                        context.onShowSaveFeedback("Area saved")
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Save") }
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
                    AppCompactIconButton(
                        icon = Icons.Outlined.Delete,
                        contentDescription = "Delete area",
                        onClick = {
                            context.onDeleteArea(area.id)
                            context.onShowSaveFeedback("Area deleted")
                        },
                        destructive = true,
                    )
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
            val machineGroups = context.allMachines
                .groupBy { machine -> context.store.area(machine.gameRoomAreaID)?.name ?: "No Area" }
                .toSortedMap(String.CASE_INSENSITIVE_ORDER)
                .map { (title, machines) ->
                    DropdownOptionGroup(
                        title = title,
                        options = machines.sortedWith(
                            compareBy<OwnedMachine> { it.displayTitle.lowercase() }
                                .thenBy { it.id },
                        ).map { machine ->
                            DropdownOption(
                                value = machine.id,
                                label = editMachineLabel(machine),
                            )
                        },
                    )
                }
            if (context.selectedEditMachine == null) {
                GroupedAnchoredDropdownFilter(
                    selectedText = "Select Machine",
                    groups = machineGroups,
                    onSelect = context.onSelectedEditMachineChange,
                )
            }
            if (context.selectedEditMachine != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    GroupedAnchoredDropdownFilter(
                        selectedText = editMachineLabel(context.selectedEditMachine),
                        groups = machineGroups,
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
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    AppPrimaryButton(
                        onClick = {
                            context.onSaveMachine()
                            context.onShowSaveFeedback("Machine details saved")
                        },
                        modifier = Modifier.weight(1f),
                    ) { Text("Save") }
                    AppDestructiveButton(
                        onClick = {
                            context.onDeleteMachine()
                            context.onShowSaveFeedback("Machine deleted")
                        },
                        modifier = Modifier.weight(1f),
                    ) { Text("Delete") }
                    if (context.onArchiveMachine != null) {
                        AppSecondaryButton(
                            onClick = {
                                context.onArchiveMachine.invoke()
                                context.onShowSaveFeedback("Machine archived")
                            },
                            modifier = Modifier.weight(1f),
                        ) { Text("Archive") }
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
        SectionTitle("Machine Archive")
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            GameRoomArchiveFilter.entries.forEachIndexed { index, filter ->
                SegmentedButton(
                    selected = archiveFilter == filter,
                    onClick = { onArchiveFilterChange(filter) },
                    colors = pinballSegmentedButtonColors(),
                    icon = {},
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

private fun editMachineLabel(machine: OwnedMachine): String {
    return if (machine.status == OwnedMachineStatus.active) {
        machine.displayTitle
    } else {
        "${machine.displayTitle} (${machine.status.name.replaceFirstChar { it.uppercase() }})"
    }
}
