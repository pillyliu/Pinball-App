package com.pillyliu.pinprofandroid.library

import android.content.Context
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject

internal enum class ImportedSourceProvider(val rawValue: String) {
    OPDB("opdb"),
    PINBALL_MAP("pinball_map"),
    MATCH_PLAY("match_play");

    companion object {
        fun fromRaw(raw: String?): ImportedSourceProvider? = entries.firstOrNull { it.rawValue == raw }
    }
}

internal data class ImportedSourceRecord(
    val id: String,
    val name: String,
    val type: LibrarySourceType,
    val provider: ImportedSourceProvider,
    val providerSourceId: String,
    val machineIds: List<String>,
    val lastSyncedAtMs: Long? = null,
    val searchQuery: String? = null,
    val distanceMiles: Int? = null,
)

internal object ImportedSourcesStore {
    private const val PREFS_NAME = "practice-upgrade-state-v2"
    private const val SOURCES_KEY = "pinball-imported-sources-v1"

    fun hasPersistedSources(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.contains(SOURCES_KEY)
    }

    fun load(context: Context): List<ImportedSourceRecord> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(SOURCES_KEY, null)
            ?: return if (!LibrarySourceStateStore.hasPersistedState(context)) {
                bundledDefaultImportedSources().also { defaults ->
                    if (defaults.isNotEmpty()) {
                        save(context, defaults)
                    }
                }
            } else {
                emptyList()
            }
        return runCatching {
            val array = JSONArray(raw)
            val records = buildList {
                for (i in 0 until array.length()) {
                    val obj = array.optJSONObject(i) ?: continue
                    val id = canonicalLibrarySourceId(obj.optString("id").trim())
                    val name = obj.optString("name").trim()
                    val type = LibrarySourceType.fromRaw(obj.optString("type")) ?: continue
                    val provider = ImportedSourceProvider.fromRaw(obj.optString("provider"))
                        ?: inferredImportedSourceProvider(type, id)
                    val providerSourceId = obj.optString("providerSourceId").trim()
                    if (id.isNullOrBlank() || name.isBlank() || providerSourceId.isBlank()) continue
                    add(
                        ImportedSourceRecord(
                            id = id,
                            name = name,
                            type = type,
                            provider = provider,
                            providerSourceId = providerSourceId,
                            machineIds = obj.optJSONArray("machineIds").toStringList(),
                            lastSyncedAtMs = obj.optLong("lastSyncedAtMs").takeIf { it > 0L },
                            searchQuery = obj.optString("searchQuery").trim().ifBlank { null },
                            distanceMiles = obj.optInt("distanceMiles").takeIf { it > 0 },
                        ),
                    )
                }
            }
            val migrated = normalizedImportedRecords(records)
            if (migrated != records) {
                save(context, migrated)
            }
            migrated
        }.getOrDefault(emptyList())
    }

    fun save(context: Context, records: List<ImportedSourceRecord>) {
        val normalized = normalizedImportedRecords(records)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = JSONArray().apply {
            normalized.forEach { record ->
                put(
                    JSONObject().apply {
                        put("id", record.id)
                        put("name", record.name)
                        put("type", record.type.rawValue)
                        put("provider", record.provider.rawValue)
                        put("providerSourceId", record.providerSourceId)
                        put("machineIds", JSONArray().apply { record.machineIds.forEach(::put) })
                        put("lastSyncedAtMs", record.lastSyncedAtMs)
                        put("searchQuery", record.searchQuery)
                        put("distanceMiles", record.distanceMiles)
                    },
                )
            }
        }
        prefs.edit { putString(SOURCES_KEY, json.toString()) }
    }

    fun upsert(context: Context, record: ImportedSourceRecord) {
        val canonicalRecord = normalizedImportedRecord(record) ?: return
        val canonicalId = canonicalRecord.id
        val current = load(context).toMutableList()
        val index = current.indexOfFirst { it.id == canonicalId }
        if (index >= 0) {
            current[index] = canonicalRecord
        } else {
            current += canonicalRecord
        }
        save(context, current)
    }

    fun remove(context: Context, id: String) {
        val canonicalId = canonicalLibrarySourceId(id) ?: return
        save(context, load(context).filterNot { it.id == canonicalId })
        LibrarySourceStateStore.removeSourcePreferences(context, canonicalId)
    }

    private fun bundledDefaultImportedSources(): List<ImportedSourceRecord> = listOf(
        ImportedSourceRecord(
            id = PM_AVENUE_LIBRARY_SOURCE_ID,
            name = PM_AVENUE_LIBRARY_SOURCE_NAME,
            type = LibrarySourceType.VENUE,
            provider = ImportedSourceProvider.PINBALL_MAP,
            providerSourceId = "8760",
            machineIds = BUNDLED_AVENUE_VENUE_MACHINE_IDS,
        ),
        ImportedSourceRecord(
            id = PM_ELECTRIC_BAT_LIBRARY_SOURCE_ID,
            name = PM_ELECTRIC_BAT_LIBRARY_SOURCE_NAME,
            type = LibrarySourceType.VENUE,
            provider = ImportedSourceProvider.PINBALL_MAP,
            providerSourceId = "10819",
            machineIds = BUNDLED_ELECTRIC_BAT_VENUE_MACHINE_IDS,
        ),
        ImportedSourceRecord(
            id = STERN_MANUFACTURER_LIBRARY_SOURCE_ID,
            name = STERN_MANUFACTURER_LIBRARY_SOURCE_NAME,
            type = LibrarySourceType.MANUFACTURER,
            provider = ImportedSourceProvider.OPDB,
            providerSourceId = STERN_MANUFACTURER_LIBRARY_SOURCE_ID,
            machineIds = emptyList(),
        ),
        ImportedSourceRecord(
            id = JERSEY_JACK_MANUFACTURER_LIBRARY_SOURCE_ID,
            name = JERSEY_JACK_MANUFACTURER_LIBRARY_SOURCE_NAME,
            type = LibrarySourceType.MANUFACTURER,
            provider = ImportedSourceProvider.OPDB,
            providerSourceId = JERSEY_JACK_MANUFACTURER_LIBRARY_SOURCE_ID,
            machineIds = emptyList(),
        ),
        ImportedSourceRecord(
            id = SPOOKY_MANUFACTURER_LIBRARY_SOURCE_ID,
            name = SPOOKY_MANUFACTURER_LIBRARY_SOURCE_NAME,
            type = LibrarySourceType.MANUFACTURER,
            provider = ImportedSourceProvider.OPDB,
            providerSourceId = SPOOKY_MANUFACTURER_LIBRARY_SOURCE_ID,
            machineIds = emptyList(),
        ),
    )
}

