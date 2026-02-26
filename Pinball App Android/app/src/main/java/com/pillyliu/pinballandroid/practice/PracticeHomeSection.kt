package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.library.LibrarySource
import com.pillyliu.pinballandroid.ui.CardContainer

private const val PRACTICE_HOME_ALL_GAMES_SOURCE_ID = "__practice_home_all_games__"

@Composable
internal fun PracticeHomeSection(
    store: PracticeStore,
    resumeOtherExpanded: Boolean,
    onResumeOtherExpandedChange: (Boolean) -> Unit,
    librarySources: List<LibrarySource>,
    selectedLibrarySourceId: String?,
    onSelectLibrarySourceId: (String) -> Unit,
    onOpenGame: (String) -> Unit,
    onOpenQuickEntry: (QuickActivity, QuickEntryOrigin) -> Unit,
    onOpenGroupDashboard: () -> Unit,
    onOpenJournal: () -> Unit,
    onOpenInsights: () -> Unit,
    onOpenMechanics: () -> Unit,
) {
    val orderedGames = orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true)
    CardContainer {
        HomeSectionTitle("Resume")
        val resumeSlug = store.resumeSlugFromLibraryOrPractice()
        val resumeGame = findGameByPracticeLookupKey(orderedGames, resumeSlug) ?: orderedGames.firstOrNull()
        if (resumeGame != null) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                OutlinedButton(
                    onClick = { onOpenGame(resumeGame.practiceKey) },
                    modifier = Modifier.weight(1f),
                ) {
                    Text(resumeGame.name, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Box {
                    OutlinedButton(onClick = { onResumeOtherExpandedChange(true) }) {
                        Text("Game List", maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    DropdownMenu(
                        expanded = resumeOtherExpanded,
                        onDismissRequest = { onResumeOtherExpandedChange(false) },
                    ) {
                        if (librarySources.size > 1) {
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        (if (selectedLibrarySourceId == null) "✓ " else "") + "All games",
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                },
                                onClick = {
                                    onSelectLibrarySourceId(PRACTICE_HOME_ALL_GAMES_SOURCE_ID)
                                },
                            )
                            librarySources.forEach { source ->
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            (if (source.id == selectedLibrarySourceId) "✓ " else "") + source.name,
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis,
                                        )
                                    },
                                    onClick = {
                                        onSelectLibrarySourceId(source.id)
                                    },
                                )
                            }
                            HorizontalDivider()
                        }
                        orderedGames.forEach { listGame ->
                            DropdownMenuItem(
                                text = { Text(listGame.name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                                onClick = {
                                    onResumeOtherExpandedChange(false)
                                    onOpenGame(listGame.practiceKey)
                                },
                            )
                        }
                    }
                }
            }
        }
    }

    CardContainer {
        HomeSectionTitle("Quick Entry")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            QuickEntryHomeButton(label = "Score", modifier = Modifier.weight(1f), onClick = {
                onOpenQuickEntry(QuickActivity.Score, QuickEntryOrigin.Score)
            })
            QuickEntryHomeButton(label = "Study", modifier = Modifier.weight(1f), onClick = {
                onOpenQuickEntry(QuickActivity.Rulesheet, QuickEntryOrigin.Study)
            })
            QuickEntryHomeButton(label = "Practice", modifier = Modifier.weight(1f), onClick = {
                onOpenQuickEntry(QuickActivity.Practice, QuickEntryOrigin.Practice)
            })
            QuickEntryHomeButton(label = "Mechanics", modifier = Modifier.weight(1f), onClick = {
                onOpenQuickEntry(QuickActivity.Mechanics, QuickEntryOrigin.Mechanics)
            })
        }
    }

    CardContainer {
        HomeSectionTitle("Active Groups")
        val active = store.activeGroups()
        if (active.isEmpty()) {
            Text("No active groups", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            active.forEach { group ->
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(group.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                    if (group.id == store.selectedGroup()?.id) {
                        Text(
                            "Selected",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier
                                .background(
                                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.8f),
                                    shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
                                )
                                .padding(horizontal = 6.dp, vertical = 3.dp),
                        )
                    }
                }
                val games = store.groupGames(group)
                if (games.isEmpty()) {
                    Text(
                        "No games in this group.",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                } else {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.horizontalScroll(rememberScrollState()),
                    ) {
                        games.forEach { game ->
                            Box(
                                modifier = Modifier
                                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
                                    .clickable { onOpenGame(game.practiceKey) },
                            ) {
                                SelectedGameMiniCard(game = game)
                            }
                        }
                    }
                }
                Spacer(Modifier.height(6.dp))
            }
        }
    }

    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        HomeMiniCard(
            label = "Group Dashboard",
            subtitle = "Focus set, suggested game, and per-game progress",
            modifier = Modifier.weight(1f),
        ) { onOpenGroupDashboard() }
        HomeMiniCard(
            label = "Journal Timeline",
            subtitle = "Full app activity history",
            modifier = Modifier.weight(1f),
        ) { onOpenJournal() }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        HomeMiniCard(
            label = "Insights",
            subtitle = "Scores, variance, and trend context",
            modifier = Modifier.weight(1f),
        ) { onOpenInsights() }
        HomeMiniCard(
            label = "Mechanics",
            subtitle = "Track transferable pinball skill practice",
            modifier = Modifier.weight(1f),
        ) { onOpenMechanics() }
    }
}
