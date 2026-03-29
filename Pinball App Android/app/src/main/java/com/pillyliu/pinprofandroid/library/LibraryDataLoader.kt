package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.gameroom.GameRoomPersistedState
import com.pillyliu.pinprofandroid.gameroom.GameRoomStateCodec
import com.pillyliu.pinprofandroid.gameroom.GameRoomStore
import com.pillyliu.pinprofandroid.gameroom.GameRoomArea
import com.pillyliu.pinprofandroid.gameroom.OwnedMachine
import org.json.JSONArray
import org.json.JSONObject

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

private val curatedModernManufacturerNames = listOf(
    "stern",
    "stern pinball",
    "jersey jack pinball",
    "chicago gaming",
    "american pinball",
    "spooky pinball",
    "multimorphic",
    "barrels of fun",
    "dutch pinball",
    "pinball brothers",
    "turner pinball",
    "pinprof labs",
)

private val curatedModernManufacturerRanks = curatedModernManufacturerNames
    .mapIndexed { index, name -> name to (index + 1) }
    .toMap()

private data class PracticeIdentityCurations(
    val practiceIdentityByOpdbId: Map<String, String> = emptyMap(),
)

private fun opdbGroupIdFromOpdbId(opdbId: String?): String? {
    val trimmed = normalizedOptionalString(opdbId) ?: return null
    if (!trimmed.startsWith("G")) return null
    val dashIndex = trimmed.indexOf('-')
    return if (dashIndex < 0) trimmed else trimmed.substring(0, dashIndex).ifBlank { null }
}

private fun parsePracticeIdentityCurations(raw: String?): PracticeIdentityCurations {
    val root = runCatching { JSONObject(raw ?: "") }.getOrNull() ?: return PracticeIdentityCurations()
    val splits = root.optJSONArray("splits") ?: return PracticeIdentityCurations()
    val resolved = linkedMapOf<String, String>()
    for (splitIndex in 0 until splits.length()) {
        val split = splits.optJSONObject(splitIndex) ?: continue
        val entries = split.optJSONArray("practiceEntries") ?: continue
        for (entryIndex in 0 until entries.length()) {
            val entry = entries.optJSONObject(entryIndex) ?: continue
            val practiceIdentity = normalizedOptionalString(entry.optString("practiceIdentity")) ?: continue
            val memberIds = entry.optJSONArray("memberOpdbIds") ?: continue
            for (memberIndex in 0 until memberIds.length()) {
                val memberId = normalizedOptionalString(memberIds.optString(memberIndex)) ?: continue
                resolved[memberId] = practiceIdentity
            }
        }
    }
    return PracticeIdentityCurations(practiceIdentityByOpdbId = resolved)
}

private fun resolvePracticeIdentity(opdbId: String?, curations: PracticeIdentityCurations): String? {
    val fullId = normalizedOptionalString(opdbId) ?: return null
    return curations.practiceIdentityByOpdbId[fullId] ?: opdbGroupIdFromOpdbId(fullId) ?: fullId
}

private fun rawOpdbYear(manufactureDate: String?): Int? {
    val prefix = manufactureDate?.take(4) ?: return null
    return if (prefix.length == 4) prefix.toIntOrNull() else null
}

private fun rawOpdbImageSet(images: JSONArray?, preferredType: String): Pair<String?, String?>? {
    if (images == null) return null
    val normalizedPreferredType = preferredType.trim().lowercase()
    val typedMatches = buildList<JSONObject> {
        for (index in 0 until images.length()) {
            val image = images.optJSONObject(index) ?: continue
            val type = image.optString("type").trim().lowercase()
            if (type == normalizedPreferredType) add(image)
        }
    }
    val selected = typedMatches.firstOrNull { image ->
        val urls = image.optJSONObject("urls")
        image.optBoolean("primary") && (
            !urls?.optString("medium").isNullOrBlank() ||
                !urls?.optString("large").isNullOrBlank()
            )
    } ?: typedMatches.firstOrNull { image ->
        val urls = image.optJSONObject("urls")
        !urls?.optString("medium").isNullOrBlank() ||
            !urls?.optString("large").isNullOrBlank()
    } ?: return null
    val urls = selected.optJSONObject("urls")
    return normalizedOptionalString(urls?.optString("medium")) to
        normalizedOptionalString(urls?.optString("large"))
}

