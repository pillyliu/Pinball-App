package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.PinballGame
import java.util.UUID
import kotlin.math.abs

internal class PracticeJournalIntegration(
    private val practiceLookupGames: () -> List<PinballGame>,
    private val gameNameForSlug: (String) -> String,
) {
    fun items(journal: List<JournalEntry>, filter: JournalFilter): List<JournalEntry> =
        filteredJournalItems(journal, filter)

    fun canEdit(entry: JournalEntry): Boolean = isUserEditablePracticeJournalEntry(entry)

    fun editDraft(
        entry: JournalEntry,
        canonicalState: CanonicalPracticePersistedState,
        scores: List<ScoreEntry>,
        notes: List<NoteEntry>,
    ): PracticeJournalEditDraft? {
        if (!canEdit(entry)) return null
        val canonical = canonicalState.journalEntries.firstOrNull { it.id == entry.id }
            ?: return parsePracticeJournalEditDraft(entry, gameNameForSlug(entry.gameSlug), scores, notes)
        return canonicalDraftForJournalEntry(canonical)
    }

    fun updateEntry(
        canonicalState: CanonicalPracticePersistedState,
        draft: PracticeJournalEditDraft,
    ): CanonicalPracticePersistedState? {
        val journalIndex = canonicalState.journalEntries.indexOfFirst { it.id == draft.id }
        if (journalIndex < 0) return null
        val original = canonicalState.journalEntries[journalIndex]
        val canonicalGameSlug = canonicalPracticeKey(draft.gameSlug, practiceLookupGames())
        if (canonicalGameSlug.isBlank()) return null

        return when (draft.kind) {
            PracticeJournalEditKind.Score -> {
                val score = draft.score ?: return null
                val contextBase = draft.scoreContext?.trim().orEmpty().ifBlank { "practice" }
                val context = if (contextBase == "tournament") "tournament" else contextBase
                val tournamentName = if (context == "tournament") draft.tournamentName?.trim()?.ifBlank { null } else null
                val scoreEntryIndex = matchingCanonicalScoreEntryIndex(canonicalState, original)
                val nextScores = canonicalState.scoreEntries.toMutableList().apply {
                    if (scoreEntryIndex != null) {
                        val existing = this[scoreEntryIndex]
                        this[scoreEntryIndex] = existing.copy(
                            gameID = canonicalGameSlug,
                            score = score,
                            context = context,
                            tournamentName = tournamentName,
                        )
                    }
                }
                canonicalState.copy(
                    scoreEntries = nextScores,
                    journalEntries = canonicalState.journalEntries.toMutableList().apply {
                        this[journalIndex] = original.copy(
                            gameID = canonicalGameSlug,
                            score = score,
                            scoreContext = context,
                            tournamentName = tournamentName,
                        )
                    },
                )
            }

            PracticeJournalEditKind.Note, PracticeJournalEditKind.Mechanics -> {
                val noteText = draft.noteText?.trim().orEmpty()
                if (noteText.isBlank()) return null
                val category = draft.noteCategory?.trim().orEmpty().ifBlank {
                    if (draft.kind == PracticeJournalEditKind.Mechanics) "mechanics" else "general"
                }
                val noteEntryIndex = matchingCanonicalNoteEntryIndex(canonicalState, original)
                val nextNotes = canonicalState.noteEntries.toMutableList().apply {
                    if (noteEntryIndex != null) {
                        val existing = this[noteEntryIndex]
                        this[noteEntryIndex] = existing.copy(
                            gameID = canonicalGameSlug,
                            category = category,
                            detail = draft.noteDetail?.trim()?.ifBlank { null },
                            note = noteText,
                        )
                    }
                }
                canonicalState.copy(
                    noteEntries = nextNotes,
                    journalEntries = canonicalState.journalEntries.toMutableList().apply {
                        this[journalIndex] = original.copy(
                            gameID = canonicalGameSlug,
                            noteCategory = category,
                            noteDetail = draft.noteDetail?.trim()?.ifBlank { null },
                            note = noteText,
                        )
                    },
                )
            }

            PracticeJournalEditKind.Study, PracticeJournalEditKind.Practice -> {
                val category = draft.studyCategory?.trim().orEmpty().lowercase()
                val value = draft.studyValue?.trim().orEmpty()
                if (category.isBlank() || value.isBlank()) return null
                val note = draft.studyNote?.trim()?.ifBlank { null }
                val action = when (category) {
                    "rulesheet" -> "rulesheetRead"
                    "tutorial" -> "tutorialWatch"
                    "gameplay" -> "gameplayWatch"
                    "playfield" -> "playfieldViewed"
                    "practice" -> "practiceSession"
                    else -> if (draft.kind == PracticeJournalEditKind.Practice) "practiceSession" else "rulesheetRead"
                }
                val task = when (category) {
                    "rulesheet" -> "rulesheet"
                    "tutorial" -> "tutorialVideo"
                    "gameplay" -> "gameplayVideo"
                    "playfield" -> "playfield"
                    "practice" -> "practice"
                    else -> if (draft.kind == PracticeJournalEditKind.Practice) "practice" else "rulesheet"
                }
                val progressPercent = Regex("""(\d{1,3})\s*%?""").find(value)?.groupValues?.getOrNull(1)?.toIntOrNull()?.coerceIn(0, 100)
                    ?.takeIf { category == "rulesheet" || category == "tutorial" || category == "gameplay" }
                val videoKind = if (category == "tutorial" || category == "gameplay") {
                    if (value.contains(":")) "clock" else "percent"
                } else null
                val videoValue = if (category == "tutorial" || category == "gameplay") value else null
                val journalNote = if (category == "practice") composePracticeSessionNote(value, note) else note
                val updatedJournal = original.copy(
                    gameID = canonicalGameSlug,
                    action = action,
                    task = task,
                    progressPercent = progressPercent,
                    videoKind = videoKind,
                    videoValue = videoValue,
                    note = journalNote,
                )

                val studyIndex = matchingCanonicalStudyEventIndex(canonicalState, original, original.task)
                val nextStudyEvents = canonicalState.studyEvents.toMutableList()
                if (progressPercent != null) {
                    if (studyIndex != null) {
                        val existing = nextStudyEvents[studyIndex]
                        nextStudyEvents[studyIndex] = existing.copy(
                            gameID = canonicalGameSlug,
                            task = task,
                            progressPercent = progressPercent,
                        )
                    } else {
                        nextStudyEvents += CanonicalStudyProgressEvent(
                            id = UUID.randomUUID().toString(),
                            gameID = canonicalGameSlug,
                            task = task,
                            progressPercent = progressPercent,
                            timestampMs = original.timestampMs,
                        )
                    }
                } else if (studyIndex != null) {
                    nextStudyEvents.removeAt(studyIndex)
                }
                val videoIndex = matchingCanonicalVideoEntryIndex(canonicalState, original)
                val nextVideos = canonicalState.videoProgressEntries.toMutableList()
                if (!videoValue.isNullOrBlank()) {
                    if (videoIndex != null) {
                        val existing = nextVideos[videoIndex]
                        nextVideos[videoIndex] = existing.copy(
                            gameID = canonicalGameSlug,
                            kind = videoKind ?: existing.kind,
                            value = videoValue,
                        )
                    } else {
                        nextVideos += CanonicalVideoProgressEntry(
                            id = UUID.randomUUID().toString(),
                            gameID = canonicalGameSlug,
                            kind = videoKind ?: "percent",
                            value = videoValue,
                            timestampMs = original.timestampMs,
                        )
                    }
                } else if (videoIndex != null) {
                    nextVideos.removeAt(videoIndex)
                }

                canonicalState.copy(
                    studyEvents = nextStudyEvents,
                    videoProgressEntries = nextVideos,
                    journalEntries = canonicalState.journalEntries.toMutableList().apply {
                        this[journalIndex] = updatedJournal
                    },
                )
            }
        }
    }

    fun deleteEntry(
        canonicalState: CanonicalPracticePersistedState,
        runtimeJournal: List<JournalEntry>,
        entryId: String,
    ): CanonicalPracticePersistedState? {
        val journalIndex = canonicalState.journalEntries.indexOfFirst { it.id == entryId }
        if (journalIndex < 0) return null
        val entry = canonicalState.journalEntries[journalIndex]
        val legacyEntry = runtimeJournal.firstOrNull { it.id == entryId }
        if (legacyEntry != null && !canEdit(legacyEntry)) return null

        val nextJournal = canonicalState.journalEntries.toMutableList().apply { removeAt(journalIndex) }
        val nextScores = canonicalState.scoreEntries.toMutableList()
        val nextNotes = canonicalState.noteEntries.toMutableList()
        val nextStudyEvents = canonicalState.studyEvents.toMutableList()
        val nextVideos = canonicalState.videoProgressEntries.toMutableList()

        when (entry.action) {
            "scoreLogged" -> matchingCanonicalScoreEntryIndex(canonicalState, entry)?.let { nextScores.removeAt(it) }
            "noteAdded" -> matchingCanonicalNoteEntryIndex(canonicalState, entry)?.let { nextNotes.removeAt(it) }
            "rulesheetRead", "playfieldViewed", "practiceSession", "tutorialWatch", "gameplayWatch" -> {
                matchingCanonicalStudyEventIndex(canonicalState, entry, entry.task)?.let { nextStudyEvents.removeAt(it) }
                if (entry.action == "tutorialWatch" || entry.action == "gameplayWatch") {
                    matchingCanonicalVideoEntryIndex(canonicalState, entry)?.let { nextVideos.removeAt(it) }
                }
            }
        }

        return canonicalState.copy(
            journalEntries = nextJournal,
            scoreEntries = nextScores,
            noteEntries = nextNotes,
            studyEvents = nextStudyEvents,
            videoProgressEntries = nextVideos,
        )
    }

    private fun canonicalDraftForJournalEntry(entry: CanonicalJournalEntry): PracticeJournalEditDraft? {
        return when (entry.action) {
            "scoreLogged" -> PracticeJournalEditDraft(
                id = entry.id,
                kind = PracticeJournalEditKind.Score,
                gameSlug = entry.gameID,
                timestampMs = entry.timestampMs,
                score = entry.score,
                scoreContext = entry.scoreContext ?: "practice",
                tournamentName = entry.tournamentName,
            )

            "noteAdded" -> {
                val category = entry.noteCategory ?: "general"
                PracticeJournalEditDraft(
                    id = entry.id,
                    kind = if (category == "mechanics") PracticeJournalEditKind.Mechanics else PracticeJournalEditKind.Note,
                    gameSlug = entry.gameID,
                    timestampMs = entry.timestampMs,
                    noteCategory = category,
                    noteDetail = entry.noteDetail,
                    noteText = entry.note ?: "",
                )
            }

            "rulesheetRead", "tutorialWatch", "gameplayWatch", "playfieldViewed", "practiceSession" -> {
                val category = when (entry.action) {
                    "rulesheetRead" -> "rulesheet"
                    "tutorialWatch" -> "tutorial"
                    "gameplayWatch" -> "gameplay"
                    "playfieldViewed" -> "playfield"
                    "practiceSession" -> "practice"
                    else -> "study"
                }
                val value = when (entry.action) {
                    "rulesheetRead" -> entry.progressPercent?.let { "$it%" } ?: "0%"
                    "tutorialWatch", "gameplayWatch" -> entry.videoValue ?: (entry.progressPercent?.let { "$it%" } ?: "0%")
                    "playfieldViewed" -> "Viewed"
                    "practiceSession" -> parsePracticeSessionParts(value = entry.note, note = null).value
                    else -> entry.note ?: "Updated"
                }
                val practiceParts = if (entry.action == "practiceSession") {
                    parsePracticeSessionParts(value = entry.note, note = null)
                } else {
                    null
                }
                PracticeJournalEditDraft(
                    id = entry.id,
                    kind = if (entry.action == "practiceSession") PracticeJournalEditKind.Practice else PracticeJournalEditKind.Study,
                    gameSlug = entry.gameID,
                    timestampMs = entry.timestampMs,
                    studyCategory = category,
                    studyValue = value,
                    studyNote = if (entry.action == "practiceSession") practiceParts?.note else entry.note,
                )
            }

            else -> null
        }
    }

    private fun matchingCanonicalScoreEntryIndex(
        canonicalState: CanonicalPracticePersistedState,
        journalEntry: CanonicalJournalEntry,
    ): Int? {
        val expectedTournament = journalEntry.tournamentName?.trim().orEmpty()
        return canonicalState.scoreEntries.withIndex()
            .filter { (_, entry) ->
                entry.gameID == journalEntry.gameID &&
                    (journalEntry.scoreContext == null || entry.context == journalEntry.scoreContext) &&
                    (journalEntry.score == null || abs(entry.score - journalEntry.score) <= 0.5) &&
                    ((expectedTournament.isEmpty() && entry.tournamentName.isNullOrBlank()) ||
                        entry.tournamentName?.trim().orEmpty().equals(expectedTournament, ignoreCase = true))
            }
            .minByOrNull { abs(it.value.timestampMs - journalEntry.timestampMs) }
            ?.index
    }

    private fun matchingCanonicalNoteEntryIndex(
        canonicalState: CanonicalPracticePersistedState,
        journalEntry: CanonicalJournalEntry,
    ): Int? {
        return canonicalState.noteEntries.withIndex()
            .filter { (_, entry) ->
                entry.gameID == journalEntry.gameID &&
                    (journalEntry.noteCategory == null || entry.category == journalEntry.noteCategory) &&
                    (journalEntry.noteDetail.isNullOrBlank() ||
                        (entry.detail?.trim().orEmpty().equals(journalEntry.noteDetail.trim(), ignoreCase = true))) &&
                    (journalEntry.note.isNullOrBlank() || entry.note.trim() == journalEntry.note.trim())
            }
            .minByOrNull { abs(it.value.timestampMs - journalEntry.timestampMs) }
            ?.index
    }

    private fun matchingCanonicalStudyEventIndex(
        canonicalState: CanonicalPracticePersistedState,
        journalEntry: CanonicalJournalEntry,
        taskOverride: String?,
    ): Int? {
        val task = taskOverride ?: journalEntry.task ?: return null
        return canonicalState.studyEvents.withIndex()
            .filter { (_, entry) ->
                entry.gameID == journalEntry.gameID &&
                    entry.task == task &&
                    (journalEntry.progressPercent == null || entry.progressPercent == journalEntry.progressPercent)
            }
            .minByOrNull { abs(it.value.timestampMs - journalEntry.timestampMs) }
            ?.index
    }

    private fun matchingCanonicalVideoEntryIndex(
        canonicalState: CanonicalPracticePersistedState,
        journalEntry: CanonicalJournalEntry,
    ): Int? {
        return canonicalState.videoProgressEntries.withIndex()
            .filter { (_, entry) ->
                entry.gameID == journalEntry.gameID &&
                    (journalEntry.videoKind == null || entry.kind == journalEntry.videoKind) &&
                    (journalEntry.videoValue.isNullOrBlank() || entry.value.trim() == journalEntry.videoValue.trim())
            }
            .minByOrNull { abs(it.value.timestampMs - journalEntry.timestampMs) }
            ?.index
    }
}
