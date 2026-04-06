package com.pillyliu.pinprofandroid.practice

internal data class PracticeStorePersistenceState(
    val runtimeState: PracticePersistedState,
    val shadowState: CanonicalPracticePersistedState,
)

internal fun practiceStoreRuntimeState(
    playerName: String,
    ifpaPlayerID: String,
    prpaPlayerID: String,
    comparisonPlayerName: String,
    leaguePlayerName: String,
    cloudSyncEnabled: Boolean,
    selectedGroupID: String?,
    groups: List<PracticeGroup>,
    scores: List<ScoreEntry>,
    notes: List<NoteEntry>,
    journal: List<JournalEntry>,
    rulesheetProgress: Map<String, Float>,
    gameSummaryNotes: Map<String, String>,
): PracticePersistedState {
    return practicePersistedStateFromValues(
        playerName = playerName,
        ifpaPlayerID = ifpaPlayerID,
        prpaPlayerID = prpaPlayerID,
        comparisonPlayerName = comparisonPlayerName,
        leaguePlayerName = leaguePlayerName,
        cloudSyncEnabled = cloudSyncEnabled,
        selectedGroupID = selectedGroupID,
        groups = groups,
        scores = scores,
        notes = notes,
        journal = journal,
        rulesheetProgress = rulesheetProgress,
        gameSummaryNotes = gameSummaryNotes,
    )
}

internal fun practiceStorePersistenceState(
    canonicalState: CanonicalPracticePersistedState,
    rulesheetResumeOffsets: Map<String, Double>,
    playerName: String,
    ifpaPlayerID: String,
    prpaPlayerID: String,
    comparisonPlayerName: String,
    leaguePlayerName: String,
    cloudSyncEnabled: Boolean,
    selectedGroupID: String?,
    groups: List<PracticeGroup>,
    scores: List<ScoreEntry>,
    notes: List<NoteEntry>,
    journal: List<JournalEntry>,
    rulesheetProgress: Map<String, Float>,
    gameSummaryNotes: Map<String, String>,
): PracticeStorePersistenceState {
    val runtimeState = practiceStoreRuntimeState(
        playerName = playerName,
        ifpaPlayerID = ifpaPlayerID,
        prpaPlayerID = prpaPlayerID,
        comparisonPlayerName = comparisonPlayerName,
        leaguePlayerName = leaguePlayerName,
        cloudSyncEnabled = cloudSyncEnabled,
        selectedGroupID = selectedGroupID,
        groups = groups,
        scores = scores,
        notes = notes,
        journal = journal,
        rulesheetProgress = rulesheetProgress,
        gameSummaryNotes = gameSummaryNotes,
    )

    return PracticeStorePersistenceState(
        runtimeState = runtimeState,
        shadowState = practiceShadowCanonicalState(
            canonicalState = canonicalState,
            rulesheetResumeOffsets = rulesheetResumeOffsets,
            gameSummaryNotes = gameSummaryNotes,
        ),
    )
}