private fun rawOpdbFallbackSlug(title: String, shortname: String?, fallback: String): String {
    val normalizedShortname = normalizedOptionalString(shortname)
        ?.lowercase()
        ?.replace(Regex("[^a-z0-9]+"), "-")
        ?.trim('-')
    if (!normalizedShortname.isNullOrBlank()) return normalizedShortname

    val titleSlug = title.trim()
        .lowercase()
        .replace("&", "and")
        .replace(Regex("[^a-z0-9]+"), "-")
        .trim('-')
    return if (titleSlug.isBlank()) fallback else titleSlug
}

private fun rawOpdbCatalogMachineRecord(
    obj: JSONObject,
    curations: PracticeIdentityCurations,
): CatalogMachineRecord? {
    if (obj.has("is_machine") && !obj.isNull("is_machine") && !obj.optBoolean("is_machine", true)) {
        return null
    }
    val opdbId = obj.optStringOrNullLocal("opdb_id") ?: return null
    val practiceIdentity = resolvePracticeIdentity(opdbId, curations) ?: return null
    val opdbGroupId = opdbGroupIdFromOpdbId(opdbId) ?: practiceIdentity
    val name = obj.optStringOrNullLocal("name") ?: return null
    val manufacturer = obj.optJSONObject("manufacturer")
    val manufacturerRawId = if (manufacturer?.has("manufacturer_id") == true && !manufacturer.isNull("manufacturer_id")) {
        manufacturer.optInt("manufacturer_id").takeIf { it > 0 }
    } else {
        null
    }
    val (primaryMediumUrl, primaryLargeUrl) = rawOpdbImageSet(obj.optJSONArray("images"), "backglass") ?: (null to null)
    val (playfieldMediumUrl, playfieldLargeUrl) = rawOpdbImageSet(obj.optJSONArray("images"), "playfield") ?: (null to null)

    return CatalogMachineRecord(
        practiceIdentity = practiceIdentity,
        opdbMachineId = opdbId,
        opdbGroupId = opdbGroupId,
        slug = practiceIdentity,
        name = name,
        variant = null,
        manufacturerId = manufacturerRawId?.let { "manufacturer-$it" },
        manufacturerName = manufacturer?.optStringOrNullLocal("name"),
        year = rawOpdbYear(obj.optStringOrNullLocal("manufacture_date")),
        opdbName = normalizedOptionalString(name),
        opdbCommonName = obj.optStringOrNullLocal("common_name"),
        opdbShortname = obj.optStringOrNullLocal("shortname"),
        opdbDescription = obj.optStringOrNullLocal("description"),
        opdbType = obj.optStringOrNullLocal("type"),
        opdbDisplay = obj.optStringOrNullLocal("display"),
        opdbPlayerCount = obj.optIntOrNullLocal("player_count"),
        opdbManufactureDate = obj.optStringOrNullLocal("manufacture_date"),
        opdbIpdbId = obj.optIntOrNullLocal("ipdb_id"),
        opdbGroupShortname = null,
        opdbGroupDescription = null,
        primaryImageMediumUrl = primaryMediumUrl,
        primaryImageLargeUrl = primaryLargeUrl,
        playfieldImageMediumUrl = playfieldMediumUrl,
        playfieldImageLargeUrl = playfieldLargeUrl,
    )
}

private const val SYNTHETIC_PINPROF_LABS_GROUP_ID = "G900001"
private const val SYNTHETIC_PINPROF_LABS_MACHINE_ID = "G900001-1"
private const val SYNTHETIC_PINPROF_LABS_MANUFACTURER_ID = "manufacturer-9001"
private const val SYNTHETIC_PINPROF_LABS_BACKGLASS_PATH = "/pinball/images/backglasses/G900001-1-backglass.webp"
private const val SYNTHETIC_PINPROF_LABS_PLAYFIELD_MEDIUM_PATH = "/pinball/images/playfields/G900001-1-playfield_700.webp"
private const val SYNTHETIC_PINPROF_LABS_PLAYFIELD_LARGE_PATH = "/pinball/images/playfields/G900001-1-playfield_1400.webp"

