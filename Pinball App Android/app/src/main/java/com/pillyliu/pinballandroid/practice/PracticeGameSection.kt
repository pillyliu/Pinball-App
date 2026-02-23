package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.pillyliu.pinballandroid.library.PinballGame
import com.pillyliu.pinballandroid.library.fullscreenPlayfieldCandidates
import com.pillyliu.pinballandroid.library.gameInlinePlayfieldCandidates
import com.pillyliu.pinballandroid.library.metaLine
import com.pillyliu.pinballandroid.library.youtubeId
import com.pillyliu.pinballandroid.ui.CardContainer

@Composable
internal fun PracticeGameSection(
    store: PracticeStore,
    game: PinballGame?,
    gameSubview: PracticeGameSubview,
    onGameSubviewChange: (PracticeGameSubview) -> Unit,
    gameSummaryDraft: String,
    onGameSummaryDraftChange: (String) -> Unit,
    activeGameVideoId: String?,
    onActiveGameVideoIdChange: (String?) -> Unit,
    onOpenQuickEntry: (QuickActivity, QuickEntryOrigin) -> Unit,
    onOpenRulesheet: () -> Unit,
    onOpenPlayfield: (List<String>) -> Unit,
) {
    if (game == null) {
        Text("Select a game first.")
        return
    }

    val heroImage = game.gameInlinePlayfieldCandidates().firstOrNull()
    val gameKey = game.practiceKey
    val hasRulesheet = !game.rulesheetLocal.isNullOrBlank()
    val playableVideos = game.videos.mapNotNull { video ->
        val id = youtubeId(video.url) ?: return@mapNotNull null
        id to (video.label ?: "Video")
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(16f / 9f)
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant),
    ) {
        if (heroImage.isNullOrBlank()) {
            Text(
                "No image",
                modifier = Modifier.align(Alignment.Center),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            AsyncImage(
                model = heroImage,
                contentDescription = game.name,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }

    CardContainer {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                text = game.name,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            game.variant?.takeIf { it.isNotBlank() }?.let { variant ->
                Text(
                    text = variant,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .background(
                            MaterialTheme.colorScheme.surfaceContainerHigh,
                            shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
                        )
                        .border(
                            width = 0.75.dp,
                            color = MaterialTheme.colorScheme.outlineVariant,
                            shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
                        )
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                )
            }
        }
        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
            PracticeGameSubview.entries.forEachIndexed { index, option ->
                SegmentedButton(
                    selected = gameSubview == option,
                    onClick = { onGameSubviewChange(option) },
                    shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(index, PracticeGameSubview.entries.size),
                    label = { Text(option.label, maxLines = 1) },
                )
            }
        }
        when (gameSubview) {
            PracticeGameSubview.Summary -> {
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
                        Text("Score Stats", fontWeight = FontWeight.SemiBold)
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
                        Text("Target Scores", fontWeight = FontWeight.SemiBold)
                        val targets = store.leagueTargetScoresFor(gameKey)
                        if (targets == null) {
                            Text("No target data yet.", style = MaterialTheme.typography.bodySmall)
                        } else {
                            StatRow("2nd", formatScore(targets.great), tint = MaterialTheme.colorScheme.tertiary)
                            StatRow("4th", formatScore(targets.main), tint = MaterialTheme.colorScheme.primary)
                            StatRow("8th", formatScore(targets.floor), tint = MaterialTheme.colorScheme.error)
                        }
                    }
                }
            }

            PracticeGameSubview.Input -> {
                Text("Task-Specific Logging", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                PracticeInputButton("View playfield image") { onOpenQuickEntry(QuickActivity.Playfield, QuickEntryOrigin.Study) }
                PracticeInputButton("Read rulesheet") { onOpenQuickEntry(QuickActivity.Rulesheet, QuickEntryOrigin.Study) }
                PracticeInputButton("Watch tutorial video(s)") { onOpenQuickEntry(QuickActivity.Tutorial, QuickEntryOrigin.Study) }
                PracticeInputButton("Watch gameplay video(s)") { onOpenQuickEntry(QuickActivity.Gameplay, QuickEntryOrigin.Study) }
                PracticeInputButton("Practice the game") { onOpenQuickEntry(QuickActivity.Practice, QuickEntryOrigin.Practice) }
                PracticeInputButton("Log Score") { onOpenQuickEntry(QuickActivity.Score, QuickEntryOrigin.Score) }
            }

            PracticeGameSubview.Log -> {
                Text("Log", fontWeight = FontWeight.SemiBold)
                val rows = store.journalItems(JournalFilter.All).filter { it.gameSlug == gameKey }
                if (rows.isEmpty()) {
                    Text("No actions logged yet.")
                } else {
                    LazyColumn(modifier = Modifier.height(280.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(rows) { row ->
                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(row.summary, style = MaterialTheme.typography.bodySmall)
                                Text(formatTimestamp(row.timestampMs), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }
        }
    }

    CardContainer {
        Text("Game Note", fontWeight = FontWeight.SemiBold)
        Text(
            "Freeform summary of how this game is going.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        OutlinedTextField(
            value = gameSummaryDraft,
            onValueChange = onGameSummaryDraftChange,
            modifier = Modifier.fillMaxWidth(),
            minLines = 4,
            label = { Text("Game note") },
        )
        Row(modifier = Modifier.fillMaxWidth()) {
            Spacer(Modifier.weight(1f))
            Button(
                onClick = { store.updateGameSummaryNote(gameKey, gameSummaryDraft) },
                enabled = gameKey.isNotBlank(),
            ) { Text("Save Note") }
        }
    }

    CardContainer {
        Text("Game Resources", fontWeight = FontWeight.SemiBold)
        Text(game.metaLine(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onOpenRulesheet, enabled = hasRulesheet) { Text("Rulesheet") }
            OutlinedButton(onClick = { onOpenPlayfield(game.fullscreenPlayfieldCandidates()) }) { Text("Playfield") }
        }

        if (playableVideos.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f)
                    .background(
                        MaterialTheme.colorScheme.surfaceContainerLow,
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(10.dp),
                    )
                    .border(
                        1.dp,
                        MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.65f),
                        shape = androidx.compose.foundation.shape.RoundedCornerShape(10.dp),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text("No videos listed.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            activeGameVideoId?.let { id ->
                PracticeEmbeddedYouTubeView(
                    videoId = id,
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(16f / 9f)
                        .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp)),
                )
            }
            val rows = playableVideos.chunked(2)
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                rows.forEach { rowItems ->
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        rowItems.forEach { (id, label) ->
                            PracticeVideoTile(
                                videoId = id,
                                label = label,
                                selected = activeGameVideoId == id,
                                modifier = Modifier.weight(1f),
                                onClick = { onActiveGameVideoIdChange(id) },
                            )
                        }
                        if (rowItems.size == 1) {
                            Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
        }
    }
}
