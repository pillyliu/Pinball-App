package com.pillyliu.pinballandroid

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoStories
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.library.LibraryScreen
import com.pillyliu.pinballandroid.standings.StandingsScreen
import com.pillyliu.pinballandroid.stats.StatsScreen
import com.pillyliu.pinballandroid.targets.TargetsScreen
import com.pillyliu.pinballandroid.ui.LocalBottomBarVisible

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        PinballDataCache.initialize(applicationContext)
        enableEdgeToEdge()
        setContent { PinballApp() }
    }

    override fun onResume() {
        super.onResume()
        PinballDataCache.requestMetadataRefresh(force = true)
    }
}

private enum class PinballTab(val title: String) {
    Stats("Stats"),
    Standings("Standings"),
    Targets("Targets"),
    Library("Library")
}

@Composable
private fun PinballApp() {
    var selectedTab by rememberSaveable { mutableStateOf(PinballTab.Stats) }
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
                bottomBar = {
                    if (!bottomBarVisible.value) return@Scaffold
                    val tabItemColors = NavigationBarItemDefaults.colors(
                        selectedIconColor = Color.White,
                        selectedTextColor = Color.White,
                        unselectedIconColor = Color(0xFFD0D0D0),
                        unselectedTextColor = Color(0xFFD0D0D0),
                        indicatorColor = Color.White.copy(alpha = 0.14f),
                    )
                    NavigationBar(
                        containerColor = Color.Black.copy(alpha = 0.68f),
                        modifier = Modifier.height(58.dp),
                        windowInsets = WindowInsets(0, 0, 0, 0),
                    ) {
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
            ) { padding ->
                when (selectedTab) {
                    PinballTab.Stats -> StatsScreen(contentPadding = padding)
                    PinballTab.Standings -> StandingsScreen(contentPadding = padding)
                    PinballTab.Targets -> TargetsScreen(contentPadding = padding)
                    PinballTab.Library -> LibraryScreen(contentPadding = padding)
                }
            }
        }
    }
}
