package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.PinballGame

internal const val PRACTICE_ALL_GAMES_SOURCE_ID = "__practice_all_games__"

internal data class PracticeLibrarySourceSelectionResult(
    val selectedSourceId: String?,
    val visibleGames: List<PinballGame>,
)

internal fun normalizePracticeLibrarySourceId(sourceId: String?): String? {
    return if (sourceId == PRACTICE_ALL_GAMES_SOURCE_ID) null else sourceId
}

internal fun resolvePreferredPracticeSource(
    loaded: PracticeLibraryLoadResult,
    savedSourceId: String?,
): LibrarySource? {
    return listOfNotNull(savedSourceId, loaded.defaultSourceId)
        .firstOrNull { id -> loaded.sources.any { it.id == id } }
        ?.let { id -> loaded.sources.firstOrNull { it.id == id } }
        ?: loaded.sources.firstOrNull()
}

internal fun applyPracticeLibrarySourceSelection(
    sourceId: String?,
    sources: List<LibrarySource>,
    allGames: List<PinballGame>,
): PracticeLibrarySourceSelectionResult {
    val normalized = normalizePracticeLibrarySourceId(sourceId)?.trim().orEmpty()
    val selected = if (normalized.isBlank()) {
        null
    } else {
        sources.firstOrNull { it.id == normalized }
    }
    val visibleGames = if (selected != null) {
        allGames.filter { it.sourceId == selected.id }
    } else {
        allGames
    }
    return PracticeLibrarySourceSelectionResult(
        selectedSourceId = selected?.id,
        visibleGames = visibleGames,
    )
}
