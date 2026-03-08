package com.pillyliu.pinprofandroid.practice

import org.json.JSONArray
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.util.UUID

private const val APPLE_REFERENCE_EPOCH_OFFSET_MS = 978_307_200_000L

internal fun buildCanonicalPracticeStateJson(state: CanonicalPracticePersistedState): String {
    val root = JSONObject()
    root.put("schemaVersion", state.schemaVersion)
    root.put("studyEvents", JSONArray().apply {
        state.studyEvents.forEach { event ->
            put(JSONObject().apply {
                put("id", event.id)
                put("gameID", event.gameID)
                put("task", event.task)
                put("progressPercent", event.progressPercent)
                put("timestamp", event.timestampMs)
            })
        }
    })
    root.put("videoProgressEntries", JSONArray().apply {
        state.videoProgressEntries.forEach { entry ->
            put(JSONObject().apply {
                put("id", entry.id)
                put("gameID", entry.gameID)
                put("kind", entry.kind)
                put("value", entry.value)
                put("timestamp", entry.timestampMs)
            })
        }
    })
    root.put("scoreEntries", JSONArray().apply {
        state.scoreEntries.forEach { entry ->
            put(JSONObject().apply {
                put("id", entry.id)
                put("gameID", entry.gameID)
                put("score", entry.score)
                put("context", entry.context)
                entry.tournamentName?.takeIf { it.isNotBlank() }?.let { put("tournamentName", it) }
                put("timestamp", entry.timestampMs)
                put("leagueImported", entry.leagueImported)
            })
        }
    })
    root.put("noteEntries", JSONArray().apply {
        state.noteEntries.forEach { entry ->
            put(JSONObject().apply {
                put("id", entry.id)
                put("gameID", entry.gameID)
                put("category", entry.category)
                entry.detail?.takeIf { it.isNotBlank() }?.let { put("detail", it) }
                put("note", entry.note)
                put("timestamp", entry.timestampMs)
            })
        }
    })
    root.put("journalEntries", JSONArray().apply {
        state.journalEntries.forEach { entry ->
            put(JSONObject().apply {
                put("id", entry.id)
                put("gameID", entry.gameID)
                put("action", entry.action)
                entry.task?.let { put("task", it) }
                entry.progressPercent?.let { put("progressPercent", it) }
                entry.videoKind?.let { put("videoKind", it) }
                entry.videoValue?.let { put("videoValue", it) }
                entry.score?.let { put("score", it) }
                entry.scoreContext?.let { put("scoreContext", it) }
                entry.tournamentName?.let { put("tournamentName", it) }
                entry.noteCategory?.let { put("noteCategory", it) }
                entry.noteDetail?.let { put("noteDetail", it) }
                entry.note?.let { put("note", it) }
                put("timestamp", entry.timestampMs)
            })
        }
    })
    root.put("customGroups", JSONArray().apply {
        state.customGroups.forEach { group ->
            put(JSONObject().apply {
                put("id", group.id)
                put("name", group.name)
                put("gameIDs", JSONArray(group.gameIDs))
                put("type", group.type)
                put("isActive", group.isActive)
                put("isArchived", group.isArchived)
                put("isPriority", group.isPriority)
                group.startDateMs?.let { put("startDate", it) }
                group.endDateMs?.let { put("endDate", it) }
                put("createdAt", group.createdAtMs)
            })
        }
    })
    root.put("leagueSettings", JSONObject().apply {
        put("playerName", state.leagueSettings.playerName)
        put("csvAutoFillEnabled", state.leagueSettings.csvAutoFillEnabled)
        state.leagueSettings.lastImportAtMs?.let { put("lastImportAt", it) }
    })
    root.put("syncSettings", JSONObject().apply {
        put("cloudSyncEnabled", state.syncSettings.cloudSyncEnabled)
        put("endpoint", state.syncSettings.endpoint)
        put("phaseLabel", state.syncSettings.phaseLabel)
    })
    root.put("analyticsSettings", JSONObject().apply {
        put("gapMode", state.analyticsSettings.gapMode)
        put("useMedian", state.analyticsSettings.useMedian)
    })
    root.put("rulesheetResumeOffsets", JSONObject().apply {
        state.rulesheetResumeOffsets.forEach { (key, value) -> put(key, value) }
    })
    root.put("videoResumeHints", JSONObject().apply {
        state.videoResumeHints.forEach { (key, value) -> put(key, value) }
    })
    root.put("gameSummaryNotes", JSONObject().apply {
        state.gameSummaryNotes.forEach { (key, value) -> put(key, value) }
    })
    root.put("practiceSettings", JSONObject().apply {
        put("playerName", state.practiceSettings.playerName)
        put("ifpaPlayerID", state.practiceSettings.ifpaPlayerID)
        put("comparisonPlayerName", state.practiceSettings.comparisonPlayerName)
        state.practiceSettings.selectedGroupID?.let { put("selectedGroupID", it) }
    })
    return root.toString()
}

