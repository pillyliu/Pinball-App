package com.pillyliu.pinprofandroid.library

import android.content.Context

internal suspend fun loadLibraryExtraction(context: Context): LibraryExtraction {
    return loadLibraryExtraction(context, filterBySourceState = true)
}

internal suspend fun loadFullLibraryExtraction(context: Context): LibraryExtraction {
    return loadLibraryExtraction(context, filterBySourceState = false)
}

private suspend fun loadLibraryExtraction(
    context: Context,
    filterBySourceState: Boolean,
): LibraryExtraction {
    return runCatching {
        loadHostedLibraryExtraction(context, filterBySourceState)
    }.getOrElse {
        LibraryExtraction(
            payload = ParsedLibraryData(games = emptyList(), sources = emptyList()),
            state = LibrarySourceStateStore.load(context),
        )
    }
}

private fun buildCAFLibraryPayload(
    machines: List<CatalogMachineRecord>,
    importedSources: List<ImportedSourceRecord>,
    rulesheetLinksByPracticeIdentity: Map<String, List<CatalogRulesheetLinkRecord>>,
    videoLinksByPracticeIdentity: Map<String, List<CatalogVideoLinkRecord>>,
    curatedOverridesByKey: Map<String, LegacyCuratedOverride>,
    venueMetadataOverlays: VenueMetadataOverlayIndex,
): ParsedLibraryData {
    if (importedSources.isEmpty()) {
        return ParsedLibraryData(games = emptyList(), sources = emptyList())
    }

    val machineByPracticeIdentity = machines.groupBy { it.practiceIdentity }
    val machineByOpdbId = machines.mapNotNull { machine ->
        normalizedOptionalString(machine.opdbMachineId)?.let { it to machine }
    }.toMap()
    val manufacturerById = buildCatalogManufacturerRecordsFromMachines(machines).associateBy { it.id }

    val resolvedSources = mutableListOf<LibrarySource>()
    val resolvedGames = mutableListOf<PinballGame>()

    importedSources.forEach { importedSource ->
        resolvedSources += LibrarySource(id = importedSource.id, name = importedSource.name, type = importedSource.type)
        when (importedSource.type) {
            LibrarySourceType.MANUFACTURER -> {
                val groupedMachines = machines
                    .filter { it.manufacturerId == importedSource.providerSourceId }
                    .groupBy { it.practiceIdentity }
                groupedMachines.values
                    .mapNotNull { group -> group.minWithOrNull(::comparePreferredMachine) }
                    .sortedWith(compareBy<CatalogMachineRecord> { it.year ?: Int.MAX_VALUE }.thenBy { it.name.lowercase() })
                    .forEach { machine ->
                        resolvedGames += resolveImportedGame(
                            machine = machine,
                            source = importedSource,
                            manufacturerById = manufacturerById,
                            curatedOverride = catalogCuratedOverride(
                                practiceIdentity = machine.practiceIdentity,
                                opdbGroupId = machine.opdbGroupId,
                                opdbId = machine.opdbMachineId,
                                overridesByKey = curatedOverridesByKey,
                            ),
                            opdbRulesheets = rulesheetLinksByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                            opdbVideos = videoLinksByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                            venueMetadata = null,
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

                    resolvedGames += resolveImportedGame(
                        machine = machine,
                        source = importedSource,
                        manufacturerById = manufacturerById,
                        curatedOverride = catalogCuratedOverride(
                            practiceIdentity = machine.practiceIdentity,
                            opdbGroupId = machine.opdbGroupId,
                            opdbId = machineId,
                            overridesByKey = curatedOverridesByKey,
                        ),
                        opdbRulesheets = rulesheetLinksByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                        opdbVideos = videoLinksByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                        venueMetadata = if (importedSource.type == LibrarySourceType.VENUE) {
                            resolveImportedVenueMetadata(
                                sourceId = importedSource.id,
                                requestedOpdbId = machineId,
                                machine = machine,
                                overlays = venueMetadataOverlays,
                            )
                        } else {
                            null
                        },
                    )
                }
            }

            LibrarySourceType.CATEGORY -> Unit
        }
    }

    return ParsedLibraryData(
        games = resolvedGames,
        sources = dedupeSources(resolvedSources),
    )
}

internal fun buildCAFLibraryExtraction(
    context: Context,
    opdbExportRaw: String,
    practiceIdentityCurationsRaw: String?,
    rulesheetAssetsRaw: String?,
    videoAssetsRaw: String?,
    playfieldAssetsRaw: String?,
    gameinfoAssetsRaw: String?,
    venueLayoutAssetsRaw: String?,
    filterBySourceState: Boolean,
): LibraryExtraction {
    val machines = decodeOPDBExportCatalogMachines(opdbExportRaw, practiceIdentityCurationsRaw)
    val rulesheetLinks = buildCAFGroupedRulesheetLinks(rulesheetAssetsRaw)
    val videoLinks = buildCAFGroupedVideoLinks(videoAssetsRaw)
    val gameRoomImport = loadGameRoomLibrarySyntheticImport(context)

    val payload = buildCAFLibraryPayload(
        machines = machines,
        importedSources = mergedImportedSources(ImportedSourcesStore.load(context), gameRoomImport),
        rulesheetLinksByPracticeIdentity = rulesheetLinks,
        videoLinksByPracticeIdentity = videoLinks,
        curatedOverridesByKey = buildCAFOverrides(
            playfieldRaw = playfieldAssetsRaw,
            gameinfoRaw = gameinfoAssetsRaw,
        ),
        venueMetadataOverlays = mergeVenueMetadataOverlayIndices(
            parseCAFVenueLayoutAssets(venueLayoutAssetsRaw),
            gameRoomImport?.venueMetadataOverlays ?: VenueMetadataOverlayIndex(),
        ),
    )
    val state = LibrarySourceStateStore.synchronize(context, payload.sources)
    return libraryExtraction(payload = payload, state = state, filterBySourceState = filterBySourceState)
}

private fun libraryExtraction(
    payload: ParsedLibraryData,
    state: LibrarySourceState,
    filterBySourceState: Boolean,
): LibraryExtraction {
    return LibraryExtraction(
        payload = if (filterBySourceState) filterPayload(payload, state) else payload,
        state = state,
    )
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

internal fun resolvedPlayfieldSourceLabel(game: PinballGame): String? {
    if (isPinProfPlayfieldUrl(game.playfieldImageUrl) || isPinProfPlayfieldUrl(game.playfieldLocalOriginalURL)) {
        return if (game.usesBundledOnlyAppAssetException) "Local" else "PinProf"
    }
    if (!game.playfieldLocal.isNullOrBlank()) {
        return if (game.usesBundledOnlyAppAssetException) "Local" else "PinProf"
    }
    val explicit = game.playfieldSourceLabel?.trim()?.takeIf { it.isNotEmpty() }
    if (explicit != null) {
        return explicit
    }
    val sourceUrl = resolveLibraryUrl(game.playfieldImageUrl) ?: return null
    return when {
        sourceUrl.contains("img.opdb.org", ignoreCase = true) -> "Playfield (OPDB)"
        isPinProfPlayfieldUrl(sourceUrl) -> "PinProf"
        else -> null
    }
}

private fun dedupeSources(sources: List<LibrarySource>): List<LibrarySource> {
    val seen = LinkedHashSet<String>()
    return sources.filter { source -> seen.add(source.id) }
}
