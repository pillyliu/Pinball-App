package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.pillyliu.pinprofandroid.ui.AppScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LibraryList(
    contentPadding: PaddingValues,
    isLoading: Boolean,
    errorMessage: String?,
    browseState: LibraryBrowseState,
    visibleCount: Int,
    onVisibleCountChange: (Int) -> Unit,
    scrollState: ScrollState,
    onSourceChange: (String) -> Unit,
    onQueryChange: (String) -> Unit,
    onSortOptionChange: (String) -> Unit,
    onBankChange: (Int?) -> Unit,
    onOpenGame: (PinballGame) -> Unit,
) {
    var showFilterSheet by remember { mutableStateOf(false) }
    val visibleGames = remember(browseState, visibleCount) { browseState.visibleGames(visibleCount) }
    val hasMoreGames = remember(browseState, visibleCount) { browseState.hasMoreGames(visibleCount) }
    val groupedSections = remember(browseState, visibleCount) { browseState.groupedSections(visibleCount) }

    AppScreen(contentPadding) {
        LibraryListContent(
            browseState = browseState,
            isLoading = isLoading,
            errorMessage = errorMessage,
            visibleGames = visibleGames,
            hasMoreGames = hasMoreGames,
            groupedSections = groupedSections,
            visibleCount = visibleCount,
            scrollState = scrollState,
            onVisibleCountChange = onVisibleCountChange,
            onQueryChange = onQueryChange,
            onOpenGame = onOpenGame,
            onShowFilterSheet = { showFilterSheet = true },
        )
    }

    if (showFilterSheet && browseState.games.isNotEmpty()) {
        LibraryFilterSheet(
            browseState = browseState,
            onDismissRequest = { showFilterSheet = false },
            onSourceChange = onSourceChange,
            onSortOptionChange = onSortOptionChange,
            onBankChange = onBankChange,
        )
    }
}
