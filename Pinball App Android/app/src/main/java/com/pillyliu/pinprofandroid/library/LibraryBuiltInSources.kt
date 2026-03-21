package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.settings.PinballMapClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal const val PM_AVENUE_LIBRARY_SOURCE_ID = "venue--pm-8760"
internal const val PM_RLM_LIBRARY_SOURCE_ID = "venue--pm-16470"
internal const val BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID = "venue--gameroom"

private val builtinVenueSourceIdAliases = mapOf(
    "the-avenue" to PM_AVENUE_LIBRARY_SOURCE_ID,
    "the-avenue-cafe" to PM_AVENUE_LIBRARY_SOURCE_ID,
    "venue--the-avenue-cafe" to PM_AVENUE_LIBRARY_SOURCE_ID,
    "rlm-amusements" to PM_RLM_LIBRARY_SOURCE_ID,
    "venue--rlm-amusements" to PM_RLM_LIBRARY_SOURCE_ID,
)

private val builtinVenueSourceNames = mapOf(
    PM_RLM_LIBRARY_SOURCE_ID to "RLM Amusements",
    PM_AVENUE_LIBRARY_SOURCE_ID to "The Avenue Cafe",
    BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID to "GameRoom",
)

internal val defaultBuiltinVenueSourceIds = emptyList<String>()

private data class LegacyPinballMapVenueMigrationTarget(
    val id: String,
    val name: String,
    val providerSourceId: String,
)

private val legacyPinballMapVenueMigrationTargets = listOf(
    LegacyPinballMapVenueMigrationTarget(
        id = PM_AVENUE_LIBRARY_SOURCE_ID,
        name = "The Avenue Cafe",
        providerSourceId = "8760",
    ),
    LegacyPinballMapVenueMigrationTarget(
        id = PM_RLM_LIBRARY_SOURCE_ID,
        name = "RLM Amusements",
        providerSourceId = "16470",
    ),
)

internal fun canonicalBuiltinVenueLibrarySourceId(raw: String?): String? {
    val trimmed = raw?.trim().orEmpty()
    if (trimmed.isEmpty()) return null
    return builtinVenueSourceIdAliases[trimmed]
}

internal fun canonicalLibrarySourceId(raw: String?): String? {
    val trimmed = raw?.trim().orEmpty()
    if (trimmed.isEmpty()) return null
    return canonicalBuiltinVenueLibrarySourceId(trimmed) ?: trimmed
}

internal fun builtinVenueSourceName(sourceId: String?): String? {
    val canonicalId = canonicalLibrarySourceId(sourceId) ?: return null
    return builtinVenueSourceNames[canonicalId]
}

internal fun builtinVenueSources(includeGameRoom: Boolean = false): List<LibrarySource> {
    val ids = buildList {
        addAll(defaultBuiltinVenueSourceIds)
        if (includeGameRoom) add(BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID)
    }
    return ids.mapNotNull { id ->
        builtinVenueSourceNames[id]?.let { name ->
            LibrarySource(id = id, name = name, type = LibrarySourceType.VENUE)
        }
    }
}

internal fun isAvenueLibrarySourceId(raw: String?): Boolean =
    canonicalLibrarySourceId(raw) == PM_AVENUE_LIBRARY_SOURCE_ID

internal fun isGameRoomLibrarySourceId(raw: String?): Boolean =
    canonicalLibrarySourceId(raw) == BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID

internal fun isImportedPinballMapSourceId(raw: String?): Boolean =
    canonicalLibrarySourceId(raw)?.lowercase()?.startsWith("venue--pm-") == true

internal fun pinballMapLocationId(raw: String?): String? {
    val canonicalId = canonicalLibrarySourceId(raw) ?: return null
    if (!canonicalId.startsWith("venue--pm-")) return null
    return canonicalId.removePrefix("venue--pm-")
}

internal suspend fun migrateLegacyPinnedVenueImportsIfNeeded(context: Context) = withContext(Dispatchers.IO) {
    val sourceState = LibrarySourceStateStore.load(context)
    val importedSources = ImportedSourcesStore.load(context)
    val importedIds = importedSources.mapTo(linkedSetOf(), ImportedSourceRecord::id)
    val referencedSourceIds = buildSet {
        addAll(sourceState.enabledSourceIds)
        addAll(sourceState.pinnedSourceIds)
        sourceState.selectedSourceId?.let(::add)
    }

    val targets = legacyPinballMapVenueMigrationTargets.filter { target ->
        referencedSourceIds.contains(target.id) && !importedIds.contains(target.id)
    }
    if (targets.isEmpty()) return@withContext

    var didChange = false
    targets.forEach { target ->
        runCatching {
            val machineIds = PinballMapClient.fetchVenueMachineIds(target.providerSourceId)
            ImportedSourcesStore.upsert(
                context,
                ImportedSourceRecord(
                    id = target.id,
                    name = target.name,
                    type = LibrarySourceType.VENUE,
                    provider = ImportedSourceProvider.PINBALL_MAP,
                    providerSourceId = target.providerSourceId,
                    machineIds = machineIds,
                    lastSyncedAtMs = System.currentTimeMillis(),
                ),
            )
            didChange = true
        }
    }

    if (didChange) {
        LibrarySourceEvents.notifyChanged()
    }
}
