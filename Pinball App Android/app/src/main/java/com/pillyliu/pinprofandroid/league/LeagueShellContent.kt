package com.pillyliu.pinprofandroid.league

import android.content.res.Configuration
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.R
import com.pillyliu.pinprofandroid.ui.CardContainer

@Composable
internal fun LeagueShellContent(
    previewState: LeaguePreviewState,
    previewRotation: LeaguePreviewRotationState,
    showFullLplLastName: Boolean,
    onOpenDestination: (LeagueDestination) -> Unit,
) {
    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val compactHeight = maxHeight < 730.dp
        val tabletMode = maxWidth >= 600.dp
        val isLandscape = LocalConfiguration.current.orientation == Configuration.ORIENTATION_LANDSCAPE
        val cardGap = if (compactHeight) 8.dp else 10.dp
        val maxRows = if (compactHeight) 4 else 5
        val titleSize = if (tabletMode) 20.sp else 19.sp
        val subtitleSize = if (tabletMode) 16.sp else 15.sp
        val miniLabelSize = if (tabletMode) 15.sp else 14.sp
        val miniHeaderSize = if (tabletMode) 14.sp else 13.sp
        val miniValueSize = if (tabletMode) 15.sp else 14.sp
        val landscapeRowGap = if (compactHeight) 6.dp else 8.dp

        @Composable
        fun DestinationCard(destination: LeagueDestination, modifier: Modifier = Modifier) {
            LeagueCard(
                destination = destination,
                modifier = modifier,
                onClick = { onOpenDestination(destination) },
                titleSize = titleSize,
                subtitleSize = subtitleSize,
            ) {
                when (destination) {
                    LeagueDestination.Stats -> {
                        StatsMiniPreview(
                            rows = previewState.statsRecentRows.take(maxRows),
                            bankLabel = previewState.statsRecentBankLabel,
                            playerLabel = previewState.statsPlayerRawName,
                            showFullLplLastName = showFullLplLastName,
                            showScore = previewRotation.showStatsScore,
                            labelSize = miniLabelSize,
                            headerSize = miniHeaderSize,
                            valueSize = miniValueSize,
                        )
                    }
                    LeagueDestination.Standings -> {
                        val showAround = previewState.standingsAroundRows.isNotEmpty() && previewRotation.standingsModeIndex == 1
                        StandingsMiniPreview(
                            seasonLabel = previewState.standingsSeasonLabel,
                            showAround = showAround,
                            topRows = previewState.standingsTopRows.take(maxRows),
                            aroundRows = previewState.standingsAroundRows.take(maxRows),
                            showFullLplLastName = showFullLplLastName,
                            labelSize = miniLabelSize,
                            headerSize = miniHeaderSize,
                            valueSize = miniValueSize,
                        )
                    }
                    LeagueDestination.Targets -> {
                        TargetsMiniPreview(
                            rows = previewState.nextBankTargets.take(maxRows),
                            bankLabel = previewState.nextBankLabel,
                            metricIndex = previewRotation.targetMetricIndex,
                            labelSize = miniLabelSize,
                            headerSize = miniHeaderSize,
                            valueSize = miniValueSize,
                        )
                    }
                    LeagueDestination.AboutLpl -> {
                        Text(
                            text = "League details, schedule, and official links.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = miniLabelSize,
                        )
                    }
                }
            }
        }

        @Composable
        fun AboutFooterCard(modifier: Modifier = Modifier) {
            CardContainer(
                modifier = Modifier
                    .then(modifier)
                    .fillMaxWidth()
                    .clickable { onOpenDestination(LeagueDestination.AboutLpl) },
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

        if (isLandscape) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(landscapeRowGap),
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(IntrinsicSize.Min),
                    horizontalArrangement = Arrangement.spacedBy(cardGap),
                ) {
                    DestinationCard(
                        LeagueDestination.Stats,
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight(),
                    )
                    DestinationCard(
                        LeagueDestination.Standings,
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight(),
                    )
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(IntrinsicSize.Min),
                    horizontalArrangement = Arrangement.spacedBy(cardGap),
                ) {
                    DestinationCard(
                        LeagueDestination.Targets,
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight(),
                    )
                    AboutFooterCard(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight(),
                    )
                }
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(cardGap),
            ) {
                DestinationCard(LeagueDestination.Stats)
                DestinationCard(LeagueDestination.Standings)
                DestinationCard(LeagueDestination.Targets)
                AboutFooterCard()
            }
        }
    }
}
