package com.pillyliu.pinprofandroid.library

import org.json.JSONArray
import org.json.JSONObject

internal fun decodeLibrarySourceState(raw: String?): LibrarySourceState {
    if (raw == null) return LibrarySourceState()
    return runCatching {
        val root = JSONObject(raw)
        LibrarySourceState(
            enabledSourceIds = root.optJSONArray("enabledSourceIds").toStringList(),
            pinnedSourceIds = root.optJSONArray("pinnedSourceIds").toStringList(),
            selectedSourceId = root.optString("selectedSourceId").trim().ifBlank { null },
            selectedSortBySource = root.optJSONObject("selectedSortBySource").toStringMap(),
            selectedBankBySource = root.optJSONObject("selectedBankBySource").toIntMap(),
        )
    }.getOrDefault(LibrarySourceState())
}

internal fun encodeLibrarySourceState(state: LibrarySourceState): String {
    val normalized = normalizeLibrarySourceState(state)
    return JSONObject().apply {
        put("enabledSourceIds", JSONArray().apply { normalized.enabledSourceIds.forEach(::put) })
        put("pinnedSourceIds", JSONArray().apply { normalized.pinnedSourceIds.forEach(::put) })
        put("selectedSourceId", normalized.selectedSourceId)
        put("selectedSortBySource", JSONObject().apply {
            normalized.selectedSortBySource.forEach { (key, value) -> put(key, value) }
        })
        put("selectedBankBySource", JSONObject().apply {
            normalized.selectedBankBySource.forEach { (key, value) -> put(key, value) }
        })
    }.toString()
}

internal fun normalizeLibrarySourceState(state: LibrarySourceState): LibrarySourceState =
    LibrarySourceState(
        enabledSourceIds = state.enabledSourceIds.mapNotNull(::canonicalLibrarySourceId).distinct(),
        pinnedSourceIds = state.pinnedSourceIds.mapNotNull(::canonicalLibrarySourceId).distinct(),
        selectedSourceId = canonicalLibrarySourceId(state.selectedSourceId),
        selectedSortBySource = state.selectedSortBySource.mapNotNullKeys(::canonicalLibrarySourceId),
        selectedBankBySource = state.selectedBankBySource.mapNotNullKeys(::canonicalLibrarySourceId),
    )

internal fun filteredKnownLibrarySourceIds(ids: List<String>, validIds: Set<String>): List<String> {
    val seen = LinkedHashSet<String>()
    return ids.mapNotNull(::canonicalLibrarySourceId).filter { id -> validIds.contains(id) && seen.add(id) }
}
