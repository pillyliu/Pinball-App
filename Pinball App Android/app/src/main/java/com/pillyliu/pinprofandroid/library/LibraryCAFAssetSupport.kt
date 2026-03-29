package com.pillyliu.pinprofandroid.library

import org.json.JSONObject

internal fun buildCAFOverrides(
    playfieldRaw: String?,
    gameinfoRaw: String?,
): Map<String, LegacyCuratedOverride> {
    val overrides = linkedMapOf<String, LegacyCuratedOverride>()

    fun upsertOverride(key: String, mutate: (LegacyCuratedOverride) -> Unit) {
        val normalizedKey = normalizedOptionalString(key) ?: return
        val current = overrides[normalizedKey] ?: LegacyCuratedOverride(practiceIdentity = normalizedKey)
        mutate(current)
        overrides[normalizedKey] = current
    }

    val playfieldRecords = runCatching { JSONObject(playfieldRaw ?: "").optJSONArray("records") }.getOrNull()
    if (playfieldRecords != null) {
        for (index in 0 until playfieldRecords.length()) {
            val obj = playfieldRecords.optJSONObject(index) ?: continue
            val playfieldLocalPath = normalizedOptionalString(obj.optString("playfieldLocalPath"))
            val playfieldSourceUrl = normalizedOptionalString(obj.optString("playfieldSourceUrl"))
            if (playfieldLocalPath == null && playfieldSourceUrl == null) continue

            val keys = linkedSetOf<String>()
            normalizedOptionalString(obj.optString("practiceIdentity"))?.let(keys::add)
            normalizedOptionalString(obj.optString("sourceOpdbMachineId"))?.let { opdbId ->
                keys += opdbId
            }
            val aliases = obj.optJSONArray("coveredAliasIds")
            if (aliases != null) {
                for (aliasIndex in 0 until aliases.length()) {
                    normalizedOptionalString(aliases.optString(aliasIndex))?.let { aliasId ->
                        keys += aliasId
                    }
                }
            }

            keys.forEach { key ->
                upsertOverride(key) { current ->
                    if (current.playfieldLocalPath == null) current.playfieldLocalPath = playfieldLocalPath
                    if (current.playfieldSourceUrl == null) current.playfieldSourceUrl = playfieldSourceUrl
                }
            }
        }
    }

    val gameinfoRecords = runCatching { JSONObject(gameinfoRaw ?: "").optJSONArray("records") }.getOrNull()
    if (gameinfoRecords != null) {
        for (index in 0 until gameinfoRecords.length()) {
            val obj = gameinfoRecords.optJSONObject(index) ?: continue
            if (obj.optBoolean("isHidden")) continue
            if (obj.has("isActive") && !obj.optBoolean("isActive", true)) continue
            val localPath = normalizedOptionalString(obj.optString("localPath")) ?: continue
            val practiceIdentity = normalizedOptionalString(obj.optString("opdbId")) ?: continue
            upsertOverride(practiceIdentity) { current ->
                if (current.gameinfoLocalPath == null) current.gameinfoLocalPath = localPath
            }
        }
    }

    return overrides
}

internal fun buildCAFGroupedRulesheetLinks(raw: String?): Map<String, List<CatalogRulesheetLinkRecord>> {
    val records = mutableListOf<CatalogRulesheetLinkRecord>()
    val array = runCatching { JSONObject(raw ?: "").optJSONArray("records") }.getOrNull() ?: return emptyMap()
    for (index in 0 until array.length()) {
        val obj = array.optJSONObject(index) ?: continue
        if (obj.optBoolean("isHidden")) continue
        if (obj.has("isActive") && !obj.optBoolean("isActive", true)) continue
        val practiceIdentity = normalizedOptionalString(obj.optString("opdbId")) ?: continue
        records += CatalogRulesheetLinkRecord(
            practiceIdentity = practiceIdentity,
            provider = normalizedOptionalString(obj.optString("provider")) ?: "",
            label = normalizedOptionalString(obj.optString("label")) ?: "Rulesheet",
            url = normalizedOptionalString(obj.optString("url")),
            localPath = normalizedOptionalString(obj.optString("localPath")),
            priority = if (obj.has("priority") && !obj.isNull("priority")) obj.optInt("priority") else null,
        )
    }
    return records.groupBy { it.practiceIdentity }
}

internal fun buildCAFGroupedVideoLinks(raw: String?): Map<String, List<CatalogVideoLinkRecord>> {
    val records = mutableListOf<CatalogVideoLinkRecord>()
    val array = runCatching { JSONObject(raw ?: "").optJSONArray("records") }.getOrNull() ?: return emptyMap()
    for (index in 0 until array.length()) {
        val obj = array.optJSONObject(index) ?: continue
        if (obj.optBoolean("isHidden")) continue
        if (obj.has("isActive") && !obj.optBoolean("isActive", true)) continue
        val practiceIdentity = normalizedOptionalString(obj.optString("opdbId")) ?: continue
        val url = normalizedOptionalString(obj.optString("url")) ?: continue
        records += CatalogVideoLinkRecord(
            practiceIdentity = practiceIdentity,
            provider = normalizedOptionalString(obj.optString("provider")) ?: "",
            kind = normalizedOptionalString(obj.optString("kind")),
            label = normalizedOptionalString(obj.optString("label")) ?: "Video",
            url = url,
            priority = if (obj.has("priority") && !obj.isNull("priority")) obj.optInt("priority") else null,
        )
    }
    return records.groupBy { it.practiceIdentity }
}

internal fun catalogCuratedOverride(
    practiceIdentity: String?,
    opdbGroupId: String?,
    opdbId: String? = null,
    overridesByKey: Map<String, LegacyCuratedOverride>,
): LegacyCuratedOverride? {
    val candidateKeys = listOf(
        normalizedOptionalString(opdbId),
        normalizedOptionalString(practiceIdentity),
        normalizedOptionalString(opdbGroupId),
    ).distinct().filterNotNull()
    return candidateKeys.firstNotNullOfOrNull { overridesByKey[it] }
}
