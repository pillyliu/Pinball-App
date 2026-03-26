package com.pillyliu.pinprofandroid.practice

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import com.pillyliu.pinprofandroid.library.youtubeId
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import java.util.Locale

@Composable
internal fun PracticeLifecycleHost(
    context: PracticeLifecycleContext,
) {
    val store = context.store
    val uiState = context.uiState
    val lifecycleResumed = rememberLifecycleResumed()
    val gameLookupPool = when {
        store.searchCatalogGames.isNotEmpty() && store.allLibraryGames.isNotEmpty() -> store.allLibraryGames + store.searchCatalogGames
        store.searchCatalogGames.isNotEmpty() -> store.games + store.searchCatalogGames
        store.allLibraryGames.isNotEmpty() -> store.allLibraryGames
        else -> store.games
    }

    LaunchedEffect(Unit) {
        store.loadIfNeeded()
        store.autoImportLeagueScoresIfEnabled()?.let { result ->
            uiState.presentation.importStatus = result.summaryLine
        }
        if (store.playerName.isBlank()) {
            uiState.presentation.openNamePrompt = true
        }
        uiState.insights.opponentName = store.comparisonPlayerName
        if (uiState.navigation.selectedGameSlug == null) {
            uiState.navigation.selectedGameSlug = store.resumeSlugFromLibraryOrPractice()
                ?: orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true)
                    .firstOrNull()
                    ?.let { preferredPracticeSelectionKey(it, store.defaultPracticeSourceId, store.librarySources) }
        }
    }

    LaunchedEffect(lifecycleResumed) {
        if (!lifecycleResumed) return@LaunchedEffect
        store.autoImportLeagueScoresIfEnabled()?.let { result ->
            uiState.presentation.importStatus = result.summaryLine
        }
    }

    LaunchedEffect(store.playerName, uiState.navigation.route) {
        if (uiState.navigation.route != PracticeRoute.Insights) return@LaunchedEffect
        val names = store.availableLeaguePlayers()
        val normalizedSelf = store.playerName.trim().lowercase(Locale.US)
        uiState.insights.opponentOptions = names.filter { it.lowercase(Locale.US) != normalizedSelf }
        if (uiState.insights.opponentName.isNotBlank() && !uiState.insights.opponentOptions.contains(uiState.insights.opponentName)) {
            uiState.insights.opponentName = ""
            store.updateComparisonPlayerName("")
        }
    }

    LaunchedEffect(uiState.navigation.selectedGameSlug, store.games, store.allLibraryGames, store.searchCatalogGames) {
        val lookup = uiState.navigation.selectedGameSlug ?: return@LaunchedEffect
        val game = findGameByPracticeLookupKey(gameLookupPool, lookup) ?: return@LaunchedEffect
        uiState.game.summaryDraft = store.gameSummaryNoteFor(game.practiceKey)
        uiState.game.activeVideoId = game.videos.firstNotNullOfOrNull { video -> youtubeId(video.url) }
    }

    BackHandler(enabled = uiState.navigation.route != PracticeRoute.Home) {
        uiState.goBack()
    }

    LaunchedEffect(store.playerName, uiState.insights.opponentName, uiState.navigation.route) {
        if (uiState.navigation.route != PracticeRoute.Insights) return@LaunchedEffect
        context.onRefreshHeadToHead()
    }

    LaunchedEffect(context.sourceVersion) {
        if (context.sourceVersion == 0L) return@LaunchedEffect
        store.loadGames()
        val refreshedLookupPool = when {
            store.searchCatalogGames.isNotEmpty() && store.allLibraryGames.isNotEmpty() -> store.allLibraryGames + store.searchCatalogGames
            store.searchCatalogGames.isNotEmpty() -> store.games + store.searchCatalogGames
            store.allLibraryGames.isNotEmpty() -> store.allLibraryGames
            else -> store.games
        }
        if (uiState.navigation.selectedGameSlug != null &&
            findGameByPracticeLookupKey(refreshedLookupPool, uiState.navigation.selectedGameSlug) == null
        ) {
            uiState.navigation.selectedGameSlug = orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true)
                .firstOrNull()
                ?.let { preferredPracticeSelectionKey(it, store.defaultPracticeSourceId, store.librarySources) }
        }
    }

    LaunchedEffect(uiState.journal.filter) {
        context.prefs.edit { putString(KEY_PRACTICE_JOURNAL_FILTER, uiState.journal.filter.name) }
        uiState.journal.resetSelection()
    }
}

@Composable
private fun rememberLifecycleResumed(): Boolean {
    val lifecycleOwner = LocalLifecycleOwner.current
    var resumed by remember(lifecycleOwner) {
        mutableStateOf(lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED))
    }

    DisposableEffect(lifecycleOwner) {
        val lifecycle = lifecycleOwner.lifecycle
        val observer = LifecycleEventObserver { _, _ ->
            resumed = lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    return resumed
}
