package com.pillyliu.pinprofandroid.gameroom

import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

internal object GameRoomStateCodec {
    sealed class LoadResult {
        data object Missing : LoadResult()
        data class Loaded(
            val state: GameRoomPersistedState,
            val needsResave: Boolean,
            val noticeMessage: String?,
        ) : LoadResult()
        data class Failed(val message: String) : LoadResult()
    }

    fun encode(state: GameRoomPersistedState): String {
        val root = JSONObject()
        root.put("schemaVersion", state.schemaVersion)
        root.put("venueName", state.venueName)
        root.put("areas", JSONArray().apply {
            state.areas.forEach { area ->
                put(
                    JSONObject().apply {
                        put("id", area.id)
                        put("name", area.name)
                        put("areaOrder", area.areaOrder)
                        put("createdAt", area.createdAtMs)
                        put("updatedAt", area.updatedAtMs)
                    },
                )
            }
        })
        root.put("ownedMachines", JSONArray().apply {
            state.ownedMachines.forEach { machine ->
                put(
                    JSONObject().apply {
                        put("id", machine.id)
                        put("catalogGameID", machine.catalogGameID)
                        putIfNotBlank("opdb_id", machine.opdbID)
                        put("canonicalPracticeIdentity", machine.canonicalPracticeIdentity)
                        put("displayTitle", machine.displayTitle)
                        putIfNotBlank("displayVariant", machine.displayVariant)
                        putIfNotBlank("importedSourceTitle", machine.importedSourceTitle)
                        putIfNotBlank("manufacturer", machine.manufacturer)
                        machine.year?.let { put("year", it) }
                        put("status", machine.status.name)
                        putIfNotBlank("gameRoomAreaID", machine.gameRoomAreaID)
                        machine.groupNumber?.let { put("groupNumber", it) }
                        machine.position?.let { put("position", it) }
                        machine.purchaseDateMs?.let { put("purchaseDate", it) }
                        putIfNotBlank("purchaseDateRawText", machine.purchaseDateRawText)
                        putIfNotBlank("purchaseSource", machine.purchaseSource)
                        machine.purchasePrice?.let { put("purchasePrice", it) }
                        putIfNotBlank("serialNumber", machine.serialNumber)
                        machine.manufactureDateMs?.let { put("manufactureDate", it) }
                        machine.soldOrTradedDateMs?.let { put("soldOrTradedDate", it) }
                        putIfNotBlank("ownershipNotes", machine.ownershipNotes)
                        put("createdAt", machine.createdAtMs)
                        put("updatedAt", machine.updatedAtMs)
                    },
                )
            }
        })
        root.put("events", JSONArray().apply {
            state.events.forEach { event ->
                put(
                    JSONObject().apply {
                        put("id", event.id)
                        put("ownedMachineID", event.ownedMachineID)
                        put("type", event.type.name)
                        put("category", event.category.name)
                        put("occurredAt", event.occurredAtMs)
                        event.playCountAtEvent?.let { put("playCountAtEvent", it) }
                        put("summary", event.summary)
                        putIfNotBlank("notes", event.notes)
                        putIfNotBlank("performedBy", event.performedBy)
                        event.cost?.let { put("cost", it) }
                        putIfNotBlank("partsUsed", event.partsUsed)
                        putIfNotBlank("consumablesUsed", event.consumablesUsed)
                        event.pitchValue?.let { put("pitchValue", it) }
                        putIfNotBlank("pitchMeasurementPoint", event.pitchMeasurementPoint)
                        putIfNotBlank("linkedIssueID", event.linkedIssueID)
                        put("createdAt", event.createdAtMs)
                        put("updatedAt", event.updatedAtMs)
                    },
                )
            }
        })
        root.put("issues", JSONArray().apply {
            state.issues.forEach { issue ->
                put(
                    JSONObject().apply {
                        put("id", issue.id)
                        put("ownedMachineID", issue.ownedMachineID)
                        put("status", issue.status.name)
                        put("severity", issue.severity.name)
                        put("subsystem", issue.subsystem.name)
                        put("symptom", issue.symptom)
                        putIfNotBlank("reproSteps", issue.reproSteps)
                        putIfNotBlank("diagnosis", issue.diagnosis)
                        putIfNotBlank("resolution", issue.resolution)
                        put("openedAt", issue.openedAtMs)
                        issue.resolvedAtMs?.let { put("resolvedAt", it) }
                        put("createdAt", issue.createdAtMs)
                        put("updatedAt", issue.updatedAtMs)
                    },
                )
            }
        })
        root.put("attachments", JSONArray().apply {
            state.attachments.forEach { attachment ->
                put(
                    JSONObject().apply {
                        put("id", attachment.id)
                        put("ownedMachineID", attachment.ownedMachineID)
                        put("ownerType", attachment.ownerType.name)
                        put("ownerID", attachment.ownerID)
                        put("kind", attachment.kind.name)
                        put("uri", attachment.uri)
                        putIfNotBlank("thumbnailURI", attachment.thumbnailURI)
                        putIfNotBlank("caption", attachment.caption)
                        put("createdAt", attachment.createdAtMs)
                    },
                )
            }
        })
        root.put("reminderConfigs", JSONArray().apply {
            state.reminderConfigs.forEach { config ->
                put(
                    JSONObject().apply {
                        put("id", config.id)
                        put("ownedMachineID", config.ownedMachineID)
                        put("taskType", config.taskType.name)
                        put("mode", config.mode.name)
                        config.intervalDays?.let { put("intervalDays", it) }
                        config.intervalPlays?.let { put("intervalPlays", it) }
                        put("enabled", config.enabled)
                        put("createdAt", config.createdAtMs)
                        put("updatedAt", config.updatedAtMs)
                    },
                )
            }
        })
        root.put("importRecords", JSONArray().apply {
            state.importRecords.forEach { record ->
                put(
                    JSONObject().apply {
                        put("id", record.id)
                        put("source", record.source.name)
                        put("sourceUserOrURL", record.sourceUserOrURL)
                        putIfNotBlank("sourceItemKey", record.sourceItemKey)
                        put("rawTitle", record.rawTitle)
                        putIfNotBlank("rawVariant", record.rawVariant)
                        putIfNotBlank("rawPurchaseDateText", record.rawPurchaseDateText)
                        record.normalizedPurchaseDateMs?.let { put("normalizedPurchaseDate", it) }
                        putIfNotBlank("matchedCatalogGameID", record.matchedCatalogGameID)
                        put("matchConfidence", record.matchConfidence.name)
                        putIfNotBlank("createdOwnedMachineID", record.createdOwnedMachineID)
                        put("importedAt", record.importedAtMs)
                        putIfNotBlank("fingerprint", record.fingerprint)
                    },
                )
            }
        })
        return root.toString()
    }

