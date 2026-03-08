package com.pillyliu.pinprofandroid

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoStories
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.SportsEsports
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.gameroom.GameRoomCatalogLoader
import com.pillyliu.pinprofandroid.gameroom.GameRoomPinsideImportService
import com.pillyliu.pinprofandroid.gameroom.GameRoomScreen
import com.pillyliu.pinprofandroid.gameroom.GameRoomStore
import com.pillyliu.pinprofandroid.league.LeagueDestination
import com.pillyliu.pinprofandroid.league.LeagueDestinationHost
import com.pillyliu.pinprofandroid.league.LeagueScreen
import com.pillyliu.pinprofandroid.library.LibraryScreen
import com.pillyliu.pinprofandroid.practice.PracticeScreen
import com.pillyliu.pinprofandroid.practice.PracticeStore
import com.pillyliu.pinprofandroid.settings.SettingsScreen
import com.pillyliu.pinprofandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinprofandroid.ui.PinballTheme
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import com.pillyliu.pinprofandroid.ui.iosEdgeSwipeBack

private enum class PinballTab(
    val title: String,
    val icon: ImageVector,
) {
    League("League", Icons.Outlined.BarChart),
    Library("Library", Icons.Outlined.AutoStories),
    Practice("Practice", Icons.Outlined.SportsEsports),
    GameRoom("GameRoom", Icons.Outlined.Home),
    Settings("Settings", Icons.Outlined.Settings),
}

@Composable
private fun contentPaddingWithExtra(
    base: PaddingValues,
    extraTop: Dp = 0.dp,
    extraBottom: Dp = 0.dp,
): PaddingValues {
    val layoutDirection = LocalLayoutDirection.current
    return PaddingValues(
        start = base.calculateStartPadding(layoutDirection),
        top = base.calculateTopPadding() + extraTop,
        end = base.calculateEndPadding(layoutDirection),
        bottom = base.calculateBottomPadding() + extraBottom,
    )
}

@Composable
fun PinballApp() {
    var selectedTab by rememberSaveable { mutableStateOf(PinballTab.League) }
    var leagueDestination by rememberSaveable { mutableStateOf<LeagueDestination?>(null) }
    val bottomBarVisible = rememberSaveable { mutableStateOf(true) }
    PinballTheme {
        CompositionLocalProvider(LocalBottomBarVisible provides bottomBarVisible) {
            PinballShell(
                selectedTab = selectedTab,
                onSelectTab = { tab ->
                    selectedTab = tab
                    if (tab == PinballTab.League) {
                        leagueDestination = null
                    }
                },
                leagueDestination = leagueDestination,
                onOpenLeagueDestination = { leagueDestination = it },
                onBackFromLeagueDestination = { leagueDestination = null },
                bottomBarVisible = bottomBarVisible,
            )
        }
    }
}

@Composable
private fun PinballShell(
    selectedTab: PinballTab,
    onSelectTab: (PinballTab) -> Unit,
    leagueDestination: LeagueDestination?,
    onOpenLeagueDestination: (LeagueDestination) -> Unit,
    onBackFromLeagueDestination: () -> Unit,
    bottomBarVisible: MutableState<Boolean>,
) {
    val spacing = PinballThemeTokens.spacing
    BackHandler(enabled = !(selectedTab == PinballTab.League && leagueDestination != null)) {
    }
    BackHandler(enabled = selectedTab == PinballTab.League && leagueDestination != null) {
        onBackFromLeagueDestination()
    }
    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = PinballThemeTokens.colors.background,
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .iosEdgeSwipeBack(
                    enabled = selectedTab == PinballTab.League && leagueDestination != null,
                    onBack = onBackFromLeagueDestination,
                ),
        ) {
            val paddedForTabBar = contentPaddingWithExtra(
                base = padding,
                extraBottom = spacing.shellContentBottomInset,
            )
            PinballShellContent(
                selectedTab = selectedTab,
                leagueDestination = leagueDestination,
                contentPadding = padding,
                contentPaddingWithBottomBar = paddedForTabBar,
                onOpenLeagueDestination = onOpenLeagueDestination,
                onBackFromLeagueDestination = onBackFromLeagueDestination,
            )
            if (bottomBarVisible.value) {
                PinballBottomBar(
                    selectedTab = selectedTab,
                    onSelectTab = onSelectTab,
                    modifier = Modifier.align(Alignment.BottomCenter),
                )
            }
        }
    }
}

@Composable
private fun PinballShellContent(
    selectedTab: PinballTab,
    leagueDestination: LeagueDestination?,
    contentPadding: PaddingValues,
    contentPaddingWithBottomBar: PaddingValues,
    onOpenLeagueDestination: (LeagueDestination) -> Unit,
    onBackFromLeagueDestination: () -> Unit,
) {
    val appContext = LocalContext.current.applicationContext
    val practiceStore = remember(appContext) { PracticeStore(appContext) }
    val gameRoomStore = remember(appContext) { GameRoomStore(appContext) }
    val gameRoomCatalogLoader = remember(appContext) { GameRoomCatalogLoader(appContext) }
    val gameRoomPinsideImportService = remember(appContext) { GameRoomPinsideImportService(appContext) }
    when (selectedTab) {
        PinballTab.Settings -> SettingsScreen(contentPadding = contentPaddingWithBottomBar)
        PinballTab.Practice -> PracticeScreen(
            contentPadding = contentPaddingWithBottomBar,
            externalStore = practiceStore,
        )
        PinballTab.GameRoom -> GameRoomScreen(
            contentPadding = contentPaddingWithBottomBar,
            externalStore = gameRoomStore,
            externalCatalogLoader = gameRoomCatalogLoader,
            externalPinsideImportService = gameRoomPinsideImportService,
        )
        PinballTab.Library -> LibraryScreen(contentPadding = contentPadding)
        PinballTab.League -> {
            when (leagueDestination) {
                null -> LeagueScreen(
                    contentPadding = contentPaddingWithBottomBar,
                    onOpenDestination = onOpenLeagueDestination,
                )
                else -> LeagueDestinationHost(
                    destination = leagueDestination,
                    contentPadding = contentPaddingWithExtra(
                        base = contentPadding,
                        extraBottom = PinballThemeTokens.spacing.shellContentBottomInset,
                    ),
                    onBack = onBackFromLeagueDestination,
                )
            }
        }
    }
}

@Composable
private fun PinballBottomBar(
    selectedTab: PinballTab,
    onSelectTab: (PinballTab) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    val spacing = PinballThemeTokens.spacing
    val typography = PinballThemeTokens.typography
    val tabItemColors = NavigationBarItemDefaults.colors(
        selectedIconColor = colors.shellSelectedContent,
        selectedTextColor = colors.shellSelectedContent,
        unselectedIconColor = colors.shellUnselectedContent,
        unselectedTextColor = colors.shellUnselectedContent,
        indicatorColor = colors.shellIndicator,
    )
    Box(
        modifier = modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .background(colors.shellSurface),
    ) {
        NavigationBar(
            containerColor = Color.Transparent,
            tonalElevation = 3.dp,
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = spacing.shellBottomPadding)
                .height(spacing.shellBarHeight),
            windowInsets = WindowInsets(0, 0, 0, 0),
        ) {
            PinballTab.entries.forEach { tab ->
                NavigationBarItem(
                    selected = selectedTab == tab,
                    onClick = { onSelectTab(tab) },
                    icon = { Icon(tab.icon, contentDescription = tab.title) },
                    label = { Text(tab.title, style = typography.shellLabel) },
                    alwaysShowLabel = false,
                    colors = tabItemColors,
                )
            }
        }
    }
}
