package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.gameroom.GameRoomArea
import com.pillyliu.pinprofandroid.gameroom.GameRoomPersistedState
import com.pillyliu.pinprofandroid.gameroom.GameRoomStateCodec
import com.pillyliu.pinprofandroid.gameroom.GameRoomStore
import com.pillyliu.pinprofandroid.gameroom.OwnedMachine

internal data class GameRoomLibrarySyntheticImport(
    val importedSource: ImportedSourceRecord,
    val venueMetadataOverlays: VenueMetadataOverlayIndex,
)

internal fun mergedImportedSources(
    importedSources: List<ImportedSourceRecord>,
    syntheticGameRoomImport: GameRoomLibrarySyntheticImport?,
): List<ImportedSourceRecord> {
    val merged = importedSources.filterNot { it.id == GAME_ROOM_LIBRARY_SOURCE_ID }.toMutableList()
    syntheticGameRoomImport?.let { merged += it.importedSource }
    return merged
}

internal fun loadGameRoomLibrarySyntheticImport(context: Context): GameRoomLibrarySyntheticImport? {
    val prefs = context.getSharedPreferences(GameRoomStore.PREFS_NAME, Context.MODE_PRIVATE)
    return when (val loadResult = GameRoomStateCodec.loadFromPreferences(
        prefs = prefs,
        storageKey = GameRoomStore.STORAGE_KEY,
        legacyStorageKey = GameRoomStore.LEGACY_STORAGE_KEY,
    )) {
        GameRoomStateCodec.LoadResult.Missing,
        is GameRoomStateCodec.LoadResult.Failed -> null

        is GameRoomStateCodec.LoadResult.Loaded -> {
            val state = loadResult.state
            val venueName = state.venueName.trim().ifBlank { GameRoomPersistedState.DEFAULT_VENUE_NAME }
            val areasByID = state.areas.associateBy { it.id }
            val activeMachines = state.ownedMachines
                .filter { it.status.countsAsActiveInventory }
                .sortedWith { lhs, rhs -> compareGameRoomOwnedMachinesForLibrary(lhs, rhs, areasByID) }

            if (activeMachines.isEmpty()) {
                return null
            }

            val machineIds = mutableListOf<String>()
            val seenMachineIds = linkedSetOf<String>()
            val areaOrderByKey = linkedMapOf<String, Int>()
            val machineLayoutByKey = linkedMapOf<String, VenueMachineLayoutOverlayRecord>()

            activeMachines.forEach { ownedMachine ->
                val exactOpdbId = normalizedOptionalString(ownedMachine.opdbID)
                if (exactOpdbId.isNullOrBlank()) {
                    println("GameRoom synthetic library import skipped machine without exact opdb_id: ${ownedMachine.id}")
                    return@forEach
                }

                if (!seenMachineIds.add(exactOpdbId)) {
                    println("GameRoom synthetic library import found duplicate opdb_id: $exactOpdbId")
                    return@forEach
                }

                machineIds += exactOpdbId

                val area = ownedMachine.gameRoomAreaID?.let { areasByID[it] }
                val normalizedArea = normalizedOptionalString(area?.name)
                if (normalizedArea != null) {
                    areaOrderByKey[venueOverlayAreaKey(GAME_ROOM_LIBRARY_SOURCE_ID, normalizedArea)] =
                        maxOf(area?.areaOrder ?: 1, 1)
                }

                if (area != null || ownedMachine.groupNumber != null || ownedMachine.position != null) {
                    machineLayoutByKey[venueOverlayMachineKey(GAME_ROOM_LIBRARY_SOURCE_ID, exactOpdbId)] =
                        VenueMachineLayoutOverlayRecord(
                            sourceId = GAME_ROOM_LIBRARY_SOURCE_ID,
                            opdbId = exactOpdbId,
                            area = area?.name,
                            groupNumber = ownedMachine.groupNumber,
                            position = ownedMachine.position,
                        )
                }
            }

            if (machineIds.isEmpty()) {
                return null
            }

            GameRoomLibrarySyntheticImport(
                importedSource = ImportedSourceRecord(
                    id = GAME_ROOM_LIBRARY_SOURCE_ID,
                    name = venueName,
                    type = LibrarySourceType.VENUE,
                    provider = ImportedSourceProvider.OPDB,
                    providerSourceId = GAME_ROOM_LIBRARY_SOURCE_ID,
                    machineIds = machineIds,
                ),
                venueMetadataOverlays = VenueMetadataOverlayIndex(
                    areaOrderByKey = areaOrderByKey,
                    machineLayoutByKey = machineLayoutByKey,
                    machineBankByKey = emptyMap(),
                ),
            )
        }
    }
}

private fun compareGameRoomOwnedMachinesForLibrary(
    lhs: OwnedMachine,
    rhs: OwnedMachine,
    areasByID: Map<String, GameRoomArea>,
): Int {
    val lhsArea = lhs.gameRoomAreaID?.let { areasByID[it] }
    val rhsArea = rhs.gameRoomAreaID?.let { areasByID[it] }
    val lhsAreaOrder = lhsArea?.areaOrder ?: Int.MAX_VALUE
    val rhsAreaOrder = rhsArea?.areaOrder ?: Int.MAX_VALUE
    if (lhsAreaOrder != rhsAreaOrder) return lhsAreaOrder.compareTo(rhsAreaOrder)

    val lhsAreaName = lhsArea?.name?.lowercase().orEmpty()
    val rhsAreaName = rhsArea?.name?.lowercase().orEmpty()
    if (lhsAreaName != rhsAreaName) return lhsAreaName.compareTo(rhsAreaName)

    val lhsGroup = lhs.groupNumber ?: Int.MAX_VALUE
    val rhsGroup = rhs.groupNumber ?: Int.MAX_VALUE
    if (lhsGroup != rhsGroup) return lhsGroup.compareTo(rhsGroup)

    val lhsPosition = lhs.position ?: Int.MAX_VALUE
    val rhsPosition = rhs.position ?: Int.MAX_VALUE
    if (lhsPosition != rhsPosition) return lhsPosition.compareTo(rhsPosition)

    val lhsTitle = lhs.displayTitle.lowercase()
    val rhsTitle = rhs.displayTitle.lowercase()
    if (lhsTitle != rhsTitle) return lhsTitle.compareTo(rhsTitle)

    return lhs.id.compareTo(rhs.id)
}