internal fun parsePracticeStatePayloadJson(
    raw: String,
    gameNameForKey: (String) -> String,
): ParsedPracticeStatePayload? {
    return runCatching {
        val root = JSONObject(raw)
        val canonical = if (looksLikeCanonicalPracticeState(root)) {
            parseCanonicalPracticeState(root)
        } else {
            val legacy = parsePracticeStateJson(raw) ?: return@runCatching null
            canonicalPracticeStateFromLegacyState(legacy)
        }
        ParsedPracticeStatePayload(
            runtime = runtimePracticeStateFromCanonicalState(canonical, gameNameForKey),
            canonical = canonical,
        )
    }.getOrNull()
}

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

private fun looksLikeCanonicalPracticeState(root: JSONObject): Boolean {
    return root.has("practiceSettings") || root.has("journalEntries") || root.has("customGroups")
}

private fun parseCanonicalPracticeState(root: JSONObject): CanonicalPracticePersistedState {
    val empty = emptyCanonicalPracticePersistedState()
    return CanonicalPracticePersistedState(
        schemaVersion = root.optInt("schemaVersion", CANONICAL_PRACTICE_SCHEMA_VERSION).takeIf { it > 0 } ?: CANONICAL_PRACTICE_SCHEMA_VERSION,
        studyEvents = root.optJSONArray("studyEvents")?.let { arr ->
            (0 until arr.length()).mapNotNull { idx ->
                arr.optJSONObject(idx)?.let { obj ->
                    CanonicalStudyProgressEvent(
                        id = validUuidOrStable("study", obj.optString("id")),
                        gameID = obj.optString("gameID"),
                        task = obj.optString("task"),
                        progressPercent = obj.optInt("progressPercent", 0).coerceIn(0, 100),
                        timestampMs = parseFlexibleTimestampMs(obj, "timestamp"),
                    )
                }
            }
        } ?: emptyList(),
        videoProgressEntries = root.optJSONArray("videoProgressEntries")?.let { arr ->
            (0 until arr.length()).mapNotNull { idx ->
                arr.optJSONObject(idx)?.let { obj ->
                    CanonicalVideoProgressEntry(
                        id = validUuidOrStable("video", obj.optString("id")),
                        gameID = obj.optString("gameID"),
                        kind = obj.optString("kind").ifBlank { "percent" },
                        value = obj.optString("value"),
                        timestampMs = parseFlexibleTimestampMs(obj, "timestamp"),
                    )
                }
            }
        } ?: emptyList(),
        scoreEntries = root.optJSONArray("scoreEntries")?.let { arr ->
            (0 until arr.length()).mapNotNull { idx ->
                arr.optJSONObject(idx)?.let { obj ->
                    CanonicalScoreLogEntry(
                        id = validUuidOrStable("score", obj.optString("id")),
                        gameID = obj.optString("gameID"),
                        score = obj.optDouble("score", 0.0),
                        context = obj.optString("context", "practice"),
                        tournamentName = obj.optString("tournamentName").takeIf { it.isNotBlank() && it != "null" },
                        timestampMs = parseFlexibleTimestampMs(obj, "timestamp"),
                        leagueImported = obj.optBoolean("leagueImported", false),
                    )
                }
            }
        } ?: emptyList(),
        noteEntries = root.optJSONArray("noteEntries")?.let { arr ->
            (0 until arr.length()).mapNotNull { idx ->
                arr.optJSONObject(idx)?.let { obj ->
                    CanonicalPracticeNoteEntry(
                        id = validUuidOrStable("note", obj.optString("id")),
                        gameID = obj.optString("gameID"),
                        category = obj.optString("category"),
                        detail = obj.optString("detail").takeIf { it.isNotBlank() && it != "null" },
                        note = obj.optString("note"),
                        timestampMs = parseFlexibleTimestampMs(obj, "timestamp"),
                    )
                }
            }
        } ?: emptyList(),
        journalEntries = root.optJSONArray("journalEntries")?.let { arr ->
            (0 until arr.length()).mapNotNull { idx ->
                arr.optJSONObject(idx)?.let { obj ->
                    CanonicalJournalEntry(
                        id = validUuidOrStable("journal", obj.optString("id")),
                        gameID = obj.optString("gameID"),
                        action = obj.optString("action"),
                        task = obj.optString("task").takeIf { it.isNotBlank() && it != "null" },
                        progressPercent = if (obj.has("progressPercent")) obj.optInt("progressPercent", 0).coerceIn(0, 100) else null,
                        videoKind = obj.optString("videoKind").takeIf { it.isNotBlank() && it != "null" },
                        videoValue = obj.optString("videoValue").takeIf { it.isNotBlank() && it != "null" },
                        score = if (obj.has("score")) obj.optDouble("score") else null,
                        scoreContext = obj.optString("scoreContext").takeIf { it.isNotBlank() && it != "null" },
                        tournamentName = obj.optString("tournamentName").takeIf { it.isNotBlank() && it != "null" },
                        noteCategory = obj.optString("noteCategory").takeIf { it.isNotBlank() && it != "null" },
                        noteDetail = obj.optString("noteDetail").takeIf { it.isNotBlank() && it != "null" },
                        note = obj.optString("note").takeIf { it.isNotBlank() && it != "null" },
                        timestampMs = parseFlexibleTimestampMs(obj, "timestamp"),
                    )
                }
            }
        } ?: emptyList(),
        customGroups = root.optJSONArray("customGroups")?.let { arr ->
            (0 until arr.length()).mapNotNull { idx ->
                arr.optJSONObject(idx)?.let { obj ->
                    CanonicalCustomGroup(
                        id = validUuidOrStable("group", obj.optString("id")),
                        name = obj.optString("name", "Group"),
                        gameIDs = obj.optJSONArray("gameIDs")?.toStringList() ?: emptyList(),
                        type = obj.optString("type", "custom"),
                        isActive = obj.optBoolean("isActive", true),
                        isArchived = obj.optBoolean("isArchived", false),
                        isPriority = obj.optBoolean("isPriority", false),
                        startDateMs = parseFlexibleTimestampMsOrNull(obj, "startDate"),
                        endDateMs = parseFlexibleTimestampMsOrNull(obj, "endDate"),
                        createdAtMs = parseFlexibleTimestampMsOrNull(obj, "createdAt") ?: System.currentTimeMillis(),
                    )
                }
            }
        } ?: emptyList(),
        leagueSettings = root.optJSONObject("leagueSettings")?.let { obj ->
            CanonicalLeagueSettings(
                playerName = obj.optString("playerName", ""),
                csvAutoFillEnabled = obj.optBoolean("csvAutoFillEnabled", false),
                lastImportAtMs = parseFlexibleTimestampMsOrNull(obj, "lastImportAt"),
            )
        } ?: empty.leagueSettings,
        syncSettings = root.optJSONObject("syncSettings")?.let { obj ->
            CanonicalSyncSettings(
                cloudSyncEnabled = obj.optBoolean("cloudSyncEnabled", false),
                endpoint = obj.optString("endpoint", "pillyliu.com"),
                phaseLabel = obj.optString("phaseLabel", "Phase 1: On-device"),
            )
        } ?: empty.syncSettings,
        analyticsSettings = root.optJSONObject("analyticsSettings")?.let { obj ->
            CanonicalAnalyticsSettings(
                gapMode = obj.optString("gapMode", "compressInactive"),
                useMedian = obj.optBoolean("useMedian", true),
            )
        } ?: empty.analyticsSettings,
        rulesheetResumeOffsets = root.optJSONObject("rulesheetResumeOffsets")?.let { obj ->
            obj.keys().asSequence().associateWith { key -> obj.optDouble(key, 0.0).coerceAtLeast(0.0) }
        } ?: emptyMap(),
        videoResumeHints = root.optJSONObject("videoResumeHints")?.let { obj ->
            obj.keys().asSequence().map { key -> key to obj.optString(key) }.filter { it.second.isNotBlank() }.toMap()
        } ?: emptyMap(),
        gameSummaryNotes = root.optJSONObject("gameSummaryNotes")?.let { obj ->
            obj.keys().asSequence().map { key -> key to obj.optString(key) }.filter { it.second.isNotBlank() }.toMap()
        } ?: emptyMap(),
        practiceSettings = root.optJSONObject("practiceSettings")?.let { obj ->
            CanonicalPracticeSettings(
                playerName = obj.optString("playerName", ""),
                ifpaPlayerID = obj.optString("ifpaPlayerID", ""),
                comparisonPlayerName = obj.optString("comparisonPlayerName", ""),
                selectedGroupID = obj.optString("selectedGroupID").takeIf { it.isNotBlank() && it != "null" }?.let { validUuidOrStable("group", it) },
            )
        } ?: empty.practiceSettings,
    )
}

