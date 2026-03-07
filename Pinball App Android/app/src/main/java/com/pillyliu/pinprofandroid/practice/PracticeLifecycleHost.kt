package com.pillyliu.pinprofandroid.practice

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.core.content.edit
import com.pillyliu.pinprofandroid.library.youtubeId
import java.util.Locale

@Composable
internal fun PracticeLifecycleHost(
    context: PracticeLifecycleContext,
) {
    val store = context.store
    val uiState = context.uiState
    val gameLookupPool = if (store.allLibraryGames.isNotEmpty()) store.allLibraryGames else store.games

    LaunchedEffect(Unit) {
        store.loadIfNeeded()
        if (store.playerName.isBlank()) {
            uiState.openNamePrompt = true
        }
        uiState.insightsOpponentName = store.comparisonPlayerName
        if (uiState.selectedGameSlug == null) {
            uiState.selectedGameSlug = store.resumeSlugFromLibraryOrPractice()
                ?: orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey
        }
    }

    LaunchedEffect(store.playerName) {
        val names = store.availableLeaguePlayers()
        val normalizedSelf = store.playerName.trim().lowercase(Locale.US)
        uiState.insightsOpponentOptions = names.filter { it.lowercase(Locale.US) != normalizedSelf }
        if (uiState.insightsOpponentName.isNotBlank() && !uiState.insightsOpponentOptions.contains(uiState.insightsOpponentName)) {
            uiState.insightsOpponentName = ""
            store.updateComparisonPlayerName("")
        }
    }

    LaunchedEffect(uiState.selectedGameSlug, store.games, store.allLibraryGames) {
        val lookup = uiState.selectedGameSlug ?: return@LaunchedEffect
        val game = findGameByPracticeLookupKey(gameLookupPool, lookup) ?: return@LaunchedEffect
        uiState.gameSummaryDraft = store.gameSummaryNoteFor(game.practiceKey)
        uiState.activeGameVideoId = game.videos.firstNotNullOfOrNull { video -> youtubeId(video.url) }
    }

    BackHandler(enabled = uiState.route != PracticeRoute.Home) {
        uiState.goBack()
    }

    LaunchedEffect(store.playerName, uiState.insightsOpponentName, uiState.route) {
        if (uiState.route != PracticeRoute.Insights) return@LaunchedEffect
        context.onRefreshHeadToHead()
    }

    LaunchedEffect(context.sourceVersion) {
        if (context.sourceVersion == 0L) return@LaunchedEffect
        store.loadGames()
        if (uiState.selectedGameSlug != null && findGameByPracticeLookupKey(store.games, uiState.selectedGameSlug) == null) {
            uiState.selectedGameSlug = orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey
        }
    }

    LaunchedEffect(uiState.journalFilter) {
        context.prefs.edit { putString(KEY_PRACTICE_JOURNAL_FILTER, uiState.journalFilter.name) }
        uiState.journalSelectionMode = false
        uiState.selectedJournalRowIds = emptySet()
    }
}
