package com.pillyliu.pinballandroid.library

import android.content.Context
import com.pillyliu.pinballandroid.data.PinballDataCache
import org.json.JSONArray
import org.json.JSONObject

private const val HOSTED_LIBRARY_REFRESH_INTERVAL_MS = 24L * 60L * 60L * 1000L

internal suspend fun loadLibraryExtraction(context: Context): LegacyCatalogExtraction {
    return runCatching {
        loadHostedLibraryExtraction(context)
    }.getOrElse {
        loadBundledLibraryExtraction(context) ?: LibrarySeedDatabase.loadExtraction(context)
    }
}

private suspend fun loadHostedLibraryExtraction(context: Context): LegacyCatalogExtraction {
    val libraryCached = PinballDataCache.loadText(
        url = LIBRARY_URL,
        allowMissing = false,
        maxCacheAgeMs = HOSTED_LIBRARY_REFRESH_INTERVAL_MS,
    )
    val opdbCached = PinballDataCache.loadText(
        url = OPDB_CATALOG_URL,
        allowMissing = true,
        maxCacheAgeMs = HOSTED_LIBRARY_REFRESH_INTERVAL_MS,
    )
    val libraryText = libraryCached.text ?: error("Missing library payload")
    val opdbText = opdbCached.text?.takeIf { it.isNotBlank() }
    return if (opdbText != null) {
        decodeMergedLibraryPayloadWithState(context, libraryText, opdbText)
    } else {
        decodeLibraryPayloadWithState(context, libraryText)
    }
}

private fun loadBundledLibraryExtraction(context: Context): LegacyCatalogExtraction? {
    val libraryText = loadBundledPinballText(context, "/pinball/data/pinball_library_v3.json") ?: return null
    val opdbText = loadBundledPinballText(context, "/pinball/data/opdb_catalog_v1.json")
    return if (!opdbText.isNullOrBlank()) {
        decodeMergedLibraryPayloadWithState(context, libraryText, opdbText)
    } else {
        decodeLibraryPayloadWithState(context, libraryText)
    }
}

