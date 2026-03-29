package com.pillyliu.pinprofandroid.library

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
