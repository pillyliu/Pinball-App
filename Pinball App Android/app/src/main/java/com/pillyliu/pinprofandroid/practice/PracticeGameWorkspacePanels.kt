package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.School
import androidx.compose.material.icons.outlined.SmartDisplay
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material.icons.outlined.Tag
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.normalizedVariant
import com.pillyliu.pinprofandroid.ui.AppVariantBadge
import com.pillyliu.pinprofandroid.library.practiceKey
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppCardTitleWithVariant
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors

@Composable
internal fun PracticeGameWorkspaceCard(
    store: PracticeStore,
    game: PinballGame,
    gameSubview: PracticeGameSubview,
    onGameSubviewChange: (PracticeGameSubview) -> Unit,
    onOpenQuickEntry: (QuickActivity, QuickEntryOrigin) -> Unit,
    onEditLogEntry: (JournalEntry) -> Unit,
    onDeleteLogEntry: (JournalEntry) -> Unit,
    activeGameVideoId: String?,
    onActiveGameVideoIdChange: (String?) -> Unit,
    onOpenRulesheet: (com.pillyliu.pinprofandroid.library.RulesheetRemoteSource?) -> Unit,
    onOpenExternalRulesheet: (String) -> Unit,
    onOpenPlayfield: (List<String>) -> Unit,
) {
    CardContainer {
        AppCardTitleWithVariant(
            text = game.name,
            variant = game.normalizedVariant,
            maxLines = 2,
            modifier = Modifier.fillMaxWidth(),
        )
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            PracticeGameSubview.entries.forEachIndexed { index, option ->
                SegmentedButton(
                    selected = gameSubview == option,
                    onClick = { onGameSubviewChange(option) },
                    colors = pinballSegmentedButtonColors(),
                    icon = {},
                    shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(index, PracticeGameSubview.entries.size),
                    label = { Text(option.label, maxLines = 1) },
                )
            }
        }
        when (gameSubview) {
            PracticeGameSubview.Summary -> PracticeGameSummaryPanel(store = store, game = game)
            PracticeGameSubview.Input -> PracticeGameInputPanel(onOpenQuickEntry = onOpenQuickEntry)
            PracticeGameSubview.Study -> PracticeGameResourcesCard(
                game = game,
                playableVideos = game.videos.mapNotNull { video ->
                    val id = com.pillyliu.pinprofandroid.library.youtubeId(video.url) ?: return@mapNotNull null
                    com.pillyliu.pinprofandroid.library.PlayableVideo(id = id, label = video.label ?: "Video")
                },
                activeGameVideoId = activeGameVideoId,
                onActiveGameVideoIdChange = onActiveGameVideoIdChange,
                onOpenRulesheet = onOpenRulesheet,
                onOpenExternalRulesheet = onOpenExternalRulesheet,
                onOpenPlayfield = onOpenPlayfield,
            )
            PracticeGameSubview.Log -> PracticeGameLogPanel(
                store = store,
                gameKey = game.practiceKey,
                onEditLogEntry = onEditLogEntry,
                onDeleteLogEntry = onDeleteLogEntry,
            )
        }
    }
}

