package com.pillyliu.pinprofandroid.league

import android.content.res.Configuration
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.FormatListNumbered
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.R
import com.pillyliu.pinprofandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.CardContainer
import kotlinx.coroutines.delay

enum class LeagueDestination(val title: String, val subtitle: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Stats("Stats", "Player trends and machine performance", Icons.Outlined.BarChart),
    Standings("Standings", "Season standings and points view", Icons.Outlined.FormatListNumbered),
    Targets("Targets", "Great game, main target, and floor goals", Icons.Outlined.Flag),
    AboutLpl("About Lansing Pinball League", "League info and links", Icons.Outlined.Info),
}

@Composable
fun LeagueScreen(
    contentPadding: PaddingValues,
    onOpenDestination: (LeagueDestination) -> Unit,
) {
    val context = LocalContext.current
    val showFullLplLastName = rememberShowFullLplLastName()
    val previewState by produceState(initialValue = LeaguePreviewState()) {
        value = loadLeaguePreviewState(context)
    }

    var targetMetricIndex by rememberSaveable { mutableIntStateOf(0) }
    var standingsModeIndex by rememberSaveable { mutableIntStateOf(0) }
    var showStatsScore by rememberSaveable { mutableStateOf(true) }

    LaunchedEffect(previewState.nextBankTargets) {
        while (true) {
            delay(4000)
            targetMetricIndex = (targetMetricIndex + 1) % 3
        }
    }

    LaunchedEffect(previewState.statsRecentRows) {
        while (true) {
            delay(4000)
            showStatsScore = !showStatsScore
        }
    }

    LaunchedEffect(previewState.standingsAroundRows) {
        standingsModeIndex = 0
        while (true) {
            delay(4000)
            if (previewState.standingsAroundRows.isNotEmpty()) {
                standingsModeIndex = (standingsModeIndex + 1) % 2
            } else {
                standingsModeIndex = 0
            }
        }
    }

    AppScreen(contentPadding) {
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
                                showScore = showStatsScore,
                                labelSize = miniLabelSize,
                                headerSize = miniHeaderSize,
                                valueSize = miniValueSize,
                            )
                        }
                        LeagueDestination.Standings -> {
                            val showAround = previewState.standingsAroundRows.isNotEmpty() && standingsModeIndex == 1
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
                                metricIndex = targetMetricIndex,
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
}
