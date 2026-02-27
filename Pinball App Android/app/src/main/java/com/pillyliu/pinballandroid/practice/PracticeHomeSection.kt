package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.Build
import androidx.compose.material.icons.outlined.Dashboard
import androidx.compose.material.icons.outlined.Insights
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material.icons.outlined.Tag
import androidx.compose.material.icons.outlined.Timeline
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.platform.LocalDensity
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
    var resumeLibraryExpanded by rememberSaveable { mutableStateOf(false) }
    var resumeControlColumnHeightPx by rememberSaveable { mutableStateOf(0) }
    val density = LocalDensity.current
    CardContainer {
        val resumeSlug = store.resumeSlugFromLibraryOrPractice()
        val resumeGame = findGameByPracticeLookupKey(orderedGames, resumeSlug) ?: orderedGames.firstOrNull()
        val selectedLibraryLabel = librarySources.firstOrNull { it.id == selectedLibrarySourceId }?.name ?: "All games"
        if (resumeGame != null) {
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
                        .clickable { onOpenGame(resumeGame.practiceKey) },
                ) {
                    SelectedGameMiniCard(
                        game = resumeGame,
                        modifier = if (resumeControlColumnHeightPx > 0) {
                            Modifier.height(with(density) { resumeControlColumnHeightPx.toDp() })
                        } else {
                            Modifier
                        },
                        cardWidth = 184.dp,
                        imageHeight = if (resumeControlColumnHeightPx > 0) null else 56.dp,
                        titleTextStyle = MaterialTheme.typography.titleSmall,
                    )
                }
                Column(
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .width(168.dp)
                        .onSizeChanged { size ->
                            if (size.height > 0) {
                                resumeControlColumnHeightPx = size.height
                            }
                        },
                ) {
                    Box {
                        ResumeDropdownButton(
                            title = "Library",
                            value = selectedLibraryLabel,
                            onClick = { resumeLibraryExpanded = true },
                        )
                        DropdownMenu(
                            expanded = resumeLibraryExpanded,
                            onDismissRequest = { resumeLibraryExpanded = false },
                        ) {
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        (if (selectedLibrarySourceId == null) "✓ " else "") + "All games",
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                },
                                onClick = {
                                    resumeLibraryExpanded = false
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
                                        resumeLibraryExpanded = false
                                        onSelectLibrarySourceId(source.id)
                                    },
                                )
                            }
                        }
                    }

                    Box {
                        ResumeDropdownButton(
                            title = "Game List",
                            value = resumeGame.name,
                            onClick = { onResumeOtherExpandedChange(true) },
                        )
                        DropdownMenu(
                            expanded = resumeOtherExpanded,
                            onDismissRequest = { onResumeOtherExpandedChange(false) },
                        ) {
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
    }

    CardContainer {
        HomeSectionTitle("Quick Entry")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            QuickEntryHomeButton(label = "Score", icon = Icons.Outlined.Tag, modifier = Modifier.weight(1f), onClick = {
                onOpenQuickEntry(QuickActivity.Score, QuickEntryOrigin.Score)
            })
            QuickEntryHomeButton(label = "Study", icon = Icons.Outlined.Book, modifier = Modifier.weight(1f), onClick = {
                onOpenQuickEntry(QuickActivity.Rulesheet, QuickEntryOrigin.Study)
            })
            QuickEntryHomeButton(label = "Practice", icon = Icons.Outlined.SportsEsports, modifier = Modifier.weight(1f), onClick = {
                onOpenQuickEntry(QuickActivity.Practice, QuickEntryOrigin.Practice)
            })
            QuickEntryHomeButton(label = "Mechanics", icon = Icons.Outlined.Build, modifier = Modifier.weight(1f), onClick = {
                onOpenQuickEntry(QuickActivity.Mechanics, QuickEntryOrigin.Mechanics)
            })
        }
    }

    CardContainer {
        val active = store.activeGroups()
        if (active.isEmpty()) {
            HomeSectionTitle("No active groups")
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
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.horizontalScroll(rememberScrollState()),
                    ) {
                        games.forEach { game ->
                            Box(
                                modifier = Modifier
                                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
                                    .clickable { onOpenGame(game.practiceKey) },
                            ) {
                                SelectedGameMiniCard(game = game, bottomPadding = 6.dp)
                            }
                        }
                    }
                }
                Spacer(Modifier.height(2.dp))
            }
        }
    }

    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        HomeMiniCard(
            label = "Group Dashboard",
            subtitle = "View and edit groups",
            icon = Icons.Outlined.Dashboard,
            modifier = Modifier.weight(1f),
        ) { onOpenGroupDashboard() }
        HomeMiniCard(
            label = "Journal Timeline",
            subtitle = "Practice and library activity history.",
            icon = Icons.Outlined.Timeline,
            modifier = Modifier.weight(1f),
        ) { onOpenJournal() }
    }
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        HomeMiniCard(
            label = "Insights",
            subtitle = "Scores, variance, and trends",
            icon = Icons.Outlined.Insights,
            modifier = Modifier.weight(1f),
        ) { onOpenInsights() }
        HomeMiniCard(
            label = "Mechanics",
            subtitle = "Track pinball skills",
            icon = Icons.Outlined.Build,
            modifier = Modifier.weight(1f),
        ) { onOpenMechanics() }
    }
}

@Composable
private fun ResumeDropdownButton(
    title: String,
    value: String,
    onClick: () -> Unit,
) {
    OutlinedButton(
        onClick = onClick,
        modifier = Modifier.width(168.dp),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(1.dp),
        ) {
            Text(
                title,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                value,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
