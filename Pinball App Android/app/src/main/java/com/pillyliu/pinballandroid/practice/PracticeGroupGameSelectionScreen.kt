package com.pillyliu.pinballandroid.practice

import androidx.core.content.edit
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext
import com.pillyliu.pinballandroid.library.PinballGame
import com.pillyliu.pinballandroid.library.LibrarySource
import com.pillyliu.pinballandroid.ui.CardContainer
import java.util.Locale

private const val GROUP_ALL_GAMES_LIBRARY_OPTION = "__all_games__"
private const val GROUP_PICKER_LIBRARY_KEY = "practice-group-picker-library-source-id"

@Composable
internal fun GroupGameSelectionScreen(
    games: List<PinballGame>,
    allGames: List<PinballGame>,
    librarySources: List<LibrarySource>,
    defaultSourceId: String?,
    selectedSlugs: SnapshotStateList<String>,
    searchText: String,
    onSearchChange: (String) -> Unit,
    onDone: () -> Unit,
) {
    val context = LocalContext.current
    val prefs = remember { practiceSharedPreferences(context) }
    val sourceOptions = remember(librarySources, allGames) {
        if (librarySources.isNotEmpty()) librarySources else {
            allGames.groupBy { it.sourceId }.values.mapNotNull { rows -> rows.firstOrNull()?.let { first ->
                LibrarySource(first.sourceId, first.sourceName, first.sourceType)
            } }
        }
    }
    var selectedLibraryOption by remember(sourceOptions, defaultSourceId) {
        val saved = prefs.getString(GROUP_PICKER_LIBRARY_KEY, null)
        mutableStateOf(
            saved?.takeIf { id -> id == GROUP_ALL_GAMES_LIBRARY_OPTION || sourceOptions.any { it.id == id } }
                ?: defaultSourceId
                ?: sourceOptions.firstOrNull()?.id
                ?: GROUP_ALL_GAMES_LIBRARY_OPTION
        )
    }
    val showLibraryDropdown = sourceOptions.size > 1
    LaunchedEffect(showLibraryDropdown) {
        if (!showLibraryDropdown) {
            selectedLibraryOption = defaultSourceId ?: sourceOptions.firstOrNull()?.id ?: GROUP_ALL_GAMES_LIBRARY_OPTION
        }
    }
    LaunchedEffect(selectedLibraryOption) {
        if (selectedLibraryOption.isBlank()) return@LaunchedEffect
        prefs.edit { putString(GROUP_PICKER_LIBRARY_KEY, selectedLibraryOption) }
    }
    val selectablePool = remember(games, allGames, selectedLibraryOption) {
        val pool = if (allGames.isNotEmpty()) allGames else games
        val filtered = if (selectedLibraryOption == GROUP_ALL_GAMES_LIBRARY_OPTION) {
            pool
        } else {
            pool.filter { it.sourceId == selectedLibraryOption }
        }
        distinctGamesByPracticeIdentity(filtered)
    }
    val filteredGames = remember(selectablePool, searchText) {
        selectablePool
            .filter { searchText.isBlank() || it.name.contains(searchText, ignoreCase = true) }
            .sortedBy { it.name.lowercase(Locale.US) }
    }
    val groupedGames = remember(filteredGames) {
        filteredGames.groupBy { game ->
            game.name.firstOrNull()?.uppercaseChar()?.toString() ?: "#"
        }.toSortedMap()
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        CardContainer {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Select Titles", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                TextButton(onClick = onDone) { Text("Done") }
            }
        }
        CardContainer {
            if (showLibraryDropdown) {
                SimpleMenuDropdown(
                    title = "Library",
                    options = listOf(GROUP_ALL_GAMES_LIBRARY_OPTION) + sourceOptions.map { it.id },
                    selected = selectedLibraryOption,
                    selectedLabel = when (selectedLibraryOption) {
                        GROUP_ALL_GAMES_LIBRARY_OPTION -> "All games"
                        else -> sourceOptions.firstOrNull { it.id == selectedLibraryOption }?.name ?: selectedLibraryOption
                    },
                    onSelect = { selectedLibraryOption = it },
                    formatOptionLabel = { option ->
                        when (option) {
                            GROUP_ALL_GAMES_LIBRARY_OPTION -> "All games"
                            else -> sourceOptions.firstOrNull { it.id == option }?.name ?: option
                        }
                    },
                )
            }
            OutlinedTextField(
                value = searchText,
                onValueChange = onSearchChange,
                label = { Text("Search titles") },
                modifier = Modifier.fillMaxWidth(),
            )
            LazyColumn(modifier = Modifier.height(420.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                groupedGames.forEach { (letter, gamesInSection) ->
                    item(key = "section-$letter") {
                        Text(letter, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    items(gamesInSection, key = { it.practiceKey }) { game ->
                        val checked = selectedSlugs.contains(game.practiceKey)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(game.name, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Checkbox(
                                checked = checked,
                                onCheckedChange = { enabled ->
                                    if (enabled && !selectedSlugs.contains(game.practiceKey)) selectedSlugs.add(game.practiceKey)
                                    if (!enabled) selectedSlugs.remove(game.practiceKey)
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}
