package com.pillyliu.pinprofandroid.practice

import org.json.JSONObject

private const val APPLE_REFERENCE_EPOCH_OFFSET_MS = 978_307_200_000L

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
                csvAutoFillEnabled = obj.optBoolean("csvAutoFillEnabled", true),
                lastImportAtMs = parseFlexibleTimestampMsOrNull(obj, "lastImportAt"),
                lastRepairVersion = if (obj.has("lastRepairVersion") && !obj.isNull("lastRepairVersion")) obj.optInt("lastRepairVersion") else null,
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
                prpaPlayerID = obj.optString("prpaPlayerID", ""),
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