private fun parseFlexibleTimestampMs(obj: JSONObject, key: String): Long {
    return parseFlexibleTimestampMsOrNull(obj, key) ?: 0L
}

private fun parseFlexibleTimestampMsOrNull(obj: JSONObject, key: String): Long? {
    if (!obj.has(key)) return null
    val value = obj.opt(key) ?: return null
    return when (value) {
        is Number -> {
            val raw = value.toDouble()
            if (!raw.isFinite()) null else flexibleDateNumberToUnixMs(raw)
        }
        is String -> value.toLongOrNull()
        else -> null
    }
}

private fun flexibleDateNumberToUnixMs(raw: Double): Long {
    return when {
        raw > 10_000_000_000L -> raw.toLong()
        raw >= 978_307_200.0 -> (raw * 1000.0).toLong()
        raw > 0 -> (raw * 1000.0).toLong() + APPLE_REFERENCE_EPOCH_OFFSET_MS
        else -> 0L
    }
}

internal fun validUuidOrStable(prefix: String, raw: String?): String {
    val trimmed = raw?.trim().orEmpty()
    if (trimmed.isNotBlank()) {
        runCatching { UUID.fromString(trimmed) }.getOrNull()?.let { return it.toString() }
    }
    return stableUuidForLegacy(prefix, trimmed.ifBlank { "$prefix-empty" })
}

internal fun stableUuidForLegacy(prefix: String, raw: String): String {
    return UUID.nameUUIDFromBytes("$prefix:$raw".toByteArray(StandardCharsets.UTF_8)).toString()
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