@Composable
private fun PracticeGameSummaryPanel(
    store: PracticeStore,
    game: PinballGame,
) {
    val gameKey = game.practiceKey
    LaunchedEffect(gameKey) {
        store.ensureLeagueTargetsLoaded()
    }
    val summary = store.scoreSummaryFor(gameKey)
    val activeGroup = store.activeGroupForGame(gameKey)
    if (activeGroup != null) {
        val groupProgress = store.taskProgressForGame(gameKey, activeGroup)
        Row(
            verticalAlignment = Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            GroupProgressWheel(
                taskProgress = groupProgress,
                modifier = Modifier
                    .height(46.dp)
                    .aspectRatio(1f),
            )
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(activeGroup.name, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold)
                Text(
                    progressSummary(groupProgress),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
    NextActionBlock(store = store, gameSlug = gameKey)
    AlertsBlock(store = store, gameSlug = gameKey)
    ConsistencyBlock(store = store, gameSlug = gameKey)
    Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            AppCardSubheading("Score Stats")
            if (summary == null) {
                Text("Log scores to unlock.", style = MaterialTheme.typography.bodySmall)
            } else {
                StatRow("High", formatScore(summary.high), tint = MaterialTheme.colorScheme.tertiary)
                StatRow("Low", formatScore(summary.low), tint = MaterialTheme.colorScheme.error)
                StatRow("Mean", formatScore(summary.mean), tint = MaterialTheme.colorScheme.primary)
                StatRow("Median", formatScore(summary.median), tint = MaterialTheme.colorScheme.primary)
                StatRow("St Dev", formatScore(summary.stdev))
            }
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            AppCardSubheading("Target Scores")
            val targets = store.leagueTargetScoresFor(gameKey)
            if (targets == null) {
                val emptyStateText = if (store.isLoadingLeagueTargets && !store.didLoadLeagueTargets) {
                    "Loading target data..."
                } else {
                    "No target data yet."
                }
                AppPanelEmptyCard(text = emptyStateText)
            } else {
                StatRow("2nd", formatScore(targets.great), tint = MaterialTheme.colorScheme.tertiary)
                StatRow("4th", formatScore(targets.main), tint = MaterialTheme.colorScheme.primary)
                StatRow("8th", formatScore(targets.floor), tint = MaterialTheme.colorScheme.error)
            }
        }
    }
}

@Composable
private fun PracticeGameInputPanel(
    onOpenQuickEntry: (QuickActivity, QuickEntryOrigin) -> Unit,
) {
    AppCardSubheading("Task-Specific Logging")
    Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            PracticeInputGridButton(
                label = "Rulesheet",
                icon = Icons.Outlined.Book,
                modifier = Modifier.weight(1f),
            ) { onOpenQuickEntry(QuickActivity.Rulesheet, QuickEntryOrigin.Study) }
            PracticeInputGridButton(
                label = "Playfield",
                icon = Icons.Outlined.Image,
                modifier = Modifier.weight(1f),
            ) { onOpenQuickEntry(QuickActivity.Playfield, QuickEntryOrigin.Study) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            PracticeInputGridButton(
                label = "Score",
                icon = Icons.Outlined.Tag,
                modifier = Modifier.weight(1f),
            ) { onOpenQuickEntry(QuickActivity.Score, QuickEntryOrigin.Score) }
            PracticeInputGridButton(
                label = "Tutorial",
                icon = Icons.Outlined.School,
                modifier = Modifier.weight(1f),
            ) { onOpenQuickEntry(QuickActivity.Tutorial, QuickEntryOrigin.Study) }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            PracticeInputGridButton(
                label = "Practice",
                icon = Icons.Outlined.SportsEsports,
                modifier = Modifier.weight(1f),
            ) { onOpenQuickEntry(QuickActivity.Practice, QuickEntryOrigin.Practice) }
            PracticeInputGridButton(
                label = "Gameplay",
                icon = Icons.Outlined.SmartDisplay,
                modifier = Modifier.weight(1f),
            ) { onOpenQuickEntry(QuickActivity.Gameplay, QuickEntryOrigin.Study) }
        }
    }
}

@Composable
private fun PracticeGameLogPanel(
    store: PracticeStore,
    gameKey: String,
    onEditLogEntry: (JournalEntry) -> Unit,
    onDeleteLogEntry: (JournalEntry) -> Unit,
) {
    AppCardSubheading("Log")
    val logRows = store.gameJournalEntriesFor(gameKey)
        .map { row ->
            JournalTimelineRow(
                id = "app-${row.id}",
                gameSlug = row.gameSlug,
                summary = row.summary,
                timestampMs = row.timestampMs,
                journalEntry = row,
                isEditable = store.canEditJournalEntry(row),
            )
        }
    if (logRows.isEmpty()) {
        AppPanelEmptyCard(text = "No actions logged yet.")
    } else {
        LazyColumn(modifier = Modifier.height(280.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(logRows, key = { it.id }) { row ->
                JournalRow(
                    row = row,
                    isSelectionMode = false,
                    isSelected = false,
                    onToggleSelected = {},
                    onOpenGame = {},
                    onEdit = onEditLogEntry,
                    onDelete = onDeleteLogEntry,
                )
            }
        }
    }
}
