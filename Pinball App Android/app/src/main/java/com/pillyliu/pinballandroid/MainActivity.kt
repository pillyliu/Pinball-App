package com.pillyliu.pinballandroid

import android.graphics.Color as AndroidColor
import android.os.Bundle
import android.os.Build
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
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.FormatListNumbered
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.data.refreshRedactedPlayersFromCsv
import com.pillyliu.pinballandroid.info.AboutScreen
import com.pillyliu.pinballandroid.library.LibraryScreen
import com.pillyliu.pinballandroid.standings.StandingsScreen
import com.pillyliu.pinballandroid.stats.StatsScreen
import com.pillyliu.pinballandroid.targets.TargetsScreen
import com.pillyliu.pinballandroid.ui.LocalBottomBarVisible
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        PinballDataCache.initialize(applicationContext)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(AndroidColor.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(AndroidColor.TRANSPARENT),
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
    About,
    Stats,
    Standings,
    Targets,
    Library,
}

@Composable
private fun contentPaddingWithExtraBottom(base: androidx.compose.foundation.layout.PaddingValues, extraBottom: Dp): androidx.compose.foundation.layout.PaddingValues {
    val layoutDirection = LocalLayoutDirection.current
    return androidx.compose.foundation.layout.PaddingValues(
        start = base.calculateStartPadding(layoutDirection),
        top = base.calculateTopPadding(),
        end = base.calculateEndPadding(layoutDirection),
        bottom = base.calculateBottomPadding() + extraBottom,
    )
}

@Composable
private fun PinballApp() {
    var selectedTab by rememberSaveable { mutableStateOf(PinballTab.About) }
    val bottomBarVisible = rememberSaveable { mutableStateOf(true) }
    val appColorScheme = darkColorScheme(
        primary = Color.White,
        secondary = Color.White,
        tertiary = Color.White,
        onPrimary = Color.Black,
        onSecondary = Color.Black,
        onTertiary = Color.Black,
    )

    MaterialTheme(colorScheme = appColorScheme) {
        CompositionLocalProvider(LocalBottomBarVisible provides bottomBarVisible) {
            Scaffold(
                modifier = Modifier.fillMaxSize(),
                containerColor = Color.Black,
            ) { padding ->
                Box(modifier = Modifier.fillMaxSize()) {
                    val paddedForTabBar = contentPaddingWithExtraBottom(padding, 74.dp)
                    when (selectedTab) {
                        PinballTab.About -> AboutScreen(contentPadding = paddedForTabBar)
                        PinballTab.Stats -> StatsScreen(contentPadding = paddedForTabBar)
                        PinballTab.Standings -> StandingsScreen(contentPadding = paddedForTabBar)
                        PinballTab.Targets -> TargetsScreen(contentPadding = paddedForTabBar)
                        PinballTab.Library -> LibraryScreen(contentPadding = padding)
                    }
                    if (bottomBarVisible.value) {
                        val tabItemColors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Color.White,
                            selectedTextColor = Color.White,
                            unselectedIconColor = Color(0xFFD0D0D0),
                            unselectedTextColor = Color(0xFFD0D0D0),
                            indicatorColor = Color.White.copy(alpha = 0.14f),
                        )
                        Box(
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .fillMaxWidth()
                                .navigationBarsPadding()
                                .background(
                                    Brush.verticalGradient(
                                        colors = listOf(
                                            Color.Black.copy(alpha = 0.5f),
                                            Color.Black.copy(alpha = 0.85f),
                                        ),
                                    ),
                                ),
                        ) {
                            NavigationBar(
                                containerColor = Color.Transparent,
                                tonalElevation = 0.dp,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(bottom = 8.dp)
                                    .height(66.dp),
                                windowInsets = WindowInsets(0, 0, 0, 0),
                            ) {
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.About,
                                    onClick = { selectedTab = PinballTab.About },
                                    icon = { Icon(Icons.Outlined.Info, contentDescription = "About") },
                                    label = { Text("About") },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.Stats,
                                    onClick = { selectedTab = PinballTab.Stats },
                                    icon = { Icon(Icons.Outlined.BarChart, contentDescription = "Stats") },
                                    label = { Text("Stats") },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.Standings,
                                    onClick = { selectedTab = PinballTab.Standings },
                                    icon = { Icon(Icons.Outlined.FormatListNumbered, contentDescription = "Standings") },
                                    label = { Text("Standings") },
                                    alwaysShowLabel = false,
                                    colors = tabItemColors,
                                )
                                NavigationBarItem(
                                    selected = selectedTab == PinballTab.Targets,
                                    onClick = { selectedTab = PinballTab.Targets },
                                    icon = { Icon(Icons.Outlined.Flag, contentDescription = "Targets") },
                                    label = { Text("Targets") },
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
                            }
                        }
                    }
                }
            }
        }
    }
}
