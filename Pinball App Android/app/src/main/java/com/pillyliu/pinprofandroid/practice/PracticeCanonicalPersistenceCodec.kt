package com.pillyliu.pinprofandroid.practice

import org.json.JSONArray
import org.json.JSONObject

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
        state.leagueSettings.lastRepairVersion?.let { put("lastRepairVersion", it) }
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
