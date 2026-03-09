package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.gameroom.GameRoomArea
import com.pillyliu.pinprofandroid.gameroom.GameRoomStateCodec
import com.pillyliu.pinprofandroid.gameroom.GameRoomStore
import com.pillyliu.pinprofandroid.gameroom.OwnedMachine
import com.pillyliu.pinprofandroid.gameroom.OwnedMachineStatus
import org.json.JSONArray
import org.json.JSONObject

private const val GAME_ROOM_LIBRARY_SOURCE_ID = "venue--gameroom"

private data class DecodedSeedOverlayState(
    val venueName: String,
    val areas: List<GameRoomArea>,
    val ownedMachines: List<OwnedMachine>,
)

internal fun filterSeedLibraryPayload(payload: ParsedLibraryData, state: LibrarySourceState): ParsedLibraryData {
    val enabled = state.enabledSourceIds.toSet()
    val hasGameRoomGames = payload.games.any { it.sourceId == GAME_ROOM_LIBRARY_SOURCE_ID }
    val filteredSources = payload.sources.filter { source ->
        source.id in enabled || (source.id == GAME_ROOM_LIBRARY_SOURCE_ID && hasGameRoomGames)
    }
    if (filteredSources.isEmpty()) return payload
    val sourceIds = filteredSources.map { it.id }.toSet()
    return ParsedLibraryData(
        games = payload.games.filter { it.sourceId in sourceIds },
        sources = filteredSources,
    )
}

