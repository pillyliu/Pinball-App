package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption

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
    if (importErrorMessage != null) {
        Text(
            text = importErrorMessage,
            color = Color(0xFFD14F4F),
        )
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
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .background(
                            if (selected) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceContainerHigh,
                            RoundedCornerShape(999.dp),
                        )
                        .border(
                            width = 1.dp,
                            color = if (selected) MaterialTheme.colorScheme.outline else MaterialTheme.colorScheme.outlineVariant,
                            shape = RoundedCornerShape(999.dp),
                        )
                        .clickable { onImportReviewFilterChange(filter) }
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    Text(
                        text = filter.label,
                        color = MaterialTheme.colorScheme.onSurface,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                    )
                }
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
                    shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(
                        index = index,
                        count = GameRoomArchiveFilter.entries.size,
                    ),
                    label = { Text(filter.label, maxLines = 1) },
                )
            }
        }

        if (filteredArchivedMachines.isEmpty()) {
            Text(
                text = "No archived machines for this filter.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
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
