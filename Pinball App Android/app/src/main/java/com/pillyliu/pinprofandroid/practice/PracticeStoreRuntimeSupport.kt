package com.pillyliu.pinprofandroid.practice

internal data class AppliedPracticeRuntimeState(
    val playerName: String,
    val ifpaPlayerID: String,
    val prpaPlayerID: String,
    val comparisonPlayerName: String,
    val leaguePlayerName: String,
    val cloudSyncEnabled: Boolean,
    val selectedGroupID: String?,
    val groups: List<PracticeGroup>,
    val scores: List<ScoreEntry>,
    val notes: List<NoteEntry>,
    val journal: List<JournalEntry>,
    val rulesheetProgress: Map<String, Float>,
    val gameSummaryNotes: Map<String, String>,
)

internal fun appliedPracticeRuntimeState(
    state: PracticePersistedState,
): AppliedPracticeRuntimeState {
    return AppliedPracticeRuntimeState(
        playerName = state.playerName,
        ifpaPlayerID = state.ifpaPlayerID,
        prpaPlayerID = state.prpaPlayerID,
        comparisonPlayerName = state.comparisonPlayerName,
        leaguePlayerName = state.leaguePlayerName,
        cloudSyncEnabled = state.cloudSyncEnabled,
        selectedGroupID = state.selectedGroupID,
        groups = state.groups,
        scores = state.scores,
        notes = state.notes,
        journal = state.journal,
        rulesheetProgress = state.rulesheetProgress,
        gameSummaryNotes = state.gameSummaryNotes,
    )
}

internal fun practiceShadowCanonicalState(
    canonicalState: CanonicalPracticePersistedState,
    rulesheetResumeOffsets: Map<String, Double>,
    gameSummaryNotes: Map<String, String>,
): CanonicalPracticePersistedState {
    return canonicalState.copy(
        rulesheetResumeOffsets = rulesheetResumeOffsets,
        gameSummaryNotes = gameSummaryNotes,
    )
}
