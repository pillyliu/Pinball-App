package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.data.redactPlayerNameForDisplay
import com.pillyliu.pinballandroid.ui.CardContainer

@Composable
internal fun PracticeInsightsSection(
    store: PracticeStore,
    selectedGameSlug: String?,
    onSelectGameSlug: (String) -> Unit,
    insightsOpponentName: String,
    insightsOpponentOptions: List<String>,
    onInsightsOpponentNameChange: (String) -> Unit,
    headToHead: HeadToHeadComparison?,
    isLoadingHeadToHead: Boolean,
    onRefreshHeadToHead: () -> Unit,
) {
    val orderedGames = orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true)
    val game = selectedGameSlug?.let { slug ->
        findGameByPracticeLookupKey(orderedGames, slug)
    } ?: orderedGames.firstOrNull()?.also { onSelectGameSlug(it.practiceKey) }

    if (game == null) {
        Text("No game data.")
        return
    }

    val availableSources = store.librarySources
    var gamePickerExpanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(
            onClick = { gamePickerExpanded = true },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = store.gameName(game.practiceKey),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Text("▼", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        DropdownMenu(
            expanded = gamePickerExpanded,
            onDismissRequest = { gamePickerExpanded = false },
        ) {
            if (availableSources.size > 1) {
                DropdownMenuItem(
                    text = {
                        Text(
                            (if (store.defaultPracticeSourceId == null) "✓ " else "") + "All games",
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    },
                    onClick = {
                        store.setPreferredLibrarySource(null)
                    },
                )
                availableSources.forEach { source ->
                    DropdownMenuItem(
                        text = {
                            Text(
                                (if (source.id == store.defaultPracticeSourceId) "✓ " else "") + source.name,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        },
                        onClick = {
                            store.setPreferredLibrarySource(source.id)
                        },
                    )
                }
                HorizontalDivider()
            }
            orderedGames.forEach { insightsGame ->
                DropdownMenuItem(
                    text = { Text(insightsGame.name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                    onClick = {
                        gamePickerExpanded = false
                        onSelectGameSlug(insightsGame.practiceKey)
                    },
                )
            }
        }
    }
    CardContainer {
        Text("Stats", fontWeight = FontWeight.SemiBold)
        val summary = store.scoreSummaryFor(game.practiceKey)
        val trendValues = store.scoreTrendValues(game.practiceKey)
        if (summary == null) {
            Text("Log scores to unlock trends and consistency analytics.")
        } else {
            StatRow("Average", formatScore(summary.mean))
            StatRow("Median", formatScore(summary.median))
            StatRow("Floor", formatScore(summary.low))
            Text(
                "IQR: ${formatScore(summary.p25)} to ${formatScore(summary.targetHigh)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                "Mode: Shows raw calendar spacing between score entries.",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            ScoreTrendSparkline(values = trendValues)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                val spreadRatio = if (summary.median <= 0) 1.0 else (summary.targetHigh - summary.targetFloor) / summary.median
                DashboardMetricPill(
                    label = "Consistency",
                    value = if (spreadRatio >= 0.6) "High Risk" else "Stable",
                    modifier = Modifier.weight(1f),
                )
                DashboardMetricPill(
                    label = "Floor",
                    value = formatScore(summary.low),
                    modifier = Modifier.weight(1f),
                )
                DashboardMetricPill(
                    label = "Median",
                    value = formatScore(summary.median),
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }

    CardContainer {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Head-to-Head", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            TextButton(
                onClick = onRefreshHeadToHead,
                enabled = !isLoadingHeadToHead,
            ) { Text("Refresh") }
        }

        InsightsMenuDropdown(
            selectedLabel = if (insightsOpponentName.isBlank()) {
                "Select player"
            } else {
                redactPlayerNameForDisplay(insightsOpponentName)
            },
            options = listOf("" to "Select player") + insightsOpponentOptions.map { it to redactPlayerNameForDisplay(it) },
            onSelect = { pair ->
                onInsightsOpponentNameChange(pair.first)
            },
        )

        when {
            isLoadingHeadToHead -> Text("Loading player comparison...", style = MaterialTheme.typography.bodySmall)
            insightsOpponentName.isBlank() -> Text("Select a player above to enable player-vs-player views.", style = MaterialTheme.typography.bodySmall)
            headToHead == null -> Text(
                "No shared machine history yet between ${if (store.playerName.isBlank()) "you" else redactPlayerNameForDisplay(store.playerName)} and ${redactPlayerNameForDisplay(insightsOpponentName)}.",
                style = MaterialTheme.typography.bodySmall,
            )

            else -> {
                val comparison = headToHead
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    DashboardMetricPill(
                        label = "Games",
                        value = "${comparison.totalGamesCompared}",
                        modifier = Modifier.weight(1f),
                    )
                    DashboardMetricPill(
                        label = "You Lead",
                        value = "${comparison.gamesYouLeadByMean}",
                        modifier = Modifier.weight(1f),
                    )
                    DashboardMetricPill(
                        label = "Avg Delta",
                        value = shortSignedDelta(comparison.averageMeanDelta),
                        modifier = Modifier.weight(1f),
                    )
                }
                comparison.games.take(8).forEach { entry ->
                    HeadToHeadGameRow(entry)
                }
                if (comparison.games.size > 8) {
                    Text("Showing top 8 by mean delta.", style = MaterialTheme.typography.labelSmall)
                }
                val chartGames = comparison.games.take(8)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.22f)),
                )
                HeadToHeadDeltaBars(
                    chartGames,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(headToHeadPlotHeight(chartGames.size)),
                )
            }
        }
    }
}
