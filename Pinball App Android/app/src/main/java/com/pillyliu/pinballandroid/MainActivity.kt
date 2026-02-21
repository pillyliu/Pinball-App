package com.pillyliu.pinballandroid

import android.graphics.Color as AndroidColor
import android.os.Bundle
import android.os.Build
import android.content.res.Configuration
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.background
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoStories
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.activity.compose.BackHandler
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.data.refreshRedactedPlayersFromCsv
import com.pillyliu.pinballandroid.info.AboutScreen
import com.pillyliu.pinballandroid.league.LeagueDestination
import com.pillyliu.pinballandroid.league.LeagueScreen
import com.pillyliu.pinballandroid.library.LibraryScreen
import com.pillyliu.pinballandroid.practice.PracticeScreen
import com.pillyliu.pinballandroid.standings.StandingsScreen
import com.pillyliu.pinballandroid.stats.StatsScreen
import com.pillyliu.pinballandroid.targets.TargetsScreen
import com.pillyliu.pinballandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinballandroid.ui.PinballTheme
import com.pillyliu.pinballandroid.ui.iosEdgeSwipeBack
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        PinballDataCache.initialize(applicationContext)
        val detectDarkMode = {
            (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        }
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.auto(
                AndroidColor.TRANSPARENT,
                AndroidColor.TRANSPARENT,
            ) { detectDarkMode() },
            navigationBarStyle = SystemBarStyle.auto(
                AndroidColor.TRANSPARENT,
                AndroidColor.TRANSPARENT,
            ) { detectDarkMode() },
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        lifecycleScope.launch {
            refreshRedactedPlayersFromCsv()
        }
        setContent { PinballApp() }
    }

    override fun onResume() {
        super.onResume()
        PinballDataCache.requestMetadataRefresh(force = true)
        lifecycleScope.launch {
            refreshRedactedPlayersFromCsv()
        }
    }
}

private enum class PinballTab {
    League,
    Library,
    Practice,
    About,
}

@Composable
private fun contentPaddingWithExtra(
    base: androidx.compose.foundation.layout.PaddingValues,
    extraTop: Dp = 0.dp,
    extraBottom: Dp = 0.dp,
): androidx.compose.foundation.layout.PaddingValues {
    val layoutDirection = LocalLayoutDirection.current
    return androidx.compose.foundation.layout.PaddingValues(
        start = base.calculateStartPadding(layoutDirection),
        top = base.calculateTopPadding() + extraTop,
        end = base.calculateEndPadding(layoutDirection),
        bottom = base.calculateBottomPadding() + extraBottom,
    )
}

@Composable
private fun PinballApp() {
    var selectedTab by rememberSaveable { mutableStateOf(PinballTab.League) }
    var leagueDestination by rememberSaveable { mutableStateOf<LeagueDestination?>(null) }
    val bottomBarVisible = rememberSaveable { mutableStateOf(true) }
    PinballTheme {
        CompositionLocalProvider(LocalBottomBarVisible provides bottomBarVisible) {
            BackHandler(enabled = selectedTab == PinballTab.League && leagueDestination != null) {
                leagueDestination = null
            }
            Scaffold(
                modifier = Modifier.fillMaxSize(),
                containerColor = MaterialTheme.colorScheme.background,
            ) { padding ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .iosEdgeSwipeBack(
                            enabled = selectedTab == PinballTab.League && leagueDestination != null,
                            onBack = { leagueDestination = null },
                        ),
                ) {
                    val paddedForTabBar = contentPaddingWithExtra(padding, extraBottom = 74.dp)
                    when (selectedTab) {
                        PinballTab.About -> AboutScreen(contentPadding = paddedForTabBar)
                        PinballTab.Practice -> PracticeScreen(contentPadding = paddedForTabBar)
                        PinballTab.League -> {
                            when (leagueDestination) {
                                null -> LeagueScreen(
                                    contentPadding = paddedForTabBar,
                                    onOpenDestination = { leagueDestination = it },
                                )
                                LeagueDestination.Stats -> Box(modifier = Modifier.fillMaxSize()) {
                                    StatsScreen(
                                        contentPadding = contentPaddingWithExtra(padding, extraBottom = 74.dp),
                                        onBack = { leagueDestination = null },
                                    )
                                }
                                LeagueDestination.Standings -> Box(modifier = Modifier.fillMaxSize()) {
                                    StandingsScreen(
                                        contentPadding = contentPaddingWithExtra(padding, extraBottom = 74.dp),
                                        onBack = { leagueDestination = null },
                                    )
                                }
                                LeagueDestination.Targets -> Box(modifier = Modifier.fillMaxSize()) {
                                    TargetsScreen(
                                        contentPadding = contentPaddingWithExtra(padding, extraBottom = 74.dp),
                                        onBack = { leagueDestination = null },
                                    )
                                }
                            }
                        }
                        PinballTab.Library -> LibraryScreen(contentPadding = padding)
                    }

                    if (bottomBarVisible.value) {
                        val tabItemColors = NavigationBarItemDefaults.colors(
                            selectedIconColor = MaterialTheme.colorScheme.onSecondaryContainer,
                            selectedTextColor = MaterialTheme.colorScheme.onSecondaryContainer,
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            indicatorColor = MaterialTheme.colorScheme.secondaryContainer,
                        )
                        Box(
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .fillMaxWidth()
                                .navigationBarsPadding()
                                .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.94f)),
                        ) {
                            NavigationBar(
                                containerColor = Color.Transparent,
                                tonalElevation = 3.dp,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(bottom = 8.dp)
                                    .height(66.dp),
                                windowInsets = WindowInsets(0, 0, 0, 0),
                            ) {
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.League,
                                    onClick = {
                                        selectedTab = PinballTab.League
                                        leagueDestination = null
                                    },
                                    icon = { Icon(Icons.Outlined.BarChart, contentDescription = "League") },
                                    label = { Text("League") },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.Library,
                                    onClick = { selectedTab = PinballTab.Library },
                                    icon = { Icon(Icons.Outlined.AutoStories, contentDescription = "Library") },
                                    label = { Text("Library") },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.Practice,
                                    onClick = { selectedTab = PinballTab.Practice },
                                    icon = { Icon(Icons.Outlined.SportsEsports, contentDescription = "Practice") },
                                    label = { Text("Practice") },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.About,
                                    onClick = {
                                        selectedTab = PinballTab.About
                                    },
                                    icon = { Icon(Icons.Outlined.Info, contentDescription = "About") },
                                    label = { Text("About") },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