    fun loadFromPreferences(
        prefs: SharedPreferences,
        storageKey: String,
        legacyStorageKey: String,
    ): LoadResult {
        return loadFromRaw(
            currentRaw = prefs.getString(storageKey, null),
            legacyRaw = prefs.getString(legacyStorageKey, null),
        )
    }

    fun loadFromRaw(currentRaw: String?, legacyRaw: String?): LoadResult {
        if (currentRaw != null) {
            decode(currentRaw)?.let { decoded ->
                return LoadResult.Loaded(
                    state = decoded,
                    needsResave = legacyRaw != null,
                    noticeMessage = null,
                )
            }

            if (legacyRaw != null) {
                decode(legacyRaw)?.let { decoded ->
                    return LoadResult.Loaded(
                        state = decoded,
                        needsResave = true,
                        noticeMessage = "GameRoom recovered from the legacy save because the current saved data could not be read.",
                    )
                }

                return LoadResult.Failed(
                    "Saved GameRoom data could not be restored from either the current or legacy save. GameRoom opened empty, and the unreadable saved data was not overwritten.",
                )
            }

            return LoadResult.Failed(
                "Saved GameRoom data could not be restored from the current save. GameRoom opened empty, and the unreadable saved data was not overwritten.",
            )
        }

        if (legacyRaw != null) {
            decode(legacyRaw)?.let { decoded ->
                return LoadResult.Loaded(
                    state = decoded,
                    needsResave = true,
                    noticeMessage = null,
                )
            }

            return LoadResult.Failed(
                "Saved GameRoom data could not be restored from the legacy save. GameRoom opened empty, and the unreadable saved data was not overwritten.",
            )
        }

        return LoadResult.Missing
    }