private fun syntheticPinProfLabsCatalogMachineRecord(): CatalogMachineRecord =
    CatalogMachineRecord(
        practiceIdentity = SYNTHETIC_PINPROF_LABS_GROUP_ID,
        opdbMachineId = SYNTHETIC_PINPROF_LABS_MACHINE_ID,
        opdbGroupId = SYNTHETIC_PINPROF_LABS_GROUP_ID,
        slug = "pinprof",
        name = "PinProf: The Final Exam",
        variant = null,
        manufacturerId = SYNTHETIC_PINPROF_LABS_MANUFACTURER_ID,
        manufacturerName = "PinProf Labs",
        year = 1982,
        opdbName = "PinProf: The Final Exam",
        opdbCommonName = "PinProf: The Final Exam",
        opdbShortname = "PinProf",
        opdbDescription = "A long-lost pinball treasure.",
        opdbType = "ss",
        opdbDisplay = "alphanumeric",
        opdbPlayerCount = 4,
        opdbManufactureDate = "1982-09-03",
        opdbIpdbId = null,
        opdbGroupShortname = "PinProf",
        opdbGroupDescription = "A long-lost pinball treasure.",
        primaryImageMediumUrl = SYNTHETIC_PINPROF_LABS_BACKGLASS_PATH,
        primaryImageLargeUrl = SYNTHETIC_PINPROF_LABS_BACKGLASS_PATH,
        playfieldImageMediumUrl = SYNTHETIC_PINPROF_LABS_PLAYFIELD_MEDIUM_PATH,
        playfieldImageLargeUrl = SYNTHETIC_PINPROF_LABS_PLAYFIELD_LARGE_PATH,
    )

private fun appendSyntheticPinProfLabsMachine(machines: List<CatalogMachineRecord>): List<CatalogMachineRecord> {
    val hasSynthetic = machines.any { machine ->
        machine.opdbMachineId?.trim()?.equals(SYNTHETIC_PINPROF_LABS_MACHINE_ID, ignoreCase = true) == true ||
            machine.practiceIdentity.trim().equals(SYNTHETIC_PINPROF_LABS_GROUP_ID, ignoreCase = true)
    }
    return if (hasSynthetic) machines else machines + syntheticPinProfLabsCatalogMachineRecord()
}

private fun catalogResolvedMachines(machines: List<CatalogMachineRecord>): List<CatalogMachineRecord> =
    machines.map { machine ->
        machine.copy(
            variant = resolvedCatalogVariantLabel(
                title = machine.name,
                explicitVariant = machine.variant,
            ),
        )
    }

internal fun decodeOPDBExportCatalogMachines(
    raw: String,
    practiceIdentityCurationsRaw: String? = null,
): List<CatalogMachineRecord> {
    val array = runCatching { JSONArray(raw.trim()) }.getOrNull() ?: return emptyList()
    val curations = parsePracticeIdentityCurations(practiceIdentityCurationsRaw)
    return catalogResolvedMachines(
        appendSyntheticPinProfLabsMachine(
            buildList {
                for (index in 0 until array.length()) {
                    val obj = array.optJSONObject(index) ?: continue
                    rawOpdbCatalogMachineRecord(obj, curations)?.let(::add)
                }
            },
        ),
    )
}

private fun buildCatalogManufacturerRecordsFromMachines(
    machines: List<CatalogMachineRecord>,
): List<CatalogManufacturerRecord> {
    val grouped = machines
        .mapNotNull { machine ->
            val manufacturerId = normalizedOptionalString(machine.manufacturerId)
            val manufacturerName = normalizedOptionalString(machine.manufacturerName)
            if (manufacturerId == null || manufacturerName == null) null
            else Triple(manufacturerId, manufacturerName, machine)
        }
        .groupBy { it.first }

    return grouped.mapNotNull { (manufacturerId, entries) ->
        val manufacturerName = entries.firstOrNull()?.second ?: return@mapNotNull null
        val modernRank = curatedModernManufacturerRanks[manufacturerName.trim().lowercase()]
        CatalogManufacturerRecord(
            id = manufacturerId,
            name = manufacturerName,
            isModern = modernRank != null,
            featuredRank = modernRank,
            gameCount = entries.map { (_, _, machine) -> machine.practiceIdentity }.toSet().size,
        )
    }.sortedWith(
        compareBy<CatalogManufacturerRecord> { if (it.isModern == true) 0 else 1 }
            .thenBy { it.featuredRank ?: Int.MAX_VALUE }
            .thenBy { it.name.lowercase() },
    )
}

