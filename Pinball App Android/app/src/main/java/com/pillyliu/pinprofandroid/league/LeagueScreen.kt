package com.pillyliu.pinprofandroid.league

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.FormatListNumbered
import androidx.compose.material.icons.outlined.Info
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.pillyliu.pinprofandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinprofandroid.ui.AppScreen
enum class LeagueDestination(val title: String, val subtitle: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Stats("Stats", "Player trends and machine performance", Icons.Outlined.BarChart),
    Standings("Standings", "Season standings and points view", Icons.Outlined.FormatListNumbered),
    Targets("Targets", "Great game, main target, and floor goals", Icons.Outlined.Flag),
    AboutLpl("About Lansing Pinball League", "League info and links", Icons.Outlined.Info),
    ;

    companion object {
        val primaryDestinations: List<LeagueDestination> = listOf(Stats, Standings, Targets)
        val footerDestination: LeagueDestination = AboutLpl
    }
}

@Composable
fun LeagueScreen(
    contentPadding: PaddingValues,
    onOpenDestination: (LeagueDestination) -> Unit,
) {
    val context = LocalContext.current
    val showFullLplLastName = rememberShowFullLplLastName()
    val previewVersion by LeaguePreviewRefreshEvents.version.collectAsState()
    val previewState by produceState(initialValue = LeaguePreviewState(), key1 = previewVersion) {
        value = loadLeaguePreviewState(context)
    }
    val previewRotation = rememberLeaguePreviewRotationState(previewState)

    AppScreen(contentPadding) {
        LeagueShellContent(
            previewState = previewState,
            previewRotation = previewRotation,
            showFullLplLastName = showFullLplLastName,
            onOpenDestination = onOpenDestination,
        )
    }
}