    fun decode(raw: String): GameRoomPersistedState? {
        return runCatching {
            val root = JSONObject(raw)
            GameRoomPersistedState(
                schemaVersion = root.optInt("schemaVersion", GameRoomPersistedState.CURRENT_SCHEMA_VERSION),
                venueName = root.optString("venueName").ifBlank { GameRoomPersistedState.DEFAULT_VENUE_NAME },
                areas = root.optJSONArray("areas").toTypedList { obj ->
                    GameRoomArea(
                        id = obj.optString("id").ifBlank { java.util.UUID.randomUUID().toString() },
                        name = obj.optString("name").ifBlank { "Area" },
                        areaOrder = obj.optInt("areaOrder", 0),
                        createdAtMs = obj.optLong("createdAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                        updatedAtMs = obj.optLong("updatedAt").takeIf { it > 0L } ?: obj.optLong("createdAt").takeIf { it > 0L }
                        ?: System.currentTimeMillis(),
                    )
                },
                ownedMachines = root.optJSONArray("ownedMachines").toTypedList { obj ->
                    OwnedMachine(
                        id = obj.optString("id").ifBlank { java.util.UUID.randomUUID().toString() },
                        catalogGameID = obj.optString("catalogGameID"),
                        opdbID = obj.optString("opdb_id").ifBlank { null },
                        canonicalPracticeIdentity = obj.optString("canonicalPracticeIdentity"),
                        displayTitle = obj.optString("displayTitle").ifBlank { "Machine" },
                        displayVariant = obj.optString("displayVariant").ifBlank { null },
                        importedSourceTitle = obj.optString("importedSourceTitle").ifBlank { null },
                        manufacturer = obj.optString("manufacturer").ifBlank { null },
                        year = obj.optIntOrNull("year"),
                        status = parseEnum(obj.optString("status"), OwnedMachineStatus.active),
                        gameRoomAreaID = obj.optString("gameRoomAreaID").ifBlank { null },
                        groupNumber = obj.optIntOrNull("groupNumber"),
                        position = obj.optIntOrNull("position"),
                        purchaseDateMs = obj.optLongOrNull("purchaseDate"),
                        purchaseDateRawText = obj.optString("purchaseDateRawText").ifBlank { null },
                        purchaseSource = obj.optString("purchaseSource").ifBlank { null },
                        purchasePrice = obj.optDoubleOrNull("purchasePrice"),
                        serialNumber = obj.optString("serialNumber").ifBlank { null },
                        manufactureDateMs = obj.optLongOrNull("manufactureDate"),
                        soldOrTradedDateMs = obj.optLongOrNull("soldOrTradedDate"),
                        ownershipNotes = obj.optString("ownershipNotes").ifBlank { null },
                        createdAtMs = obj.optLong("createdAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                        updatedAtMs = obj.optLong("updatedAt").takeIf { it > 0L } ?: obj.optLong("createdAt").takeIf { it > 0L }
                        ?: System.currentTimeMillis(),
                    )
                },
                events = root.optJSONArray("events").toTypedList { obj ->
                    MachineEvent(
                        id = obj.optString("id").ifBlank { java.util.UUID.randomUUID().toString() },
                        ownedMachineID = obj.optString("ownedMachineID"),
                        type = parseEnum(obj.optString("type"), MachineEventType.custom),
                        category = parseEnum(obj.optString("category"), MachineEventCategory.custom),
                        occurredAtMs = obj.optLong("occurredAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                        playCountAtEvent = obj.optIntOrNull("playCountAtEvent"),
                        summary = obj.optString("summary").ifBlank { "Event" },
                        notes = obj.optString("notes").ifBlank { null },
                        performedBy = obj.optString("performedBy").ifBlank { null },
                        cost = obj.optDoubleOrNull("cost"),
                        partsUsed = obj.optString("partsUsed").ifBlank { null },
                        consumablesUsed = obj.optString("consumablesUsed").ifBlank { null },
                        pitchValue = obj.optDoubleOrNull("pitchValue"),
                        pitchMeasurementPoint = obj.optString("pitchMeasurementPoint").ifBlank { null },
                        linkedIssueID = obj.optString("linkedIssueID").ifBlank { null },
                        createdAtMs = obj.optLong("createdAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                        updatedAtMs = obj.optLong("updatedAt").takeIf { it > 0L } ?: obj.optLong("createdAt").takeIf { it > 0L }
                        ?: System.currentTimeMillis(),
                    )
                },
                issues = root.optJSONArray("issues").toTypedList { obj ->
                    MachineIssue(
                        id = obj.optString("id").ifBlank { java.util.UUID.randomUUID().toString() },
                        ownedMachineID = obj.optString("ownedMachineID"),
                        status = parseEnum(obj.optString("status"), MachineIssueStatus.open),
                        severity = parseEnum(obj.optString("severity"), MachineIssueSeverity.medium),
                        subsystem = parseEnum(obj.optString("subsystem"), MachineIssueSubsystem.other),
                        symptom = obj.optString("symptom").ifBlank { "Issue" },
                        reproSteps = obj.optString("reproSteps").ifBlank { null },
                        diagnosis = obj.optString("diagnosis").ifBlank { null },
                        resolution = obj.optString("resolution").ifBlank { null },
                        openedAtMs = obj.optLong("openedAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                        resolvedAtMs = obj.optLongOrNull("resolvedAt"),
                        createdAtMs = obj.optLong("createdAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                        updatedAtMs = obj.optLong("updatedAt").takeIf { it > 0L } ?: obj.optLong("createdAt").takeIf { it > 0L }
                        ?: System.currentTimeMillis(),
                    )
                },
                attachments = root.optJSONArray("attachments").toTypedList { obj ->
                    MachineAttachment(
                        id = obj.optString("id").ifBlank { java.util.UUID.randomUUID().toString() },
                        ownedMachineID = obj.optString("ownedMachineID"),
                        ownerType = parseEnum(obj.optString("ownerType"), MachineAttachmentOwnerType.event),
                        ownerID = obj.optString("ownerID"),
                        kind = parseEnum(obj.optString("kind"), MachineAttachmentKind.photo),
                        uri = obj.optString("uri"),
                        thumbnailURI = obj.optString("thumbnailURI").ifBlank { null },
                        caption = obj.optString("caption").ifBlank { null },
                        createdAtMs = obj.optLong("createdAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                    )
                },
                reminderConfigs = root.optJSONArray("reminderConfigs").toTypedList { obj ->
                    MachineReminderConfig(
                        id = obj.optString("id").ifBlank { java.util.UUID.randomUUID().toString() },
                        ownedMachineID = obj.optString("ownedMachineID"),
                        taskType = parseEnum(obj.optString("taskType"), MachineReminderTaskType.glassCleaned),
                        mode = parseEnum(obj.optString("mode"), MachineReminderMode.dateBased),
                        intervalDays = obj.optIntOrNull("intervalDays"),
                        intervalPlays = obj.optIntOrNull("intervalPlays"),
                        enabled = obj.optBoolean("enabled", true),
                        createdAtMs = obj.optLong("createdAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                        updatedAtMs = obj.optLong("updatedAt").takeIf { it > 0L } ?: obj.optLong("createdAt").takeIf { it > 0L }
                        ?: System.currentTimeMillis(),
                    )
                },
                importRecords = root.optJSONArray("importRecords").toTypedList { obj ->
                    MachineImportRecord(
                        id = obj.optString("id").ifBlank { java.util.UUID.randomUUID().toString() },
                        source = parseEnum(obj.optString("source"), MachineImportSource.pinside),
                        sourceUserOrURL = obj.optString("sourceUserOrURL"),
                        sourceItemKey = obj.optString("sourceItemKey").ifBlank { null },
                        rawTitle = obj.optString("rawTitle").ifBlank { "Imported Machine" },
                        rawVariant = obj.optString("rawVariant").ifBlank { null },
                        rawPurchaseDateText = obj.optString("rawPurchaseDateText").ifBlank { null },
                        normalizedPurchaseDateMs = obj.optLongOrNull("normalizedPurchaseDate"),
                        matchedCatalogGameID = obj.optString("matchedCatalogGameID").ifBlank { null },
                        matchConfidence = parseEnum(obj.optString("matchConfidence"), MachineImportMatchConfidence.manual),
                        createdOwnedMachineID = obj.optString("createdOwnedMachineID").ifBlank { null },
                        importedAtMs = obj.optLong("importedAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                        fingerprint = obj.optString("fingerprint").ifBlank { null },
                    )
                },
            )
        }.getOrNull()
    }
}

private inline fun <reified T : Enum<T>> parseEnum(raw: String?, fallback: T): T {
    val normalized = raw?.trim().orEmpty()
    if (normalized.isEmpty()) return fallback
    return enumValues<T>().firstOrNull { it.name.equals(normalized, ignoreCase = true) } ?: fallback
}

private inline fun <T> JSONArray?.toTypedList(transform: (JSONObject) -> T): List<T> = buildList {
    if (this@toTypedList == null) return@buildList
    for (index in 0 until this@toTypedList.length()) {
        val obj = this@toTypedList.optJSONObject(index) ?: continue
        add(transform(obj))
    }
}

private fun JSONObject.putIfNotBlank(key: String, value: String?) {
    if (!value.isNullOrBlank()) put(key, value)
}

private fun JSONObject.optLongOrNull(key: String): Long? {
    if (!has(key) || isNull(key)) return null
    val value = optLong(key)
    return value.takeIf { it > 0L }
}

private fun JSONObject.optIntOrNull(key: String): Int? {
    if (!has(key) || isNull(key)) return null
    return optInt(key)
}

private fun JSONObject.optDoubleOrNull(key: String): Double? {
    if (!has(key) || isNull(key)) return null
    return optDouble(key)
}
