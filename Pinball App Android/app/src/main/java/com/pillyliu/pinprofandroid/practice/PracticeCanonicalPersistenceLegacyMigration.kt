package com.pillyliu.pinprofandroid.practice

import kotlin.math.abs

internal fun canonicalPracticeStateFromLegacyState(legacy: PracticePersistedState): CanonicalPracticePersistedState {
    val groupIdMap = stableIdMap(legacy.groups, "group") { it.id }
    val scoreIdMap = stableIdMap(legacy.scores, "score") { it.id }
    val noteIdMap = stableIdMap(legacy.notes, "note") { it.id }

    val convertedScores = legacy.scores.map { score ->
        val (context, tournamentName) = splitLegacyScoreContext(score.context)
        CanonicalScoreLogEntry(
            id = scoreIdMap.getValue(score.id),
            gameID = score.gameSlug,
            score = score.score,
            context = context,
            tournamentName = tournamentName,
            timestampMs = score.timestampMs,
            leagueImported = score.leagueImported,
        )
    }
    val convertedNotes = legacy.notes.map { note ->
        CanonicalPracticeNoteEntry(
            id = noteIdMap.getValue(note.id),
            gameID = note.gameSlug,
            category = note.category,
            detail = note.detail?.takeIf { it.isNotBlank() },
            note = note.note,
            timestampMs = note.timestampMs,
        )
    }

    val workingStudyEvents = mutableListOf<CanonicalStudyProgressEvent>()
    val workingVideoEntries = mutableListOf<CanonicalVideoProgressEntry>()
    val workingJournal = mutableListOf<CanonicalJournalEntry>()

    legacy.journal.forEach { journal ->
        val parsed = parseLegacyJournalToCanonical(journal, legacy.scores, legacy.notes)
        workingStudyEvents += parsed.studyEvents
        workingVideoEntries += parsed.videoEntries
        workingJournal += parsed.journalEntry
    }

    val customGroups = legacy.groups.map { group ->
        CanonicalCustomGroup(
            id = groupIdMap.getValue(group.id),
            name = group.name,
            gameIDs = group.gameSlugs.distinct(),
            type = group.type.ifBlank { "custom" },
            isActive = group.isActive,
            isArchived = group.isArchived,
            isPriority = group.isPriority,
            startDateMs = group.startDateMs,
            endDateMs = group.endDateMs,
            createdAtMs = group.startDateMs ?: System.currentTimeMillis(),
        )
    }

    val remappedSelectedGroupId = legacy.selectedGroupID?.let { groupIdMap[it] }

    return emptyCanonicalPracticePersistedState().copy(
        studyEvents = workingStudyEvents,
        videoProgressEntries = workingVideoEntries,
        scoreEntries = convertedScores,
        noteEntries = convertedNotes,
        journalEntries = workingJournal,
        customGroups = customGroups,
        leagueSettings = CanonicalLeagueSettings(
            playerName = legacy.leaguePlayerName,
            csvAutoFillEnabled = true,
            lastImportAtMs = null,
            lastRepairVersion = null,
        ),
        syncSettings = emptyCanonicalPracticePersistedState().syncSettings.copy(cloudSyncEnabled = legacy.cloudSyncEnabled),
        rulesheetResumeOffsets = legacy.rulesheetProgress.mapValues { it.value.toDouble() },
        gameSummaryNotes = legacy.gameSummaryNotes,
        practiceSettings = CanonicalPracticeSettings(
            playerName = legacy.playerName,
            ifpaPlayerID = legacy.ifpaPlayerID,
            comparisonPlayerName = legacy.comparisonPlayerName,
            selectedGroupID = remappedSelectedGroupId,
        ),
    )
}

private data class LegacyToCanonicalJournalParse(
    val journalEntry: CanonicalJournalEntry,
    val studyEvents: List<CanonicalStudyProgressEvent> = emptyList(),
    val videoEntries: List<CanonicalVideoProgressEntry> = emptyList(),
)

