package com.pillyliu.pinballandroid.library

import android.content.Context
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject

internal data class LibrarySourceState(
    val enabledSourceIds: List<String> = emptyList(),
    val pinnedSourceIds: List<String> = emptyList(),
    val selectedSourceId: String? = null,
    val selectedSortBySource: Map<String, String> = emptyMap(),
    val selectedBankBySource: Map<String, Int> = emptyMap(),
)

internal enum class ImportedSourceProvider(val rawValue: String) {
    OPDB("opdb"),
    PINBALL_MAP("pinball_map");

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

internal object LibrarySourceStateStore {
    private const val PREFS_NAME = "practice-upgrade-state-v2"
    private const val STATE_KEY = "pinball-library-source-state-v1"
    const val MAX_PINNED_SOURCES = 10

    fun load(context: Context): LibrarySourceState {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(STATE_KEY, null) ?: return LibrarySourceState()
        return runCatching {
            val root = JSONObject(raw)
            LibrarySourceState(
                enabledSourceIds = root.optJSONArray("enabledSourceIds").toStringList(),
                pinnedSourceIds = root.optJSONArray("pinnedSourceIds").toStringList(),
                selectedSourceId = root.optString("selectedSourceId").trim().ifBlank { null },
                selectedSortBySource = root.optJSONObject("selectedSortBySource").toStringMap(),
                selectedBankBySource = root.optJSONObject("selectedBankBySource").toIntMap(),
            )
        }.getOrDefault(LibrarySourceState())
    }

    fun save(context: Context, state: LibrarySourceState) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = JSONObject().apply {
            put("enabledSourceIds", JSONArray().apply { state.enabledSourceIds.forEach(::put) })
            put("pinnedSourceIds", JSONArray().apply { state.pinnedSourceIds.forEach(::put) })
            put("selectedSourceId", state.selectedSourceId)
            put("selectedSortBySource", JSONObject().apply {
                state.selectedSortBySource.forEach { (key, value) -> put(key, value) }
            })
            put("selectedBankBySource", JSONObject().apply {
                state.selectedBankBySource.forEach { (key, value) -> put(key, value) }
            })
        }
        prefs.edit { putString(STATE_KEY, json.toString()) }
    }

    fun synchronize(context: Context, payloadSources: List<LibrarySource>): LibrarySourceState {
        val validIds = payloadSources.map { it.id }.toSet()
        var state = load(context)
        state = state.copy(
            enabledSourceIds = filteredKnownIds(state.enabledSourceIds, validIds).ifEmpty {
                payloadSources.map { it.id }
            },
            pinnedSourceIds = filteredKnownIds(state.pinnedSourceIds, validIds).take(MAX_PINNED_SOURCES).ifEmpty {
                payloadSources.take(MAX_PINNED_SOURCES).map { it.id }
            },
            selectedSourceId = state.selectedSourceId?.takeIf { validIds.contains(it) },
            selectedSortBySource = state.selectedSortBySource.filterKeys { validIds.contains(it) },
            selectedBankBySource = state.selectedBankBySource.filterKeys { validIds.contains(it) },
        )
        save(context, state)
        return state
    }

    fun upsertSource(context: Context, id: String, enable: Boolean = true, pinIfPossible: Boolean = true) {
        val current = load(context)
        val enabled = current.enabledSourceIds.toMutableList()
        val pinned = current.pinnedSourceIds.toMutableList()
        if (enable && !enabled.contains(id)) {
            enabled += id
        }
        if (pinIfPossible && !pinned.contains(id) && pinned.size < MAX_PINNED_SOURCES) {
            pinned += id
        }
        save(context, current.copy(enabledSourceIds = enabled, pinnedSourceIds = pinned))
    }

    fun setEnabled(context: Context, sourceId: String, isEnabled: Boolean) {
        val current = load(context)
        val enabled = current.enabledSourceIds.toMutableList()
        val pinned = current.pinnedSourceIds.toMutableList()
        val selected = current.selectedSourceId
        if (isEnabled) {
            if (!enabled.contains(sourceId)) enabled += sourceId
            save(context, current.copy(enabledSourceIds = enabled))
            return
        }
        enabled.removeAll { it == sourceId }
        pinned.removeAll { it == sourceId }
        save(
            context,
            current.copy(
                enabledSourceIds = enabled,
                pinnedSourceIds = pinned,
                selectedSourceId = if (selected == sourceId) null else selected,
            ),
        )
    }

