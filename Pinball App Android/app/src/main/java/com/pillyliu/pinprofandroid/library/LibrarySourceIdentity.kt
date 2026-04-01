package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.settings.PinballMapClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.OffsetDateTime

internal const val PM_AVENUE_LIBRARY_SOURCE_ID = "venue--pm-8760"
internal const val PM_ELECTRIC_BAT_LIBRARY_SOURCE_ID = "venue--pm-10819"
internal const val PM_RLM_LIBRARY_SOURCE_ID = "venue--pm-16470"
internal const val GAME_ROOM_LIBRARY_SOURCE_ID = "venue--gameroom"
internal const val STERN_MANUFACTURER_LIBRARY_SOURCE_ID = "manufacturer-12"
internal const val JERSEY_JACK_MANUFACTURER_LIBRARY_SOURCE_ID = "manufacturer-74"
internal const val SPOOKY_MANUFACTURER_LIBRARY_SOURCE_ID = "manufacturer-95"
internal const val PM_AVENUE_LIBRARY_SOURCE_NAME = "The Avenue Cafe"
internal const val PM_ELECTRIC_BAT_LIBRARY_SOURCE_NAME = "Electric Bat Arcade"
internal const val PM_RLM_LIBRARY_SOURCE_NAME = "RLM Amusements"
internal const val STERN_MANUFACTURER_LIBRARY_SOURCE_NAME = "Stern"
internal const val JERSEY_JACK_MANUFACTURER_LIBRARY_SOURCE_NAME = "Jersey Jack Pinball"
internal const val SPOOKY_MANUFACTURER_LIBRARY_SOURCE_NAME = "Spooky Pinball"
internal val DEFAULT_SEEDED_LIBRARY_SOURCE_IDS = listOf(
    PM_AVENUE_LIBRARY_SOURCE_ID,
    PM_ELECTRIC_BAT_LIBRARY_SOURCE_ID,
    STERN_MANUFACTURER_LIBRARY_SOURCE_ID,
    JERSEY_JACK_MANUFACTURER_LIBRARY_SOURCE_ID,
    SPOOKY_MANUFACTURER_LIBRARY_SOURCE_ID,
)

private val legacyLibrarySourceIdAliases = mapOf(
    "the-avenue" to PM_AVENUE_LIBRARY_SOURCE_ID,
    "the-avenue-cafe" to PM_AVENUE_LIBRARY_SOURCE_ID,
    "venue--the-avenue-cafe" to PM_AVENUE_LIBRARY_SOURCE_ID,
    "rlm-amusements" to PM_RLM_LIBRARY_SOURCE_ID,
    "venue--rlm-amusements" to PM_RLM_LIBRARY_SOURCE_ID,
)

private data class LegacyPinballMapVenueMigrationTarget(
    val id: String,
    val name: String,
    val providerSourceId: String,
)

private val legacyPinballMapVenueMigrationTargets = listOf(
    LegacyPinballMapVenueMigrationTarget(
        id = PM_AVENUE_LIBRARY_SOURCE_ID,
        name = PM_AVENUE_LIBRARY_SOURCE_NAME,
        providerSourceId = "8760",
    ),
    LegacyPinballMapVenueMigrationTarget(
        id = PM_RLM_LIBRARY_SOURCE_ID,
        name = PM_RLM_LIBRARY_SOURCE_NAME,
        providerSourceId = "16470",
    ),
)

// Refresh saved Pinball Map venue imports that were synced before the machine-ID replacement fix shipped.
internal val STALE_IMPORTED_PINBALL_MAP_VENUE_REFRESH_CUTOFF_MS: Long =
    OffsetDateTime.parse("2026-04-01T08:00:00-04:00").toInstant().toEpochMilli()

internal fun canonicalLegacyLibrarySourceAliasId(raw: String?): String? {
    val trimmed = raw?.trim().orEmpty()
    if (trimmed.isEmpty()) return null
    return legacyLibrarySourceIdAliases[trimmed]
}

internal fun canonicalLibrarySourceId(raw: String?): String? {
    val trimmed = raw?.trim().orEmpty()
    if (trimmed.isEmpty()) return null
    return canonicalLegacyLibrarySourceAliasId(trimmed) ?: trimmed
}

internal fun isAvenueLibrarySourceId(raw: String?): Boolean =
    canonicalLibrarySourceId(raw) == PM_AVENUE_LIBRARY_SOURCE_ID

internal fun isGameRoomLibrarySourceId(raw: String?): Boolean =
    canonicalLibrarySourceId(raw) == GAME_ROOM_LIBRARY_SOURCE_ID

internal fun isImportedPinballMapSourceId(raw: String?): Boolean =
    canonicalLibrarySourceId(raw)?.lowercase()?.startsWith("venue--pm-") == true

internal fun pinballMapLocationId(raw: String?): String? {
    val canonicalId = canonicalLibrarySourceId(raw) ?: return null
    if (!canonicalId.startsWith("venue--pm-")) return null
    return canonicalId.removePrefix("venue--pm-")
}

internal fun importedPinballMapVenueNeedsStaleRefresh(source: ImportedSourceRecord): Boolean {
    if (source.type != LibrarySourceType.VENUE) return false
    if (source.provider != ImportedSourceProvider.PINBALL_MAP && !isImportedPinballMapSourceId(source.id)) return false
    if (source.providerSourceId.isBlank()) return false
    val lastSyncedAtMs = source.lastSyncedAtMs ?: return false
    return lastSyncedAtMs < STALE_IMPORTED_PINBALL_MAP_VENUE_REFRESH_CUTOFF_MS
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

    val didRefreshStaleVenueImports = refreshStaleImportedPinballMapVenueImportsIfNeeded(
        context = context,
        importedSources = ImportedSourcesStore.load(context),
    )

    if (didRefreshStaleVenueImports) {
        didChange = true
    }

    if (didChange) {
        LibrarySourceEvents.notifyChanged()
    }
}

private fun refreshStaleImportedPinballMapVenueImportsIfNeeded(
    context: Context,
    importedSources: List<ImportedSourceRecord>,
): Boolean {
    val staleSources = importedSources.filter(::importedPinballMapVenueNeedsStaleRefresh)
    if (staleSources.isEmpty()) return false

    var didChange = false
    staleSources.forEach { source ->
        runCatching {
            val machineIds = PinballMapClient.fetchVenueMachineIds(source.providerSourceId)
            val previousMachineIds = source.machineIds
                .mapNotNull { it.trim().ifBlank { null } }
                .distinct()

            ImportedSourcesStore.upsert(
                context,
                source.copy(
                    machineIds = machineIds,
                    lastSyncedAtMs = System.currentTimeMillis(),
                ),
            )

            if (previousMachineIds != machineIds) {
                didChange = true
            }
        }
    }

    return didChange
}
