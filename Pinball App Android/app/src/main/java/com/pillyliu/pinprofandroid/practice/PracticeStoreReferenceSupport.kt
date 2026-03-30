package com.pillyliu.pinprofandroid.practice

import android.content.SharedPreferences
import com.pillyliu.pinprofandroid.library.PM_AVENUE_LIBRARY_SOURCE_ID
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.canonicalLibrarySourceId

internal fun practiceStoredReferenceIds(
    groups: List<PracticeGroup>,
    scores: List<ScoreEntry>,
    notes: List<NoteEntry>,
    journal: List<JournalEntry>,
    rulesheetProgress: Map<String, Float>,
    gameSummaryNotes: Map<String, String>,
    canonicalState: CanonicalPracticePersistedState,
    prefs: SharedPreferences,
    quickGamePrefKeys: List<String>,
): List<String> {
    val preferenceKeys = listOf(
        KEY_PRACTICE_LAST_VIEWED_SLUG,
        KEY_LIBRARY_LAST_VIEWED_SLUG,
    ) + quickGamePrefKeys

    return buildList {
        addAll(groups.flatMap { it.gameSlugs })
        addAll(scores.map { it.gameSlug })
        addAll(notes.map { it.gameSlug })
        addAll(journal.map { it.gameSlug })
        addAll(rulesheetProgress.keys)
        addAll(gameSummaryNotes.keys)
        addAll(canonicalState.rulesheetResumeOffsets.keys)
        addAll(canonicalState.videoResumeHints.keys)
        addAll(canonicalState.gameSummaryNotes.keys)
        preferenceKeys.forEach { key ->
            prefs.getString(key, null)?.let(::add)
        }
    }
}

internal fun practiceNeedsBankTemplateGamesForReferences(
    referenceIds: List<String>,
    gameResolver: (String) -> PinballGame?,
): Boolean {
    return referenceIds.any { raw ->
        val trimmed = raw.trim()
        if (trimmed.isBlank()) return@any false
        val parsed = parseSourceScopedPracticeGameID(trimmed)
        parsed.sourceID != null && gameResolver(trimmed) == null
    }
}

internal fun practiceNeedsSearchCatalogForReferences(
    referenceIds: List<String>,
    searchCatalogGamesLoaded: Boolean,
    gameResolver: (String) -> PinballGame?,
): Boolean {
    if (searchCatalogGamesLoaded) return false

    return referenceIds.any { raw ->
        val trimmed = raw.trim()
        if (trimmed.isBlank()) return@any false
        val parsed = parseSourceScopedPracticeGameID(trimmed)
        if (parsed.sourceID != null) return@any false
        gameResolver(trimmed) == null
    }
}

internal fun practiceNeedsAllLibraryGamesForReferences(
    referenceIds: List<String>,
    fullLibraryLoaded: Boolean,
    gameResolver: (String) -> PinballGame?,
): Boolean {
    if (fullLibraryLoaded) return false

    return referenceIds.any { raw ->
        val trimmed = raw.trim()
        if (trimmed.isBlank()) return@any false
        val parsed = parseSourceScopedPracticeGameID(trimmed)
        val sourceId = canonicalLibrarySourceId(parsed.sourceID)
        if (sourceId == null || sourceId == PM_AVENUE_LIBRARY_SOURCE_ID) return@any false
        gameResolver(trimmed) == null
    }
}
