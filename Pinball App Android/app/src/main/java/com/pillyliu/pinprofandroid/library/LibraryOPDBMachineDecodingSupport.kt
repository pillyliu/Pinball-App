package com.pillyliu.pinprofandroid.library

import org.json.JSONArray
import org.json.JSONObject

internal fun rawOpdbCatalogMachineRecord(
    obj: JSONObject,
    curations: PracticeIdentityCurations,
): CatalogMachineRecord? {
    if (obj.has("is_machine") && !obj.isNull("is_machine") && !obj.optBoolean("is_machine", true)) {
        return null
    }
    val opdbId = obj.optStringOrNullLocal("opdb_id") ?: return null
    val practiceIdentity = resolvePracticeIdentity(opdbId, curations) ?: return null
    val opdbGroupId = opdbGroupIdFromOpdbId(opdbId) ?: practiceIdentity
    val name = obj.optStringOrNullLocal("name") ?: return null
    val manufacturer = obj.optJSONObject("manufacturer")
    val manufacturerRawId = if (manufacturer?.has("manufacturer_id") == true && !manufacturer.isNull("manufacturer_id")) {
        manufacturer.optInt("manufacturer_id").takeIf { it > 0 }
    } else {
        null
    }
    val (primaryMediumUrl, primaryLargeUrl) = rawOpdbImageSet(obj.optJSONArray("images"), "backglass") ?: (null to null)
    val (playfieldMediumUrl, playfieldLargeUrl) = rawOpdbImageSet(obj.optJSONArray("images"), "playfield") ?: (null to null)

    return CatalogMachineRecord(
        practiceIdentity = practiceIdentity,
        opdbMachineId = opdbId,
        opdbGroupId = opdbGroupId,
        slug = practiceIdentity,
        name = name,
        variant = null,
        manufacturerId = manufacturerRawId?.let { "manufacturer-$it" },
        manufacturerName = manufacturer?.optStringOrNullLocal("name"),
        year = rawOpdbYear(obj.optStringOrNullLocal("manufacture_date")),
        opdbName = normalizedOptionalString(name),
        opdbCommonName = obj.optStringOrNullLocal("common_name"),
        opdbShortname = obj.optStringOrNullLocal("shortname"),
        opdbDescription = obj.optStringOrNullLocal("description"),
        opdbType = obj.optStringOrNullLocal("type"),
        opdbDisplay = obj.optStringOrNullLocal("display"),
        opdbPlayerCount = obj.optIntOrNullLocal("player_count"),
        opdbManufactureDate = obj.optStringOrNullLocal("manufacture_date"),
        opdbIpdbId = obj.optIntOrNullLocal("ipdb_id"),
        opdbGroupShortname = null,
        opdbGroupDescription = null,
        primaryImageMediumUrl = primaryMediumUrl,
        primaryImageLargeUrl = primaryLargeUrl,
        playfieldImageMediumUrl = playfieldMediumUrl,
        playfieldImageLargeUrl = playfieldLargeUrl,
    )
}

private fun rawOpdbYear(manufactureDate: String?): Int? {
    val prefix = manufactureDate?.take(4) ?: return null
    return if (prefix.length == 4) prefix.toIntOrNull() else null
}

private fun rawOpdbImageSet(images: JSONArray?, preferredType: String): Pair<String?, String?>? {
    if (images == null) return null
    val normalizedPreferredType = preferredType.trim().lowercase()
    val typedMatches = buildList<JSONObject> {
        for (index in 0 until images.length()) {
            val image = images.optJSONObject(index) ?: continue
            val type = image.optString("type").trim().lowercase()
            if (type == normalizedPreferredType) add(image)
        }
    }
    val selected = typedMatches.firstOrNull { image ->
        val urls = image.optJSONObject("urls")
        image.optBoolean("primary") && (
            !urls?.optString("medium").isNullOrBlank() ||
                !urls?.optString("large").isNullOrBlank()
            )
    } ?: typedMatches.firstOrNull { image ->
        val urls = image.optJSONObject("urls")
        !urls?.optString("medium").isNullOrBlank() ||
            !urls?.optString("large").isNullOrBlank()
    } ?: return null
    val urls = selected.optJSONObject("urls")
    return normalizedOptionalString(urls?.optString("medium")) to
        normalizedOptionalString(urls?.optString("large"))
}

private fun JSONObject.optIntOrNullLocal(name: String): Int? =
    if (has(name) && !isNull(name)) optInt(name) else null

private fun JSONObject.optStringOrNullLocal(name: String): String? =
    optString(name)
        .trim()
        .takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }
