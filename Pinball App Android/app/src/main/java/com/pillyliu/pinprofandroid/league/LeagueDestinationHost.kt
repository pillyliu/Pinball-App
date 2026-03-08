package com.pillyliu.pinprofandroid.league

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import com.pillyliu.pinprofandroid.info.AboutScreen
import com.pillyliu.pinprofandroid.standings.StandingsScreen
import com.pillyliu.pinprofandroid.stats.StatsScreen
import com.pillyliu.pinprofandroid.targets.TargetsScreen

@Composable
fun LeagueDestinationHost(
    destination: LeagueDestination,
    contentPadding: PaddingValues,
    onBack: () -> Unit,
) {
    Box(modifier = androidx.compose.ui.Modifier.fillMaxSize()) {
        when (destination) {
            LeagueDestination.Stats -> StatsScreen(
                contentPadding = contentPadding,
                onBack = onBack,
            )
            LeagueDestination.Standings -> StandingsScreen(
                contentPadding = contentPadding,
                onBack = onBack,
            )
            LeagueDestination.Targets -> TargetsScreen(
                contentPadding = contentPadding,
                onBack = onBack,
            )
            LeagueDestination.AboutLpl -> AboutScreen(
                contentPadding = contentPadding,
            )
        }
    }
}
