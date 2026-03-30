package com.pillyliu.pinprofandroid.league

import android.content.res.Configuration
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
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

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
        val sizing = LeagueShellPreviewSizing(
            maxRows = maxRows,
            titleSize = titleSize,
            subtitleSize = subtitleSize,
            miniLabelSize = miniLabelSize,
            miniHeaderSize = miniHeaderSize,
            miniValueSize = miniValueSize,
            footerTitleSize = if (tabletMode) 15.sp else 14.sp,
        )

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
                    LeagueDestinationCard(
                        LeagueDestination.primaryDestinations[0],
                        previewState = previewState,
                        previewRotation = previewRotation,
                        showFullLplLastName = showFullLplLastName,
                        sizing = sizing,
                        onOpenDestination = onOpenDestination,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
                    )
                    LeagueDestinationCard(
                        LeagueDestination.primaryDestinations[1],
                        previewState = previewState,
                        previewRotation = previewRotation,
                        showFullLplLastName = showFullLplLastName,
                        sizing = sizing,
                        onOpenDestination = onOpenDestination,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
                    )
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(IntrinsicSize.Min),
                    horizontalArrangement = Arrangement.spacedBy(cardGap),
                ) {
                    LeagueDestinationCard(
                        LeagueDestination.primaryDestinations[2],
                        previewState = previewState,
                        previewRotation = previewRotation,
                        showFullLplLastName = showFullLplLastName,
                        sizing = sizing,
                        onOpenDestination = onOpenDestination,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
                    )
                    LeagueAboutFooterCard(
                        tabletMode = tabletMode,
                        onOpenDestination = onOpenDestination,
                        modifier = Modifier.weight(1f).fillMaxHeight(),
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
                LeagueDestination.primaryDestinations.forEach { destination ->
                    LeagueDestinationCard(
                        destination = destination,
                        previewState = previewState,
                        previewRotation = previewRotation,
                        showFullLplLastName = showFullLplLastName,
                        sizing = sizing,
                        onOpenDestination = onOpenDestination,
                    )
                }
                LeagueAboutFooterCard(
                    tabletMode = tabletMode,
                    onOpenDestination = onOpenDestination,
                )
            }
        }
    }
}