internal fun decodeCatalogManufacturerOptionsFromOPDBExport(
    raw: String,
    practiceIdentityCurationsRaw: String? = null,
): List<CatalogManufacturerOption> {
    val manufacturers = buildCatalogManufacturerRecordsFromMachines(
        decodeOPDBExportCatalogMachines(raw, practiceIdentityCurationsRaw),
    )
    return manufacturers.map { manufacturer ->
        CatalogManufacturerOption(
            id = manufacturer.id,
            name = manufacturer.name,
            gameCount = manufacturer.gameCount ?: 0,
            isModern = manufacturer.isModern == true,
            featuredRank = manufacturer.featuredRank,
            sortBucket = if (manufacturer.isModern == true) 0 else 1,
        )
    }
}

internal fun decodePracticeCatalogGamesFromOPDBExport(
    raw: String,
    practiceIdentityCurationsRaw: String? = null,
): List<PinballGame> {
    val machines = decodeOPDBExportCatalogMachines(raw, practiceIdentityCurationsRaw)
    if (machines.isEmpty()) return emptyList()

    val source = ImportedSourceRecord(
        id = "catalog--opdb-practice",
        name = "All OPDB Games",
        type = LibrarySourceType.CATEGORY,
        provider = ImportedSourceProvider.OPDB,
        providerSourceId = "opdb-catalog",
        machineIds = emptyList(),
    )

    return machines
        .groupBy { it.practiceIdentity }
        .values
        .mapNotNull { group ->
            val machine = group.minWithOrNull(::compareGroupDefaultMachine) ?: return@mapNotNull null
            resolveImportedGame(
                machine = machine,
                source = source,
                manufacturerById = emptyMap(),
                curatedOverride = null,
                opdbRulesheets = emptyList(),
                opdbVideos = emptyList(),
                venueMetadata = null,
            )
        }
        .sortedWith(compareBy<PinballGame> { it.name.lowercase() }.thenBy { it.practiceKey.lowercase() })
}

internal suspend fun loadPracticeCatalogGames(context: Context): List<PinballGame> {
    val raw = runCatching {
        PinballDataCache.loadText(
            url = hostedOPDBExportPath,
            allowMissing = true,
            maxCacheAgeMs = HOSTED_LIBRARY_REFRESH_INTERVAL_MS,
        ).text
    }.getOrNull()?.takeIf { it.isNotBlank() } ?: return emptyList()
    val practiceIdentityCurationsRaw = runCatching {
        PinballDataCache.loadText(
            url = hostedPracticeIdentityCurationsPath,
            allowMissing = true,
            maxCacheAgeMs = HOSTED_LIBRARY_REFRESH_INTERVAL_MS,
        ).text
    }.getOrNull()?.takeIf { it.isNotBlank() }

    return decodePracticeCatalogGamesFromOPDBExport(raw, practiceIdentityCurationsRaw)
}

