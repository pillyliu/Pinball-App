package com.pillyliu.pinprofandroid.library

import org.json.JSONObject

internal data class VenueMachineLayoutOverlayRecord(
    val sourceId: String,
    val opdbId: String,
    val area: String?,
    val groupNumber: Int?,
    val position: Int?,
)

internal data class VenueMachineBankOverlayRecord(
    val sourceId: String,
    val opdbId: String,
    val bank: Int,
)

internal data class VenueMetadataOverlayIndex(
    val areaOrderByKey: Map<String, Int> = emptyMap(),
    val machineLayoutByKey: Map<String, VenueMachineLayoutOverlayRecord> = emptyMap(),
    val machineBankByKey: Map<String, VenueMachineBankOverlayRecord> = emptyMap(),
)

internal data class ResolvedImportedVenueMetadata(
    val area: String?,
    val areaOrder: Int?,
    val group: Int?,
    val position: Int?,
    val bank: Int?,
)

internal fun venueOverlayAreaKey(sourceId: String, area: String): String = "$sourceId::$area"

internal fun venueOverlayMachineKey(sourceId: String, opdbId: String): String = "$sourceId::$opdbId"

internal fun parseCAFVenueLayoutAssets(raw: String?): VenueMetadataOverlayIndex {
    val areaOrderByKey = linkedMapOf<String, Int>()
    val machineLayoutByKey = linkedMapOf<String, VenueMachineLayoutOverlayRecord>()
    val machineBankByKey = linkedMapOf<String, VenueMachineBankOverlayRecord>()
    val array = runCatching { JSONObject(raw ?: "").optJSONArray("records") }.getOrNull() ?: return VenueMetadataOverlayIndex()

    for (index in 0 until array.length()) {
        val obj = array.optJSONObject(index) ?: continue
        val sourceId = canonicalLibrarySourceId(obj.optString("sourceId"))
            ?: normalizedOptionalString(obj.optString("sourceId"))
            ?: continue
        val opdbId = normalizedOptionalString(obj.optString("opdbId")) ?: continue
        val area = normalizedOptionalString(obj.optString("area"))
        val areaOrder = if (obj.has("areaOrder") && !obj.isNull("areaOrder")) obj.optInt("areaOrder") else null
        val groupNumber = if (obj.has("groupNumber") && !obj.isNull("groupNumber")) obj.optInt("groupNumber") else null
        val position = if (obj.has("position") && !obj.isNull("position")) obj.optInt("position") else null
        val bank = if (obj.has("bank") && !obj.isNull("bank")) obj.optInt("bank") else null

        if (area != null && areaOrder != null) {
            areaOrderByKey[venueOverlayAreaKey(sourceId, area)] = areaOrder
        }
        if (area != null || groupNumber != null || position != null) {
            machineLayoutByKey[venueOverlayMachineKey(sourceId, opdbId)] = VenueMachineLayoutOverlayRecord(
                sourceId = sourceId,
                opdbId = opdbId,
                area = area,
                groupNumber = groupNumber,
                position = position,
            )
        }
        if (bank != null) {
            machineBankByKey[venueOverlayMachineKey(sourceId, opdbId)] = VenueMachineBankOverlayRecord(
                sourceId = sourceId,
                opdbId = opdbId,
                bank = bank,
            )
        }
    }

    return VenueMetadataOverlayIndex(
        areaOrderByKey = areaOrderByKey,
        machineLayoutByKey = machineLayoutByKey,
        machineBankByKey = machineBankByKey,
    )
}

internal fun mergeVenueMetadataOverlayIndices(
    lhs: VenueMetadataOverlayIndex,
    rhs: VenueMetadataOverlayIndex,
): VenueMetadataOverlayIndex = VenueMetadataOverlayIndex(
    areaOrderByKey = lhs.areaOrderByKey + rhs.areaOrderByKey,
    machineLayoutByKey = lhs.machineLayoutByKey + rhs.machineLayoutByKey,
    machineBankByKey = lhs.machineBankByKey + rhs.machineBankByKey,
)

internal fun resolveImportedVenueMetadata(
    sourceId: String,
    requestedOpdbId: String,
    machine: CatalogMachineRecord,
    overlays: VenueMetadataOverlayIndex,
): ResolvedImportedVenueMetadata? {
    fun expandedOverlayCandidateIds(value: String?): List<String> {
        val normalized = normalizedOptionalString(value) ?: return emptyList()
        val out = mutableListOf<String>()
        var current: String? = normalized
        while (current != null) {
            if (!out.contains(current)) out += current
            val dashIndex = current.lastIndexOf('-')
            if (dashIndex <= 0) break
            current = current.substring(0, dashIndex)
        }
        return out
    }

    val candidateIds = buildList {
        (
            expandedOverlayCandidateIds(requestedOpdbId) +
                expandedOverlayCandidateIds(machine.opdbMachineId) +
                expandedOverlayCandidateIds(machine.opdbGroupId) +
                expandedOverlayCandidateIds(machine.practiceIdentity)
            ).forEach { candidate ->
            if (!contains(candidate)) {
                add(candidate)
            }
        }
    }

    for (candidateId in candidateIds) {
        val layout = overlays.machineLayoutByKey[venueOverlayMachineKey(sourceId, candidateId)]
        val bank = overlays.machineBankByKey[venueOverlayMachineKey(sourceId, candidateId)]
        if (layout == null && bank == null) continue

        val area = normalizedOptionalString(layout?.area)
        return ResolvedImportedVenueMetadata(
            area = area,
            areaOrder = area?.let { overlays.areaOrderByKey[venueOverlayAreaKey(sourceId, it)] },
            group = layout?.groupNumber,
            position = layout?.position,
            bank = bank?.bank,
        )
    }

    return null
}
