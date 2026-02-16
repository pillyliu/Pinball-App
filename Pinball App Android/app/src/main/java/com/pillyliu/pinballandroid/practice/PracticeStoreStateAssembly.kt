package com.pillyliu.pinballandroid.practice

internal fun practicePersistedStateFromValues(
    playerName: String,
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