private fun buildCAFOverrides(
    playfieldRaw: String?,
    gameinfoRaw: String?,
): Map<String, LegacyCuratedOverride> {
    val overrides = linkedMapOf<String, LegacyCuratedOverride>()

    fun upsertOverride(key: String, mutate: (LegacyCuratedOverride) -> Unit) {
        val normalizedKey = normalizedOptionalString(key) ?: return
        val current = overrides[normalizedKey] ?: LegacyCuratedOverride(practiceIdentity = normalizedKey)
        mutate(current)
        overrides[normalizedKey] = current
    }

    val playfieldRecords = runCatching { JSONObject(playfieldRaw ?: "").optJSONArray("records") }.getOrNull()
    if (playfieldRecords != null) {
        for (index in 0 until playfieldRecords.length()) {
            val obj = playfieldRecords.optJSONObject(index) ?: continue
            val playfieldLocalPath = normalizedOptionalString(obj.optString("playfieldLocalPath"))
            val playfieldSourceUrl = normalizedOptionalString(obj.optString("playfieldSourceUrl"))
            if (playfieldLocalPath == null && playfieldSourceUrl == null) continue

            val keys = linkedSetOf<String>()
            normalizedOptionalString(obj.optString("practiceIdentity"))?.let(keys::add)
            normalizedOptionalString(obj.optString("sourceOpdbMachineId"))?.let { opdbId ->
                keys += opdbId
            }
            val aliases = obj.optJSONArray("coveredAliasIds")
            if (aliases != null) {
                for (aliasIndex in 0 until aliases.length()) {
                    normalizedOptionalString(aliases.optString(aliasIndex))?.let { aliasId ->
                        keys += aliasId
                    }
                }
            }

            keys.forEach { key ->
                upsertOverride(key) { current ->
                    if (current.playfieldLocalPath == null) current.playfieldLocalPath = playfieldLocalPath
                    if (current.playfieldSourceUrl == null) current.playfieldSourceUrl = playfieldSourceUrl
                }
            }
        }
    }

    val gameinfoRecords = runCatching { JSONObject(gameinfoRaw ?: "").optJSONArray("records") }.getOrNull()
    if (gameinfoRecords != null) {
        for (index in 0 until gameinfoRecords.length()) {
            val obj = gameinfoRecords.optJSONObject(index) ?: continue
            if (obj.optBoolean("isHidden")) continue
            if (obj.has("isActive") && !obj.optBoolean("isActive", true)) continue
            val localPath = normalizedOptionalString(obj.optString("localPath")) ?: continue
            val practiceIdentity = normalizedOptionalString(obj.optString("opdbId")) ?: continue
            listOf(practiceIdentity).forEach { key ->
                upsertOverride(key) { current ->
                    if (current.gameinfoLocalPath == null) current.gameinfoLocalPath = localPath
                }
            }
        }
    }

    return overrides
}

private fun buildCAFGroupedRulesheetLinks(raw: String?): Map<String, List<CatalogRulesheetLinkRecord>> {
    val records = mutableListOf<CatalogRulesheetLinkRecord>()
    val array = runCatching { JSONObject(raw ?: "").optJSONArray("records") }.getOrNull() ?: return emptyMap()
    for (index in 0 until array.length()) {
        val obj = array.optJSONObject(index) ?: continue
        if (obj.optBoolean("isHidden")) continue
        if (obj.has("isActive") && !obj.optBoolean("isActive", true)) continue
        val practiceIdentity = normalizedOptionalString(obj.optString("opdbId")) ?: continue
        records += CatalogRulesheetLinkRecord(
            practiceIdentity = practiceIdentity,
            provider = normalizedOptionalString(obj.optString("provider")) ?: "",
            label = normalizedOptionalString(obj.optString("label")) ?: "Rulesheet",
            url = normalizedOptionalString(obj.optString("url")),
            localPath = normalizedOptionalString(obj.optString("localPath")),
            priority = if (obj.has("priority") && !obj.isNull("priority")) obj.optInt("priority") else null,
        )
    }
    return records.groupBy { it.practiceIdentity }
}

private fun buildCAFGroupedVideoLinks(raw: String?): Map<String, List<CatalogVideoLinkRecord>> {
    val records = mutableListOf<CatalogVideoLinkRecord>()
    val array = runCatching { JSONObject(raw ?: "").optJSONArray("records") }.getOrNull() ?: return emptyMap()
    for (index in 0 until array.length()) {
        val obj = array.optJSONObject(index) ?: continue
        if (obj.optBoolean("isHidden")) continue
        if (obj.has("isActive") && !obj.optBoolean("isActive", true)) continue
        val practiceIdentity = normalizedOptionalString(obj.optString("opdbId")) ?: continue
        val url = normalizedOptionalString(obj.optString("url")) ?: continue
        records += CatalogVideoLinkRecord(
            practiceIdentity = practiceIdentity,
            provider = normalizedOptionalString(obj.optString("provider")) ?: "",
            kind = normalizedOptionalString(obj.optString("kind")),
            label = normalizedOptionalString(obj.optString("label")) ?: "Video",
            url = url,
            priority = if (obj.has("priority") && !obj.isNull("priority")) obj.optInt("priority") else null,
        )
    }
    return records.groupBy { it.practiceIdentity }
}

