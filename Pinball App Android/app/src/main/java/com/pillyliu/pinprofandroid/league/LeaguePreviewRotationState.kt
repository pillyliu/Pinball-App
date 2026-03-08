package com.pillyliu.pinprofandroid.league

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay

@Stable
internal data class LeaguePreviewRotationState(
    val targetMetricIndex: Int,
    val standingsModeIndex: Int,
    val showStatsScore: Boolean,
)

@Composable
internal fun rememberLeaguePreviewRotationState(previewState: LeaguePreviewState): LeaguePreviewRotationState {
    var targetMetricIndex by rememberSaveable { mutableIntStateOf(0) }
    var standingsModeIndex by rememberSaveable { mutableIntStateOf(0) }
    var showStatsScore by rememberSaveable { mutableStateOf(true) }

    LaunchedEffect(previewState.nextBankTargets) {
        if (previewState.nextBankTargets.isEmpty()) {
            targetMetricIndex = 0
            return@LaunchedEffect
        }

        while (true) {
            delay(4000)
            targetMetricIndex = (targetMetricIndex + 1) % 3
        }
    }

    LaunchedEffect(previewState.statsRecentRows) {
        if (previewState.statsRecentRows.isEmpty()) {
            showStatsScore = true
            return@LaunchedEffect
        }

        while (true) {
            delay(4000)
            showStatsScore = !showStatsScore
        }
    }

    LaunchedEffect(previewState.standingsAroundRows) {
        standingsModeIndex = 0
        if (previewState.standingsAroundRows.isEmpty()) {
            return@LaunchedEffect
        }

        while (true) {
            delay(4000)
            standingsModeIndex = (standingsModeIndex + 1) % 2
        }
    }

    return remember(targetMetricIndex, standingsModeIndex, showStatsScore) {
        LeaguePreviewRotationState(
            targetMetricIndex = targetMetricIndex,
            standingsModeIndex = standingsModeIndex,
            showStatsScore = showStatsScore,
        )
    }
}
