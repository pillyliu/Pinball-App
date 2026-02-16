package com.pillyliu.pinballandroid.practice

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
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.library.PinballGame
import com.pillyliu.pinballandroid.ui.CardContainer
import java.util.Locale

@Composable
internal fun GroupGameSelectionScreen(
    games: List<PinballGame>,
    selectedSlugs: SnapshotStateList<String>,
    searchText: String,
    onSearchChange: (String) -> Unit,
    onDone: () -> Unit,
) {
    val filteredGames = remember(games, searchText) {
        games
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
                    items(gamesInSection, key = { it.slug }) { game ->
                        val checked = selectedSlugs.contains(game.slug)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(game.name, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Checkbox(
                                checked = checked,
                                onCheckedChange = { enabled ->
                                    if (enabled && !selectedSlugs.contains(game.slug)) selectedSlugs.add(game.slug)
                                    if (!enabled) selectedSlugs.remove(game.slug)
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}
