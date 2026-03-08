package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
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
import com.pillyliu.pinprofandroid.library.RulesheetRemoteSource
import com.pillyliu.pinprofandroid.library.actualFullscreenPlayfieldCandidates
import com.pillyliu.pinprofandroid.library.hasRulesheetResource
import com.pillyliu.pinprofandroid.library.metaLine
import com.pillyliu.pinprofandroid.library.openYoutubeInApp
import com.pillyliu.pinprofandroid.library.playfieldButtonLabel
import com.pillyliu.pinprofandroid.ui.AppResourceChip
import com.pillyliu.pinprofandroid.ui.AppResourceRow
import com.pillyliu.pinprofandroid.ui.AppUnavailableResourceChip
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.appShortRulesheetTitle

@Composable
internal fun PracticeGameNoteCard(
    gameKey: String,
    store: PracticeStore,
    gameSummaryDraft: String,
    onGameSummaryDraftChange: (String) -> Unit,
) {
    CardContainer {
        AppCardSubheading("Game Note")
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
            AppResourceRow(label = "Rulesheet:") {
                if (game.rulesheetLinks.isEmpty()) {
                    if (game.hasRulesheetResource) {
                        AppResourceChip(label = "Local") { onOpenRulesheet(null) }
                    } else {
                        AppUnavailableResourceChip()
                    }
                } else {
                    game.rulesheetLinks.forEach { link ->
                        val destination = link.destinationUrl
                        val embedded = link.embeddedRulesheetSource
                        AppResourceChip(label = appShortRulesheetTitle(link)) {
                            when {
                                embedded != null -> onOpenRulesheet(embedded)
                                destination != null -> onOpenExternalRulesheet(destination)
                                else -> onOpenRulesheet(null)
                            }
                        }
                    }
                }
            }
            AppResourceRow(label = "Playfield:") {
                val playfieldCandidates = game.actualFullscreenPlayfieldCandidates
                if (playfieldCandidates.isNotEmpty()) {
                    AppResourceChip(label = game.playfieldButtonLabel) {
                        onOpenPlayfield(playfieldCandidates)
                    }
                } else {
                    AppUnavailableResourceChip()
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
