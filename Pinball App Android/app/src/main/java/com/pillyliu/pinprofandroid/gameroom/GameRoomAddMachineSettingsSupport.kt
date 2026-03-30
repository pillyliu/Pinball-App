package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppControlCard
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption

@Composable
@OptIn(ExperimentalMaterial3Api::class)
internal fun GameRoomAddMachineSettingsCard(
    context: GameRoomEditSettingsContext,
) {
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
                    opdbID = resolvedGame.opdbID,
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
                AppPanelEmptyCard(text = "Search by name or abbreviation. Open Advanced Filters for manufacturer, year, and game type.")
            } else {
                AppInlineTaskStatus(text = "${filteredCatalogGames.size} matches")
                if (filteredCatalogGames.isEmpty()) {
                    AppPanelEmptyCard(text = "No titles match the current search.")
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
}