private fun parseCAFVenueLayoutAssets(raw: String?): VenueMetadataOverlayIndex {
    val areaOrderByKey = linkedMapOf<String, Int>()
    val machineLayoutByKey = linkedMapOf<String, VenueMachineLayoutOverlayRecord>()
    val machineBankByKey = linkedMapOf<String, VenueMachineBankOverlayRecord>()
    val array = runCatching { JSONObject(raw ?: "").optJSONArray("records") }.getOrNull() ?: return VenueMetadataOverlayIndex()

    for (index in 0 until array.length()) {
        val obj = array.optJSONObject(index) ?: continue
        val sourceId = canonicalLibrarySourceId(obj.optString("sourceId"))
            ?: normalizedOptionalString(obj.optString("sourceId"))
            ?: continue
        val opdbId = normalizedOptionalString(obj.optString("opdbId")) ?: continue
        val area = normalizedOptionalString(obj.optString("area"))
        val areaOrder = if (obj.has("areaOrder") && !obj.isNull("areaOrder")) obj.optInt("areaOrder") else null
        val groupNumber = if (obj.has("groupNumber") && !obj.isNull("groupNumber")) obj.optInt("groupNumber") else null
        val position = if (obj.has("position") && !obj.isNull("position")) obj.optInt("position") else null
        val bank = if (obj.has("bank") && !obj.isNull("bank")) obj.optInt("bank") else null

        if (area != null && areaOrder != null) {
            areaOrderByKey[venueOverlayAreaKey(sourceId, area)] = areaOrder
        }
        if (area != null || groupNumber != null || position != null) {
            machineLayoutByKey[venueOverlayMachineKey(sourceId, opdbId)] = VenueMachineLayoutOverlayRecord(
                sourceId = sourceId,
                opdbId = opdbId,
                area = area,
                groupNumber = groupNumber,
                position = position,
            )
        }
        if (bank != null) {
            machineBankByKey[venueOverlayMachineKey(sourceId, opdbId)] = VenueMachineBankOverlayRecord(
                sourceId = sourceId,
                opdbId = opdbId,
                bank = bank,
            )
        }
    }

    return VenueMetadataOverlayIndex(
        areaOrderByKey = areaOrderByKey,
        machineLayoutByKey = machineLayoutByKey,
        machineBankByKey = machineBankByKey,
    )
}