internal fun addSeedGameRoomOverlay(
    context: Context,
    basePayload: ParsedLibraryData,
): ParsedLibraryData {
    return runCatching {
        val prefs = context.getSharedPreferences(GameRoomStore.PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(GameRoomStore.STORAGE_KEY, null)
            ?: prefs.getString(GameRoomStore.LEGACY_STORAGE_KEY, null)
            ?: return basePayload
        val decodedState = GameRoomStateCodec.decode(raw)?.let { state ->
            DecodedSeedOverlayState(
                venueName = state.venueName,
                areas = state.areas,
                ownedMachines = state.ownedMachines,
            )
        } ?: decodeSeedOverlayStateFromRaw(raw)
            ?: return basePayload
        val venueName = decodedState.venueName.trim().ifBlank { "GameRoom" }
        val areasByID = decodedState.areas.associateBy { it.id }
        val activeMachines = decodedState.ownedMachines
            .filter { it.status == OwnedMachineStatus.active || it.status == OwnedMachineStatus.loaned }
            .sortedWith { lhs, rhs -> compareGameRoomOwnedMachinesForSeed(lhs, rhs, areasByID) }
        if (activeMachines.isEmpty()) return basePayload

        val overlayGames = activeMachines.map { ownedMachine ->
            val template = bestSeedTemplateForOwnedMachine(ownedMachine, basePayload.games)
            val area = areasByID[ownedMachine.gameRoomAreaID]
            val practiceIdentity = normalizedOptionalString(ownedMachine.canonicalPracticeIdentity)
                ?: normalizedOptionalString(template?.practiceIdentity)
                ?: normalizedOptionalString(ownedMachine.catalogGameID)
                ?: ownedMachine.id
            val slug = normalizedOptionalString(template?.slug) ?: practiceIdentity
            PinballGame(
                libraryEntryId = "gameroom:${ownedMachine.id}",
                practiceIdentity = practiceIdentity,
                opdbId = normalizedOptionalString(template?.opdbId),
                opdbGroupId = normalizedOptionalString(ownedMachine.catalogGameID)
                    ?: normalizedOptionalString(template?.opdbGroupId)
                    ?: practiceIdentity,
                variant = normalizedOptionalString(ownedMachine.displayVariant),
                sourceId = GAME_ROOM_LIBRARY_SOURCE_ID,
                sourceName = venueName,
                sourceType = LibrarySourceType.VENUE,
                area = area?.name,
                areaOrder = area?.areaOrder,
                group = ownedMachine.groupNumber,
                position = ownedMachine.position,
                bank = null,
                name = ownedMachine.displayTitle,
                manufacturer = normalizedOptionalString(ownedMachine.manufacturer)
                    ?: normalizedOptionalString(template?.manufacturer),
                year = ownedMachine.year ?: template?.year,
                slug = slug,
                primaryImageUrl = normalizedOptionalString(template?.primaryImageUrl),
                primaryImageLargeUrl = normalizedOptionalString(template?.primaryImageLargeUrl),
                playfieldImageUrl = normalizedOptionalString(template?.playfieldImageUrl),
                playfieldLocalOriginal = normalizeLibraryCachePath(template?.playfieldLocalOriginal ?: template?.playfieldLocal),
                playfieldLocal = normalizeLibraryPlayfieldLocalPath(template?.playfieldLocalOriginal ?: template?.playfieldLocal),
                playfieldSourceLabel = template?.playfieldSourceLabel,
                gameinfoLocal = normalizedOptionalString(template?.gameinfoLocal),
                rulesheetLocal = normalizedOptionalString(template?.rulesheetLocal),
                rulesheetUrl = normalizedOptionalString(template?.rulesheetUrl),
                rulesheetLinks = template?.rulesheetLinks.orEmpty(),
                videos = template?.videos.orEmpty(),
            )
        }

        ParsedLibraryData(
            games = basePayload.games + overlayGames,
            sources = dedupedSources(
                basePayload.sources + LibrarySource(
                    id = GAME_ROOM_LIBRARY_SOURCE_ID,
                    name = venueName,
                    type = LibrarySourceType.VENUE,
                ),
            ),
        )
    }.getOrDefault(basePayload)
}

private fun bestSeedTemplateForOwnedMachine(
    ownedMachine: OwnedMachine,
    baseGames: List<PinballGame>,
): PinballGame? {
    val normalizedPracticeIdentity = normalizedOptionalString(ownedMachine.canonicalPracticeIdentity)
    val normalizedCatalogID = normalizedOptionalString(ownedMachine.catalogGameID)
    val normalizedTitle = ownedMachine.displayTitle.trim().lowercase()
    val requestedVariant = normalizedOptionalString(ownedMachine.displayVariant)?.lowercase()
    return baseGames
        .mapNotNull { game ->
            val matchScore = when {
                normalizedPracticeIdentity != null &&
                    normalizedOptionalString(game.practiceIdentity) == normalizedPracticeIdentity -> 300
                normalizedCatalogID != null &&
                    normalizedOptionalString(game.opdbGroupId) == normalizedCatalogID -> 260
                game.name.trim().lowercase() == normalizedTitle -> 180
                else -> 0
            }
            if (matchScore <= 0) {
                null
            } else {
                val variantScore = buildSeedTemplateVariantScore(game, requestedVariant)
                game to (matchScore + variantScore)
            }
        }
        .maxByOrNull { it.second }
        ?.first
}

private fun buildSeedTemplateVariantScore(game: PinballGame, requestedVariant: String?): Int {
    val normalizedGameVariant = normalizedOptionalString(game.normalizedVariant)?.lowercase()
    var score = catalogVariantScore(normalizedGameVariant, requestedVariant)
    if (requestedVariant == null && normalizedGameVariant == null) {
        score += 80
    }
    if (!game.primaryImageLargeUrl.isNullOrBlank() || !game.primaryImageUrl.isNullOrBlank()) {
        score += 20
    }
    return score
}

private fun compareGameRoomOwnedMachinesForSeed(
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

private fun decodeSeedOverlayStateFromRaw(raw: String): DecodedSeedOverlayState? {
    return runCatching {
        val root = JSONObject(raw)
        val venueName = root.optString("venueName").ifBlank { "GameRoom" }
        val areas = buildList {
            val areaArray = root.optJSONArray("areas") ?: JSONArray()
            for (index in 0 until areaArray.length()) {
                val obj = areaArray.optJSONObject(index) ?: continue
                val id = obj.optString("id").ifBlank { continue }
                val name = obj.optString("name").ifBlank { "Area" }
                add(
                    GameRoomArea(
                        id = id,
                        name = name,
                        areaOrder = obj.optInt("areaOrder", 0),
                        createdAtMs = obj.optLong("createdAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                        updatedAtMs = obj.optLong("updatedAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                    ),
                )
            }
        }
        val ownedMachines = buildList {
            val machines = root.optJSONArray("ownedMachines") ?: JSONArray()
            for (index in 0 until machines.length()) {
                val obj = machines.optJSONObject(index) ?: continue
                val id = obj.optString("id").ifBlank { continue }
                val catalogGameID = obj.optString("catalogGameID").ifBlank { continue }
                val canonicalPracticeIdentity = obj.optString("canonicalPracticeIdentity").ifBlank { catalogGameID }
                val displayTitle = obj.optString("displayTitle").ifBlank { catalogGameID }
                val statusRaw = obj.optString("status").trim().lowercase()
                val status = when (statusRaw) {
                    OwnedMachineStatus.active.name -> OwnedMachineStatus.active
                    OwnedMachineStatus.loaned.name -> OwnedMachineStatus.loaned
                    OwnedMachineStatus.archived.name -> OwnedMachineStatus.archived
                    OwnedMachineStatus.sold.name -> OwnedMachineStatus.sold
                    OwnedMachineStatus.traded.name -> OwnedMachineStatus.traded
                    else -> OwnedMachineStatus.active
                }
                add(
                    OwnedMachine(
                        id = id,
                        catalogGameID = catalogGameID,
                        canonicalPracticeIdentity = canonicalPracticeIdentity,
                        displayTitle = displayTitle,
                        displayVariant = obj.optString("displayVariant").ifBlank { null },
                        manufacturer = obj.optString("manufacturer").ifBlank { null },
                        year = obj.optInt("year").takeIf { it > 0 },
                        status = status,
                        gameRoomAreaID = obj.optString("gameRoomAreaID").ifBlank { null },
                        groupNumber = if (obj.has("groupNumber") && !obj.isNull("groupNumber")) obj.optInt("groupNumber") else null,
                        position = if (obj.has("position") && !obj.isNull("position")) obj.optInt("position") else null,
                        createdAtMs = obj.optLong("createdAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                        updatedAtMs = obj.optLong("updatedAt").takeIf { it > 0L } ?: System.currentTimeMillis(),
                    ),
                )
            }
        }
        DecodedSeedOverlayState(
            venueName = venueName,
            areas = areas,
            ownedMachines = ownedMachines,
        )
    }.getOrNull()
}

internal fun dedupedSources(sources: List<LibrarySource>): List<LibrarySource> {
    val seen = linkedMapOf<String, LibrarySource>()
    sources.forEach { source ->
        if (!seen.containsKey(source.id)) {
            seen[source.id] = source
        }
    }
    return seen.values.toList()
}
