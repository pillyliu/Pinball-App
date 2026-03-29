package com.pillyliu.pinprofandroid.library

import android.content.Context
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject

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
}
