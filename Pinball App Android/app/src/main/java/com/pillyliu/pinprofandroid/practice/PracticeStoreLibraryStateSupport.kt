package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.PinballGame

internal data class AppliedPracticeLibraryState(
    val visibleGames: List<PinballGame>,
    val allGames: List<PinballGame>,
    val sources: List<LibrarySource>,
    val defaultSourceId: String?,
    val isFullLibraryScope: Boolean,
    val persistedSelectedSourceId: String?,
)

internal data class AppliedPracticeLibrarySelectionState(
    val visibleGames: List<PinballGame>,
    val selectedSourceId: String?,
)

internal fun appliedPracticeLibraryState(
    libraryState: PracticeLibraryStoreState,
): AppliedPracticeLibraryState {
    return AppliedPracticeLibraryState(
        visibleGames = libraryState.visibleGames,
        allGames = libraryState.allGames,
        sources = libraryState.sources,
        defaultSourceId = libraryState.defaultSourceId,
        isFullLibraryScope = libraryState.isFullLibraryScope,
        persistedSelectedSourceId = libraryState.defaultSourceId,
    )
}

internal fun appliedPracticeLibrarySelectionState(
    sourceId: String?,
    currentVisibleGames: List<PinballGame>,
    allGames: List<PinballGame>,
    sources: List<LibrarySource>,
): AppliedPracticeLibrarySelectionState {
    val pool = if (allGames.isNotEmpty()) allGames else currentVisibleGames
    val selection = applyPracticeLibrarySourceSelection(
        sourceId = sourceId,
        sources = sources,
        allGames = pool,
    )
    return AppliedPracticeLibrarySelectionState(
        visibleGames = selection.visibleGames,
        selectedSourceId = selection.selectedSourceId,
    )
}