private val BUNDLED_AVENUE_VENUE_MACHINE_IDS = listOf(
    "G43W4-MdEjy",
    "G4do5-MW9z8",
    "Gj66P-MXr0E-A1nx0",
    "GD7Ld-MBRP4-A1e4P",
    "G4835-M2YPK-ARkb7",
    "G6lnq-Mq1kv",
    "GK1Ej-MePok-A1zKx",
    "GZVOd-MwNxZ-AR8vV",
    "GpeoL-MkPz1-A944p",
    "G41d5-M9REd",
    "GR9Nr-MVKol",
    "GweeP-Ml9pZ-A9vXB",
    "GweeP-Ml9pZ-ARZoY",
    "G4xZy-MLno6",
    "G4dOQ-MyNbb",
    "GLWll-M1r8O-A1kx7",
    "GQKyP-MP3OK-A1KoX",
    "GQK1P-Ml95Z-A9bjw",
    "GK17D-MdEqz",
    "GEL0V-MyN8E-ARq7n",
    "G4qX5-Ml9jb",
    "G5pe4-MePZv",
    "GRBE4-MQK1Z",
    "Gr3EW-MD3Nj",
    "GoEkx-MdEzN-AR50E",
    "G2Lkd-M0ope-A97xV",
    "G4xbP-Mp45Y",
    "Gryw4-MNEKn",
    "G5vLR-MwNwy",
    "Gxv81-Mo1rp-A9Qew",
    "Gzy89-M0oPy-A9xXV",
    "GrkL5-MJoNN",
    "G4llj-MQYb2",
    "Gd2Xb-MRjpZ-A92v0",
    "G4ODR-MDXEy",
    "Grx8Y-MKNe9",
    "GBLLP-MW900-AOEEN",
    "GbPde-M5Rkv",
    "GRvBL-MP3Ev",
    "G7ZEz-MyN3K-ARl3o",
    "G3EBl-MRj6e-ARzbx",
)

