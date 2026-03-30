package com.pillyliu.pinprofandroid.practice

import android.content.SharedPreferences
import com.pillyliu.pinprofandroid.library.PinballGame

internal data class PracticeStoredReferenceLoadRequirements(
    val needsBankTemplateGames: Boolean,
    val needsSearchCatalogGames: Boolean,
    val needsAllLibraryGames: Boolean,
)

internal fun practiceStoredReferenceLoadRequirements(
    groups: List<PracticeGroup>,
    scores: List<ScoreEntry>,
    notes: List<NoteEntry>,
    journal: List<JournalEntry>,
    rulesheetProgress: Map<String, Float>,
    gameSummaryNotes: Map<String, String>,
    canonicalState: CanonicalPracticePersistedState,
    prefs: SharedPreferences,
    quickGamePrefKeys: List<String>,
    searchCatalogGamesLoaded: Boolean,
    fullLibraryLoaded: Boolean,
    gameResolver: (String) -> PinballGame?,
): PracticeStoredReferenceLoadRequirements {
    val referenceIds = practiceStoredReferenceIds(
        groups = groups,
        scores = scores,
        notes = notes,
        journal = journal,
        rulesheetProgress = rulesheetProgress,
        gameSummaryNotes = gameSummaryNotes,
        canonicalState = canonicalState,
        prefs = prefs,
        quickGamePrefKeys = quickGamePrefKeys,
    )

    return PracticeStoredReferenceLoadRequirements(
        needsBankTemplateGames = practiceNeedsBankTemplateGamesForReferences(
            referenceIds = referenceIds,
            gameResolver = gameResolver,
        ),
        needsSearchCatalogGames = practiceNeedsSearchCatalogForReferences(
            referenceIds = referenceIds,
            searchCatalogGamesLoaded = searchCatalogGamesLoaded,
            gameResolver = gameResolver,
        ),
        needsAllLibraryGames = practiceNeedsAllLibraryGamesForReferences(
            referenceIds = referenceIds,
            fullLibraryLoaded = fullLibraryLoaded,
            gameResolver = gameResolver,
        ),
    )
}

internal fun practiceRequiresCanonicalSaveAfterInitialLoad(
    loadedState: LoadedPracticeStatePayload?,
    migratedLoadedState: Boolean,
): Boolean {
    return loadedState?.requiresCanonicalSave == true && !migratedLoadedState
}
