package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppCardTitle
import com.pillyliu.pinprofandroid.ui.AppControlCard
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSelectionPill
import com.pillyliu.pinprofandroid.ui.DropdownOption

@Composable
internal fun GameRoomImportReviewContent(
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    importRows: List<ImportDraftRow>,
    importReviewFilter: ImportReviewFilter,
    onImportReviewFilterChange: (ImportReviewFilter) -> Unit,
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

    AppCardSubheading(text = "Review matches (${importRows.size})")
    GameRoomImportReviewFilterRow(
        importReviewFilter = importReviewFilter,
        onImportReviewFilterChange = onImportReviewFilterChange,
    )
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        filteredImportRows.forEach { row ->
            GameRoomImportReviewRowCard(
                row = row,
                store = store,
                catalogLoader = catalogLoader,
                onUpdateImportPurchaseDate = onUpdateImportPurchaseDate,
                onUpdateImportMatch = onUpdateImportMatch,
                onUpdateImportVariant = onUpdateImportVariant,
            )
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

@Composable
private fun GameRoomImportReviewFilterRow(
    importReviewFilter: ImportReviewFilter,
    onImportReviewFilterChange: (ImportReviewFilter) -> Unit,
) {
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
}

@Composable
private fun GameRoomImportReviewRowCard(
    row: ImportDraftRow,
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
    onUpdateImportPurchaseDate: (String, String) -> Unit,
    onUpdateImportMatch: (String, String?) -> Unit,
    onUpdateImportVariant: (String, String?) -> Unit,
) {
    val duplicateWarning = duplicateWarningMessage(row, store, catalogLoader)

    AppControlCard {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
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
