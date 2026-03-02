package com.pillyliu.pinprofandroid.practice

internal fun practicePersistedStateFromValues(
    playerName: String,
    ifpaPlayerID: String,
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
    return PracticePersistedState(
        playerName = playerName,
        ifpaPlayerID = ifpaPlayerID,
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

internal fun emptyPracticePersistedState(): PracticePersistedState {
    return PracticePersistedState(
        playerName = "",
        ifpaPlayerID = "",
        comparisonPlayerName = "",
        leaguePlayerName = "",
        cloudSyncEnabled = false,
        selectedGroupID = null,
        groups = emptyList(),
        scores = emptyList(),
        notes = emptyList(),
        journal = emptyList(),
        rulesheetProgress = emptyMap(),
        gameSummaryNotes = emptyMap(),
    )
}
