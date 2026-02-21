package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.library.LIBRARY_URL
import com.pillyliu.pinballandroid.library.LibrarySourceType
import com.pillyliu.pinballandroid.library.PinballGame
import com.pillyliu.pinballandroid.library.parseLibraryPayload
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal suspend fun loadPracticeGamesFromLibrary(): List<PinballGame> = withContext(Dispatchers.IO) {
    try {
        val cached = PinballDataCache.passthroughOrCachedText(LIBRARY_URL)
        val parsed = parseLibraryPayload(cached.text.orEmpty())
        val selectedSource = parsed.sources.firstOrNull { it.type == LibrarySourceType.VENUE }
            ?: parsed.sources.firstOrNull()
        if (selectedSource == null) {
            parsed.games
        } else {
            parsed.games.filter { it.sourceId == selectedSource.id }
        }
    } catch (_: Throwable) {
        emptyList()
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
