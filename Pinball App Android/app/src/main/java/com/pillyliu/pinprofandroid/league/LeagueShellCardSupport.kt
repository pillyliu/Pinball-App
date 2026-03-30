package com.pillyliu.pinprofandroid.league

import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.R
import com.pillyliu.pinprofandroid.ui.CardContainer

internal data class LeagueShellPreviewSizing(
    val maxRows: Int,
    val titleSize: TextUnit,
    val subtitleSize: TextUnit,
    val miniLabelSize: TextUnit,
    val miniHeaderSize: TextUnit,
    val miniValueSize: TextUnit,
    val footerTitleSize: TextUnit,
)

@Composable
internal fun LeagueDestinationCard(
    destination: LeagueDestination,
    previewState: LeaguePreviewState,
    previewRotation: LeaguePreviewRotationState,
    showFullLplLastName: Boolean,
    sizing: LeagueShellPreviewSizing,
    onOpenDestination: (LeagueDestination) -> Unit,
    modifier: Modifier = Modifier,
) {
    LeagueCard(
        destination = destination,
        modifier = modifier,
        onClick = { onOpenDestination(destination) },
        titleSize = sizing.titleSize,
        subtitleSize = sizing.subtitleSize,
    ) {
        when (destination) {
            LeagueDestination.Stats -> {
                StatsMiniPreview(
                    rows = previewState.statsRecentRows.take(sizing.maxRows),
                    bankLabel = previewState.statsRecentBankLabel,
                    playerLabel = previewState.statsPlayerRawName,
                    showFullLplLastName = showFullLplLastName,
                    showScore = previewRotation.showStatsScore,
                    labelSize = sizing.miniLabelSize,
                    headerSize = sizing.miniHeaderSize,
                    valueSize = sizing.miniValueSize,
                )
            }

            LeagueDestination.Standings -> {
                val showAround = previewState.standingsAroundRows.isNotEmpty() && previewRotation.standingsModeIndex == 1
                StandingsMiniPreview(
                    seasonLabel = previewState.standingsSeasonLabel,
                    showAround = showAround,
                    topRows = previewState.standingsTopRows,
                    aroundRows = previewState.standingsAroundRows,
                    currentPlayerRow = previewState.currentPlayerStanding,
                    showFullLplLastName = showFullLplLastName,
                    labelSize = sizing.miniLabelSize,
                    headerSize = sizing.miniHeaderSize,
                    valueSize = sizing.miniValueSize,
                )
            }

            LeagueDestination.Targets -> {
                TargetsMiniPreview(
                    rows = previewState.nextBankTargets.take(sizing.maxRows),
                    bankLabel = previewState.nextBankLabel,
                    metricIndex = previewRotation.targetMetricIndex,
                    labelSize = sizing.miniLabelSize,
                    headerSize = sizing.miniHeaderSize,
                    valueSize = sizing.miniValueSize,
                )
            }

            LeagueDestination.AboutLpl -> {
                Text(
                    text = "League details, schedule, and official links.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = sizing.miniLabelSize,
                )
            }
        }
    }
}

@Composable
internal fun LeagueAboutFooterCard(
    tabletMode: Boolean,
    onOpenDestination: (LeagueDestination) -> Unit,
    modifier: Modifier = Modifier,
) {
    CardContainer(
        modifier = Modifier
            .then(modifier)
            .fillMaxWidth()
            .clickable { onOpenDestination(LeagueDestination.footerDestination) },
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Image(
                painter = painterResource(id = R.drawable.lpl_logo),
                contentDescription = "Lansing Pinball League logo",
                modifier = Modifier
                    .width(42.dp)
                    .height(28.dp),
                contentScale = ContentScale.Fit,
            )
            Text(
                text = "About Lansing Pinball League",
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.SemiBold,
                fontSize = if (tabletMode) 15.sp else 14.sp,
                modifier = Modifier.weight(1f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Icon(
                imageVector = Icons.Outlined.ChevronRight,
                contentDescription = "Open About Lansing Pinball League",
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
