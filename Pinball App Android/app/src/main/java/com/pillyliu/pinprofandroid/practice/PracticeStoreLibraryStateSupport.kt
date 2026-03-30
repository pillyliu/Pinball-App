package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.PinballGame

internal data class AppliedPracticeLibraryState(
    val visibleGames: List<PinballGame>,
    val allGames: List<PinballGame>,
    val sources: List<LibrarySource>,
    val defaultSourceId: String?,
    val isFullLibraryScope: Boolean,
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
    )
}
