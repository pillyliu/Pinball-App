package com.pillyliu.pinprofandroid.library

import org.json.JSONObject

internal data class PracticeIdentityCurations(
    val practiceIdentityByOpdbId: Map<String, String> = emptyMap(),
)

internal fun opdbGroupIdFromOpdbId(opdbId: String?): String? {
    val trimmed = normalizedOptionalString(opdbId) ?: return null
    if (!trimmed.startsWith("G")) return null
    val dashIndex = trimmed.indexOf('-')
    return if (dashIndex < 0) trimmed else trimmed.substring(0, dashIndex).ifBlank { null }
}

internal fun parsePracticeIdentityCurations(raw: String?): PracticeIdentityCurations {
    val root = runCatching { JSONObject(raw ?: "") }.getOrNull() ?: return PracticeIdentityCurations()
    val splits = root.optJSONArray("splits") ?: return PracticeIdentityCurations()
    val resolved = linkedMapOf<String, String>()
    for (splitIndex in 0 until splits.length()) {
        val split = splits.optJSONObject(splitIndex) ?: continue
        val entries = split.optJSONArray("practiceEntries") ?: continue
        for (entryIndex in 0 until entries.length()) {
            val entry = entries.optJSONObject(entryIndex) ?: continue
            val practiceIdentity = normalizedOptionalString(entry.optString("practiceIdentity")) ?: continue
            val memberIds = entry.optJSONArray("memberOpdbIds") ?: continue
            for (memberIndex in 0 until memberIds.length()) {
                val memberId = normalizedOptionalString(memberIds.optString(memberIndex)) ?: continue
                resolved[memberId] = practiceIdentity
            }
        }
    }
    return PracticeIdentityCurations(practiceIdentityByOpdbId = resolved)
}

internal fun resolvePracticeIdentity(opdbId: String?, curations: PracticeIdentityCurations): String? {
    val fullId = normalizedOptionalString(opdbId) ?: return null
    return curations.practiceIdentityByOpdbId[fullId] ?: opdbGroupIdFromOpdbId(fullId) ?: fullId
}
