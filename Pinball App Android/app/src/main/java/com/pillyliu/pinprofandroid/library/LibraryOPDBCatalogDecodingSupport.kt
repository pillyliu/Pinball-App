package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.data.PinballDataCache
import org.json.JSONArray

private fun catalogResolvedMachines(machines: List<CatalogMachineRecord>): List<CatalogMachineRecord> =
    machines.map { machine ->
        machine.copy(
            variant = resolvedCatalogVariantLabel(
                title = machine.name,
                explicitVariant = machine.variant,
            ),
        )
    }

internal fun decodeOPDBExportCatalogMachines(
    raw: String,
    practiceIdentityCurationsRaw: String? = null,
): List<CatalogMachineRecord> {
    val array = runCatching { JSONArray(raw.trim()) }.getOrNull() ?: return emptyList()
    val curations = parsePracticeIdentityCurations(practiceIdentityCurationsRaw)
    return catalogResolvedMachines(
        appendSyntheticPinProfLabsMachine(
            buildList {
                for (index in 0 until array.length()) {
                    val obj = array.optJSONObject(index) ?: continue
                    rawOpdbCatalogMachineRecord(obj, curations)?.let(::add)
                }
            },
        ),
    )
}

internal fun decodePracticeCatalogGamesFromOPDBExport(
    raw: String,
    practiceIdentityCurationsRaw: String? = null,
): List<PinballGame> {
    val machines = decodeOPDBExportCatalogMachines(raw, practiceIdentityCurationsRaw)
    if (machines.isEmpty()) return emptyList()

    val source = ImportedSourceRecord(
        id = "catalog--opdb-practice",
        name = "All OPDB Games",
        type = LibrarySourceType.CATEGORY,
        provider = ImportedSourceProvider.OPDB,
        providerSourceId = "opdb-catalog",
        machineIds = emptyList(),
    )

    return machines
        .groupBy { it.practiceIdentity }
        .values
        .mapNotNull { group ->
            val machine = group.minWithOrNull(::compareGroupDefaultMachine) ?: return@mapNotNull null
            resolveImportedGame(
                machine = machine,
                source = source,
                manufacturerById = emptyMap(),
                curatedOverride = null,
                opdbRulesheets = emptyList(),
                opdbVideos = emptyList(),
                venueMetadata = null,
            )
        }
        .sortedWith(compareBy<PinballGame> { it.name.lowercase() }.thenBy { it.practiceKey.lowercase() })
}

internal suspend fun loadPracticeCatalogGames(context: Context): List<PinballGame> {
    val raw = runCatching {
        PinballDataCache.loadText(
            url = hostedOPDBExportPath,
            allowMissing = true,
            maxCacheAgeMs = HOSTED_LIBRARY_REFRESH_INTERVAL_MS,
        ).text
    }.getOrNull()?.takeIf { it.isNotBlank() } ?: return emptyList()
    val practiceIdentityCurationsRaw = runCatching {
        PinballDataCache.loadText(
            url = hostedPracticeIdentityCurationsPath,
            allowMissing = true,
            maxCacheAgeMs = HOSTED_LIBRARY_REFRESH_INTERVAL_MS,
        ).text
    }.getOrNull()?.takeIf { it.isNotBlank() }

    return decodePracticeCatalogGamesFromOPDBExport(raw, practiceIdentityCurationsRaw)
}