private val BUNDLED_ELECTRIC_BAT_VENUE_MACHINE_IDS = listOf(
    "Gr16e-MnKEX",
    "GrXOZ-MLyb0",
    "G4do5-MkPnV",
    "Gj66P-M3dxn",
    "GRoz4-MjBV6",
    "G4jQw-MJ5rl",
    "G5nbD-MDyXb",
    "GD7Ld-ME0BP",
    "G41do-MP3Py",
    "G5Woz-MKNq6",
    "GrknN-MQrdv",
    "GrNd0-MJNW1",
    "GrNWn-MQdqZ",
    "G6lnq-Mq1kv",
    "G43Yq-MJ7o4",
    "GK1Ej-MwNZr",
    "GrN7J-MJ78q",
    "GZVOd-MwNxZ-AOLoy",
    "GYWvw-MKNP4",
    "G5VDd-MJpqO",
    "G5Wxd-MLxl3",
    "GpeoL-MyNPq",
    "GrdDB-ML8xK",
    "GR9Nr-Mz2dY",
    "GweeP-Ml9pZ-ARZoY",
    "GrENE-MD0dz",
    "G4dOQ-MyNbb",
    "GRVq4-M4oNp",
    "GLWll-MXr4N",
    "Ge1Dy-M9Rrp",
    "GQKyP-MP3OK-AOEEx",
    "GQK1P-MW9pj",
    "GR6W8-Mb55B",
    "GR9o1-MQjj8",
    "GK17D-MdEqz",
    "GEL0V-MBRyb",
    "G5pe4-MyNkp",
    "GO0q3-MOEy8-ARol7",
    "GryQj-MLvN7",
    "GrP6q-M5Rp1",
    "Gr2Y2-MDxZq",
    "GrkOB-MJVvl",
    "GV8wB-Mq12N",
    "GoEkx-MdEzN-ARJQz",
    "G2Lkd-MNEdK",
    "G4xbP-Mp45Y",
    "G4xqN-MD1Rj",
    "GRDqo-MDbPx",
    "G4qxv-MJPyv",
    "Gxv81-M610r",
    "GrXEW-MDEwr",
    "Gzy89-M0oPy-A1zrL",
    "GrleW-MYeod",
    "GR6wO-MDvzk",
    "GR9Bx-MQkd5",
    "G4ODR-MDXEy",
    "Grx8Y-MKNe9",
    "GbPde-Mp43l-AOQwL",
    "G7ZEz-MBRYn",
    "G5nz5-M3d38",
    "GrXzD-MjBPX",
    "G3EBl-Mq1zy",
    "G57kN-MQ71K",
    "GrE7e-MQ9N1",
    "G42E2-MQP9e",
)

private fun inferredImportedSourceProvider(type: LibrarySourceType, id: String?): ImportedSourceProvider =
    when (type) {
        LibrarySourceType.MANUFACTURER -> ImportedSourceProvider.OPDB
        LibrarySourceType.TOURNAMENT -> ImportedSourceProvider.MATCH_PLAY
        LibrarySourceType.VENUE -> if ((id ?: "").startsWith("venue--pm-")) ImportedSourceProvider.PINBALL_MAP else ImportedSourceProvider.OPDB
        LibrarySourceType.CATEGORY -> ImportedSourceProvider.OPDB
    }

private fun normalizedImportedVenueProviderSourceId(rawProviderSourceId: String, canonicalId: String): String {
    return if (canonicalId.startsWith("venue--pm-")) {
        canonicalId.removePrefix("venue--pm-")
    } else {
        rawProviderSourceId
    }
}

private fun normalizedImportedRecord(record: ImportedSourceRecord): ImportedSourceRecord? {
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

private fun normalizedImportedRecords(records: List<ImportedSourceRecord>): List<ImportedSourceRecord> {
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