private fun loadBundledPinballText(context: Context, path: String): String? {
    val normalizedPath = if (path.startsWith("/")) path else "/$path"
    if (!normalizedPath.startsWith("/pinball/")) return null
    val assetPath = "starter-pack$normalizedPath"
    return runCatching {
        context.assets.open(assetPath).bufferedReader().use { it.readText() }
    }.getOrNull()
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
    val filteredSources = payload.sources.filter { it.id in enabled }
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

private data class CatalogManufacturerRecord(
    val id: String,
    val name: String,
)

private data class CatalogMachineRecord(
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

private data class CatalogRulesheetLinkRecord(
    val practiceIdentity: String,
    val provider: String,
    val label: String,
    val url: String?,
    val localPath: String?,
    val priority: Int?,
)

private data class CatalogVideoLinkRecord(
    val practiceIdentity: String,
    val provider: String,
    val kind: String?,
    val label: String,
    val url: String?,
    val priority: Int?,
)

private data class LegacyCuratedOverride(
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
    if (importedSources.isEmpty()) {
        return ParsedLibraryData(games = mergedLegacyGames, sources = legacyPayload.sources)
    }

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

                LibrarySourceType.VENUE -> {
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

    return ParsedLibraryData(
        games = mergedLegacyGames + additionalGames,
        sources = dedupeSources(legacyPayload.sources + additionalSources),
    )
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

private fun resolveImportedGame(
    machine: CatalogMachineRecord,
    source: ImportedSourceRecord,
    manufacturerById: Map<String, CatalogManufacturerRecord>,
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheets: List<CatalogRulesheetLinkRecord>,
    opdbVideos: List<CatalogVideoLinkRecord>,
): PinballGame {
    val manufacturerName = curatedOverride?.manufacturerOverride
        ?: machine.manufacturerName
        ?: machine.manufacturerId?.let { manufacturerById[it]?.name }
    val resolvedRulesheet = if (!curatedOverride?.rulesheetLocalPath.isNullOrBlank()) {
        normalizedOptionalString(curatedOverride?.rulesheetLocalPath) to emptyList()
    } else if (!curatedOverride?.rulesheetLinks.isNullOrEmpty()) {
        null to curatedOverride!!.rulesheetLinks
    } else {
        val resolved = resolveRulesheetLinks(opdbRulesheets)
        resolved.localPath to resolved.links
    }
    val resolvedVideos = if (!curatedOverride?.videos.isNullOrEmpty()) curatedOverride!!.videos else resolveVideoLinks(opdbVideos)
    val playfieldLocalPath = curatedOverride?.playfieldLocalPath
    val playfieldSourceUrl = curatedOverride?.playfieldSourceUrl
        ?: normalizedOptionalString(machine.playfieldImageLargeUrl ?: machine.playfieldImageMediumUrl)
    return PinballGame(
        libraryEntryId = "${source.id}:${machine.practiceIdentity}",
        practiceIdentity = machine.practiceIdentity,
        opdbId = machine.opdbMachineId,
        opdbGroupId = machine.opdbGroupId,
        variant = if (source.type == LibrarySourceType.MANUFACTURER) null else (curatedOverride?.variantOverride ?: normalizedOptionalString(machine.variant)),
        sourceId = source.id,
        sourceName = source.name,
        sourceType = source.type,
        area = null,
        areaOrder = null,
        group = null,
        position = null,
        bank = null,
        name = curatedOverride?.nameOverride ?: machine.name,
        manufacturer = normalizedOptionalString(manufacturerName),
        year = curatedOverride?.yearOverride ?: machine.year,
        slug = normalizedOptionalString(machine.slug) ?: machine.practiceIdentity,
        primaryImageUrl = normalizedOptionalString(machine.primaryImageMediumUrl),
        primaryImageLargeUrl = normalizedOptionalString(machine.primaryImageLargeUrl),
        playfieldImageUrl = playfieldSourceUrl,
        playfieldLocalOriginal = normalizeCachePath(playfieldLocalPath),
        playfieldLocal = normalizePlayfieldLocalPath(playfieldLocalPath),
        playfieldSourceLabel = if (playfieldLocalPath == null && (machine.playfieldImageLargeUrl != null || machine.playfieldImageMediumUrl != null)) "Playfield (OPDB)" else null,
        gameinfoLocal = curatedOverride?.gameinfoLocalPath,
        rulesheetLocal = resolvedRulesheet.first,
        rulesheetUrl = resolvedRulesheet.second.firstOrNull()?.url,
        rulesheetLinks = resolvedRulesheet.second,
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
): CatalogMachineRecord? {
    val preferredGroupMachine = normalizedOptionalString(legacyGame.practiceIdentity ?: legacyGame.opdbGroupId)
        ?.let { practiceIdentity -> machineByPracticeIdentity[practiceIdentity]?.minWithOrNull(::comparePreferredMachine) }
    val requestedMachineId = normalizedOptionalString(legacyGame.opdbId) ?: return preferredGroupMachine
    val exactMachine = machineByOpdbId[requestedMachineId] ?: return preferredGroupMachine
    return if (seedMachineHasPrimaryImage(exactMachine)) exactMachine else preferredGroupMachine ?: exactMachine
}

private fun preferredMachineForSourceLookup(
    requestedMachineId: String,
    machineByOpdbId: Map<String, CatalogMachineRecord>,
    machineByPracticeIdentity: Map<String, List<CatalogMachineRecord>>,
): CatalogMachineRecord? {
    val normalizedMachineId = normalizedOptionalString(requestedMachineId)
    val preferredGroupMachine = normalizedMachineId
        ?.let { machineByPracticeIdentity[it]?.minWithOrNull(::comparePreferredMachine) }
    val exactMachine = normalizedMachineId?.let { machineByOpdbId[it] } ?: return preferredGroupMachine
    if (seedMachineHasPrimaryImage(exactMachine)) return exactMachine
    val exactGroupMachine = machineByPracticeIdentity[exactMachine.practiceIdentity]?.minWithOrNull(::comparePreferredMachine)
    return exactGroupMachine ?: preferredGroupMachine ?: exactMachine
}

private fun comparePreferredMachine(lhs: CatalogMachineRecord, rhs: CatalogMachineRecord): Int {
    val lhsHasPrimary = seedMachineHasPrimaryImage(lhs)
    val rhsHasPrimary = seedMachineHasPrimaryImage(rhs)
    if (lhsHasPrimary != rhsHasPrimary) return if (lhsHasPrimary) -1 else 1

    val lhsVariant = normalizedOptionalString(lhs.variant)
    val rhsVariant = normalizedOptionalString(rhs.variant)
    if ((lhsVariant == null) != (rhsVariant == null)) return if (lhsVariant == null) -1 else 1

    val lhsYear = lhs.year ?: Int.MAX_VALUE
    val rhsYear = rhs.year ?: Int.MAX_VALUE
    if (lhsYear != rhsYear) return lhsYear.compareTo(rhsYear)

    val lhsName = lhs.name.lowercase()
    val rhsName = rhs.name.lowercase()
    if (lhsName != rhsName) return lhsName.compareTo(rhsName)

    return (lhs.opdbMachineId ?: lhs.practiceIdentity).compareTo(rhs.opdbMachineId ?: rhs.practiceIdentity)
}

private fun seedMachineHasPrimaryImage(machine: CatalogMachineRecord): Boolean =
    machine.primaryImageMediumUrl != null || machine.primaryImageLargeUrl != null

private fun resolveRulesheetLinks(rulesheetLinks: List<CatalogRulesheetLinkRecord>): ResolvedRulesheetLinks {
    val sortedLinks = rulesheetLinks.sortedWith(compareBy<CatalogRulesheetLinkRecord> { it.priority ?: Int.MAX_VALUE }.thenBy { it.label })
    val links = sortedLinks.mapNotNull { link ->
        val url = normalizedOptionalString(link.url) ?: return@mapNotNull null
        ReferenceLink(label = catalogRulesheetLabel(link.provider, link.label), url = url)
    }
    return ResolvedRulesheetLinks(
        localPath = normalizedOptionalString(sortedLinks.firstOrNull()?.localPath),
        links = links,
    )
}

private fun resolveVideoLinks(videoLinks: List<CatalogVideoLinkRecord>): List<Video> {
    val groupedByProvider = videoLinks.groupBy { it.provider.lowercase() }
    val preferred = groupedByProvider["local"]?.sortedWith(compareVideoLinks())
        ?: groupedByProvider["matchplay"]?.sortedWith(compareVideoLinks())
        ?: emptyList()
    return preferred.map { link -> Video(kind = link.kind, label = link.label, url = link.url) }
}

private fun compareVideoLinks(): Comparator<CatalogVideoLinkRecord> =
    compareBy<CatalogVideoLinkRecord> { it.priority ?: Int.MAX_VALUE }.thenBy { it.label.lowercase() }

private fun catalogRulesheetLabel(providerRawValue: String, fallback: String): String {
    return when (providerRawValue.lowercase()) {
        "tf" -> "Rulesheet (TF)"
        "pp" -> "Rulesheet (PP)"
        "bob" -> "Rulesheet (Bob)"
        "papa" -> "Rulesheet (PAPA)"
        "opdb" -> "Rulesheet (OPDB)"
        "local" -> "Rulesheet"
        else -> fallback
    }
}

private data class ResolvedRulesheetLinks(
    val localPath: String?,
    val links: List<ReferenceLink>,
)

private fun normalizedOptionalString(value: String?): String? =
    value?.trim()?.takeIf { it.isNotEmpty() }

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
            add(CatalogManufacturerRecord(id = id, name = name))
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
