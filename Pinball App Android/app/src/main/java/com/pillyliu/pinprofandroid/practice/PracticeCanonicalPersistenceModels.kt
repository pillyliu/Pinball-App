package com.pillyliu.pinprofandroid.practice

internal const val CANONICAL_PRACTICE_SCHEMA_VERSION = 4

internal data class CanonicalStudyProgressEvent(
    val id: String,
    val gameID: String,
    val task: String,
    val progressPercent: Int,
    val timestampMs: Long,
)

internal data class CanonicalVideoProgressEntry(
    val id: String,
    val gameID: String,
    val kind: String,
    val value: String,
    val timestampMs: Long,
)

internal data class CanonicalScoreLogEntry(
    val id: String,
    val gameID: String,
    val score: Double,
    val context: String,
    val tournamentName: String?,
    val timestampMs: Long,
    val leagueImported: Boolean,
)

internal data class CanonicalPracticeNoteEntry(
    val id: String,
    val gameID: String,
    val category: String,
    val detail: String?,
    val note: String,
    val timestampMs: Long,
)

internal data class CanonicalJournalEntry(
    val id: String,
    val gameID: String,
    val action: String,
    val task: String?,
    val progressPercent: Int?,
    val videoKind: String?,
    val videoValue: String?,
    val score: Double?,
    val scoreContext: String?,
    val tournamentName: String?,
    val noteCategory: String?,
    val noteDetail: String?,
    val note: String?,
    val timestampMs: Long,
)

internal data class CanonicalCustomGroup(
    val id: String,
    val name: String,
    val gameIDs: List<String>,
    val type: String,
    val isActive: Boolean,
    val isArchived: Boolean,
    val isPriority: Boolean,
    val startDateMs: Long?,
    val endDateMs: Long?,
    val createdAtMs: Long,
)

internal data class CanonicalLeagueSettings(
    val playerName: String,
    val csvAutoFillEnabled: Boolean,
    val lastImportAtMs: Long?,
)

internal data class CanonicalSyncSettings(
    val cloudSyncEnabled: Boolean,
    val endpoint: String,
    val phaseLabel: String,
)

internal data class CanonicalAnalyticsSettings(
    val gapMode: String,
    val useMedian: Boolean,
)

internal data class CanonicalPracticeSettings(
    val playerName: String,
    val ifpaPlayerID: String,
    val comparisonPlayerName: String,
    val selectedGroupID: String?,
)

internal data class CanonicalPracticePersistedState(
    val schemaVersion: Int,
    val studyEvents: List<CanonicalStudyProgressEvent>,
    val videoProgressEntries: List<CanonicalVideoProgressEntry>,
    val scoreEntries: List<CanonicalScoreLogEntry>,
    val noteEntries: List<CanonicalPracticeNoteEntry>,
    val journalEntries: List<CanonicalJournalEntry>,
    val customGroups: List<CanonicalCustomGroup>,
    val leagueSettings: CanonicalLeagueSettings,
    val syncSettings: CanonicalSyncSettings,
    val analyticsSettings: CanonicalAnalyticsSettings,
    val rulesheetResumeOffsets: Map<String, Double>,
    val videoResumeHints: Map<String, String>,
    val gameSummaryNotes: Map<String, String>,
    val practiceSettings: CanonicalPracticeSettings,
)

internal data class ParsedPracticeStatePayload(
    val runtime: PracticePersistedState,
    val canonical: CanonicalPracticePersistedState,
)

internal fun emptyCanonicalPracticePersistedState(): CanonicalPracticePersistedState {
    return CanonicalPracticePersistedState(
        schemaVersion = CANONICAL_PRACTICE_SCHEMA_VERSION,
        studyEvents = emptyList(),
        videoProgressEntries = emptyList(),
        scoreEntries = emptyList(),
        noteEntries = emptyList(),
        journalEntries = emptyList(),
        customGroups = emptyList(),
        leagueSettings = CanonicalLeagueSettings(playerName = "", csvAutoFillEnabled = false, lastImportAtMs = null),
        syncSettings = CanonicalSyncSettings(
            cloudSyncEnabled = false,
            endpoint = "pillyliu.com",
            phaseLabel = "Phase 1: On-device",
        ),
        analyticsSettings = CanonicalAnalyticsSettings(gapMode = "compressInactive", useMedian = true),
        rulesheetResumeOffsets = emptyMap(),
        videoResumeHints = emptyMap(),
        gameSummaryNotes = emptyMap(),
        practiceSettings = CanonicalPracticeSettings(playerName = "", ifpaPlayerID = "", comparisonPlayerName = "", selectedGroupID = null),
    )
}
