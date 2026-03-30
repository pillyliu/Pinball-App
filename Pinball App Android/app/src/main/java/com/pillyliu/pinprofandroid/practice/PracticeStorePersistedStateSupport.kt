package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.PinballGame

internal data class AppliedPracticeStorePersistedState(
    val canonicalState: CanonicalPracticePersistedState,
    val rulesheetResumeOffsets: Map<String, Double>,
    val runtimeState: PracticePersistedState,
)

internal data class AppliedPracticeHomeBootstrapState(
    val canonicalState: CanonicalPracticePersistedState,
    val rulesheetResumeOffsets: Map<String, Double>,
    val runtimeState: PracticePersistedState,
    val visibleGames: List<PinballGame>,
    val lookupGames: List<PinballGame>,
    val librarySources: List<LibrarySource>,
    val selectedLibrarySourceId: String?,
    val hasUsableSnapshot: Boolean,
)

internal fun appliedPracticeStorePersistedState(
    canonicalState: CanonicalPracticePersistedState,
    runtimeState: PracticePersistedState,
): AppliedPracticeStorePersistedState {
    return AppliedPracticeStorePersistedState(
        canonicalState = canonicalState,
        rulesheetResumeOffsets = canonicalState.rulesheetResumeOffsets,
        runtimeState = runtimeState,
    )
}

internal fun appliedPracticeStorePersistedState(
    payload: ParsedPracticeStatePayload,
): AppliedPracticeStorePersistedState {
    return appliedPracticeStorePersistedState(
        canonicalState = payload.canonical,
        runtimeState = payload.runtime,
    )
}

internal fun appliedPracticeCanonicalRefresh(
    canonicalState: CanonicalPracticePersistedState,
    gameName: (String) -> String,
): AppliedPracticeStorePersistedState {
    return appliedPracticeStorePersistedState(
        canonicalState = canonicalState,
        runtimeState = runtimePracticeStateFromCanonicalState(canonicalState, gameName),
    )
}

internal fun appliedPracticeHomeBootstrapState(
    snapshot: PracticeHomeBootstrapRestorePayload,
): AppliedPracticeHomeBootstrapState {
    return AppliedPracticeHomeBootstrapState(
        canonicalState = snapshot.canonicalState,
        rulesheetResumeOffsets = emptyMap(),
        runtimeState = snapshot.runtimeState,
        visibleGames = snapshot.visibleGames,
        lookupGames = snapshot.lookupGames,
        librarySources = snapshot.librarySources,
        selectedLibrarySourceId = snapshot.selectedLibrarySourceId,
        hasUsableSnapshot = snapshot.hasUsableSnapshot,
    )
}
