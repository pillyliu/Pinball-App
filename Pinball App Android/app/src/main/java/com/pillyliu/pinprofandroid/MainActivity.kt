package com.pillyliu.pinprofandroid

import android.os.Bundle
import android.os.Build
import androidx.activity.ComponentActivity
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
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Settings
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.activity.compose.BackHandler
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.data.refreshRedactedPlayersFromCsv
import com.pillyliu.pinprofandroid.gameroom.GameRoomScreen
import com.pillyliu.pinprofandroid.info.AboutScreen
import com.pillyliu.pinprofandroid.league.LeagueDestination
import com.pillyliu.pinprofandroid.league.LeagueDestinationHost
import com.pillyliu.pinprofandroid.league.LeagueScreen
import com.pillyliu.pinprofandroid.library.LibraryScreen
import com.pillyliu.pinprofandroid.practice.PracticeScreen
import com.pillyliu.pinprofandroid.settings.SettingsScreen
import com.pillyliu.pinprofandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinprofandroid.ui.PinballTheme
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import com.pillyliu.pinprofandroid.ui.iosEdgeSwipeBack
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        PinballDataCache.initialize(applicationContext)
        enableEdgeToEdge()
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
    GameRoom,
    Settings;

    val title: String
        get() = when (this) {
            League -> "League"
            Library -> "Library"
            Practice -> "Practice"
            GameRoom -> "GameRoom"
            Settings -> "Settings"
        }

    val icon: ImageVector
        get() = when (this) {
            League -> Icons.Outlined.BarChart
            Library -> Icons.Outlined.AutoStories
            Practice -> Icons.Outlined.SportsEsports
            GameRoom -> Icons.Outlined.Home
            Settings -> Icons.Outlined.Settings
        }
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
        val colors = PinballThemeTokens.colors
        CompositionLocalProvider(LocalBottomBarVisible provides bottomBarVisible) {
            // Prevent system back/edge gestures from exiting the app at the root level.
            // Nested screens can still override this with their own BackHandler.
            BackHandler(enabled = !(selectedTab == PinballTab.League && leagueDestination != null)) {
            }
            BackHandler(enabled = selectedTab == PinballTab.League && leagueDestination != null) {
                leagueDestination = null
            }
            Scaffold(
                modifier = Modifier.fillMaxSize(),
                containerColor = colors.background,
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
                        PinballTab.Settings -> SettingsScreen(contentPadding = paddedForTabBar)
                        PinballTab.Practice -> PracticeScreen(contentPadding = paddedForTabBar)
                        PinballTab.GameRoom -> GameRoomScreen(contentPadding = paddedForTabBar)
                        PinballTab.League -> {
                            when (leagueDestination) {
                                null -> LeagueScreen(
                                    contentPadding = paddedForTabBar,
                                    onOpenDestination = { leagueDestination = it },
                                )
                                else -> LeagueDestinationHost(
                                    destination = leagueDestination!!,
                                    contentPadding = contentPaddingWithExtra(padding, extraBottom = 74.dp),
                                    onBack = { leagueDestination = null },
                                )
                            }
                        }
                        PinballTab.Library -> LibraryScreen(contentPadding = padding)
                    }

                    if (bottomBarVisible.value) {
                        val tabItemColors = NavigationBarItemDefaults.colors(
                            selectedIconColor = colors.shellSelectedContent,
                            selectedTextColor = colors.shellSelectedContent,
                            unselectedIconColor = colors.shellUnselectedContent,
                            unselectedTextColor = colors.shellUnselectedContent,
                            indicatorColor = colors.shellIndicator,
                        )
                        Box(
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .fillMaxWidth()
                                .navigationBarsPadding()
                                .background(colors.shellSurface),
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
                                    icon = { Icon(PinballTab.League.icon, contentDescription = PinballTab.League.title) },
                                    label = { Text(PinballTab.League.title) },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.Library,
                                    onClick = { selectedTab = PinballTab.Library },
                                    icon = { Icon(PinballTab.Library.icon, contentDescription = PinballTab.Library.title) },
                                    label = { Text(PinballTab.Library.title) },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.Practice,
                                    onClick = { selectedTab = PinballTab.Practice },
                                    icon = { Icon(PinballTab.Practice.icon, contentDescription = PinballTab.Practice.title) },
                                    label = { Text(PinballTab.Practice.title) },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.GameRoom,
                                    onClick = { selectedTab = PinballTab.GameRoom },
                                    icon = { Icon(PinballTab.GameRoom.icon, contentDescription = PinballTab.GameRoom.title) },
                                    label = { Text(PinballTab.GameRoom.title) },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.Settings,
                                    onClick = { selectedTab = PinballTab.Settings },
                                    icon = { Icon(PinballTab.Settings.icon, contentDescription = PinballTab.Settings.title) },
                                    label = { Text(PinballTab.Settings.title) },
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
