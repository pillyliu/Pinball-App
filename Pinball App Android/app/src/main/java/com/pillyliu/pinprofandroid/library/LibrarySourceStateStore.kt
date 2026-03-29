package com.pillyliu.pinprofandroid.library

import android.content.Context
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject

internal data class LibrarySourceState(
    val enabledSourceIds: List<String> = emptyList(),
    val pinnedSourceIds: List<String> = emptyList(),
    val selectedSourceId: String? = null,
    val selectedSortBySource: Map<String, String> = emptyMap(),
    val selectedBankBySource: Map<String, Int> = emptyMap(),
)

internal object LibrarySourceStateStore {
    private const val PREFS_NAME = "practice-upgrade-state-v2"
    private const val STATE_KEY = "pinball-library-source-state-v1"
    const val MAX_PINNED_SOURCES = 10

    fun hasPersistedState(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.contains(STATE_KEY)
    }

    fun load(context: Context): LibrarySourceState {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(STATE_KEY, null) ?: return LibrarySourceState()
        return runCatching {
            val root = JSONObject(raw)
            val decoded = LibrarySourceState(
                enabledSourceIds = root.optJSONArray("enabledSourceIds").toStringList(),
                pinnedSourceIds = root.optJSONArray("pinnedSourceIds").toStringList(),
                selectedSourceId = root.optString("selectedSourceId").trim().ifBlank { null },
                selectedSortBySource = root.optJSONObject("selectedSortBySource").toStringMap(),
                selectedBankBySource = root.optJSONObject("selectedBankBySource").toIntMap(),
            )
            val normalized = normalize(decoded)
            if (normalized != decoded) {
                save(context, normalized)
            }
            normalized
        }.getOrDefault(LibrarySourceState())
    }

    fun save(context: Context, state: LibrarySourceState) {
        val normalized = normalize(state)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = JSONObject().apply {
            put("enabledSourceIds", JSONArray().apply { normalized.enabledSourceIds.forEach(::put) })
            put("pinnedSourceIds", JSONArray().apply { normalized.pinnedSourceIds.forEach(::put) })
            put("selectedSourceId", normalized.selectedSourceId)
            put("selectedSortBySource", JSONObject().apply {
                normalized.selectedSortBySource.forEach { (key, value) -> put(key, value) }
            })
            put("selectedBankBySource", JSONObject().apply {
                normalized.selectedBankBySource.forEach { (key, value) -> put(key, value) }
            })
        }
        prefs.edit { putString(STATE_KEY, json.toString()) }
    }

    fun synchronize(context: Context, payloadSources: List<LibrarySource>): LibrarySourceState {
        val validIds = payloadSources.map { it.id }.toSet()
        var state = load(context)
        state = state.copy(
            enabledSourceIds = filteredKnownIds(state.enabledSourceIds, validIds),
            pinnedSourceIds = filteredKnownIds(state.pinnedSourceIds, validIds).take(MAX_PINNED_SOURCES),
            selectedSourceId = canonicalLibrarySourceId(state.selectedSourceId)?.takeIf { validIds.contains(it) },
            selectedSortBySource = state.selectedSortBySource.mapNotNullKeys(::canonicalLibrarySourceId).filterKeys { validIds.contains(it) },
            selectedBankBySource = state.selectedBankBySource.mapNotNullKeys(::canonicalLibrarySourceId).filterKeys { validIds.contains(it) },
        )
        if (!hasPersistedState(context)) {
            val seededIds = DEFAULT_SEEDED_LIBRARY_SOURCE_IDS.filter { validIds.contains(it) }
            if (seededIds.isNotEmpty()) {
                state = state.copy(
                    enabledSourceIds = seededIds,
                    pinnedSourceIds = seededIds.take(MAX_PINNED_SOURCES),
                    selectedSourceId = seededIds.firstOrNull(),
                )
            }
        }
        save(context, state)
        return state
    }

    fun upsertSource(context: Context, id: String, enable: Boolean = true, pinIfPossible: Boolean = true) {
        val canonicalId = canonicalLibrarySourceId(id) ?: return
        val current = load(context)
        val enabled = current.enabledSourceIds.toMutableList()
        val pinned = current.pinnedSourceIds.toMutableList()
        if (enable && !enabled.contains(canonicalId)) {
            enabled += canonicalId
        }
        if (pinIfPossible && !pinned.contains(canonicalId) && pinned.size < MAX_PINNED_SOURCES) {
            pinned += canonicalId
        }
        save(context, current.copy(enabledSourceIds = enabled, pinnedSourceIds = pinned))
    }

