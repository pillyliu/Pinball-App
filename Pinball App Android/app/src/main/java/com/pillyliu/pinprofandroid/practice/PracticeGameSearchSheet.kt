package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ExpandLess
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors

private enum class PracticeSearchTab(val label: String) {
    Search("Search"),
    Recent("Recent"),
}

@Composable
internal fun PracticeGameSearchSheet(
    games: List<PinballGame>,
    isLoadingGames: Boolean,
    onOpenGame: (String) -> Unit,
) {
    val context = LocalContext.current
    val prefs = remember(context) { practiceSharedPreferences(context) }

    var selectedTab by rememberSaveable { mutableStateOf(PracticeSearchTab.Search) }
    var nameQuery by rememberSaveable { mutableStateOf("") }
    var manufacturerQuery by rememberSaveable { mutableStateOf("") }
    var yearQuery by rememberSaveable { mutableStateOf("") }
    var selectedType by rememberSaveable { mutableStateOf<PracticeSearchTypeFilter?>(null) }
    var advancedExpanded by rememberSaveable { mutableStateOf(false) }
    var recentGameIds by rememberSaveable { mutableStateOf(loadPracticeSearchRecents(prefs)) }

    val searchIndex = remember(games) { buildPracticeSearchIndex(games) }
    val filters = remember(nameQuery, manufacturerQuery, yearQuery, selectedType) {
        PracticeSearchFilters(
            nameQuery = nameQuery,
            manufacturerQuery = manufacturerQuery,
            yearQuery = yearQuery,
            selectedType = selectedType,
        )
    }
    val manufacturerSuggestions = remember(searchIndex, manufacturerQuery) {
        searchIndex.manufacturerSuggestions(manufacturerQuery)
    }
    val filteredResults = remember(searchIndex, filters) {
        searchIndex.filteredResults(filters)
    }
    val recentResults = remember(searchIndex, recentGameIds) {
        searchIndex.recentResults(recentGameIds)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            PracticeSearchTab.entries.forEachIndexed { index, tab ->
                SegmentedButton(
                    selected = selectedTab == tab,
                    onClick = { selectedTab = tab },
                    colors = pinballSegmentedButtonColors(),
                    shape = SegmentedButtonDefaults.itemShape(index = index, count = PracticeSearchTab.entries.size),
                ) {
                    Text(tab.label)
                }
            }
        }

        if (selectedTab == PracticeSearchTab.Search) {
            CardContainer {
                OutlinedTextField(
                    value = nameQuery,
                    onValueChange = { nameQuery = it },
                    label = { Text("Game name") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
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
                        imageVector = if (advancedExpanded) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore,
                        contentDescription = null,
                    )
                }

                if (advancedExpanded) {
                    HorizontalDivider()

                    OutlinedTextField(
                        value = manufacturerQuery,
                        onValueChange = { manufacturerQuery = it },
                        label = { Text("Manufacturer") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
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
                        onValueChange = { updated ->
                            yearQuery = updated.filter { it.isDigit() }.take(4)
                        },
                        label = { Text("Year") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                    )

                    PracticeSearchTypeDropdown(
                        selectedType = selectedType,
                        onTypeSelected = { selectedType = it },
                    )

                    if (filters.hasFilters) {
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
            }
        }

        Box(modifier = Modifier.fillMaxSize()) {
            when (selectedTab) {
                PracticeSearchTab.Search -> {
                    if (isLoadingGames && searchIndex.results.isEmpty()) {
                        AppPanelEmptyCard(
                            text = "Loading all OPDB games…",
                        )
                    } else if (!filters.hasFilters) {
                        AppPanelEmptyCard(
                            text = "Search by name or abbreviation. Open Advanced Filters for manufacturer, year, and game type.",
                        )
                    } else {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            items(filteredResults, key = { it.canonicalGameId }) { result ->
                                PracticeSearchResultCard(
                                    result = result,
                                    metaLine = searchIndex.metaLine(result),
                                    onClick = {
                                        recentGameIds = rememberPracticeSearchRecent(prefs, result.canonicalGameId)
                                        onOpenGame(result.canonicalGameId)
                                    },
                                )
                            }
                        }
                    }
                }

                PracticeSearchTab.Recent -> {
                    if (recentResults.isEmpty()) {
                        AppPanelEmptyCard(text = "Games opened from search will show up here.")
                    } else {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            items(recentResults, key = { it.canonicalGameId }) { result ->
                                PracticeSearchResultCard(
                                    result = result,
                                    metaLine = searchIndex.metaLine(result),
                                    onClick = {
                                        recentGameIds = rememberPracticeSearchRecent(prefs, result.canonicalGameId)
                                        onOpenGame(result.canonicalGameId)
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PracticeSearchTypeDropdown(
    selectedType: PracticeSearchTypeFilter?,
    onTypeSelected: (PracticeSearchTypeFilter?) -> Unit,
) {
    val options = remember {
        listOf(DropdownOption(value = "", label = "Any type")) +
            PracticeSearchTypeFilter.entries.map { DropdownOption(value = it.rawValue, label = it.label) }
    }
    AnchoredDropdownFilter(
        selectedText = selectedType?.label ?: "Any type",
        options = options,
        onSelect = { raw ->
            onTypeSelected(PracticeSearchTypeFilter.entries.firstOrNull { it.rawValue == raw })
        },
        label = "Game type",
    )
}

@Composable
private fun PracticeSearchResultCard(
    result: PracticeSearchResult,
    metaLine: String,
    onClick: () -> Unit,
) {
    CardContainer(
        modifier = Modifier.clickable(onClick = onClick),
    ) {
        Text(
            text = result.displayName,
            fontWeight = FontWeight.SemiBold,
            color = PinballThemeTokens.colors.brandInk,
        )
        Text(
            text = metaLine,
            color = PinballThemeTokens.colors.brandChalk,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
