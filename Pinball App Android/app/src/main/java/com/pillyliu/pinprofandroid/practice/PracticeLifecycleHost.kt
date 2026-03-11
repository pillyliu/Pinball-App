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
            uiState.presentation.openNamePrompt = true
        }
        uiState.insights.opponentName = store.comparisonPlayerName
        if (uiState.navigation.selectedGameSlug == null) {
            uiState.navigation.selectedGameSlug = store.resumeSlugFromLibraryOrPractice()
                ?: orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey
        }
    }

    LaunchedEffect(store.playerName) {
        val names = store.availableLeaguePlayers()
        val normalizedSelf = store.playerName.trim().lowercase(Locale.US)
        uiState.insights.opponentOptions = names.filter { it.lowercase(Locale.US) != normalizedSelf }
        if (uiState.insights.opponentName.isNotBlank() && !uiState.insights.opponentOptions.contains(uiState.insights.opponentName)) {
            uiState.insights.opponentName = ""
            store.updateComparisonPlayerName("")
        }
    }

    LaunchedEffect(uiState.navigation.selectedGameSlug, store.games, store.allLibraryGames) {
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
        val refreshedLookupPool = if (store.allLibraryGames.isNotEmpty()) store.allLibraryGames else store.games
        if (uiState.navigation.selectedGameSlug != null &&
            findGameByPracticeLookupKey(refreshedLookupPool, uiState.navigation.selectedGameSlug) == null
        ) {
            uiState.navigation.selectedGameSlug = orderedGamesForDropdown(store.games, collapseByPracticeIdentity = true).firstOrNull()?.practiceKey
        }
    }

    LaunchedEffect(uiState.journal.filter) {
        context.prefs.edit { putString(KEY_PRACTICE_JOURNAL_FILTER, uiState.journal.filter.name) }
        uiState.journal.resetSelection()
    }
}
