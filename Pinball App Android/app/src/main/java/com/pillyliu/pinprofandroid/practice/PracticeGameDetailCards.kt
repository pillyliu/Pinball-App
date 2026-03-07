package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.PinballVideoLaunchPanel
import com.pillyliu.pinprofandroid.library.PlayableVideo
import com.pillyliu.pinprofandroid.library.ReferenceLink
import com.pillyliu.pinprofandroid.library.RulesheetRemoteSource
import com.pillyliu.pinprofandroid.library.actualFullscreenPlayfieldCandidates
import com.pillyliu.pinprofandroid.library.hasRulesheetResource
import com.pillyliu.pinprofandroid.library.metaLine
import com.pillyliu.pinprofandroid.library.openYoutubeInApp
import com.pillyliu.pinprofandroid.ui.CardContainer

@Composable
internal fun PracticeGameNoteCard(
    gameKey: String,
    store: PracticeStore,
    gameSummaryDraft: String,
    onGameSummaryDraftChange: (String) -> Unit,
) {
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
}

@Composable
internal fun PracticeGameResourcesCard(
    game: PinballGame,
    playableVideos: List<PlayableVideo>,
    activeGameVideoId: String?,
    onActiveGameVideoIdChange: (String?) -> Unit,
    onOpenRulesheet: (RulesheetRemoteSource?) -> Unit,
    onOpenExternalRulesheet: (String) -> Unit,
    onOpenPlayfield: (List<String>) -> Unit,
) {
    val context = LocalContext.current

    CardContainer {
        Text("Game Resources", fontWeight = FontWeight.SemiBold)
        Text(game.metaLine(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Column(
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
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
            val selectedVideo = playableVideos.firstOrNull { it.id == activeGameVideoId } ?: playableVideos.firstOrNull()
            PinballVideoLaunchPanel(
                selectedVideo = selectedVideo,
                onOpenVideo = { video ->
                    openYoutubeInApp(
                        context = context,
                        url = video.watchUrl,
                        fallbackVideoId = video.id,
                    )
                },
            )
            val rows = playableVideos.chunked(2)
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                rows.forEach { rowItems ->
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        rowItems.forEach { video ->
                            PracticeVideoTile(
                                video = video,
                                selected = activeGameVideoId == video.id,
                                modifier = Modifier.weight(1f),
                                onClick = { onActiveGameVideoIdChange(video.id) },
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