private fun parseLegacyJournalToCanonical(
    journal: JournalEntry,
    scores: List<ScoreEntry>,
    notes: List<NoteEntry>,
): LegacyToCanonicalJournalParse {
    val ts = journal.timestampMs
    val journalID = validUuidOrStable("journal", journal.id)
    return when (journal.action) {
        "score" -> {
            val scoreMatch = scores
                .filter { it.gameSlug == journal.gameSlug }
                .minByOrNull { abs(it.timestampMs - ts) }
            val (context, tournamentName) = splitLegacyScoreContext(scoreMatch?.context ?: "practice")
            LegacyToCanonicalJournalParse(
                journalEntry = CanonicalJournalEntry(
                    id = journalID,
                    gameID = journal.gameSlug,
                    action = "scoreLogged",
                    task = null,
                    progressPercent = null,
                    videoKind = null,
                    videoValue = null,
                    score = scoreMatch?.score,
                    scoreContext = context,
                    tournamentName = tournamentName,
                    noteCategory = null,
                    noteDetail = null,
                    note = null,
                    timestampMs = ts,
                ),
            )
        }
        "note", "mechanics" -> {
            val noteMatch = notes
                .filter { it.gameSlug == journal.gameSlug }
                .minByOrNull { abs(it.timestampMs - ts) }
            val category = noteMatch?.category ?: if (journal.action == "mechanics") "mechanics" else "general"
            LegacyToCanonicalJournalParse(
                journalEntry = CanonicalJournalEntry(
                    id = journalID,
                    gameID = journal.gameSlug,
                    action = "noteAdded",
                    task = null,
                    progressPercent = null,
                    videoKind = null,
                    videoValue = null,
                    score = null,
                    scoreContext = null,
                    tournamentName = null,
                    noteCategory = category,
                    noteDetail = noteMatch?.detail,
                    note = noteMatch?.note,
                    timestampMs = ts,
                ),
            )
        }
        "study", "practice" -> {
            val parsed = parseLegacyStudySummaryHeuristics(journal.summary, journal.action)
            val action = when (parsed.category) {
                "rulesheet" -> "rulesheetRead"
                "tutorial" -> "tutorialWatch"
                "gameplay" -> "gameplayWatch"
                "playfield" -> "playfieldViewed"
                "practice" -> "practiceSession"
                else -> if (journal.action == "practice") "practiceSession" else "rulesheetRead"
            }
            val task = when (parsed.category) {
                "rulesheet" -> "rulesheet"
                "tutorial" -> "tutorialVideo"
                "gameplay" -> "gameplayVideo"
                "playfield" -> "playfield"
                "practice" -> "practice"
                else -> if (journal.action == "practice") "practice" else "rulesheet"
            }
            val progress = parsed.value.let(::extractPercentInt)
            val videoKind = when (parsed.category) {
                "tutorial", "gameplay" -> inferVideoKind(parsed.value)
                else -> null
            }
            val videoValue = when (parsed.category) {
                "tutorial", "gameplay" -> parsed.value.takeIf { it.isNotBlank() }
                else -> null
            }
            val journalNote = if (parsed.category == "practice") {
                parsed.note ?: parsed.value.takeIf { it.isNotBlank() && it != "Practice session" }
            } else {
                parsed.note
            }
            val journalEntry = CanonicalJournalEntry(
                id = journalID,
                gameID = journal.gameSlug,
                action = action,
                task = task,
                progressPercent = progress,
                videoKind = videoKind,
                videoValue = videoValue,
                score = null,
                scoreContext = null,
                tournamentName = null,
                noteCategory = null,
                noteDetail = null,
                note = journalNote,
                timestampMs = ts,
            )
            val studyEvent = progress?.let {
                CanonicalStudyProgressEvent(
                    id = validUuidOrStable("study", "${journal.id}:$task"),
                    gameID = journal.gameSlug,
                    task = task,
                    progressPercent = it,
                    timestampMs = ts,
                )
            }
            val videoEntry = if ((parsed.category == "tutorial" || parsed.category == "gameplay") && !videoValue.isNullOrBlank()) {
                CanonicalVideoProgressEntry(
                    id = validUuidOrStable("video", journal.id),
                    gameID = journal.gameSlug,
                    kind = videoKind ?: "percent",
                    value = videoValue,
                    timestampMs = ts,
                )
            } else {
                null
            }
            LegacyToCanonicalJournalParse(
                journalEntry = journalEntry,
                studyEvents = listOfNotNull(studyEvent),
                videoEntries = listOfNotNull(videoEntry),
            )
        }
        else -> {
            LegacyToCanonicalJournalParse(
                journalEntry = CanonicalJournalEntry(
                    id = journalID,
                    gameID = journal.gameSlug,
                    action = "gameBrowse",
                    task = null,
                    progressPercent = null,
                    videoKind = null,
                    videoValue = null,
                    score = null,
                    scoreContext = null,
                    tournamentName = null,
                    noteCategory = null,
                    noteDetail = null,
                    note = null,
                    timestampMs = ts,
                ),
            )
        }
    }
}