    fun setPinned(context: Context, sourceId: String, isPinned: Boolean): Boolean {
        val current = load(context)
        val enabled = current.enabledSourceIds.toMutableList()
        val pinned = current.pinnedSourceIds.toMutableList()
        if (isPinned) {
            if (pinned.contains(sourceId)) return true
            if (pinned.size >= MAX_PINNED_SOURCES) return false
            if (!enabled.contains(sourceId)) enabled += sourceId
            pinned += sourceId
        } else {
            pinned.removeAll { it == sourceId }
        }
        save(context, current.copy(enabledSourceIds = enabled, pinnedSourceIds = pinned))
        return true
    }

    fun setSelectedSource(context: Context, sourceId: String?) {
        save(context, load(context).copy(selectedSourceId = sourceId?.trim()?.ifBlank { null }))
    }

    fun setSelectedSort(context: Context, sourceId: String, sortName: String) {
        val next = load(context).selectedSortBySource.toMutableMap()
        next[sourceId] = sortName
        save(context, load(context).copy(selectedSortBySource = next))
    }

    fun setSelectedBank(context: Context, sourceId: String, bank: Int?) {
        val next = load(context).selectedBankBySource.toMutableMap()
        if (bank == null) next.remove(sourceId) else next[sourceId] = bank
        save(context, load(context).copy(selectedBankBySource = next))
    }

    private fun filteredKnownIds(ids: List<String>, validIds: Set<String>): List<String> {
        val seen = LinkedHashSet<String>()
        return ids.filter { id -> validIds.contains(id) && seen.add(id) }
    }
}

internal object ImportedSourcesStore {
    private const val PREFS_NAME = "practice-upgrade-state-v2"
    private const val SOURCES_KEY = "pinball-imported-sources-v1"

    fun load(context: Context): List<ImportedSourceRecord> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(SOURCES_KEY, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                for (i in 0 until array.length()) {
                    val obj = array.optJSONObject(i) ?: continue
                    val id = obj.optString("id").trim()
                    val name = obj.optString("name").trim()
                    val type = LibrarySourceType.fromRaw(obj.optString("type")) ?: continue
                    val provider = ImportedSourceProvider.fromRaw(obj.optString("provider")) ?: continue
                    val providerSourceId = obj.optString("providerSourceId").trim()
                    if (id.isBlank() || name.isBlank() || providerSourceId.isBlank()) continue
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
            }.sortedWith(compareBy<ImportedSourceRecord> { it.type.rawValue }.thenBy { it.name.lowercase() })
        }.getOrDefault(emptyList())
    }

    fun save(context: Context, records: List<ImportedSourceRecord>) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = JSONArray().apply {
            records.forEach { record ->
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
        val current = load(context).toMutableList()
        val index = current.indexOfFirst { it.id == record.id }
        if (index >= 0) {
            current[index] = record
        } else {
            current += record
        }
        save(context, current)
    }

    fun remove(context: Context, id: String) {
        save(context, load(context).filterNot { it.id == id })
        val state = LibrarySourceStateStore.load(context)
        LibrarySourceStateStore.save(
            context,
            state.copy(
                enabledSourceIds = state.enabledSourceIds.filterNot { it == id },
                pinnedSourceIds = state.pinnedSourceIds.filterNot { it == id },
                selectedSourceId = state.selectedSourceId?.takeUnless { it == id },
                selectedSortBySource = state.selectedSortBySource.filterKeys { it != id },
                selectedBankBySource = state.selectedBankBySource.filterKeys { it != id },
            ),
        )
    }
}

internal object LibrarySourceEvents {
    private val _version = MutableStateFlow(0L)
    val version = _version.asStateFlow()

    fun notifyChanged() {
        _version.value = System.currentTimeMillis()
    }
}

private fun JSONArray?.toStringList(): List<String> {
    if (this == null) return emptyList()
    return buildList {
        for (i in 0 until length()) {
            val value = optString(i).trim()
            if (value.isNotBlank()) add(value)
        }
    }
}

private fun JSONObject?.toStringMap(): Map<String, String> {
    if (this == null) return emptyMap()
    val out = linkedMapOf<String, String>()
    val keys = keys()
    while (keys.hasNext()) {
        val key = keys.next()
        val value = optString(key).trim()
        if (value.isNotBlank()) out[key] = value
    }
    return out
}

private fun JSONObject?.toIntMap(): Map<String, Int> {
    if (this == null) return emptyMap()
    val out = linkedMapOf<String, Int>()
    val keys = keys()
    while (keys.hasNext()) {
        val key = keys.next()
        if (has(key) && !isNull(key)) {
            out[key] = optInt(key)
        }
    }
    return out
}
