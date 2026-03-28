package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.gameroom.GameRoomStateCodec
import com.pillyliu.pinprofandroid.gameroom.GameRoomStore
import com.pillyliu.pinprofandroid.gameroom.GameRoomArea
import com.pillyliu.pinprofandroid.gameroom.OwnedMachine
import com.pillyliu.pinprofandroid.gameroom.OwnedMachineStatus
import org.json.JSONArray
import org.json.JSONObject

internal suspend fun loadLibraryExtraction(context: Context): LegacyCatalogExtraction {
    return loadLibraryExtraction(context, filterBySourceState = true)
}

internal suspend fun loadFullLibraryExtraction(context: Context): LegacyCatalogExtraction {
    return loadLibraryExtraction(context, filterBySourceState = false)
}

private suspend fun loadLibraryExtraction(
    context: Context,
    filterBySourceState: Boolean,
): LegacyCatalogExtraction {
    return runCatching {
        loadHostedLibraryExtraction(context, filterBySourceState)
    }.getOrElse {
        LegacyCatalogExtraction(
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

internal fun decodeCatalogManufacturerOptions(raw: String): List<CatalogManufacturerOption> {
    val root = parseNormalizedRoot(raw)
    if (root.manufacturers.isEmpty()) return emptyList()

    val groupCountsByManufacturerId = root.machines
        .groupBy { it.manufacturerId.orEmpty() }
        .mapValues { (_, machines) ->
            machines.map { it.practiceIdentity }.toSet().size
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

private fun decodePracticeCatalogGames(root: NormalizedRoot): List<PinballGame> {
    if (root.machines.isEmpty()) return emptyList()

    val manufacturerById = root.manufacturers.associateBy { it.id }
    val rulesheetsByPracticeIdentity = root.rulesheetLinks.groupBy { it.practiceIdentity }
    val videosByPracticeIdentity = root.videoLinks.groupBy { it.practiceIdentity }
    val source = ImportedSourceRecord(
        id = "catalog--opdb-practice",
        name = "All OPDB Games",
        type = LibrarySourceType.CATEGORY,
        provider = ImportedSourceProvider.OPDB,
        providerSourceId = "opdb-catalog",
        machineIds = emptyList(),
    )

    return root.machines
        .groupBy { it.practiceIdentity }
        .values
        .mapNotNull { group ->
            val machine = group.minWithOrNull(::compareGroupDefaultMachine) ?: return@mapNotNull null
            resolveImportedGame(
                machine = machine,
                source = source,
                manufacturerById = manufacturerById,
                curatedOverride = null,
                opdbRulesheets = rulesheetsByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                opdbVideos = videosByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                venueMetadata = null,
            )
        }
        .sortedWith(compareBy<PinballGame> { it.name.lowercase() }.thenBy { it.practiceKey.lowercase() })
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
    ).filterNotNull()
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
): LegacyCatalogExtraction {
    val machines = decodeOPDBExportCatalogMachines(opdbExportRaw, practiceIdentityCurationsRaw)
    val manufacturers = buildCatalogManufacturerRecordsFromMachines(machines)
    val rulesheetLinks = buildCAFGroupedRulesheetLinks(rulesheetAssetsRaw)
    val videoLinks = buildCAFGroupedVideoLinks(videoAssetsRaw)

    val payload = buildCAFLibraryPayload(
        machines = machines,
        importedSources = ImportedSourcesStore.load(context),
        rulesheetLinksByPracticeIdentity = rulesheetLinks,
        videoLinksByPracticeIdentity = videoLinks,
        curatedOverridesByKey = buildCAFOverrides(
            playfieldRaw = playfieldAssetsRaw,
            gameinfoRaw = gameinfoAssetsRaw,
        ),
        venueMetadataOverlays = parseCAFVenueLayoutAssets(venueLayoutAssetsRaw),
    )

    val gameRoomOverlay = buildGameRoomOverlay(
        context = context,
        baseGames = payload.games,
        root = NormalizedRoot(
            manufacturers = manufacturers,
            machines = machines,
            rulesheetLinks = rulesheetLinks.values.flatten(),
            videoLinks = videoLinks.values.flatten(),
        ),
    )

    val payloadWithGameRoom = ParsedLibraryData(
        games = payload.games + gameRoomOverlay.games,
        sources = dedupeSources(payload.sources + listOfNotNull(gameRoomOverlay.source)),
    )
    val state = LibrarySourceStateStore.synchronize(context, payloadWithGameRoom.sources)
    return legacyCatalogExtraction(payload = payloadWithGameRoom, state = state, filterBySourceState = filterBySourceState)
}

private fun legacyCatalogExtraction(
    payload: ParsedLibraryData,
    state: LibrarySourceState,
    filterBySourceState: Boolean,
): LegacyCatalogExtraction {
    return LegacyCatalogExtraction(
        payload = if (filterBySourceState) filterPayload(payload, state) else payload,
        state = state,
    )
}

private fun filterPayload(payload: ParsedLibraryData, state: LibrarySourceState): ParsedLibraryData {
    val enabled = state.enabledSourceIds.toSet()
    val hasGameRoomGames = payload.games.any { it.sourceId == BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID }
    val filteredSources = payload.sources.filter { source ->
        source.id in enabled || (source.id == BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID && hasGameRoomGames)
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

private data class PublicLibraryOverridesRoot(
    val playfieldOverrides: List<PublicLibraryPlayfieldOverrideRecord> = emptyList(),
)

private data class PublicLibraryPlayfieldOverrideRecord(
    val practiceIdentity: String,
    val opdbGroupId: String?,
    val playfieldLocalPath: String?,
    val playfieldSourceUrl: String?,
)

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

internal data class ResolvedImportedVenueMetadata(
    val area: String?,
    val areaOrder: Int?,
    val group: Int?,
    val position: Int?,
    val bank: Int?,
)

private fun curatedOverrideForKeys(
    practiceIdentity: String?,
    opdbGroupId: String?,
    overridesByKey: Map<String, LegacyCuratedOverride>,
): LegacyCuratedOverride? {
    val candidateKeys = listOf(
        normalizedOptionalString(practiceIdentity),
        normalizedOptionalString(opdbGroupId),
    ).distinct().filterNotNull()
    return candidateKeys.firstNotNullOfOrNull { overridesByKey[it] }
}

private fun venueOverlayAreaKey(sourceId: String, area: String): String = "$sourceId::$area"

private fun venueOverlayMachineKey(sourceId: String, opdbId: String): String = "$sourceId::$opdbId"

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
    publicOverrides: PublicLibraryOverridesRoot,
    venueMetadataOverlays: VenueMetadataOverlayIndex,
): ParsedLibraryData {
    val importedSources = ImportedSourcesStore.load(context)
    val importedSourceIds = importedSources.map { it.id }.toSet()
    val suppressedLegacySourceIds = buildSet {
        addAll(importedSourceIds)
        add(PM_AVENUE_LIBRARY_SOURCE_ID)
        add(PM_RLM_LIBRARY_SOURCE_ID)
        add(BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID)
    }
    val filteredLegacyGames = legacyPayload.games.filter { it.sourceId !in suppressedLegacySourceIds }
    val filteredLegacySources = legacyPayload.sources.filter { it.id !in suppressedLegacySourceIds }
    val machineByPracticeIdentity = root.machines.groupBy { it.practiceIdentity }
    val machineByOpdbId = root.machines.mapNotNull { machine ->
        normalizedOptionalString(machine.opdbMachineId)?.let { it to machine }
    }.toMap()
    val manufacturerById = root.manufacturers.associateBy { it.id }
    val curatedOverridesByPracticeIdentity = buildLegacyCuratedOverrides(legacyPayload.games).toMutableMap()
    applyPublicPlayfieldOverrides(curatedOverridesByPracticeIdentity, publicOverrides)
    val opdbRulesheetsByPracticeIdentity = root.rulesheetLinks.groupBy { it.practiceIdentity }
    val opdbVideosByPracticeIdentity = root.videoLinks.groupBy { it.practiceIdentity }

    val mergedLegacyGames = filteredLegacyGames.map { legacyGame ->
        resolveLegacyGame(
            legacyGame = legacyGame,
            curatedOverridesByPracticeIdentity = curatedOverridesByPracticeIdentity,
            machineByPracticeIdentity = machineByPracticeIdentity,
            machineByOpdbId = machineByOpdbId,
            manufacturerById = manufacturerById,
            opdbRulesheetsByPracticeIdentity = opdbRulesheetsByPracticeIdentity,
            opdbVideosByPracticeIdentity = opdbVideosByPracticeIdentity,
        )
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
                        .groupBy { it.practiceIdentity }
                    grouped.values
                        .mapNotNull { group -> group.minWithOrNull(::comparePreferredMachine) }
                        .sortedWith(compareBy<CatalogMachineRecord> { it.year ?: Int.MAX_VALUE }.thenBy { it.name.lowercase() })
                        .forEach { machine ->
                            add(
                                resolveImportedGame(
                                    machine = machine,
                                    source = importedSource,
                                    manufacturerById = manufacturerById,
                                    curatedOverride = curatedOverrideForKeys(
                                        practiceIdentity = machine.practiceIdentity,
                                        opdbGroupId = machine.opdbGroupId,
                                        overridesByKey = curatedOverridesByPracticeIdentity,
                                    ),
                                    opdbRulesheets = opdbRulesheetsByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                                    opdbVideos = opdbVideosByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                                    venueMetadata = null,
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
                                curatedOverride = curatedOverrideForKeys(
                                    practiceIdentity = machine.practiceIdentity,
                                    opdbGroupId = machine.opdbGroupId,
                                    overridesByKey = curatedOverridesByPracticeIdentity,
                                ),
                                opdbRulesheets = opdbRulesheetsByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                                opdbVideos = opdbVideosByPracticeIdentity[machine.practiceIdentity].orEmpty(),
                                venueMetadata = resolveImportedVenueMetadata(
                                    sourceId = importedSource.id,
                                    requestedOpdbId = machineId,
                                    machine = machine,
                                    overlays = venueMetadataOverlays,
                                ),
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
        sources = dedupeSources(filteredLegacySources + additionalSources + listOfNotNull(gameRoomOverlay.source)),
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
    val loadResult = GameRoomStateCodec.loadFromRaw(
        currentRaw = prefs.getString(GameRoomStore.STORAGE_KEY, null),
        legacyRaw = prefs.getString(GameRoomStore.LEGACY_STORAGE_KEY, null),
    )
    val decodedState = when (loadResult) {
        GameRoomStateCodec.LoadResult.Missing,
        is GameRoomStateCodec.LoadResult.Failed -> return GameRoomOverlay(source = null, games = emptyList())
        is GameRoomStateCodec.LoadResult.Loaded -> DecodedGameRoomOverlayState(
            venueName = loadResult.state.venueName,
            areas = loadResult.state.areas,
            ownedMachines = loadResult.state.ownedMachines,
        )
    }

    val venueName = decodedState.venueName.trim().ifBlank { "GameRoom" }
    val areasByID = decodedState.areas.associateBy { it.id }
    val activeMachines = decodedState.ownedMachines
        .filter { it.status == OwnedMachineStatus.active || it.status == OwnedMachineStatus.loaned }
        .sortedWith { lhs, rhs -> compareGameRoomOwnedMachinesForLibrary(lhs, rhs, areasByID) }

    if (activeMachines.isEmpty()) return GameRoomOverlay(source = null, games = emptyList())

    val opdbMediaIndex = loadGameRoomOPDBMediaIndex(root.machines)
    val rulesheetsByPracticeIdentity = root.rulesheetLinks.groupBy { it.practiceIdentity }
    val videosByPracticeIdentity = root.videoLinks.groupBy { it.practiceIdentity }

    val games = activeMachines.map { ownedMachine ->
        val visualTemplate = bestVisualTemplateForOwnedMachine(ownedMachine = ownedMachine, baseGames = baseGames)
        val contentTemplate = bestContentTemplateForOwnedMachine(ownedMachine = ownedMachine, baseGames = baseGames)
        val opdbMedia = bestOPDBMediaRecord(
            ownedMachine = ownedMachine,
            mediaIndex = opdbMediaIndex,
        )
        val canonicalPracticeIdentity = ownedMachine.canonicalPracticeIdentity.trim()
        val practiceIdentity = normalizedOptionalString(opdbMedia?.practiceIdentity)
            ?: normalizedOptionalString(contentTemplate?.practiceIdentity)
            ?: normalizedOptionalString(visualTemplate?.practiceIdentity)
            ?: canonicalPracticeIdentity.takeIf { it.isNotBlank() }
            ?: normalizedOptionalString(ownedMachine.catalogGameID)
            ?: ownedMachine.id
        val area = areasByID[ownedMachine.gameRoomAreaID]
        val resolvedRulesheet = when {
            !contentTemplate?.rulesheetLocal.isNullOrBlank() -> normalizedOptionalString(contentTemplate?.rulesheetLocal) to emptyList()
            !contentTemplate?.rulesheetLinks.isNullOrEmpty() -> null to (contentTemplate?.rulesheetLinks ?: emptyList())
            else -> {
                val resolved = resolveRulesheetLinks(rulesheetsByPracticeIdentity[practiceIdentity].orEmpty())
                resolved.localPath to resolved.links
            }
        }
        val resolvedVideos = mergeResolvedVideos(
            primary = contentTemplate?.videos.orEmpty(),
            secondary = resolveVideoLinks(videosByPracticeIdentity[practiceIdentity].orEmpty()),
        )
        val playfieldLocalRaw = normalizedOptionalString(visualTemplate?.playfieldLocalOriginal ?: visualTemplate?.playfieldLocal)
        val playfieldImageUrl = normalizedOptionalString(visualTemplate?.playfieldImageUrl)
        val playfieldSourceLabel = visualTemplate?.let(::resolvedPlayfieldSourceLabel)
        val rawResolvedName = ownedMachine.displayTitle.trim().ifBlank { visualTemplate?.name ?: ownedMachine.catalogGameID }
        val parsedResolvedName = parseOwnedMachineLibraryName(
            title = rawResolvedName,
            explicitVariant = ownedMachine.displayVariant,
        )
        val resolvedName = parsedResolvedName.displayTitle
        val slugFallback = canonicalPracticeIdentity.ifBlank {
            normalizedOptionalString(ownedMachine.catalogGameID) ?: ownedMachine.id
        }
        val exactOPDBID = normalizedOptionalString(ownedMachine.opdbID)

        PinballGame(
            libraryEntryId = "gameroom:${ownedMachine.id}",
            practiceIdentity = practiceIdentity,
            opdbId = exactOPDBID ?: normalizedOptionalString(ownedMachine.catalogGameID),
            opdbGroupId = normalizedOptionalString(ownedMachine.catalogGameID),
            variant = parsedResolvedName.displayVariant,
            sourceId = BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID,
            sourceName = venueName,
            sourceType = LibrarySourceType.VENUE,
            area = area?.name,
            areaOrder = area?.areaOrder,
            group = ownedMachine.groupNumber,
            position = ownedMachine.position,
            bank = null,
            name = resolvedName,
            manufacturer = normalizedOptionalString(ownedMachine.manufacturer),
            year = ownedMachine.year,
            slug = slugForLibraryGame(title = resolvedName, fallback = slugFallback),
            primaryImageUrl = normalizedOptionalString(opdbMedia?.primaryImageMediumUrl)
                ?: normalizedOptionalString(visualTemplate?.primaryImageUrl),
            primaryImageLargeUrl = normalizedOptionalString(opdbMedia?.primaryImageLargeUrl)
                ?: normalizedOptionalString(visualTemplate?.primaryImageLargeUrl),
            playfieldImageUrl = playfieldImageUrl,
            playfieldLocalOriginal = normalizeLibraryCachePath(playfieldLocalRaw),
            playfieldLocal = normalizeLibraryPlayfieldLocalPath(playfieldLocalRaw),
            playfieldSourceLabel = playfieldSourceLabel,
            gameinfoLocal = contentTemplate?.gameinfoLocal,
            rulesheetLocal = resolvedRulesheet.first,
            rulesheetUrl = resolvedRulesheet.second.firstOrNull()?.url,
            rulesheetLinks = resolvedRulesheet.second,
            videos = resolvedVideos,
        )
    }

    return GameRoomOverlay(
        source = LibrarySource(
            id = BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID,
            name = venueName,
            type = LibrarySourceType.VENUE,
        ),
        games = games,
    )
}

private fun loadGameRoomOPDBMediaIndex(
    machines: List<CatalogMachineRecord>,
): Map<String, List<CatalogMachineRecord>> {
    val index = linkedMapOf<String, MutableList<CatalogMachineRecord>>()
    machines.forEach { machine ->
        val keys = listOfNotNull(
            normalizedGameRoomID(machine.opdbGroupId),
            normalizedGameRoomID(machine.opdbMachineId),
            normalizedGameRoomID(machine.practiceIdentity),
        ).distinct()
        keys.forEach { key ->
            index.getOrPut(key) { mutableListOf() }.add(machine)
        }
    }
    return index
}

private data class DecodedGameRoomOverlayState(
    val venueName: String,
    val areas: List<GameRoomArea>,
    val ownedMachines: List<OwnedMachine>,
)

private data class ParsedOwnedMachineLibraryName(
    val displayTitle: String,
    val displayVariant: String?,
)

private fun parseOwnedMachineLibraryName(title: String, explicitVariant: String?): ParsedOwnedMachineLibraryName {
    val trimmedTitle = title.trim()
    val normalizedExplicitVariant = normalizeOwnedMachineVariantLabel(explicitVariant)
    if (!normalizedExplicitVariant.isNullOrBlank()) {
        val strippedTitle = stripOwnedMachineVariantSuffix(trimmedTitle, normalizedExplicitVariant)
        return ParsedOwnedMachineLibraryName(
            displayTitle = strippedTitle.ifBlank { trimmedTitle },
            displayVariant = normalizedExplicitVariant,
        )
    }
    if (!trimmedTitle.endsWith(")")) {
        return ParsedOwnedMachineLibraryName(displayTitle = trimmedTitle, displayVariant = null)
    }
    val openParenIndex = trimmedTitle.lastIndexOf('(')
    if (openParenIndex <= 0) {
        return ParsedOwnedMachineLibraryName(displayTitle = trimmedTitle, displayVariant = null)
    }
    val baseTitle = trimmedTitle.substring(0, openParenIndex).trim()
    val rawSuffix = trimmedTitle.substring(openParenIndex + 1, trimmedTitle.length - 1).trim()
    val derivedVariant = normalizeOwnedMachineVariantLabel(rawSuffix)
    return if (baseTitle.isNotBlank() && !derivedVariant.isNullOrBlank() && looksLikeOwnedMachineVariant(rawSuffix)) {
        ParsedOwnedMachineLibraryName(displayTitle = baseTitle, displayVariant = derivedVariant)
    } else {
        ParsedOwnedMachineLibraryName(displayTitle = trimmedTitle, displayVariant = null)
    }
}

private fun stripOwnedMachineVariantSuffix(title: String, normalizedVariant: String): String {
    if (!title.endsWith(")")) return title
    val openParenIndex = title.lastIndexOf('(')
    if (openParenIndex <= 0) return title
    val rawSuffix = title.substring(openParenIndex + 1, title.length - 1).trim()
    val normalizedSuffix = normalizeOwnedMachineVariantLabel(rawSuffix)
    if (normalizedSuffix == null || normalizedSuffix != normalizedVariant || !looksLikeOwnedMachineVariant(rawSuffix)) {
        return title
    }
    return title.substring(0, openParenIndex).trim().ifBlank { title }
}

private fun looksLikeOwnedMachineVariant(value: String): Boolean {
    val lowered = value.trim().lowercase()
    if (lowered.isBlank()) return false
    return lowered == "premium" ||
        lowered == "pro" ||
        lowered == "le" ||
        lowered == "ce" ||
        lowered == "se" ||
        lowered == "home" ||
        lowered.contains("anniversary") ||
        lowered.contains("limited edition") ||
        lowered.contains("special edition") ||
        lowered.contains("collector") ||
        lowered == "premium/le" ||
        lowered == "premium le" ||
        lowered == "premium-le"
}

private fun normalizeOwnedMachineVariantLabel(value: String?): String? {
    val trimmed = value?.trim().orEmpty()
    if (trimmed.isBlank()) return null
    val lowered = trimmed.lowercase()
    return when {
        lowered == "null" || lowered == "none" -> null
        lowered == "premium" -> "Premium"
        lowered == "pro" -> "Pro"
        lowered == "le" || lowered.contains("limited edition") -> "LE"
        lowered == "ce" || lowered.contains("collector") -> "CE"
        lowered == "se" || lowered.contains("special edition") -> "SE"
        lowered == "premium/le" || lowered == "premium le" || lowered == "premium-le" -> "Premium/LE"
        lowered.contains("anniversary") -> trimmed.split(" ")
            .filter { it.isNotBlank() }
            .joinToString(" ") { token ->
                when (token.lowercase()) {
                    "le", "ce", "se" -> token.uppercase()
                    else -> token.replaceFirstChar { ch -> if (ch.isLowerCase()) ch.titlecase() else ch.toString() }
                }
            }
        else -> trimmed
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

private fun bestVisualTemplateForOwnedMachine(
    ownedMachine: OwnedMachine,
    baseGames: List<PinballGame>,
): PinballGame? {
    val normalizedExactOPDBID = normalizedGameRoomID(ownedMachine.opdbID)
    val normalizedCatalogID = normalizedGameRoomID(ownedMachine.catalogGameID)
    val normalizedCatalogGroup = normalizedGroupFromOpdbID(ownedMachine.catalogGameID)
    val normalizedPracticeIdentity = normalizedGameRoomID(ownedMachine.canonicalPracticeIdentity)
    val normalizedMachineVariant = normalizedGameRoomVariant(ownedMachine.displayVariant)

    val candidates = baseGames.mapNotNull { game ->
        if (game.sourceId == BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID) {
            null
        } else {
            val gameMatchScore = templateMatchScore(
                game = game,
                exactOPDBID = normalizedExactOPDBID,
                catalogID = normalizedCatalogID,
                catalogGroupID = normalizedCatalogGroup,
                canonicalPracticeIdentity = normalizedPracticeIdentity,
            )
            if (gameMatchScore <= 0) {
                null
            } else {
                game to (gameMatchScore + visualTemplateScore(game, machineVariant = normalizedMachineVariant))
            }
        }
    }

    return candidates.maxByOrNull { it.second }?.first
}

private fun bestContentTemplateForOwnedMachine(
    ownedMachine: OwnedMachine,
    baseGames: List<PinballGame>,
): PinballGame? {
    val normalizedExactOPDBID = normalizedGameRoomID(ownedMachine.opdbID)
    val normalizedCatalogID = normalizedGameRoomID(ownedMachine.catalogGameID)
    val normalizedCatalogGroup = normalizedGroupFromOpdbID(ownedMachine.catalogGameID)
    val normalizedPracticeIdentity = normalizedGameRoomID(ownedMachine.canonicalPracticeIdentity)

    val candidates = baseGames.mapNotNull { game ->
        if (game.sourceId == BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID) {
            null
        } else {
            val gameMatchScore = templateMatchScore(
                game = game,
                exactOPDBID = normalizedExactOPDBID,
                catalogID = normalizedCatalogID,
                catalogGroupID = normalizedCatalogGroup,
                canonicalPracticeIdentity = normalizedPracticeIdentity,
            )
            if (gameMatchScore <= 0) {
                null
            } else {
                game to (gameMatchScore + contentTemplateScore(game))
            }
        }
    }

    return candidates.maxByOrNull { it.second }?.first
}

private fun templateMatchScore(
    game: PinballGame,
    exactOPDBID: String?,
    catalogID: String?,
    catalogGroupID: String?,
    canonicalPracticeIdentity: String?,
): Int {
    val gameOPDBID = normalizedGameRoomID(game.opdbId)
    val gameOPDBGroupID = normalizedGameRoomID(game.opdbGroupId)
    val gamePracticeIdentity = normalizedGameRoomID(game.practiceIdentity)
    val allowGroupFallback = allowsSharedGameRoomGroupFallback(
        catalogID = catalogID,
        catalogGroupID = catalogGroupID,
        canonicalPracticeIdentity = canonicalPracticeIdentity,
    )

    var score = 0

    if (exactOPDBID != null && gameOPDBID == exactOPDBID) {
        score = maxOf(score, 1300)
    }

    if (catalogID != null) {
        if (gameOPDBID == catalogID) score = maxOf(score, 1200)
        if (gameOPDBGroupID == catalogID) score = maxOf(score, 1150)
        if (gamePracticeIdentity == catalogID) score = maxOf(score, 1100)
    }

    if (allowGroupFallback && catalogGroupID != null) {
        if (gameOPDBGroupID == catalogGroupID) score = maxOf(score, 1125)
        if (gameOPDBID == catalogGroupID) score = maxOf(score, 1075)
    }

    if (canonicalPracticeIdentity != null) {
        if (gamePracticeIdentity == canonicalPracticeIdentity) score = maxOf(score, 1050)
        if (gameOPDBID == canonicalPracticeIdentity) score = maxOf(score, 1000)
        if (gameOPDBGroupID == canonicalPracticeIdentity) score = maxOf(score, 1000)
    }

    return score
}

private fun visualTemplateScore(game: PinballGame, machineVariant: String?): Int {
    val normalizedTemplateVariant = normalizedGameRoomVariant(game.normalizedVariant)
    var score = 0
    if (machineVariant == normalizedTemplateVariant) {
        score += 100
    } else if (machineVariant == null && normalizedTemplateVariant == null) {
        score += 80
    } else if (machineVariant == null) {
        score += 20
    }
    if (!game.playfieldImageUrl.isNullOrBlank() || !game.primaryImageUrl.isNullOrBlank()) {
        score += 20
    }
    return score
}

private fun contentTemplateScore(game: PinballGame): Int {
    var score = 0
    if (game.hasRulesheetResource || game.rulesheetLinks.isNotEmpty()) {
        score += 40
    }
    if (game.videos.isNotEmpty()) {
        score += 30
    }
    if (!game.gameinfoLocal.isNullOrBlank()) {
        score += 10
    }
    return score
}

private fun bestOPDBMediaRecord(
    ownedMachine: OwnedMachine,
    mediaIndex: Map<String, List<CatalogMachineRecord>>,
): CatalogMachineRecord? {
    val normalizedCatalogID = normalizedGameRoomID(ownedMachine.catalogGameID)
    val normalizedCatalogGroup = normalizedGroupFromOpdbID(ownedMachine.catalogGameID)
    val normalizedPracticeIdentity = normalizedGameRoomID(ownedMachine.canonicalPracticeIdentity)
    val allowGroupFallback = allowsSharedGameRoomGroupFallback(
        catalogID = normalizedCatalogID,
        catalogGroupID = normalizedCatalogGroup,
        canonicalPracticeIdentity = normalizedPracticeIdentity,
    )
    val keys = listOfNotNull(
        normalizedGameRoomID(ownedMachine.opdbID),
        normalizedCatalogID,
        normalizedPracticeIdentity,
        if (allowGroupFallback) normalizedCatalogGroup else null,
    ).distinct()
    val candidates = keys.flatMap { mediaIndex[it].orEmpty() }
    if (candidates.isEmpty()) return null

    val normalizedMachineVariant = normalizedGameRoomVariant(ownedMachine.displayVariant)
    if (normalizedMachineVariant != null) {
        val variantMatches = candidates
            .filter { opdbVariantMatchScore(it.variant, normalizedMachineVariant) > 0 }
            .sortedWith { lhs, rhs ->
                val lhsScore = opdbVariantMatchScore(lhs.variant, normalizedMachineVariant)
                val rhsScore = opdbVariantMatchScore(rhs.variant, normalizedMachineVariant)
                when {
                    lhsScore != rhsScore -> rhsScore.compareTo(lhsScore)
                    opdbRecordHasPrimaryImage(lhs) != opdbRecordHasPrimaryImage(rhs) ->
                        if (opdbRecordHasPrimaryImage(lhs)) -1 else 1
                    (lhs.year ?: Int.MAX_VALUE) != (rhs.year ?: Int.MAX_VALUE) ->
                        (lhs.year ?: Int.MAX_VALUE).compareTo(rhs.year ?: Int.MAX_VALUE)
                    else -> lhs.practiceIdentity.compareTo(rhs.practiceIdentity)
                }
            }
        variantMatches.firstOrNull(::opdbRecordHasPrimaryImage)?.let { return it }
    }

    candidates
        .filter(::opdbRecordHasPrimaryImage)
        .sortedWith(
            compareByDescending<CatalogMachineRecord> { opdbMediaScore(it, machineVariant = null) }
                .thenBy { it.year ?: Int.MAX_VALUE }
                .thenBy { it.practiceIdentity },
        )
        .firstOrNull()
        ?.let { return it }

    return candidates
        .sortedWith(
            compareByDescending<CatalogMachineRecord> { opdbMediaScore(it, machineVariant = normalizedMachineVariant) }
                .thenBy { it.year ?: Int.MAX_VALUE }
                .thenBy { it.practiceIdentity },
        )
        .firstOrNull()
}

private fun opdbMediaScore(
    machine: CatalogMachineRecord,
    machineVariant: String?,
): Int {
    val recordVariant = normalizedGameRoomVariant(machine.variant)
    var score = 0

    if (machineVariant != null) {
        score += opdbVariantMatchScore(machine.variant, machineVariant)
    } else if (recordVariant == null) {
        score += 140
    } else {
        score += variantPreferenceScore(recordVariant)
    }

    if (opdbRecordHasPrimaryImage(machine)) {
        score += 20
    }

    return score
}

private fun opdbVariantMatchScore(
    recordVariant: String?,
    requestedVariant: String,
): Int {
    val normalizedRecordVariant = normalizedGameRoomVariant(recordVariant).orEmpty()
    if (normalizedRecordVariant.isEmpty()) return 0
    if (normalizedRecordVariant == requestedVariant) return 200

    val recordTokens = normalizedRecordVariant
        .split(Regex("[^A-Za-z0-9]+"))
        .filter { it.isNotBlank() }
        .toSet()
    val requestTokens = requestedVariant
        .split(Regex("[^A-Za-z0-9]+"))
        .filter { it.isNotBlank() }
        .toSet()
    val sharedTokens = recordTokens.intersect(requestTokens)
    if (sharedTokens.isNotEmpty()) {
        var score = 100 + (sharedTokens.size * 20)
        if ("anniversary" in sharedTokens) score += 200
        if (sharedTokens.any { it.endsWith("th") || it.all(Char::isDigit) }) score += 120
        if ("premium" in sharedTokens) score += 40
        if ("le" in sharedTokens) score += 40
        return score
    }
    if (normalizedRecordVariant.contains(requestedVariant) || requestedVariant.contains(normalizedRecordVariant)) return 80
    if (requestedVariant.contains("premium") && normalizedRecordVariant == "le") return 70
    return 0
}

private fun opdbRecordHasPrimaryImage(machine: CatalogMachineRecord): Boolean =
    machine.primaryImageLargeUrl != null || machine.primaryImageMediumUrl != null

private fun variantPreferenceScore(normalizedVariant: String?): Int {
    if (normalizedVariant == null) return 120
    return when {
        normalizedVariant == "premium" || normalizedVariant.contains("premium") -> 110
        normalizedVariant == "le" || normalizedVariant.contains("limited") -> 100
        normalizedVariant == "pro" || normalizedVariant.contains("pro") -> 90
        normalizedVariant.contains("anniversary") -> 20
        else -> 60
    }
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

private fun normalizedGameRoomVariant(raw: String?): String? =
    raw?.trim()?.takeIf { it.isNotEmpty() }?.lowercase()

private fun normalizedGameRoomID(raw: String?): String? =
    raw?.trim()?.takeIf { it.isNotEmpty() }?.lowercase()

private fun normalizedGroupFromOpdbID(raw: String?): String? {
    val normalized = normalizedGameRoomID(raw) ?: return null
    if (!normalized.startsWith("g")) return null
    val dashIndex = normalized.indexOf('-')
    return if (dashIndex == -1) normalized else normalized.substring(0, dashIndex).ifBlank { null }
}

private fun allowsSharedGameRoomGroupFallback(
    catalogID: String?,
    catalogGroupID: String?,
    canonicalPracticeIdentity: String?,
): Boolean {
    if (catalogID != null && catalogGroupID != null && catalogID != catalogGroupID) {
        return false
    }
    val canonicalGroup = normalizedGroupFromOpdbID(canonicalPracticeIdentity)
    if (canonicalPracticeIdentity != null && canonicalGroup != null && canonicalPracticeIdentity != canonicalGroup) {
        return false
    }
    return true
}

private fun slugForLibraryGame(title: String, fallback: String): String {
    val slugified = title
        .trim()
        .lowercase()
        .replace("&", "and")
        .replace(Regex("[^a-z0-9]+"), "-")
        .trim('-')
    if (slugified.isNotEmpty()) return slugified
    return fallback
        .trim()
        .lowercase()
        .replace(Regex("[^a-z0-9]+"), "-")
        .trim('-')
}

internal fun resolveLegacyGame(
    legacyGame: PinballGame,
    curatedOverridesByPracticeIdentity: Map<String, LegacyCuratedOverride>,
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
    val curatedOverride = curatedOverrideForKeys(
        practiceIdentity = practiceIdentity,
        opdbGroupId = legacyGame.opdbGroupId ?: machine.opdbGroupId,
        overridesByKey = curatedOverridesByPracticeIdentity,
    )
    val manufacturerName = normalizedOptionalString(legacyGame.manufacturer)
        ?: machine.manufacturerName
        ?: machine.manufacturerId?.let { manufacturerById[it]?.name }

    val hasCuratedRulesheet = !legacyGame.rulesheetLocal.isNullOrBlank() || legacyGame.rulesheetLinks.isNotEmpty() || !legacyGame.rulesheetUrl.isNullOrBlank()
    val hasCuratedVideos = legacyGame.videos.isNotEmpty()
    val playfieldLocalPath = normalizedOptionalString(legacyGame.playfieldLocalOriginal ?: legacyGame.playfieldLocal)
        ?: normalizedOptionalString(curatedOverride?.playfieldLocalPath)
    val curatedPlayfieldImageUrl = normalizedOptionalString(curatedOverride?.playfieldSourceUrl)
        ?: preferredLegacyPlayfieldOverride(legacyGame)
    val hasCuratedPlayfield = playfieldLocalPath != null || curatedPlayfieldImageUrl != null
    val opdbPlayfieldImageUrl = normalizedOptionalString(machine.playfieldImageLargeUrl ?: machine.playfieldImageMediumUrl)

    val resolvedCatalogRulesheets = resolveRulesheetLinks(opdbRulesheetsByPracticeIdentity[practiceIdentity].orEmpty())
    val resolvedRulesheets = if (hasCuratedRulesheet) {
        val primaryLinks = when {
            legacyGame.rulesheetLinks.isNotEmpty() -> legacyGame.rulesheetLinks
            !legacyGame.rulesheetUrl.isNullOrBlank() -> listOf(ReferenceLink(label = "Rulesheet", url = legacyGame.rulesheetUrl))
            else -> emptyList()
        }.filterNot { link ->
            !legacyGame.rulesheetLocal.isNullOrBlank() && shouldSuppressLocalMarkdownRulesheetLink(link)
        }
        mergeRulesheetLinks(
            primaryLinks,
            resolvedCatalogRulesheets.links,
        )
    } else {
        resolvedCatalogRulesheets.links
    }
    val rulesheetLocalPath = if (hasCuratedRulesheet) {
        normalizedOptionalString(legacyGame.rulesheetLocal)
            ?.takeUnless { shouldSuppressLocalRulesheetPath(resolvedRulesheets) }
    } else {
        resolvedCatalogRulesheets.localPath
    }
    val resolvedVideos = mergeResolvedVideos(
        primary = if (hasCuratedVideos) legacyGame.videos else emptyList(),
        secondary = resolveVideoLinks(opdbVideosByPracticeIdentity[practiceIdentity].orEmpty()),
    )
    val playfieldImageUrl = if (hasCuratedPlayfield) {
        curatedPlayfieldImageUrl
    } else {
        opdbPlayfieldImageUrl
    }

    return legacyGame.copy(
        practiceIdentity = practiceIdentity,
        opdbId = normalizedOptionalString(legacyGame.opdbId) ?: normalizedOptionalString(machine.opdbMachineId),
        name = normalizedOptionalString(curatedOverride?.nameOverride)
            ?: resolvedCatalogDisplayTitle(title = machine.name, explicitVariant = machine.variant),
        variant = normalizedOptionalString(legacyGame.normalizedVariant ?: machine.variant),
        manufacturer = normalizedOptionalString(manufacturerName),
        year = legacyGame.year ?: machine.year,
        primaryImageUrl = normalizedOptionalString(machine.primaryImageMediumUrl),
        primaryImageLargeUrl = normalizedOptionalString(machine.primaryImageLargeUrl),
        playfieldImageUrl = playfieldImageUrl,
        alternatePlayfieldImageUrl = if (hasCuratedPlayfield) opdbPlayfieldImageUrl else null,
        playfieldLocalOriginal = normalizeLibraryCachePath(playfieldLocalPath),
        playfieldLocal = normalizeLibraryPlayfieldLocalPath(playfieldLocalPath),
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
        if (!isImportedPinballMapSourceId(game.sourceId)) {
            current.nameOverride = current.nameOverride ?: preferredLegacyNameOverride(game)
            current.variantOverride = current.variantOverride ?: normalizedOptionalString(game.normalizedVariant)
            current.manufacturerOverride = current.manufacturerOverride ?: normalizedOptionalString(game.manufacturer)
            current.yearOverride = current.yearOverride ?: game.year
        }
        current.playfieldLocalPath = current.playfieldLocalPath ?: normalizedOptionalString(game.playfieldLocalOriginal ?: game.playfieldLocal)
        current.playfieldSourceUrl = current.playfieldSourceUrl ?: preferredLegacyPlayfieldOverride(game)
        current.gameinfoLocalPath = current.gameinfoLocalPath ?: normalizedOptionalString(game.gameinfoLocal)
        current.rulesheetLocalPath = current.rulesheetLocalPath ?: normalizedOptionalString(game.rulesheetLocal)
        if (current.rulesheetLinks.isEmpty()) {
            val hasLocalRulesheetPath = !game.rulesheetLocal.isNullOrBlank()
            current.rulesheetLinks = when {
                isImportedPinballMapSourceId(game.sourceId) -> emptyList()
                game.rulesheetLinks.isNotEmpty() -> game.rulesheetLinks.filterNot { link ->
                    hasLocalRulesheetPath && shouldSuppressLocalMarkdownRulesheetLink(link)
                }
                !game.rulesheetUrl.isNullOrBlank() -> listOf(ReferenceLink(label = "Rulesheet", url = game.rulesheetUrl)).filterNot { link ->
                    hasLocalRulesheetPath && shouldSuppressLocalMarkdownRulesheetLink(link)
                }
                else -> emptyList()
            }
        }
        if (current.videos.isEmpty() && game.videos.isNotEmpty()) {
            current.videos = game.videos
        }
    }
    return out
}

private fun preferredLegacyNameOverride(game: PinballGame): String? {
    val name = normalizedOptionalString(game.name) ?: return null
    return when {
        game.sourceId == BUILTIN_GAME_ROOM_LIBRARY_SOURCE_ID -> name
        game.sourceType.name != "VENUE" -> name
        name.contains(":") -> name
        else -> null
    }
}

private fun preferredLegacyPlayfieldOverride(game: PinballGame): String? {
    val playfieldUrl = normalizedOptionalString(game.playfieldImageUrl) ?: return null
    return playfieldUrl.takeIf(::isPinProfPlayfieldUrl)
}

private fun parsePublicLibraryOverrides(raw: String?): PublicLibraryOverridesRoot {
    if (raw.isNullOrBlank()) return PublicLibraryOverridesRoot()
    val root = runCatching { JSONObject(raw.trim()) }.getOrDefault(JSONObject())
    val playfieldOverrides = root.optJSONArray("playfieldOverrides")
        ?.let { array ->
            buildList {
                for (index in 0 until array.length()) {
                    val obj = array.optJSONObject(index) ?: continue
                    val practiceIdentity = obj.optStringOrNullLocal("practiceIdentity") ?: continue
                    val playfieldLocalPath = obj.optStringOrNullLocal("playfieldLocalPath")
                    val playfieldSourceUrl = obj.optStringOrNullLocal("playfieldSourceUrl")
                    if (playfieldLocalPath == null && playfieldSourceUrl == null) continue
                    add(
                        PublicLibraryPlayfieldOverrideRecord(
                            practiceIdentity = practiceIdentity,
                            opdbGroupId = obj.optStringOrNullLocal("opdbGroupId"),
                            playfieldLocalPath = playfieldLocalPath,
                            playfieldSourceUrl = playfieldSourceUrl,
                        ),
                    )
                }
            }
        }
        .orEmpty()
    return PublicLibraryOverridesRoot(playfieldOverrides = playfieldOverrides)
}

private fun parseVenueMetadataOverlays(raw: String?): VenueMetadataOverlayIndex {
    if (raw.isNullOrBlank()) return VenueMetadataOverlayIndex()
    val root = runCatching { JSONObject(raw.trim()) }.getOrDefault(JSONObject())

    val areaOrderByKey = buildMap {
        val array = root.optJSONArray("layout_areas") ?: return@buildMap
        for (index in 0 until array.length()) {
            val obj = array.optJSONObject(index) ?: continue
            val sourceId = obj.optStringOrNullLocal("source_id") ?: continue
            val area = obj.optStringOrNullLocal("area") ?: continue
            val areaOrder = if (obj.has("area_order") && !obj.isNull("area_order")) obj.optInt("area_order") else continue
            put(venueOverlayAreaKey(sourceId, area), areaOrder)
        }
    }

    val machineLayoutByKey = buildMap {
        val array = root.optJSONArray("machine_layout") ?: return@buildMap
        for (index in 0 until array.length()) {
            val obj = array.optJSONObject(index) ?: continue
            val sourceId = obj.optStringOrNullLocal("source_id") ?: continue
            val opdbId = obj.optStringOrNullLocal("opdb_id") ?: continue
            put(
                venueOverlayMachineKey(sourceId, opdbId),
                VenueMachineLayoutOverlayRecord(
                    sourceId = sourceId,
                    opdbId = opdbId,
                    area = obj.optStringOrNullLocal("area"),
                    groupNumber = if (obj.has("group_number") && !obj.isNull("group_number")) obj.optInt("group_number") else null,
                    position = if (obj.has("position") && !obj.isNull("position")) obj.optInt("position") else null,
                ),
            )
        }
    }

    val machineBankByKey = buildMap {
        val array = root.optJSONArray("machine_bank") ?: return@buildMap
        for (index in 0 until array.length()) {
            val obj = array.optJSONObject(index) ?: continue
            val sourceId = obj.optStringOrNullLocal("source_id") ?: continue
            val opdbId = obj.optStringOrNullLocal("opdb_id") ?: continue
            if (!obj.has("bank") || obj.isNull("bank")) continue
            put(
                venueOverlayMachineKey(sourceId, opdbId),
                VenueMachineBankOverlayRecord(
                    sourceId = sourceId,
                    opdbId = opdbId,
                    bank = obj.optInt("bank"),
                ),
            )
        }
    }

    return VenueMetadataOverlayIndex(
        areaOrderByKey = areaOrderByKey,
        machineLayoutByKey = machineLayoutByKey,
        machineBankByKey = machineBankByKey,
    )
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

private fun applyPublicPlayfieldOverrides(
    curatedOverridesByPracticeIdentity: MutableMap<String, LegacyCuratedOverride>,
    publicOverrides: PublicLibraryOverridesRoot,
) {
    publicOverrides.playfieldOverrides.forEach { override ->
        val practiceIdentity = normalizedOptionalString(override.practiceIdentity) ?: return@forEach
        val playfieldLocalPath = normalizedOptionalString(override.playfieldLocalPath)
        val playfieldSourceUrl = normalizedOptionalString(override.playfieldSourceUrl)
        if (playfieldLocalPath == null && playfieldSourceUrl == null) return@forEach
        val opdbGroupId = normalizedOptionalString(override.opdbGroupId)

        listOfNotNull(practiceIdentity, opdbGroupId).forEach { key ->
            val current = curatedOverridesByPracticeIdentity[key]
                ?: LegacyCuratedOverride(practiceIdentity = key)
            current.playfieldLocalPath = playfieldLocalPath
            if (playfieldSourceUrl != null) {
                current.playfieldSourceUrl = playfieldSourceUrl
            }
            curatedOverridesByPracticeIdentity[key] = current
        }
    }
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
                    variant = resolvedCatalogVariantLabel(
                        title = name,
                        explicitVariant = obj.optStringOrNullLocal("variant"),
                    ),
                    manufacturerId = obj.optStringOrNullLocal("manufacturer_id"),
                    manufacturerName = obj.optStringOrNullLocal("manufacturer_name"),
                    year = obj.optIntOrNullLocal("year"),
                    opdbName = obj.optStringOrNullLocal("opdb_name"),
                    opdbCommonName = obj.optStringOrNullLocal("opdb_common_name"),
                    opdbShortname = obj.optStringOrNullLocal("opdb_shortname"),
                    opdbDescription = obj.optStringOrNullLocal("opdb_description"),
                    opdbType = obj.optStringOrNullLocal("opdb_type"),
                    opdbDisplay = obj.optStringOrNullLocal("opdb_display"),
                    opdbPlayerCount = obj.optIntOrNullLocal("opdb_player_count"),
                    opdbManufactureDate = obj.optStringOrNullLocal("opdb_manufacture_date"),
                    opdbIpdbId = obj.optIntOrNullLocal("opdb_ipdb_id"),
                    opdbGroupShortname = obj.optStringOrNullLocal("opdb_group_shortname"),
                    opdbGroupDescription = obj.optStringOrNullLocal("opdb_group_description"),
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
