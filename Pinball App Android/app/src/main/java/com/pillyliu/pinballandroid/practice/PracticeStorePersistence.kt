package com.pillyliu.pinballandroid.practice

import org.json.JSONArray
import org.json.JSONObject

internal data class PracticePersistedState(
    val playerName: String,
    val comparisonPlayerName: String,
    val leaguePlayerName: String,
    val cloudSyncEnabled: Boolean,
    val selectedGroupID: String?,
    val groups: List<PracticeGroup>,
    val scores: List<ScoreEntry>,
    val notes: List<NoteEntry>,
    val journal: List<JournalEntry>,
    val rulesheetProgress: Map<String, Float>,
    val gameSummaryNotes: Map<String, String>,
)

internal fun buildPracticeStateJson(state: PracticePersistedState): String {
    val root = JSONObject()
    root.put("playerName", state.playerName)
    root.put("comparisonPlayerName", state.comparisonPlayerName)
    root.put("leaguePlayerName", state.leaguePlayerName)
    root.put("cloudSyncEnabled", state.cloudSyncEnabled)
    root.put("selectedGroupID", state.selectedGroupID)

    root.put("groups", JSONArray().apply {
        state.groups.forEach { group ->
            put(JSONObject().apply {
                put("id", group.id)
                put("name", group.name)
                put("gameSlugs", JSONArray(group.gameSlugs))
                put("type", group.type)
                put("isActive", group.isActive)
                put("isArchived", group.isArchived)
                put("isPriority", group.isPriority)
                put("startDateMs", group.startDateMs)
                put("endDateMs", group.endDateMs)
            })
        }
    })

    root.put("scores", JSONArray().apply {
        state.scores.forEach { score ->
            put(JSONObject().apply {
                put("id", score.id)
                put("gameSlug", score.gameSlug)
                put("score", score.score)
                put("context", score.context)
                put("timestampMs", score.timestampMs)
                put("leagueImported", score.leagueImported)
            })
        }
    })

    root.put("notes", JSONArray().apply {
        state.notes.forEach { note ->
            put(JSONObject().apply {
                put("id", note.id)
                put("gameSlug", note.gameSlug)
                put("category", note.category)
                put("detail", note.detail)
                put("note", note.note)
                put("timestampMs", note.timestampMs)
            })
        }
    })

    root.put("journal", JSONArray().apply {
        state.journal.forEach { entry ->
            put(JSONObject().apply {
                put("id", entry.id)
                put("gameSlug", entry.gameSlug)
                put("action", entry.action)
                put("summary", entry.summary)
                put("timestampMs", entry.timestampMs)
            })
        }
    })

    root.put("rulesheetProgress", JSONObject().apply {
        state.rulesheetProgress.forEach { (slug, ratio) -> put(slug, ratio.toDouble()) }
    })

    root.put("gameSummaryNotes", JSONObject().apply {
        state.gameSummaryNotes.forEach { (slug, note) -> put(slug, note) }
    })

    return root.toString()
}

internal fun parsePracticeStateJson(raw: String): PracticePersistedState? {
    return runCatching {
        val root = JSONObject(raw)
        PracticePersistedState(
            playerName = root.optString("playerName", ""),
            comparisonPlayerName = root.optString("comparisonPlayerName", ""),
            leaguePlayerName = root.optString("leaguePlayerName", ""),
            cloudSyncEnabled = root.optBoolean("cloudSyncEnabled", false),
            selectedGroupID = root.optString("selectedGroupID").takeIf { it.isNotBlank() && it != "null" },
            groups = root.optJSONArray("groups")?.let { arr ->
                (0 until arr.length()).mapNotNull { idx ->
                    arr.optJSONObject(idx)?.let { obj ->
                        PracticeGroup(
                            id = obj.optString("id"),
                            name = obj.optString("name"),
                            gameSlugs = obj.optJSONArray("gameSlugs")?.toStringList() ?: emptyList(),
                            type = obj.optString("type", "custom"),
                            isActive = obj.optBoolean("isActive", true),
                            isArchived = obj.optBoolean("isArchived", false),
                            isPriority = obj.optBoolean("isPriority", false),
                            startDateMs = obj.optLong("startDateMs").takeIf { it > 0 },
                            endDateMs = obj.optLong("endDateMs").takeIf { it > 0 },
                        )
                    }
                }
            } ?: emptyList(),
            scores = root.optJSONArray("scores")?.let { arr ->
                (0 until arr.length()).mapNotNull { idx ->
                    arr.optJSONObject(idx)?.let { obj ->
                        ScoreEntry(
                            id = obj.optString("id"),
                            gameSlug = obj.optString("gameSlug"),
                            score = obj.optDouble("score"),
                            context = obj.optString("context", "practice"),
                            timestampMs = obj.optLong("timestampMs"),
                            leagueImported = obj.optBoolean("leagueImported", false),
                        )
                    }
                }
            } ?: emptyList(),
            notes = root.optJSONArray("notes")?.let { arr ->
                (0 until arr.length()).mapNotNull { idx ->
                    arr.optJSONObject(idx)?.let { obj ->
                        NoteEntry(
                            id = obj.optString("id"),
                            gameSlug = obj.optString("gameSlug"),
                            category = obj.optString("category"),
                            detail = obj.optString("detail").takeIf { it.isNotBlank() },
                            note = obj.optString("note"),
                            timestampMs = obj.optLong("timestampMs"),
                        )
                    }
                }
            } ?: emptyList(),
            journal = root.optJSONArray("journal")?.let { arr ->
                (0 until arr.length()).mapNotNull { idx ->
                    arr.optJSONObject(idx)?.let { obj ->
                        JournalEntry(
                            id = obj.optString("id"),
                            gameSlug = obj.optString("gameSlug"),
                            action = obj.optString("action"),
                            summary = obj.optString("summary"),
                            timestampMs = obj.optLong("timestampMs"),
                        )
                    }
                }
            } ?: emptyList(),
            rulesheetProgress = root.optJSONObject("rulesheetProgress")?.let { obj ->
                obj.keys().asSequence().associateWith { key -> obj.optDouble(key, 0.0).toFloat().coerceIn(0f, 1f) }
            } ?: emptyMap(),
            gameSummaryNotes = root.optJSONObject("gameSummaryNotes")?.let { obj ->
                obj.keys().asSequence()
                    .map { key -> key to obj.optString(key) }
                    .filter { (_, value) -> value.isNotBlank() }
                    .toMap()
            } ?: emptyMap(),
        )
    }.getOrNull()
}
