package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.LibraryGameLookup
import org.json.JSONObject

internal data class LeagueMachineMappingRecord(
    val machine: String,
    val practiceIdentity: String?,
    val opdbId: String?,
)

internal fun parseLeagueMachineMappings(text: String): Map<String, LeagueMachineMappingRecord> {
    val root = runCatching { JSONObject(text.trim()) }.getOrNull() ?: return emptyMap()
    if (root.optInt("version", 0) < 1) return emptyMap()
    val items = root.optJSONArray("items") ?: return emptyMap()
    val out = linkedMapOf<String, LeagueMachineMappingRecord>()
    for (index in 0 until items.length()) {
        val obj = items.optJSONObject(index) ?: continue
        val machine = obj.optString("machine").trim()
        if (machine.isBlank()) continue
        val key = LibraryGameLookup.normalizeMachineName(machine)
        if (key.isBlank()) continue
        out[key] = LeagueMachineMappingRecord(
            machine = machine,
            practiceIdentity = obj.optString("practice_identity").trim().ifBlank { null },
            opdbId = obj.optString("opdb_id").trim().ifBlank { null },
        )
    }
    return out
}
