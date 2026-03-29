package com.pillyliu.pinprofandroid.library

import android.content.res.Configuration
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.ui.AppFullscreenStatusOverlay
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPanelStatusCard
import com.pillyliu.pinprofandroid.ui.AppSearchFilterBar

@Composable
internal fun LibraryListContent(
    browseState: LibraryBrowseState,
    isLoading: Boolean,
    errorMessage: String?,
    visibleGames: List<PinballGame>,
    hasMoreGames: Boolean,
    groupedSections: List<LibraryGroupSection>,
    visibleCount: Int,
    scrollState: ScrollState,
    onVisibleCountChange: (Int) -> Unit,
    onQueryChange: (String) -> Unit,
    onOpenGame: (PinballGame) -> Unit,
    onShowFilterSheet: () -> Unit,
) {
    val isLandscape = LocalConfiguration.current.orientation == Configuration.ORIENTATION_LANDSCAPE
    val searchFontSize = if (isLandscape) 14.sp else 13.sp
    val searchControlMinHeight = 48.dp
    val showGroupedView = browseState.showGroupedView
    val showsLoadingOverlay = isLoading && browseState.games.isEmpty()
    val showsListChrome = browseState.games.isNotEmpty()
    val controlsTopOffset = 2.dp
    val controlsTopInset = 64.dp

    Box(modifier = Modifier.fillMaxSize()) {
        when {
            showsLoadingOverlay -> {
                AppFullscreenStatusOverlay(
                    text = "Loading library…",
                    showsProgress = true,
                )
            }

            browseState.games.isNotEmpty() -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(scrollState)
                        .padding(top = controlsTopInset),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    if (showGroupedView) {
                        groupedSections.forEachIndexed { idx, section ->
                            if (idx > 0) {
                                HorizontalDivider(color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f), thickness = 1.dp)
                            }
                            LibrarySectionGrid(
                                games = section.games,
                                onOpenGame = onOpenGame,
                                onGameAppear = { game ->
                                    if (hasMoreGames && visibleGames.lastOrNull()?.libraryRouteId == game.libraryRouteId) {
                                        onVisibleCountChange(visibleCount + 36)
                                    }
                                },
                            )
                        }
                    } else {
                        LibrarySectionGrid(
                            games = visibleGames,
                            onOpenGame = onOpenGame,
                            onGameAppear = { game ->
                                if (hasMoreGames && visibleGames.lastOrNull()?.libraryRouteId == game.libraryRouteId) {
                                    onVisibleCountChange(visibleCount + 36)
                                }
                            },
                        )
                    }
                    Spacer(Modifier.height(LIBRARY_CONTENT_BOTTOM_FILLER))
                }
            }

            else -> {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    when {
                        !errorMessage.isNullOrBlank() -> AppPanelStatusCard(
                            text = errorMessage,
                            isError = true,
                        )
                        else -> AppPanelEmptyCard(text = "No data loaded.")
                    }
                }
            }
        }

        if (showsListChrome) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = controlsTopOffset),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                AppSearchFilterBar(
                    query = browseState.query,
                    onQueryChange = onQueryChange,
                    placeholder = "Search games...",
                    onFilterClick = onShowFilterSheet,
                    minHeight = searchControlMinHeight,
                    textStyle = MaterialTheme.typography.bodyMedium.copy(fontSize = searchFontSize),
                    placeholderTextStyle = MaterialTheme.typography.bodyMedium.copy(fontSize = searchFontSize),
                )
            }
        }
    }
}