private fun catalogCuratedOverride(
    practiceIdentity: String?,
    opdbGroupId: String?,
    opdbId: String? = null,
    overridesByKey: Map<String, LegacyCuratedOverride>,
): LegacyCuratedOverride? {
    val candidateKeys = listOf(
        normalizedOptionalString(opdbId),
        normalizedOptionalString(practiceIdentity),
        normalizedOptionalString(opdbGroupId),
    ).distinct().filterNotNull()
    return candidateKeys.firstNotNullOfOrNull { overridesByKey[it] }
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

private data class VenueMachineLayoutOverlayRecord(
    val sourceId: String,
    val opdbId: String,
    val area: String?,
    val groupNumber: Int?,
    val position: Int?,
)

private data class VenueMachineBankOverlayRecord(
    val sourceId: String,
    val opdbId: String,
    val bank: Int,
)

private data class VenueMetadataOverlayIndex(
    val areaOrderByKey: Map<String, Int> = emptyMap(),
    val machineLayoutByKey: Map<String, VenueMachineLayoutOverlayRecord> = emptyMap(),
    val machineBankByKey: Map<String, VenueMachineBankOverlayRecord> = emptyMap(),
)

private data class GameRoomLibrarySyntheticImport(
    val importedSource: ImportedSourceRecord,
    val venueMetadataOverlays: VenueMetadataOverlayIndex,
)

internal data class ResolvedImportedVenueMetadata(
    val area: String?,
    val areaOrder: Int?,
    val group: Int?,
    val position: Int?,
    val bank: Int?,
)

private fun venueOverlayAreaKey(sourceId: String, area: String): String = "$sourceId::$area"

private fun venueOverlayMachineKey(sourceId: String, opdbId: String): String = "$sourceId::$opdbId"

private fun mergedImportedSources(
    importedSources: List<ImportedSourceRecord>,
    syntheticGameRoomImport: GameRoomLibrarySyntheticImport?,
): List<ImportedSourceRecord> {
    val merged = importedSources.filterNot { it.id == GAME_ROOM_LIBRARY_SOURCE_ID }.toMutableList()
    syntheticGameRoomImport?.let { merged += it.importedSource }
    return merged
}

private fun mergeVenueMetadataOverlayIndices(
    lhs: VenueMetadataOverlayIndex,
    rhs: VenueMetadataOverlayIndex,
): VenueMetadataOverlayIndex = VenueMetadataOverlayIndex(
    areaOrderByKey = lhs.areaOrderByKey + rhs.areaOrderByKey,
    machineLayoutByKey = lhs.machineLayoutByKey + rhs.machineLayoutByKey,
    machineBankByKey = lhs.machineBankByKey + rhs.machineBankByKey,
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
    val opdbName: String? = null,
    val opdbCommonName: String? = null,
    val opdbShortname: String? = null,
    val opdbDescription: String? = null,
    val opdbType: String? = null,
    val opdbDisplay: String? = null,
    val opdbPlayerCount: Int? = null,
    val opdbManufactureDate: String? = null,
    val opdbIpdbId: Int? = null,
    val opdbGroupShortname: String? = null,
    val opdbGroupDescription: String? = null,
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

private fun loadGameRoomLibrarySyntheticImport(context: Context): GameRoomLibrarySyntheticImport? {
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


private fun resolveImportedVenueMetadata(
    sourceId: String,
    requestedOpdbId: String,
    machine: CatalogMachineRecord,
    overlays: VenueMetadataOverlayIndex,
): ResolvedImportedVenueMetadata? {
    fun expandedOverlayCandidateIds(value: String?): List<String> {
        val normalized = normalizedOptionalString(value) ?: return emptyList()
        val out = mutableListOf<String>()
        var current: String? = normalized
        while (current != null) {
            if (!out.contains(current)) out += current
            val dashIndex = current.lastIndexOf('-')
            if (dashIndex <= 0) break
            current = current.substring(0, dashIndex)
        }
        return out
    }

    val candidateIds = buildList {
        (
            expandedOverlayCandidateIds(requestedOpdbId) +
                expandedOverlayCandidateIds(machine.opdbMachineId) +
                expandedOverlayCandidateIds(machine.opdbGroupId) +
                expandedOverlayCandidateIds(machine.practiceIdentity)
            ).forEach { candidate ->
            if (!contains(candidate)) {
                add(candidate)
            }
        }
    }

    for (candidateId in candidateIds) {
        val layout = overlays.machineLayoutByKey[venueOverlayMachineKey(sourceId, candidateId)]
        val bank = overlays.machineBankByKey[venueOverlayMachineKey(sourceId, candidateId)]
        if (layout == null && bank == null) continue

        val area = normalizedOptionalString(layout?.area)
        return ResolvedImportedVenueMetadata(
            area = area,
            areaOrder = area?.let { overlays.areaOrderByKey[venueOverlayAreaKey(sourceId, it)] },
            group = layout?.groupNumber,
            position = layout?.position,
            bank = bank?.bank,
        )
    }

    return null
}

private fun dedupeSources(sources: List<LibrarySource>): List<LibrarySource> {
    val seen = LinkedHashSet<String>()
    return sources.filter { source -> seen.add(source.id) }
}

private fun JSONObject.optIntOrNullLocal(name: String): Int? =
    if (has(name) && !isNull(name)) optInt(name) else null

private fun JSONObject.optStringOrNullLocal(name: String): String? =
    optString(name)
        .trim()
        .takeIf { it.isNotBlank() && !it.equals("null", ignoreCase = true) }
