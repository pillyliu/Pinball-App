package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.gameroom.GameRoomStateCodec
import com.pillyliu.pinprofandroid.gameroom.GameRoomStore
import com.pillyliu.pinprofandroid.gameroom.GameRoomArea
import com.pillyliu.pinprofandroid.gameroom.OwnedMachine
import com.pillyliu.pinprofandroid.gameroom.OwnedMachineStatus
import org.json.JSONArray
import org.json.JSONObject

private const val GAME_ROOM_LIBRARY_SOURCE_ID = "venue--gameroom"

internal suspend fun loadLibraryExtraction(context: Context): LegacyCatalogExtraction {
    return runCatching {
        loadHostedLibraryExtraction(context)
    }.getOrElse {
        loadBundledLibraryExtraction(context) ?: LibrarySeedDatabase.loadExtraction(context)
    }
}

internal fun decodeCatalogManufacturerOptions(raw: String): List<CatalogManufacturerOption> {
    val root = parseNormalizedRoot(raw)
    if (root.manufacturers.isEmpty()) return emptyList()

    val groupCountsByManufacturerId = root.machines
        .groupBy { it.manufacturerId.orEmpty() }
        .mapValues { (_, machines) ->
            machines.map { it.opdbGroupId ?: it.practiceIdentity }.toSet().size
        }

    return root.manufacturers
        .map { manufacturer ->
            CatalogManufacturerOption(
                id = manufacturer.id,
                name = manufacturer.name,
                gameCount = groupCountsByManufacturerId[manufacturer.id] ?: manufacturer.gameCount ?: 0,
                isModern = manufacturer.isModern ?: false,
                featuredRank = manufacturer.featuredRank,
                sortBucket = if (manufacturer.isModern == true) 0 else if (manufacturer.featuredRank == null) 2 else 1,
            )
        }
        .sortedWith(
            compareBy<CatalogManufacturerOption> { it.sortBucket }
                .thenBy { it.featuredRank ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
}

internal fun decodeLibraryPayloadWithState(context: Context, raw: String): LegacyCatalogExtraction {
    val payload = parseLibraryPayload(raw)
    val state = LibrarySourceStateStore.synchronize(context, payload.sources)
    return LegacyCatalogExtraction(payload = filterPayload(payload, state), state = state)
}

internal fun decodeMergedLibraryPayloadWithState(
    context: Context,
    libraryRaw: String,
    opdbCatalogRaw: String,
): LegacyCatalogExtraction {
    val legacyPayload = parseLibraryPayload(libraryRaw)
    val root = parseNormalizedRoot(opdbCatalogRaw)
    if (root.machines.isEmpty()) {
        val state = LibrarySourceStateStore.synchronize(context, legacyPayload.sources)
        return LegacyCatalogExtraction(payload = filterPayload(legacyPayload, state), state = state)
    }

    val payload = resolveMergedCatalog(
        context = context,
        legacyPayload = legacyPayload,
        root = root,
    )
    val state = LibrarySourceStateStore.synchronize(context, payload.sources)
    return LegacyCatalogExtraction(payload = filterPayload(payload, state), state = state)
}

private fun filterPayload(payload: ParsedLibraryData, state: LibrarySourceState): ParsedLibraryData {
    val enabled = state.enabledSourceIds.toSet()
    val hasGameRoomGames = payload.games.any { it.sourceId == GAME_ROOM_LIBRARY_SOURCE_ID }
    val filteredSources = payload.sources.filter { source ->
        source.id in enabled || (source.id == GAME_ROOM_LIBRARY_SOURCE_ID && hasGameRoomGames)
    }
    if (filteredSources.isEmpty()) return payload
    val sourceIds = filteredSources.map { it.id }.toSet()
    val filteredGames = payload.games.filter { it.sourceId in sourceIds }
    return ParsedLibraryData(games = filteredGames, sources = filteredSources)
}

private data class NormalizedRoot(
    val manufacturers: List<CatalogManufacturerRecord>,
    val machines: List<CatalogMachineRecord>,
    val rulesheetLinks: List<CatalogRulesheetLinkRecord>,
    val videoLinks: List<CatalogVideoLinkRecord>,
)

internal data class CatalogManufacturerRecord(
    val id: String,
    val name: String,
    val isModern: Boolean?,
    val featuredRank: Int?,
    val gameCount: Int?,
)

internal data class CatalogMachineRecord(
    val practiceIdentity: String,
    val opdbMachineId: String?,
    val opdbGroupId: String?,
    val slug: String,
    val name: String,
    val variant: String?,
    val manufacturerId: String?,
    val manufacturerName: String?,
    val year: Int?,
    val primaryImageMediumUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldImageMediumUrl: String?,
    val playfieldImageLargeUrl: String?,
)

internal data class CatalogRulesheetLinkRecord(
    val practiceIdentity: String,
    val provider: String,
    val label: String,
    val url: String?,
    val localPath: String?,
    val priority: Int?,
)

internal data class CatalogVideoLinkRecord(
    val practiceIdentity: String,
    val provider: String,
    val kind: String?,
    val label: String,
    val url: String?,
    val priority: Int?,
)

internal data class LegacyCuratedOverride(
    val practiceIdentity: String,
    var nameOverride: String? = null,
    var variantOverride: String? = null,
    var manufacturerOverride: String? = null,
    var yearOverride: Int? = null,
    var playfieldLocalPath: String? = null,
    var playfieldSourceUrl: String? = null,
    var gameinfoLocalPath: String? = null,
    var rulesheetLocalPath: String? = null,
    var rulesheetLinks: List<ReferenceLink> = emptyList(),
    var videos: List<Video> = emptyList(),
)

private fun parseNormalizedRoot(raw: String): NormalizedRoot {
    val root = runCatching { JSONObject(raw.trim()) }.getOrDefault(JSONObject())
    return NormalizedRoot(
        manufacturers = root.optJSONArray("manufacturers").toManufacturerRecords(),
        machines = root.optJSONArray("machines").toMachineRecords(),
        rulesheetLinks = root.optJSONArray("rulesheet_links").toRulesheetLinkRecords(),
        videoLinks = root.optJSONArray("video_links").toVideoLinkRecords(),
    )
}

private fun resolveMergedCatalog(
    context: Context,
    legacyPayload: ParsedLibraryData,
    root: NormalizedRoot,
): ParsedLibraryData {
    val machineByPracticeIdentity = root.machines.groupBy { it.practiceIdentity }
    val machineByOpdbId = root.machines.mapNotNull { machine ->
        normalizedOptionalString(machine.opdbMachineId)?.let { it to machine }
    }.toMap()
    val manufacturerById = root.manufacturers.associateBy { it.id }
    val curatedOverridesByPracticeIdentity = buildLegacyCuratedOverrides(legacyPayload.games)
    val opdbRulesheetsByPracticeIdentity = root.rulesheetLinks.groupBy { it.practiceIdentity }
    val opdbVideosByPracticeIdentity = root.videoLinks.groupBy { it.practiceIdentity }

    val mergedLegacyGames = legacyPayload.games.map { legacyGame ->
        resolveLegacyGame(
            legacyGame = legacyGame,
            machineByPracticeIdentity = machineByPracticeIdentity,
            machineByOpdbId = machineByOpdbId,
            manufacturerById = manufacturerById,
            opdbRulesheetsByPracticeIdentity = opdbRulesheetsByPracticeIdentity,
            opdbVideosByPracticeIdentity = opdbVideosByPracticeIdentity,
        )
    }

    val importedSources = ImportedSourcesStore.load(context)
    val additionalSources = importedSources.map { source ->
        LibrarySource(id = source.id, name = source.name, type = source.type)
    }
    val additionalGames = buildList {
        importedSources.forEach { importedSource ->
            when (importedSource.type) {
                LibrarySourceType.MANUFACTURER -> {
                    val grouped = root.machines
                        .filter { it.manufacturerId == importedSource.providerSourceId }
                        .groupBy { it.opdbGroupId ?: it.practiceIdentity }
                    grouped.values
                        .mapNotNull { group -> group.minWithOrNull(::comparePreferredMachine) }
                        .sortedWith(compareBy<CatalogMachineRecord> { it.year ?: Int.MAX_VALUE }.thenBy { it.name.lowercase() })
                        .forEach { machine ->
                            add(
                                resolveImportedGame(
                                    machine = machine,
                                    source = importedSource,
                                    manufacturerById = manufacturerById,
                                    curatedOverride = curatedOverridesByPracticeIdentity[machine.practiceIdentity],
                                    opdbRulesheets = opdbRulesheetsByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                                    opdbVideos = opdbVideosByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                                ),
                            )
                        }
                }

                LibrarySourceType.VENUE,
                LibrarySourceType.TOURNAMENT -> {
                    importedSource.machineIds.forEach { machineId ->
                        val machine = preferredMachineForSourceLookup(
                            requestedMachineId = machineId,
                            machineByOpdbId = machineByOpdbId,
                            machineByPracticeIdentity = machineByPracticeIdentity,
                        ) ?: return@forEach
                        add(
                            resolveImportedGame(
                                machine = machine,
                                source = importedSource,
                                manufacturerById = manufacturerById,
                                curatedOverride = curatedOverridesByPracticeIdentity[machine.practiceIdentity],
                                opdbRulesheets = opdbRulesheetsByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                                opdbVideos = opdbVideosByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                            ),
                        )
                    }
                }

                LibrarySourceType.CATEGORY -> Unit
            }
        }
    }

    val mergedGames = mergedLegacyGames + additionalGames
    val gameRoomOverlay = buildGameRoomOverlay(
        context = context,
        baseGames = mergedGames,
        root = root,
    )

    return ParsedLibraryData(
        games = mergedGames + gameRoomOverlay.games,
        sources = dedupeSources(legacyPayload.sources + additionalSources + listOfNotNull(gameRoomOverlay.source)),
    )
}

private data class GameRoomOverlay(
    val source: LibrarySource?,
    val games: List<PinballGame>,
)

private fun buildGameRoomOverlay(
    context: Context,
    baseGames: List<PinballGame>,
    root: NormalizedRoot,
): GameRoomOverlay {
    val prefs = context.getSharedPreferences(GameRoomStore.PREFS_NAME, Context.MODE_PRIVATE)
    val raw = prefs.getString(GameRoomStore.STORAGE_KEY, null)
        ?: prefs.getString(GameRoomStore.LEGACY_STORAGE_KEY, null)
        ?: return GameRoomOverlay(source = null, games = emptyList())
    val decodedState = GameRoomStateCodec.decode(raw)?.let { state ->
        DecodedGameRoomOverlayState(
            venueName = state.venueName,
            areas = state.areas,
            ownedMachines = state.ownedMachines,
        )
    } ?: decodeGameRoomOverlayStateFromRaw(raw)
        ?: return GameRoomOverlay(source = null, games = emptyList())

    val venueName = decodedState.venueName.trim().ifBlank { "GameRoom" }
    val areasByID = decodedState.areas.associateBy { it.id }
    val activeMachines = decodedState.ownedMachines
        .filter { it.status == OwnedMachineStatus.active || it.status == OwnedMachineStatus.loaned }
        .sortedWith { lhs, rhs -> compareGameRoomOwnedMachinesForLibrary(lhs, rhs, areasByID) }

    if (activeMachines.isEmpty()) return GameRoomOverlay(source = null, games = emptyList())

    val machineByPracticeIdentity = root.machines.groupBy { it.practiceIdentity }
    val machineByGroupID = root.machines.groupBy { normalizedOptionalString(it.opdbGroupId) ?: "" }
    val rulesheetsByPracticeIdentity = root.rulesheetLinks.groupBy { it.practiceIdentity }
    val videosByPracticeIdentity = root.videoLinks.groupBy { it.practiceIdentity }

    val games = activeMachines.map { ownedMachine ->
        val catalogMachine = preferredCatalogMachineForOwnedMachine(
            ownedMachine = ownedMachine,
            machineByPracticeIdentity = machineByPracticeIdentity,
            machineByGroupID = machineByGroupID,
        )
        val practiceIdentity = normalizedOptionalString(ownedMachine.canonicalPracticeIdentity)
            ?: normalizedOptionalString(catalogMachine?.practiceIdentity)
            ?: normalizedOptionalString(ownedMachine.catalogGameID)
            ?: ownedMachine.id
        val template = bestTemplateForOwnedMachine(ownedMachine = ownedMachine, baseGames = baseGames)
        val area = areasByID[ownedMachine.gameRoomAreaID]
        val resolvedRulesheet = when {
            !template?.rulesheetLocal.isNullOrBlank() -> normalizedOptionalString(template?.rulesheetLocal) to emptyList()
            !template?.rulesheetLinks.isNullOrEmpty() -> null to (template?.rulesheetLinks ?: emptyList())
            else -> {
                val resolved = resolveRulesheetLinks(rulesheetsByPracticeIdentity[practiceIdentity].orEmpty())
                resolved.localPath to resolved.links
            }
        }
        val resolvedVideos = if (!template?.videos.isNullOrEmpty()) {
            template?.videos ?: emptyList()
        } else {
            resolveVideoLinks(videosByPracticeIdentity[practiceIdentity].orEmpty())
        }
        val playfieldLocalRaw = normalizedOptionalString(template?.playfieldLocalOriginal ?: template?.playfieldLocal)
        val playfieldImageUrl = normalizedOptionalString(template?.playfieldImageUrl)
            ?: normalizedOptionalString(catalogMachine?.playfieldImageLargeUrl ?: catalogMachine?.playfieldImageMediumUrl)
        val playfieldSourceLabel = when {
            playfieldLocalRaw != null -> "Local"
            playfieldImageUrl != null -> "Playfield (OPDB)"
            else -> null
        }

        PinballGame(
            libraryEntryId = "gameroom:${ownedMachine.id}",
            practiceIdentity = practiceIdentity,
            opdbId = normalizedOptionalString(catalogMachine?.opdbMachineId),
            opdbGroupId = normalizedOptionalString(ownedMachine.catalogGameID) ?: normalizedOptionalString(catalogMachine?.opdbGroupId),
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
            manufacturer = normalizedOptionalString(ownedMachine.manufacturer) ?: normalizedOptionalString(catalogMachine?.manufacturerName),
            year = ownedMachine.year ?: catalogMachine?.year,
            slug = normalizedOptionalString(catalogMachine?.slug) ?: practiceIdentity,
            primaryImageUrl = normalizedOptionalString(catalogMachine?.primaryImageMediumUrl),
            primaryImageLargeUrl = normalizedOptionalString(catalogMachine?.primaryImageLargeUrl),
            playfieldImageUrl = playfieldImageUrl,
            playfieldLocalOriginal = normalizeLibraryCachePath(playfieldLocalRaw),
            playfieldLocal = normalizeLibraryPlayfieldLocalPath(playfieldLocalRaw),
            playfieldSourceLabel = playfieldSourceLabel,
            gameinfoLocal = template?.gameinfoLocal,
            rulesheetLocal = resolvedRulesheet.first,
            rulesheetUrl = resolvedRulesheet.second.firstOrNull()?.url,
            rulesheetLinks = resolvedRulesheet.second,
            videos = resolvedVideos,
        )
    }

    return GameRoomOverlay(
        source = LibrarySource(
            id = GAME_ROOM_LIBRARY_SOURCE_ID,
            name = venueName,
            type = LibrarySourceType.VENUE,
        ),
        games = games,
    )
}

private data class DecodedGameRoomOverlayState(
    val venueName: String,
    val areas: List<GameRoomArea>,
    val ownedMachines: List<OwnedMachine>,
)

private fun decodeGameRoomOverlayStateFromRaw(raw: String): DecodedGameRoomOverlayState? {
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
        DecodedGameRoomOverlayState(
            venueName = venueName,
            areas = areas,
            ownedMachines = ownedMachines,
        )
    }.getOrNull()
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

private fun preferredCatalogMachineForOwnedMachine(
    ownedMachine: OwnedMachine,
    machineByPracticeIdentity: Map<String, List<CatalogMachineRecord>>,
    machineByGroupID: Map<String, List<CatalogMachineRecord>>,
): CatalogMachineRecord? {
    val byPractice = normalizedOptionalString(ownedMachine.canonicalPracticeIdentity)
        ?.let { machineByPracticeIdentity[it] }
        .orEmpty()
    val byGroup = normalizedOptionalString(ownedMachine.catalogGameID)
        ?.let { machineByGroupID[it] }
        .orEmpty()
    val candidates = (byPractice + byGroup).distinctBy { it.opdbMachineId ?: it.practiceIdentity }
    if (candidates.isEmpty()) return null
    val requestedVariant = normalizedOptionalString(ownedMachine.displayVariant)?.lowercase()
    return candidates.sortedWith { lhs, rhs ->
        val lhsScore = catalogVariantScore(lhs.variant, requestedVariant)
        val rhsScore = catalogVariantScore(rhs.variant, requestedVariant)
        when {
            lhsScore != rhsScore -> rhsScore.compareTo(lhsScore)
            else -> comparePreferredMachine(lhs, rhs)
        }
    }.firstOrNull()
}

private fun bestTemplateForOwnedMachine(
    ownedMachine: OwnedMachine,
    baseGames: List<PinballGame>,
): PinballGame? {
    val normalizedPracticeIdentity = normalizedOptionalString(ownedMachine.canonicalPracticeIdentity)
    val normalizedCatalogID = normalizedOptionalString(ownedMachine.catalogGameID)
    val normalizedTitle = ownedMachine.displayTitle.trim().lowercase()
    return baseGames.firstOrNull { game ->
        normalizedOptionalString(game.practiceIdentity) == normalizedPracticeIdentity ||
            normalizedOptionalString(game.opdbGroupId) == normalizedCatalogID ||
            game.name.trim().lowercase() == normalizedTitle
    }
}

private fun resolveLegacyGame(
    legacyGame: PinballGame,
    machineByPracticeIdentity: Map<String, List<CatalogMachineRecord>>,
    machineByOpdbId: Map<String, CatalogMachineRecord>,
    manufacturerById: Map<String, CatalogManufacturerRecord>,
    opdbRulesheetsByPracticeIdentity: Map<String, List<CatalogRulesheetLinkRecord>>,
    opdbVideosByPracticeIdentity: Map<String, List<CatalogVideoLinkRecord>>,
): PinballGame {
    val machine = preferredMachineForLegacyGame(
        legacyGame = legacyGame,
        machineByOpdbId = machineByOpdbId,
        machineByPracticeIdentity = machineByPracticeIdentity,
        requestedVariant = normalizedOptionalString(legacyGame.normalizedVariant)?.lowercase(),
    ) ?: return legacyGame

    val practiceIdentity = legacyGame.practiceIdentity ?: machine.practiceIdentity
    val manufacturerName = normalizedOptionalString(legacyGame.manufacturer)
        ?: machine.manufacturerName
        ?: machine.manufacturerId?.let { manufacturerById[it]?.name }

    val hasCuratedRulesheet = !legacyGame.rulesheetLocal.isNullOrBlank() || legacyGame.rulesheetLinks.isNotEmpty() || !legacyGame.rulesheetUrl.isNullOrBlank()
    val hasCuratedVideos = legacyGame.videos.isNotEmpty()
    val hasCuratedPlayfield = !legacyGame.playfieldLocalOriginal.isNullOrBlank() || !legacyGame.playfieldLocal.isNullOrBlank() || !legacyGame.playfieldImageUrl.isNullOrBlank()

    val resolvedRulesheets = if (hasCuratedRulesheet) {
        when {
            legacyGame.rulesheetLinks.isNotEmpty() -> legacyGame.rulesheetLinks
            !legacyGame.rulesheetUrl.isNullOrBlank() -> listOf(ReferenceLink(label = "Rulesheet", url = legacyGame.rulesheetUrl))
            else -> emptyList()
        }
    } else {
        resolveRulesheetLinks(opdbRulesheetsByPracticeIdentity[practiceIdentity].orEmpty()).links
    }
    val rulesheetLocalPath = if (hasCuratedRulesheet) {
        normalizedOptionalString(legacyGame.rulesheetLocal)
    } else {
        resolveRulesheetLinks(opdbRulesheetsByPracticeIdentity[practiceIdentity].orEmpty()).localPath
    }
    val resolvedVideos = if (hasCuratedVideos) legacyGame.videos else resolveVideoLinks(opdbVideosByPracticeIdentity[practiceIdentity].orEmpty())
    val playfieldImageUrl = if (hasCuratedPlayfield) {
        normalizedOptionalString(legacyGame.playfieldImageUrl)
    } else {
        normalizedOptionalString(machine.playfieldImageLargeUrl ?: machine.playfieldImageMediumUrl)
    }

    return legacyGame.copy(
        practiceIdentity = practiceIdentity,
        opdbId = normalizedOptionalString(legacyGame.opdbId) ?: normalizedOptionalString(machine.opdbMachineId),
        variant = normalizedOptionalString(legacyGame.normalizedVariant ?: machine.variant),
        manufacturer = normalizedOptionalString(manufacturerName),
        year = legacyGame.year ?: machine.year,
        primaryImageUrl = normalizedOptionalString(machine.primaryImageMediumUrl),
        primaryImageLargeUrl = normalizedOptionalString(machine.primaryImageLargeUrl),
        playfieldImageUrl = playfieldImageUrl,
        playfieldSourceLabel = if (hasCuratedPlayfield) null else if (machine.playfieldImageLargeUrl != null || machine.playfieldImageMediumUrl != null) "Playfield (OPDB)" else null,
        gameinfoLocal = legacyGame.gameinfoLocal,
        rulesheetLocal = rulesheetLocalPath,
        rulesheetUrl = resolvedRulesheets.firstOrNull()?.url,
        rulesheetLinks = resolvedRulesheets,
        videos = resolvedVideos,
    )
}

private fun buildLegacyCuratedOverrides(games: List<PinballGame>): Map<String, LegacyCuratedOverride> {
    val out = linkedMapOf<String, LegacyCuratedOverride>()
    games.forEach { game ->
        val practiceIdentity = normalizedOptionalString(game.practiceIdentity ?: game.opdbGroupId) ?: return@forEach
        val current = out.getOrPut(practiceIdentity) { LegacyCuratedOverride(practiceIdentity = practiceIdentity) }
        current.nameOverride = current.nameOverride ?: normalizedOptionalString(game.name)
        current.variantOverride = current.variantOverride ?: normalizedOptionalString(game.normalizedVariant)
        current.manufacturerOverride = current.manufacturerOverride ?: normalizedOptionalString(game.manufacturer)
        current.yearOverride = current.yearOverride ?: game.year
        current.playfieldLocalPath = current.playfieldLocalPath ?: normalizedOptionalString(game.playfieldLocalOriginal ?: game.playfieldLocal)
        current.playfieldSourceUrl = current.playfieldSourceUrl ?: normalizedOptionalString(game.playfieldImageUrl)
        current.gameinfoLocalPath = current.gameinfoLocalPath ?: normalizedOptionalString(game.gameinfoLocal)
        current.rulesheetLocalPath = current.rulesheetLocalPath ?: normalizedOptionalString(game.rulesheetLocal)
        if (current.rulesheetLinks.isEmpty()) {
            current.rulesheetLinks = when {
                game.rulesheetLinks.isNotEmpty() -> game.rulesheetLinks
                !game.rulesheetUrl.isNullOrBlank() -> listOf(ReferenceLink(label = "Rulesheet", url = game.rulesheetUrl))
                else -> emptyList()
            }
        }
        if (current.videos.isEmpty() && game.videos.isNotEmpty()) {
            current.videos = game.videos
        }
    }
    return out
}

private fun preferredMachineForLegacyGame(
    legacyGame: PinballGame,
    machineByOpdbId: Map<String, CatalogMachineRecord>,
    machineByPracticeIdentity: Map<String, List<CatalogMachineRecord>>,
    requestedVariant: String?,
): CatalogMachineRecord? {
    val groupCandidates = normalizedOptionalString(legacyGame.practiceIdentity ?: legacyGame.opdbGroupId)
        ?.let { practiceIdentity -> machineByPracticeIdentity[practiceIdentity].orEmpty() }
        .orEmpty()
    val preferredGroupMachine = groupCandidates.minWithOrNull(::compareGroupDefaultMachine)
    val groupArtFallback = groupCandidates
        .filter(::catalogMachineHasPrimaryImage)
        .minWithOrNull(::comparePreferredMachine)

    val requestedMachineId = normalizedOptionalString(legacyGame.opdbId) ?: run {
        val variantMatch = preferredMachineForVariant(groupCandidates, requestedVariant)
        return when {
            variantMatch != null && catalogMachineHasPrimaryImage(variantMatch) -> variantMatch
            preferredGroupMachine != null && catalogMachineHasPrimaryImage(preferredGroupMachine) -> preferredGroupMachine
            groupArtFallback != null -> groupArtFallback
            else -> preferredGroupMachine
        }
    }
    val exactMachine = machineByOpdbId[requestedMachineId] ?: run {
        val variantMatch = preferredMachineForVariant(groupCandidates, requestedVariant)
        return when {
            variantMatch != null && catalogMachineHasPrimaryImage(variantMatch) -> variantMatch
            preferredGroupMachine != null && catalogMachineHasPrimaryImage(preferredGroupMachine) -> preferredGroupMachine
            groupArtFallback != null -> groupArtFallback
            else -> preferredGroupMachine
        }
    }

    val variantCandidates = machineByPracticeIdentity[exactMachine.practiceIdentity].orEmpty().ifEmpty { groupCandidates }
    val variantMatch = preferredMachineForVariant(variantCandidates, requestedVariant)
    // Fallback ladder: variant art -> exact machine art -> group default -> any group variant with art.
    if (variantMatch != null && catalogMachineHasPrimaryImage(variantMatch)) {
        return variantMatch
    }
    if (catalogMachineHasPrimaryImage(exactMachine)) {
        return exactMachine
    }
    if (preferredGroupMachine != null && catalogMachineHasPrimaryImage(preferredGroupMachine)) {
        return preferredGroupMachine
    }
    if (groupArtFallback != null) {
        return groupArtFallback
    }
    return preferredGroupMachine ?: variantMatch ?: exactMachine
}

private fun dedupeSources(sources: List<LibrarySource>): List<LibrarySource> {
    val seen = LinkedHashSet<String>()
    return sources.filter { source -> seen.add(source.id) }
}

private fun JSONArray?.toManufacturerRecords(): List<CatalogManufacturerRecord> {
    if (this == null) return emptyList()
    return buildList {
        for (i in 0 until length()) {
            val obj = optJSONObject(i) ?: continue
            val id = obj.optStringOrNullLocal("id") ?: continue
            val name = obj.optStringOrNullLocal("name") ?: continue
            add(
                CatalogManufacturerRecord(
                    id = id,
                    name = name,
                    isModern = if (obj.has("is_modern") && !obj.isNull("is_modern")) obj.optBoolean("is_modern") else null,
                    featuredRank = obj.optIntOrNullLocal("featured_rank"),
                    gameCount = obj.optIntOrNullLocal("game_count"),
                ),
            )
        }
    }
}

private fun JSONObject.optIntOrNullLocal(name: String): Int? =
    if (has(name) && !isNull(name)) optInt(name) else null

private fun JSONObject.optStringOrNullLocal(name: String): String? =
    optString(name)
        .trim()
        .takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }

private fun JSONArray?.toMachineRecords(): List<CatalogMachineRecord> {
    if (this == null) return emptyList()
    return buildList {
        for (i in 0 until length()) {
            val obj = optJSONObject(i) ?: continue
            val practiceIdentity = obj.optStringOrNullLocal("practice_identity") ?: continue
            val slug = obj.optStringOrNullLocal("slug") ?: practiceIdentity
            val name = obj.optStringOrNullLocal("name") ?: continue
            val primary = obj.optJSONObject("primary_image")
            val playfield = obj.optJSONObject("playfield_image")
            add(
                CatalogMachineRecord(
                    practiceIdentity = practiceIdentity,
                    opdbMachineId = obj.optStringOrNullLocal("opdb_machine_id"),
                    opdbGroupId = obj.optStringOrNullLocal("opdb_group_id"),
                    slug = slug,
                    name = name,
                    variant = obj.optStringOrNullLocal("variant"),
                    manufacturerId = obj.optStringOrNullLocal("manufacturer_id"),
                    manufacturerName = obj.optStringOrNullLocal("manufacturer_name"),
                    year = obj.optIntOrNullLocal("year"),
                    primaryImageMediumUrl = primary?.optStringOrNullLocal("medium_url"),
                    primaryImageLargeUrl = primary?.optStringOrNullLocal("large_url"),
                    playfieldImageMediumUrl = playfield?.optStringOrNullLocal("medium_url"),
                    playfieldImageLargeUrl = playfield?.optStringOrNullLocal("large_url"),
                ),
            )
        }
    }
}

private fun JSONArray?.toRulesheetLinkRecords(): List<CatalogRulesheetLinkRecord> {
    if (this == null) return emptyList()
    return buildList {
        for (i in 0 until length()) {
            val obj = optJSONObject(i) ?: continue
            val practiceIdentity = obj.optStringOrNullLocal("practice_identity") ?: continue
            add(
                CatalogRulesheetLinkRecord(
                    practiceIdentity = practiceIdentity,
                    provider = obj.optStringOrNullLocal("provider") ?: "",
                    label = obj.optStringOrNullLocal("label") ?: "Rulesheet",
                    url = obj.optStringOrNullLocal("url"),
                    localPath = obj.optStringOrNullLocal("local_path"),
                    priority = obj.optIntOrNullLocal("priority"),
                ),
            )
        }
    }
}

private fun JSONArray?.toVideoLinkRecords(): List<CatalogVideoLinkRecord> {
    if (this == null) return emptyList()
    return buildList {
        for (i in 0 until length()) {
            val obj = optJSONObject(i) ?: continue
            val practiceIdentity = obj.optStringOrNullLocal("practice_identity") ?: continue
            add(
                CatalogVideoLinkRecord(
                    practiceIdentity = practiceIdentity,
                    provider = obj.optStringOrNullLocal("provider") ?: "",
                    kind = obj.optStringOrNullLocal("kind"),
                    label = obj.optStringOrNullLocal("label") ?: "Video",
                    url = obj.optStringOrNullLocal("url"),
                    priority = obj.optIntOrNullLocal("priority"),
                ),
            )
        }
    }
}
