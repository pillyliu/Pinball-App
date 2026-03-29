package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppCardTitleWithVariant
import com.pillyliu.pinprofandroid.ui.AppResourceChip
import com.pillyliu.pinprofandroid.ui.AppResourceRow
import com.pillyliu.pinprofandroid.ui.AppUnavailableResourceChip
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.appShortRulesheetTitle

@Composable
internal fun LibraryDetailScreenshotSection(game: PinballGame) {
    ConstrainedAsyncImagePreview(
        urls = game.detailArtworkCandidates(),
        contentDescription = game.name,
        emptyMessage = "No image",
    )
}

@Composable
internal fun LibraryDetailSummaryCard(
    game: PinballGame,
    onOpenRulesheet: (RulesheetRemoteSource?, String?) -> Unit,
    onOpenExternalRulesheet: (String, String?) -> Unit,
    onOpenPlayfield: (List<String>) -> Unit,
) {
    val livePlayfieldStatus by produceState<LivePlayfieldStatus?>(initialValue = null, key1 = game.practiceIdentity) {
        value = loadLivePlayfieldStatus(game.practiceIdentity)
    }
    val playfieldOptions = remember(game, livePlayfieldStatus) {
        game.resolvedPlayfieldOptions(livePlayfieldStatus)
    }
    val displayedRulesheetLinks = game.displayedRulesheetLinks
    CardContainer {
        AppCardTitleWithVariant(
            text = game.name,
            variant = game.normalizedVariant,
            maxLines = 2,
            modifier = Modifier.fillMaxWidth(),
        )
        AppCardSubheading(game.metaLine())
        Column(
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            AppResourceRow(label = "Rulesheet:") {
                if (game.hasLocalRulesheetResource) {
                    AppResourceChip(label = game.localRulesheetChipLabel) {
                        onOpenRulesheet(null, game.localRulesheetChipLabel)
                    }
                }
                if (displayedRulesheetLinks.isEmpty()) {
                    if (!game.hasLocalRulesheetResource) {
                        AppUnavailableResourceChip()
                    }
                } else {
                    displayedRulesheetLinks.forEach { link ->
                        val destination = link.destinationUrl
                        val embedded = link.embeddedRulesheetSource
                        AppResourceChip(label = appShortRulesheetTitle(link)) {
                            when {
                                embedded != null -> onOpenRulesheet(embedded, link.label)
                                destination != null -> onOpenExternalRulesheet(destination, link.label)
                                else -> onOpenRulesheet(null, link.label)
                            }
                        }
                    }
                }
            }
            AppResourceRow(label = "Playfield:") {
                if (playfieldOptions.isNotEmpty()) {
                    playfieldOptions.forEach { option ->
                        AppResourceChip(label = option.label) {
                            onOpenPlayfield(option.candidates)
                        }
                    }
                } else {
                    AppUnavailableResourceChip()
                }
            }
        }
    }
}