private fun <T> stableIdMap(items: List<T>, prefix: String, keyOf: (T) -> String): Map<String, String> {
    return items.associate { item ->
        val key = keyOf(item)
        key to validUuidOrStable(prefix, key)
    }
}

private data class LegacyStudyHeuristic(val category: String, val value: String, val note: String?)

private fun parseLegacyStudySummaryHeuristics(summary: String, action: String): LegacyStudyHeuristic {
    if (action == "practice") {
        val (head, note) = splitLegacyHeadAndNote(summary)
        val value = head.substringBefore(" on ").trim().ifBlank { "Practice session" }
        return LegacyStudyHeuristic("practice", value, note)
    }
    Regex("""^Read\s+(.+?)\s+of\s+.+\s+rulesheet(?:\:\s+(.*))?$""", RegexOption.IGNORE_CASE)
        .matchEntire(summary.trim())
        ?.let { match ->
            return LegacyStudyHeuristic("rulesheet", match.groupValues[1].trim(), match.groupValues.getOrNull(2)?.ifBlank { null })
        }
    Regex("""^Tutorial progress on .+?:\s*(.+)$""", RegexOption.IGNORE_CASE)
        .matchEntire(summary.trim())
        ?.let { match ->
            val (value, note) = splitLegacyHeadAndNote(match.groupValues[1])
            return LegacyStudyHeuristic("tutorial", value.ifBlank { "0%" }, note)
        }
    Regex("""^Gameplay progress on .+?:\s*(.+)$""", RegexOption.IGNORE_CASE)
        .matchEntire(summary.trim())
        ?.let { match ->
            val (value, note) = splitLegacyHeadAndNote(match.groupValues[1])
            return LegacyStudyHeuristic("gameplay", value.ifBlank { "0%" }, note)
        }
    Regex("""^Viewed .+ playfield(?:\:\s+(.*))?$""", RegexOption.IGNORE_CASE)
        .matchEntire(summary.trim())
        ?.let { match ->
            return LegacyStudyHeuristic("playfield", "Viewed", match.groupValues.getOrNull(1)?.ifBlank { null })
        }
    return LegacyStudyHeuristic(if (action == "practice") "practice" else "rulesheet", summary.trim(), null)
}

private fun splitLegacyHeadAndNote(raw: String): Pair<String, String?> {
    val index = raw.indexOf(": ")
    if (index < 0) return raw.trim() to null
    return raw.substring(0, index).trim() to raw.substring(index + 2).trim().ifBlank { null }
}

private fun splitLegacyScoreContext(raw: String): Pair<String, String?> {
    return if (raw.startsWith("tournament:")) {
        "tournament" to raw.removePrefix("tournament:").trim().ifBlank { null }
    } else {
        raw.ifBlank { "practice" } to null
    }
}

private fun extractPercentInt(raw: String?): Int? =
    raw?.let { Regex("""(\d{1,3})\s*%""").find(it)?.groupValues?.getOrNull(1)?.toIntOrNull() }?.coerceIn(0, 100)

private fun inferVideoKind(value: String): String {
    return if (value.contains(":")) "clock" else "percent"
}
