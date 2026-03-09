package com.pillyliu.pinprofandroid.practice

import java.util.UUID

internal class PracticeProgressIntegration {
    fun addScore(
        canonicalState: CanonicalPracticePersistedState,
        canonicalGameID: String,
        score: Double,
        context: String,
        timestampMs: Long,
        leagueImported: Boolean,
    ): CanonicalPracticePersistedState {
        val (scoreContext, tournamentName) = splitCanonicalScoreContext(context)
        val scoreEntry = CanonicalScoreLogEntry(
            id = UUID.randomUUID().toString(),
            gameID = canonicalGameID,
            score = score,
            context = scoreContext,
            tournamentName = tournamentName,
            timestampMs = timestampMs,
            leagueImported = leagueImported,
        )
        val journalEntry = CanonicalJournalEntry(
            id = UUID.randomUUID().toString(),
            gameID = canonicalGameID,
            action = "scoreLogged",
            task = null,
            progressPercent = null,
            videoKind = null,
            videoValue = null,
            score = score,
            scoreContext = scoreContext,
            tournamentName = tournamentName,
            noteCategory = null,
            noteDetail = null,
            note = null,
            timestampMs = timestampMs,
        )
        return canonicalState.copy(
            scoreEntries = canonicalState.scoreEntries + scoreEntry,
            journalEntries = canonicalState.journalEntries + journalEntry,
        )
    }

    fun addStudy(
        canonicalState: CanonicalPracticePersistedState,
        canonicalGameID: String,
        category: String,
        value: String,
        note: String?,
        timestampMs: Long,
    ): CanonicalPracticePersistedState? {
        val normalizedCategory = category.trim().lowercase()
        val trimmedValue = value.trim()
        if (trimmedValue.isBlank()) return null

        val trimmedNote = note?.trim()?.ifBlank { null }
        val action = when (normalizedCategory) {
            "rulesheet" -> "rulesheetRead"
            "tutorial" -> "tutorialWatch"
            "gameplay" -> "gameplayWatch"
            "playfield" -> "playfieldViewed"
            "practice" -> "practiceSession"
            else -> "rulesheetRead"
        }
        val task = when (normalizedCategory) {
            "rulesheet" -> "rulesheet"
            "tutorial" -> "tutorialVideo"
            "gameplay" -> "gameplayVideo"
            "playfield" -> "playfield"
            "practice" -> "practice"
            else -> "rulesheet"
        }
        val progressPercent = Regex("""(\d{1,3})\s*%?""").find(trimmedValue)?.groupValues?.getOrNull(1)?.toIntOrNull()?.coerceIn(0, 100)
            ?.takeIf { normalizedCategory == "rulesheet" || normalizedCategory == "tutorial" || normalizedCategory == "gameplay" }
        val videoKind = if (normalizedCategory == "tutorial" || normalizedCategory == "gameplay") {
            if (trimmedValue.contains(":")) "clock" else "percent"
        } else {
            null
        }
        val videoValue = if (normalizedCategory == "tutorial" || normalizedCategory == "gameplay") trimmedValue else null
        val journalNote = when (normalizedCategory) {
            "practice" -> trimmedNote ?: trimmedValue
            else -> trimmedNote
        }
        val studyEvent = progressPercent?.let {
            CanonicalStudyProgressEvent(
                id = UUID.randomUUID().toString(),
                gameID = canonicalGameID,
                task = task,
                progressPercent = it,
                timestampMs = timestampMs,
            )
        }
        val videoEntry = if (!videoValue.isNullOrBlank()) {
            CanonicalVideoProgressEntry(
                id = UUID.randomUUID().toString(),
                gameID = canonicalGameID,
                kind = videoKind ?: "percent",
                value = videoValue,
                timestampMs = timestampMs,
            )
        } else {
            null
        }
        val journalEntry = CanonicalJournalEntry(
            id = UUID.randomUUID().toString(),
            gameID = canonicalGameID,
            action = action,
            task = task,
            progressPercent = progressPercent,
            videoKind = videoKind,
            videoValue = videoValue,
            score = null,
            scoreContext = null,
            tournamentName = null,
            noteCategory = null,
            noteDetail = null,
            note = journalNote,
            timestampMs = timestampMs,
        )
        return canonicalState.copy(
            studyEvents = canonicalState.studyEvents + listOfNotNull(studyEvent),
            videoProgressEntries = canonicalState.videoProgressEntries + listOfNotNull(videoEntry),
            journalEntries = canonicalState.journalEntries + journalEntry,
        )
    }

    fun addPracticeNote(
        canonicalState: CanonicalPracticePersistedState,
        canonicalGameID: String,
        category: String,
        detail: String?,
        note: String,
        timestampMs: Long,
    ): CanonicalPracticePersistedState? {
        val trimmedNote = note.trim()
        if (trimmedNote.isBlank()) return null

        val normalizedCategory = category.trim().ifBlank { "general" }
        val noteEntry = CanonicalPracticeNoteEntry(
            id = UUID.randomUUID().toString(),
            gameID = canonicalGameID,
            category = normalizedCategory,
            detail = detail?.trim()?.ifBlank { null },
            note = trimmedNote,
            timestampMs = timestampMs,
        )
        val journalEntry = CanonicalJournalEntry(
            id = UUID.randomUUID().toString(),
            gameID = canonicalGameID,
            action = "noteAdded",
            task = null,
            progressPercent = null,
            videoKind = null,
            videoValue = null,
            score = null,
            scoreContext = null,
            tournamentName = null,
            noteCategory = normalizedCategory,
            noteDetail = noteEntry.detail,
            note = trimmedNote,
            timestampMs = timestampMs,
        )
        return canonicalState.copy(
            noteEntries = canonicalState.noteEntries + noteEntry,
            journalEntries = canonicalState.journalEntries + journalEntry,
        )
    }

    fun updatedRulesheetResumeOffsets(
        currentOffsets: Map<String, Double>,
        canonicalGameID: String,
        ratio: Float,
    ): Map<String, Double> {
        return updatedRulesheetProgress(
            currentOffsets.mapValues { it.value.toFloat() },
            canonicalGameID,
            ratio,
        ).mapValues { it.value.toDouble() }
    }

    private fun splitCanonicalScoreContext(raw: String): Pair<String, String?> {
        val trimmed = raw.trim()
        return if (trimmed.startsWith("tournament:")) {
            "tournament" to trimmed.removePrefix("tournament:").trim().ifBlank { null }
        } else {
            trimmed.ifBlank { "practice" } to null
        }
    }
}
