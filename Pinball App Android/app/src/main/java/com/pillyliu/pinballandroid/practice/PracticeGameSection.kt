package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Book
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.School
import androidx.compose.material.icons.outlined.SmartDisplay
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material.icons.outlined.Tag
import com.pillyliu.pinballandroid.library.ConstrainedAsyncImagePreview
import com.pillyliu.pinballandroid.library.PinballGame
import com.pillyliu.pinballandroid.library.actualFullscreenPlayfieldCandidates
import com.pillyliu.pinballandroid.library.fullscreenPlayfieldCandidates
import com.pillyliu.pinballandroid.library.gameInlinePlayfieldCandidates
import com.pillyliu.pinballandroid.library.hasPlayfieldResource
import com.pillyliu.pinballandroid.library.hasRulesheetResource
import com.pillyliu.pinballandroid.library.metaLine
import com.pillyliu.pinballandroid.library.normalizedVariant
import com.pillyliu.pinballandroid.library.practiceKey
import com.pillyliu.pinballandroid.library.ReferenceLink
import com.pillyliu.pinballandroid.library.RulesheetRemoteSource
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
    onOpenRulesheet: (RulesheetRemoteSource?) -> Unit,
    onOpenExternalRulesheet: (String) -> Unit,
    onOpenPlayfield: (List<String>) -> Unit,
) {
    val uriHandler = LocalUriHandler.current
    if (game == null) {
        Text("Select a game first.")
        return
    }
    val gameKey = game.practiceKey
    val playableVideos = game.videos.mapNotNull { video ->
        val id = youtubeId(video.url) ?: return@mapNotNull null
        id to (video.label ?: "Video")
    }
    var editingDraft by remember { mutableStateOf<PracticeJournalEditDraft?>(null) }
    var pendingDeleteEntry by remember { mutableStateOf<JournalEntry?>(null) }
    var editValidation by remember { mutableStateOf<String?>(null) }
    var revealedLogRowId by rememberSaveable(gameKey) { mutableStateOf<String?>(null) }

    ConstrainedAsyncImagePreview(
        urls = game.gameInlinePlayfieldCandidates(),
        contentDescription = game.name,
        emptyMessage = "No image",
    )

    CardContainer(
        modifier = Modifier.pointerInput(revealedLogRowId) {
            detectTapGestures(
                onTap = {
                    if (revealedLogRowId != null) {
                        revealedLogRowId = null
                    }
                }
            )
        }
    ) {
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
            game.normalizedVariant?.let { variant ->
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

            PracticeGameSubview.Log -> {
                Text("Log", fontWeight = FontWeight.SemiBold)
                val logRows = store.journalItems(JournalFilter.All)
                    .filter { it.gameSlug == gameKey }
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
                    Text("No actions logged yet.")
                } else {
                    LazyColumn(modifier = Modifier.height(280.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(logRows, key = { it.id }) { row ->
                            JournalRow(
                                row = row,
                                revealedRowId = revealedLogRowId,
                                onRevealedRowIdChange = { revealedLogRowId = it },
                                isSelectionMode = false,
                                isSelected = false,
                                onToggleSelected = {},
                                onOpenGame = {},
                                onEdit = { entry ->
                                    revealedLogRowId = null
                                    editingDraft = store.journalEditDraft(entry)
                                    editValidation = null
                                },
                                onDelete = { entry ->
                                    revealedLogRowId = null
                                    pendingDeleteEntry = entry
                                },
                            )
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
        PracticeResourceRow(label = "Rulesheet:") {
            if (game.rulesheetLinks.isEmpty()) {
                if (game.hasRulesheetResource) {
                    PracticeResourceChip(label = "Local") { onOpenRulesheet(null) }
                } else {
                    PracticeUnavailableResourceChip()
                }
            } else {
                game.rulesheetLinks.forEach { link ->
                    val destination = link.destinationUrl
                    val embedded = link.embeddedRulesheetSource
                    PracticeResourceChip(label = shortRulesheetTitle(link)) {
                        when {
                            embedded != null -> onOpenRulesheet(embedded)
                            destination != null -> onOpenExternalRulesheet(destination)
                            else -> onOpenRulesheet(null)
                        }
                    }
                }
            }
        }
        PracticeResourceRow(label = "Playfield:") {
            val playfieldCandidates = game.actualFullscreenPlayfieldCandidates
            if (playfieldCandidates.isNotEmpty()) {
                PracticeResourceChip(label = if (game.playfieldSourceLabel == "Playfield (OPDB)") "OPDB" else "Local") {
                    onOpenPlayfield(playfieldCandidates)
                }
            } else {
                PracticeUnavailableResourceChip()
            }
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
            val selectedVideo = playableVideos.firstOrNull { it.first == activeGameVideoId } ?: playableVideos.firstOrNull()
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
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(16.dp),
                ) {
                    androidx.compose.material3.Icon(
                        imageVector = Icons.Outlined.SmartDisplay,
                        contentDescription = null,
                    )
                    Text(
                        selectedVideo?.second ?: "Tap a video thumbnail",
                        style = MaterialTheme.typography.titleMedium,
                    )
                    Text("Opens in YouTube", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    OutlinedButton(
                        onClick = {
                            selectedVideo?.first?.let { id ->
                                uriHandler.openUri("https://www.youtube.com/watch?v=$id")
                            }
                        },
                        enabled = selectedVideo != null,
                    ) {
                        Text("Open in YouTube")
                    }
                }
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

    pendingDeleteEntry?.let { entry ->
        AlertDialog(
            onDismissRequest = { pendingDeleteEntry = null },
            title = { Text("Delete entry?") },
            text = { Text("This will remove the selected journal entry and linked practice data.") },
            confirmButton = {
                TextButton(onClick = {
                    store.deleteJournalEntry(entry.id)
                    pendingDeleteEntry = null
                    revealedLogRowId = null
                }) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { pendingDeleteEntry = null }) { Text("Cancel") }
            },
        )
    }

    editingDraft?.let { draft ->
        JournalEditDialog(
            store = store,
            initial = draft,
            validationMessage = editValidation,
            onDismiss = {
                editingDraft = null
                editValidation = null
            },
            onSave = { updated ->
                if (store.updateJournalEntry(updated)) {
                    editingDraft = null
                    editValidation = null
                    revealedLogRowId = null
                } else {
                    editValidation = "Could not save changes."
                }
            },
        )
    }
}

@Composable
private fun PracticeResourceRow(
    label: String,
    content: @Composable () -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.labelMedium)
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .weight(1f, fill = false)
                .horizontalScroll(rememberScrollState()),
        ) {
            content()
        }
        Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
private fun PracticeResourceChip(
    label: String,
    onClick: () -> Unit,
) {
    OutlinedButton(onClick = onClick) {
        Text(label)
    }
}

@Composable
private fun PracticeUnavailableResourceChip() {
    Text(
        "Unavailable",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier
            .background(
                MaterialTheme.colorScheme.surfaceContainerLow,
                androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
            )
            .border(
                1.dp,
                MaterialTheme.colorScheme.outlineVariant,
                androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
            )
            .padding(horizontal = 10.dp, vertical = 7.dp),
    )
}

private fun shortRulesheetTitle(link: ReferenceLink): String {
    val label = link.label.lowercase()
    return when {
        "(tf)" in label -> "TF"
        "(pp)" in label -> "PP"
        "(papa)" in label -> "PAPA"
        "(bob)" in label -> "Bob"
        else -> "Local"
    }
}
