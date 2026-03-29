package com.pillyliu.pinprofandroid.library

internal fun inferredImportedSourceProvider(type: LibrarySourceType, id: String?): ImportedSourceProvider =
    when (type) {
        LibrarySourceType.MANUFACTURER -> ImportedSourceProvider.OPDB
        LibrarySourceType.TOURNAMENT -> ImportedSourceProvider.MATCH_PLAY
        LibrarySourceType.VENUE -> if ((id ?: "").startsWith("venue--pm-")) ImportedSourceProvider.PINBALL_MAP else ImportedSourceProvider.OPDB
        LibrarySourceType.CATEGORY -> ImportedSourceProvider.OPDB
    }

internal fun normalizedImportedVenueProviderSourceId(rawProviderSourceId: String, canonicalId: String): String {
    return if (canonicalId.startsWith("venue--pm-")) {
        canonicalId.removePrefix("venue--pm-")
    } else {
        rawProviderSourceId
    }
}

internal fun normalizedImportedRecord(record: ImportedSourceRecord): ImportedSourceRecord? {
    val canonicalId = canonicalLibrarySourceId(record.id)?.takeIf { it.isNotBlank() }
        ?: record.id.trim().takeIf { it.isNotBlank() }
        ?: return null
    val trimmedName = record.name.trim().takeIf { it.isNotBlank() } ?: return null
    val normalizedProvider = if (record.provider == ImportedSourceProvider.OPDB && canonicalId.startsWith("venue--pm-")) {
        inferredImportedSourceProvider(record.type, canonicalId)
    } else {
        record.provider
    }
    val normalizedProviderSourceId = normalizedImportedVenueProviderSourceId(
        rawProviderSourceId = record.providerSourceId.trim(),
        canonicalId = canonicalId,
    ).takeIf { it.isNotBlank() } ?: return null
    val normalizedMachineIds = record.machineIds
        .mapNotNull { it.trim().ifBlank { null } }
        .distinct()

    return ImportedSourceRecord(
        id = canonicalId,
        name = trimmedName,
        type = record.type,
        provider = normalizedProvider,
        providerSourceId = normalizedProviderSourceId,
        machineIds = normalizedMachineIds,
        lastSyncedAtMs = record.lastSyncedAtMs,
        searchQuery = record.searchQuery?.trim()?.ifBlank { null },
        distanceMiles = record.distanceMiles,
    )
}

internal fun normalizedImportedRecords(records: List<ImportedSourceRecord>): List<ImportedSourceRecord> {
    val byId = linkedMapOf<String, ImportedSourceRecord>()
    records.forEach { record ->
        val normalized = normalizedImportedRecord(record) ?: return@forEach
        val existing = byId[normalized.id]
        byId[normalized.id] = if (existing == null) {
            normalized
        } else {
            existing.copy(
                name = normalized.name.ifBlank { existing.name },
                type = normalized.type,
                provider = normalized.provider,
                providerSourceId = normalized.providerSourceId.ifBlank { existing.providerSourceId },
                machineIds = (existing.machineIds + normalized.machineIds).distinct(),
                lastSyncedAtMs = maxOf(existing.lastSyncedAtMs ?: 0L, normalized.lastSyncedAtMs ?: 0L).takeIf { it > 0L },
                searchQuery = normalized.searchQuery ?: existing.searchQuery,
                distanceMiles = normalized.distanceMiles ?: existing.distanceMiles,
            )
        }
    }
    return byId.values.sortedWith(
        compareBy<ImportedSourceRecord>({ it.type.rawValue }, { it.name.lowercase() }, { it.id }),
    )
}
