package com.pillyliu.pinprofandroid.practice

internal fun canonicalPracticeStateFromRuntimeAndShadow(
    runtime: PracticePersistedState,
    shadow: CanonicalPracticePersistedState,
    nowMs: Long = System.currentTimeMillis(),
): CanonicalPracticePersistedState {
    val existingGroupMeta = shadow.customGroups.associateBy { it.id }
    val customGroups = runtime.groups.map { group ->
        val existing = existingGroupMeta[group.id]
        CanonicalCustomGroup(
            id = group.id,
            name = group.name,
            gameIDs = group.gameSlugs.distinct(),
            type = group.type.ifBlank { "custom" },
            isActive = group.isActive,
            isArchived = group.isArchived,
            isPriority = group.isPriority,
            startDateMs = group.startDateMs,
            endDateMs = group.endDateMs,
            createdAtMs = existing?.createdAtMs ?: (group.startDateMs ?: nowMs),
        )
    }
    return shadow.copy(
        schemaVersion = CANONICAL_PRACTICE_SCHEMA_VERSION,
        customGroups = customGroups,
        leagueSettings = shadow.leagueSettings.copy(playerName = runtime.leaguePlayerName),
        syncSettings = shadow.syncSettings.copy(cloudSyncEnabled = runtime.cloudSyncEnabled),
        gameSummaryNotes = runtime.gameSummaryNotes,
        practiceSettings = shadow.practiceSettings.copy(
            playerName = runtime.playerName,
            ifpaPlayerID = runtime.ifpaPlayerID,
            prpaPlayerID = runtime.prpaPlayerID,
            comparisonPlayerName = runtime.comparisonPlayerName,
            selectedGroupID = runtime.selectedGroupID,
        ),
    )
}

internal fun runtimePracticeStateFromCanonicalState(
    canonical: CanonicalPracticePersistedState,
    gameNameForKey: (String) -> String,
): PracticePersistedState {
    val scores = canonical.scoreEntries.map { entry ->
        val contextString = if (entry.context == "tournament" && !entry.tournamentName.isNullOrBlank()) {
            "tournament:${entry.tournamentName.trim()}"
        } else {
            entry.context
        }
        ScoreEntry(
            id = entry.id,
            gameSlug = entry.gameID,
            score = entry.score,
            context = contextString,
            timestampMs = entry.timestampMs,
            leagueImported = entry.leagueImported,
        )
    }
    val notes = canonical.noteEntries.map { entry ->
        NoteEntry(
            id = entry.id,
            gameSlug = entry.gameID,
            category = entry.category,
            detail = entry.detail?.takeIf { it.isNotBlank() },
            note = entry.note,
            timestampMs = entry.timestampMs,
        )
    }
    val journal = canonical.journalEntries.map { entry ->
        val gameName = gameNameForKey(entry.gameID)
        JournalEntry(
            id = entry.id,
            gameSlug = entry.gameID,
            action = legacyActionForCanonicalJournal(entry),
            summary = legacySummaryForCanonicalJournal(entry, gameName),
            timestampMs = entry.timestampMs,
        )
    }
    val rulesheetProgress = latestRulesheetProgressFromCanonicalStudyEvents(canonical.studyEvents)
    val groups = canonical.customGroups.map { group ->
        PracticeGroup(
            id = group.id,
            name = group.name,
            gameSlugs = group.gameIDs.distinct(),
            type = group.type,
            isActive = group.isActive,
            isArchived = group.isArchived,
            isPriority = group.isPriority,
            startDateMs = group.startDateMs,
            endDateMs = group.endDateMs,
        )
    }
    return PracticePersistedState(
        playerName = canonical.practiceSettings.playerName,
        ifpaPlayerID = canonical.practiceSettings.ifpaPlayerID,
        prpaPlayerID = canonical.practiceSettings.prpaPlayerID,
        comparisonPlayerName = canonical.practiceSettings.comparisonPlayerName,
        leaguePlayerName = canonical.leagueSettings.playerName,
        cloudSyncEnabled = canonical.syncSettings.cloudSyncEnabled,
        selectedGroupID = canonical.practiceSettings.selectedGroupID,
        groups = groups,
        scores = scores,
        notes = notes,
        journal = journal,
        rulesheetProgress = rulesheetProgress,
        gameSummaryNotes = canonical.gameSummaryNotes,
    )
}

private fun latestRulesheetProgressFromCanonicalStudyEvents(
    events: List<CanonicalStudyProgressEvent>,
): Map<String, Float> {
    val sorted = events.sortedBy { it.timestampMs }
    val out = linkedMapOf<String, Float>()
    sorted.forEach { event ->
        if (event.task != "rulesheet") return@forEach
        out[event.gameID] = (event.progressPercent.coerceIn(0, 100) / 100f)
    }
    return out
}

private fun legacyActionForCanonicalJournal(entry: CanonicalJournalEntry): String {
    return when (entry.action) {
        "rulesheetRead", "tutorialWatch", "gameplayWatch", "playfieldViewed" -> "study"
        "practiceSession" -> "practice"
        "scoreLogged" -> "score"
        "noteAdded" -> if (entry.noteCategory == "mechanics") "mechanics" else "note"
        "gameBrowse" -> "browse"
        else -> "browse"
    }
}

private fun legacySummaryForCanonicalJournal(entry: CanonicalJournalEntry, gameName: String): String {
    return when (entry.action) {
        "scoreLogged" -> {
            val score = entry.score ?: 0.0
            val contextLabel = when {
                entry.scoreContext == "tournament" && !entry.tournamentName.isNullOrBlank() -> "Tournament: ${entry.tournamentName}"
                !entry.scoreContext.isNullOrBlank() -> entry.scoreContext.replaceFirstChar { it.titlecase() }
                else -> "Practice"
            }
            "Score: ${formatScore(score)} • $gameName ($contextLabel)"
        }
        "noteAdded" -> practiceNoteJournalSummary(
            category = entry.noteCategory ?: "general",
            gameName = gameName,
            detail = entry.noteDetail,
            note = entry.note ?: "",
        )
        "rulesheetRead", "tutorialWatch", "gameplayWatch", "playfieldViewed", "practiceSession" -> {
            val category = when (entry.action) {
                "rulesheetRead" -> "rulesheet"
                "tutorialWatch" -> "tutorial"
                "gameplayWatch" -> "gameplay"
                "playfieldViewed" -> "playfield"
                "practiceSession" -> "practice"
                else -> "study"
            }
            val value = when (category) {
                "rulesheet" -> entry.progressPercent?.let { "$it%" } ?: "0%"
                "tutorial", "gameplay" -> entry.videoValue ?: (entry.progressPercent?.let { "$it%" } ?: "0%")
                "playfield" -> "Viewed"
                "practice" -> "Practice session"
                else -> entry.note ?: "Updated"
            }
            studyJournalSummaryForCategory(category, value, gameName, entry.note)
        }
        "gameBrowse" -> "Viewed $gameName game page"
        else -> "Viewed $gameName game page"
    }
}
