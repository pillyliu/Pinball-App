package com.pillyliu.pinballandroid.practice

import android.content.Context
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.library.LibrarySource
import com.pillyliu.pinballandroid.library.LibrarySourceType
import com.pillyliu.pinballandroid.library.PinballGame
import com.pillyliu.pinballandroid.library.loadLibraryExtraction
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal data class PracticeLibraryLoadResult(
    val games: List<PinballGame>,
    val allGames: List<PinballGame>,
    val sources: List<LibrarySource>,
    val defaultSourceId: String?,
)

internal suspend fun loadPracticeGamesFromLibrary(context: Context): PracticeLibraryLoadResult = withContext(Dispatchers.IO) {
    try {
        val extraction = loadLibraryExtraction(context)
        val parsed = extraction.payload
        val selectedSource = parsed.sources.firstOrNull { it.id == extraction.state.selectedSourceId }
            ?: parsed.sources.firstOrNull { it.type == LibrarySourceType.VENUE }
            ?: parsed.sources.firstOrNull()
        if (selectedSource == null) {
            PracticeLibraryLoadResult(
                games = parsed.games,
                allGames = parsed.games,
                sources = parsed.sources,
                defaultSourceId = null,
            )
        } else {
            PracticeLibraryLoadResult(
                games = parsed.games.filter { it.sourceId == selectedSource.id },
                allGames = parsed.games,
                sources = parsed.sources,
                defaultSourceId = selectedSource.id,
            )
        }
    } catch (_: Throwable) {
        PracticeLibraryLoadResult(
            games = emptyList(),
            allGames = emptyList(),
            sources = emptyList(),
            defaultSourceId = null,
        )
    }
}

internal suspend fun loadLeagueTargetsMap(path: String): Map<String, LeagueTargetScores> = withContext(Dispatchers.IO) {
    try {
        val result = PinballDataCache.loadText(path, allowMissing = true)
        val text = result.text ?: return@withContext emptyMap()
        parseLeagueTargets(text)
    } catch (_: Throwable) {
        emptyMap()
    }
}