    fun setEnabled(context: Context, sourceId: String, isEnabled: Boolean) {
        val canonicalId = canonicalLibrarySourceId(sourceId) ?: return
        val current = load(context)
        val enabled = current.enabledSourceIds.toMutableList()
        val pinned = current.pinnedSourceIds.toMutableList()
        val selected = current.selectedSourceId
        if (isEnabled) {
            if (!enabled.contains(canonicalId)) enabled += canonicalId
            save(context, current.copy(enabledSourceIds = enabled))
            return
        }
        enabled.removeAll { it == canonicalId }
        pinned.removeAll { it == canonicalId }
        save(
            context,
            current.copy(
                enabledSourceIds = enabled,
                pinnedSourceIds = pinned,
                selectedSourceId = if (selected == canonicalId) null else selected,
            ),
        )
    }

    fun setPinned(context: Context, sourceId: String, isPinned: Boolean): Boolean {
        val canonicalId = canonicalLibrarySourceId(sourceId) ?: return false
        val current = load(context)
        val enabled = current.enabledSourceIds.toMutableList()
        val pinned = current.pinnedSourceIds.toMutableList()
        if (isPinned) {
            if (pinned.contains(canonicalId)) return true
            if (pinned.size >= MAX_PINNED_SOURCES) return false
            if (!enabled.contains(canonicalId)) enabled += canonicalId
            pinned += canonicalId
        } else {
            pinned.removeAll { it == canonicalId }
        }
        save(context, current.copy(enabledSourceIds = enabled, pinnedSourceIds = pinned))
        return true
    }

    fun setSelectedSource(context: Context, sourceId: String?) {
        save(context, load(context).copy(selectedSourceId = canonicalLibrarySourceId(sourceId)))
    }

    fun setSelectedSort(context: Context, sourceId: String, sortName: String) {
        val canonicalId = canonicalLibrarySourceId(sourceId) ?: return
        val current = load(context)
        val next = current.selectedSortBySource.toMutableMap()
        next[canonicalId] = sortName
        save(context, current.copy(selectedSortBySource = next))
    }

    fun setSelectedBank(context: Context, sourceId: String, bank: Int?) {
        val canonicalId = canonicalLibrarySourceId(sourceId) ?: return
        val current = load(context)
        val next = current.selectedBankBySource.toMutableMap()
        if (bank == null) next.remove(canonicalId) else next[canonicalId] = bank
        save(context, current.copy(selectedBankBySource = next))
    }

    fun removeSourcePreferences(context: Context, sourceId: String) {
        val canonicalId = canonicalLibrarySourceId(sourceId) ?: return
        val current = load(context)
        save(
            context,
            current.copy(
                enabledSourceIds = current.enabledSourceIds.filterNot { it == canonicalId },
                pinnedSourceIds = current.pinnedSourceIds.filterNot { it == canonicalId },
                selectedSourceId = current.selectedSourceId?.takeUnless { it == canonicalId },
                selectedSortBySource = current.selectedSortBySource.filterKeys { it != canonicalId },
                selectedBankBySource = current.selectedBankBySource.filterKeys { it != canonicalId },
            ),
        )
    }

    private fun normalize(state: LibrarySourceState): LibrarySourceState =
        LibrarySourceState(
            enabledSourceIds = state.enabledSourceIds.mapNotNull(::canonicalLibrarySourceId).distinct(),
            pinnedSourceIds = state.pinnedSourceIds.mapNotNull(::canonicalLibrarySourceId).distinct(),
            selectedSourceId = canonicalLibrarySourceId(state.selectedSourceId),
            selectedSortBySource = state.selectedSortBySource.mapNotNullKeys(::canonicalLibrarySourceId),
            selectedBankBySource = state.selectedBankBySource.mapNotNullKeys(::canonicalLibrarySourceId),
        )

    private fun filteredKnownIds(ids: List<String>, validIds: Set<String>): List<String> {
        val seen = LinkedHashSet<String>()
        return ids.mapNotNull(::canonicalLibrarySourceId).filter { id -> validIds.contains(id) && seen.add(id) }
    }
}
