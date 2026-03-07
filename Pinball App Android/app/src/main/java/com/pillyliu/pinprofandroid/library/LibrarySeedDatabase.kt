package com.pillyliu.pinprofandroid.library

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import com.pillyliu.pinprofandroid.gameroom.GameRoomArea
import com.pillyliu.pinprofandroid.gameroom.GameRoomStateCodec
import com.pillyliu.pinprofandroid.gameroom.GameRoomStore
import com.pillyliu.pinprofandroid.gameroom.OwnedMachine
import com.pillyliu.pinprofandroid.gameroom.OwnedMachineStatus
import java.io.File
import java.security.MessageDigest
import org.json.JSONArray
import org.json.JSONObject

private const val GAME_ROOM_LIBRARY_SOURCE_ID = "venue--gameroom"

internal data class LegacyCatalogExtraction(
    val payload: ParsedLibraryData,
    val state: LibrarySourceState,
)

internal data class CatalogManufacturerOption(
    val id: String,
    val name: String,
    val gameCount: Int,
    val isModern: Boolean,
    val featuredRank: Int?,
    val sortBucket: Int,
)

internal object LibrarySeedDatabase {
    private const val SEED_FILE_NAME = "pinball_library_seed_v1.sqlite"
    private const val SEED_ASSET_PATH = "starter-pack/pinball/data/$SEED_FILE_NAME"

    suspend fun loadExtraction(context: Context): LegacyCatalogExtraction {
        val db = openDatabase(context)
        db.use { database ->
            val builtInSources = loadBuiltInSources(database)
            val builtInGames = loadBuiltInGames(database)
            val importedSources = ImportedSourcesStore.load(context)
            val importedGames = loadImportedGames(database, importedSources)
            val payload = ParsedLibraryData(
                games = builtInGames + importedGames,
                sources = dedupedSources(
                    builtInSources + importedSources.map { source ->
                        LibrarySource(id = source.id, name = source.name, type = source.type)
                    },
                ),
            )
            val payloadWithGameRoom = addGameRoomOverlay(context = context, basePayload = payload)
            val state = LibrarySourceStateStore.synchronize(context, payloadWithGameRoom.sources)
            return LegacyCatalogExtraction(
                payload = filterPayload(payloadWithGameRoom, state),
                state = state,
            )
        }
    }

    suspend fun loadManufacturerOptions(context: Context): List<CatalogManufacturerOption> {
        val db = openDatabase(context)
        db.use { database ->
            database.rawQuery(
                """
                SELECT
                    manufacturers.id,
                    manufacturers.name,
                    COUNT(DISTINCT COALESCE(machines.opdb_group_id, machines.practice_identity)) AS group_count,
                    manufacturers.is_modern,
                    manufacturers.featured_rank,
                    manufacturers.sort_bucket
                FROM manufacturers
                LEFT JOIN machines ON machines.manufacturer_id = manufacturers.id
                GROUP BY manufacturers.id, manufacturers.name, manufacturers.is_modern, manufacturers.featured_rank, manufacturers.sort_bucket
                ORDER BY sort_bucket ASC, COALESCE(featured_rank, 9999) ASC, sort_name ASC
                """.trimIndent(),
                emptyArray(),
            ).use { cursor ->
                return buildList {
                    while (cursor.moveToNext()) {
                        add(
                            CatalogManufacturerOption(
                                id = cursor.getString(0).orEmpty(),
                                name = cursor.getString(1).orEmpty(),
                                gameCount = cursor.getInt(2),
                                isModern = cursor.getInt(3) > 0,
                                featuredRank = cursor.getIntOrNull(4),
                                sortBucket = cursor.getInt(5),
                            ),
                        )
                    }
                }
            }
        }
    }

    private suspend fun openDatabase(context: Context): SQLiteDatabase {
        val file = ensureDatabaseReady(context)
        return SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)
    }

    private suspend fun ensureDatabaseReady(context: Context): File {
        val dir = File(context.filesDir, "pinball-seed-db")
        if (!dir.exists()) dir.mkdirs()
        val target = File(dir, SEED_FILE_NAME)
        val bytes = context.assets.open(SEED_ASSET_PATH).use { it.readBytes() }
        if (!target.exists() || target.sha256Hex() != bytes.sha256Hex()) {
            target.writeBytes(bytes)
        }
        return target
    }

    private fun File.sha256Hex(): String {
        if (!exists()) return ""
        return readBytes().sha256Hex()
    }

    private fun ByteArray.sha256Hex(): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(this)
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
    }

    private fun loadBuiltInSources(database: SQLiteDatabase): List<LibrarySource> {
        database.rawQuery(
            "SELECT id, name, type FROM built_in_sources ORDER BY sort_rank ASC",
            emptyArray(),
        ).use { cursor ->
            return buildList {
                while (cursor.moveToNext()) {
                    add(
                        LibrarySource(
                            id = cursor.getString(0).orEmpty(),
                            name = cursor.getString(1).orEmpty(),
                            type = LibrarySourceType.fromRaw(cursor.getString(2)) ?: LibrarySourceType.VENUE,
                        ),
                    )
                }
            }
        }
    }

    private fun loadBuiltInGames(database: SQLiteDatabase): List<PinballGame> {
        val rulesheetsByEntry = loadBuiltInRulesheets(database)
        val videosByEntry = loadBuiltInVideos(database)
        val machineById = loadMachinesById(database)
        val machinesByPracticeIdentity = machineById.values.groupBy { it.practiceIdentity }
        val machinesByOpdbId = machineById
        database.rawQuery(
            """
            SELECT
                library_entry_id, source_id, source_name, source_type, practice_identity, opdb_id,
                area, area_order, group_number, position, bank, name, variant, manufacturer, year, slug,
                primary_image_url, primary_image_large_url, playfield_image_url, playfield_local_path,
                playfield_source_label, gameinfo_local_path, rulesheet_local_path, rulesheet_url
            FROM built_in_games
            ORDER BY source_name ASC, COALESCE(area_order, 9999) ASC, COALESCE(group_number, 9999) ASC, COALESCE(position, 9999) ASC, name ASC
            """.trimIndent(),
            emptyArray(),
        ).use { cursor ->
            return buildList {
                while (cursor.moveToNext()) {
                    val libraryEntryId = cursor.getString(0).orEmpty()
                    val practiceIdentity = cursor.getNullableString(4)
                        ?: cursor.getNullableString(5)?.substringBefore('-')
                        ?: libraryEntryId
                    val resolvedMachine = preferredSeedMachineForBuiltInGame(
                        requestedMachineId = cursor.getNullableString(5),
                        practiceIdentity = practiceIdentity,
                        machinesByPracticeIdentity = machinesByPracticeIdentity,
                        machinesByOpdbId = machinesByOpdbId,
                    )
                    add(
                        PinballGame(
                            libraryEntryId = libraryEntryId,
                            practiceIdentity = practiceIdentity,
                            opdbId = cursor.getNullableString(5),
                            opdbGroupId = practiceIdentity,
                            variant = cursor.getNullableString(12),
                            sourceId = cursor.getString(1).orEmpty(),
                            sourceName = cursor.getString(2).orEmpty(),
                            sourceType = LibrarySourceType.fromRaw(cursor.getString(3)) ?: LibrarySourceType.VENUE,
                            area = cursor.getNullableString(6),
                            areaOrder = cursor.getIntOrNull(7),
                            group = cursor.getIntOrNull(8),
                            position = cursor.getIntOrNull(9),
                            bank = cursor.getIntOrNull(10),
                            name = cursor.getString(11).orEmpty(),
                            manufacturer = cursor.getNullableString(13),
                            year = cursor.getIntOrNull(14),
                            slug = cursor.getString(15).orEmpty(),
                            primaryImageUrl = cursor.getNullableString(16) ?: resolvedMachine?.primaryImageMediumUrl,
                            primaryImageLargeUrl = cursor.getNullableString(17) ?: resolvedMachine?.primaryImageLargeUrl,
                            playfieldImageUrl = cursor.getNullableString(18),
                            playfieldLocalOriginal = normalizeCachePath(cursor.getNullableString(19)),
                            playfieldLocal = normalizePlayfieldLocalPath(cursor.getNullableString(19)),
                            playfieldSourceLabel = cursor.getNullableString(20),
                            gameinfoLocal = cursor.getNullableString(21),
                            rulesheetLocal = cursor.getNullableString(22),
                            rulesheetUrl = cursor.getNullableString(23),
                            rulesheetLinks = rulesheetsByEntry[libraryEntryId].orEmpty(),
                            videos = videosByEntry[libraryEntryId].orEmpty(),
                        ),
                    )
                }
            }
        }
    }

    private fun loadBuiltInRulesheets(database: SQLiteDatabase): Map<String, List<ReferenceLink>> {
        database.rawQuery(
            "SELECT library_entry_id, label, url FROM built_in_rulesheet_links ORDER BY library_entry_id ASC, priority ASC",
            emptyArray(),
        ).use { cursor ->
            val out = linkedMapOf<String, MutableList<ReferenceLink>>()
            while (cursor.moveToNext()) {
                val entryId = cursor.getString(0).orEmpty()
                val label = cursor.getString(1).orEmpty()
                val url = cursor.getNullableString(2) ?: continue
                out.getOrPut(entryId) { mutableListOf() }.add(ReferenceLink(label = label, url = url))
            }
            return out.mapValues { (_, links) -> dedupeRulesheetLinks(links) }
        }
    }

    private fun loadBuiltInVideos(database: SQLiteDatabase): Map<String, List<Video>> {
        database.rawQuery(
            "SELECT library_entry_id, kind, label, url FROM built_in_videos ORDER BY library_entry_id ASC, priority ASC",
            emptyArray(),
        ).use { cursor ->
            val out = linkedMapOf<String, MutableList<Video>>()
            while (cursor.moveToNext()) {
                val entryId = cursor.getString(0).orEmpty()
                out.getOrPut(entryId) { mutableListOf() }.add(
                    Video(
                        kind = cursor.getNullableString(1),
                        label = cursor.getNullableString(2),
                        url = cursor.getNullableString(3),
                    ),
                )
            }
            return out
        }
    }

    private fun loadImportedGames(
        database: SQLiteDatabase,
        importedSources: List<ImportedSourceRecord>,
    ): List<PinballGame> {
        if (importedSources.isEmpty()) return emptyList()
        val manufacturersById = loadManufacturers(database).mapValues { (_, row) -> row.toCatalogManufacturerRecord() }
        val overridesByPracticeIdentity = loadOverrides(database)
        val overrideRulesheets = loadOverrideRulesheets(database)
        val catalogRulesheets = loadCatalogRulesheetRecords(database)
        val overrideVideos = loadOverrideVideos(database)
        val catalogVideos = loadCatalogVideoRecords(database)
        val machineById = loadMachinesById(database)
        val catalogMachineById = machineById.mapValues { (_, machine) -> machine.toCatalogMachineRecord() }
        val catalogMachines = catalogMachineById.values.toList()
        val groupedByPracticeIdentity = catalogMachines.groupBy { it.practiceIdentity }

        val out = mutableListOf<PinballGame>()
        importedSources.forEach { source ->
            when (source.type) {
                LibrarySourceType.MANUFACTURER -> {
                    val grouped = catalogMachines
                        .filter { it.manufacturerId == source.providerSourceId }
                        .groupBy { it.opdbGroupId ?: it.practiceIdentity }
                    grouped.values
                        .mapNotNull { machines -> machines.minWithOrNull(::comparePreferredMachine) }
                        .sortedWith(compareBy<CatalogMachineRecord> { it.year ?: Int.MAX_VALUE }.thenBy { it.name.lowercase() })
                        .forEach { machine ->
                            out += resolveImportedGame(
                                machine = machine,
                                source = source,
                                manufacturerById = manufacturersById,
                                curatedOverride = overridesByPracticeIdentity[machine.practiceIdentity]?.toLegacyCuratedOverride(
                                    rulesheetLinks = overrideRulesheets[machine.practiceIdentity].orEmpty(),
                                    videos = overrideVideos[machine.practiceIdentity].orEmpty(),
                                ),
                                opdbRulesheets = catalogRulesheets[machine.practiceIdentity].orEmpty(),
                                opdbVideos = catalogVideos[machine.practiceIdentity].orEmpty(),
                            )
                        }
                }

                LibrarySourceType.VENUE,
                LibrarySourceType.TOURNAMENT -> {
                    source.machineIds.forEach { machineId ->
                        val preferred = preferredMachineForSourceLookup(
                            requestedMachineId = machineId,
                            machineByOpdbId = catalogMachineById,
                            machineByPracticeIdentity = groupedByPracticeIdentity,
                        )
                            ?: return@forEach
                        out += resolveImportedGame(
                            machine = preferred,
                            source = source,
                            manufacturerById = manufacturersById,
                            curatedOverride = overridesByPracticeIdentity[preferred.practiceIdentity]?.toLegacyCuratedOverride(
                                rulesheetLinks = overrideRulesheets[preferred.practiceIdentity].orEmpty(),
                                videos = overrideVideos[preferred.practiceIdentity].orEmpty(),
                            ),
                            opdbRulesheets = catalogRulesheets[preferred.practiceIdentity].orEmpty(),
                            opdbVideos = catalogVideos[preferred.practiceIdentity].orEmpty(),
                        )
                    }
                }

                LibrarySourceType.CATEGORY -> Unit
            }
        }
        return out
    }

    private fun loadManufacturers(database: SQLiteDatabase): Map<String, SeedManufacturer> {
        database.rawQuery("SELECT id, name FROM manufacturers", emptyArray()).use { cursor ->
            val out = linkedMapOf<String, SeedManufacturer>()
            while (cursor.moveToNext()) {
                out[cursor.getString(0)] = SeedManufacturer(
                    id = cursor.getString(0),
                    name = cursor.getString(1),
                )
            }
            return out
        }
    }

    private fun loadOverrides(database: SQLiteDatabase): Map<String, SeedOverride> {
        database.rawQuery(
            """
            SELECT practice_identity, name_override, variant_override, manufacturer_override, year_override, playfield_local_path, playfield_source_url, gameinfo_local_path, rulesheet_local_path
            FROM overrides
            """.trimIndent(),
            emptyArray(),
        ).use { cursor ->
            val out = linkedMapOf<String, SeedOverride>()
            while (cursor.moveToNext()) {
                out[cursor.getString(0)] = SeedOverride(
                    practiceIdentity = cursor.getString(0),
                    nameOverride = cursor.getNullableString(1),
                    variantOverride = cursor.getNullableString(2),
                    manufacturerOverride = cursor.getNullableString(3),
                    yearOverride = cursor.getIntOrNull(4),
                    playfieldLocalPath = cursor.getNullableString(5),
                    playfieldSourceUrl = cursor.getNullableString(6),
                    gameinfoLocalPath = cursor.getNullableString(7),
                    rulesheetLocalPath = cursor.getNullableString(8),
                )
            }
            return out
        }
    }

    private fun loadMachinesById(database: SQLiteDatabase): Map<String, SeedMachine> {
        database.rawQuery(
            """
            SELECT opdb_machine_id, practice_identity, opdb_group_id, slug, name, variant, manufacturer_id, manufacturer_name, year,
                   primary_image_medium_url, primary_image_large_url, playfield_image_medium_url, playfield_image_large_url
            FROM machines
            """.trimIndent(),
            emptyArray(),
        ).use { cursor ->
            val out = linkedMapOf<String, SeedMachine>()
            while (cursor.moveToNext()) {
                val machine = SeedMachine(
                    opdbMachineId = cursor.getString(0),
                    practiceIdentity = cursor.getString(1),
                    opdbGroupId = cursor.getNullableString(2),
                    slug = cursor.getString(3),
                    name = cursor.getString(4),
                    variant = cursor.getNullableString(5),
                    manufacturerId = cursor.getNullableString(6),
                    manufacturerName = cursor.getNullableString(7),
                    year = cursor.getIntOrNull(8),
                    primaryImageMediumUrl = cursor.getNullableString(9),
                    primaryImageLargeUrl = cursor.getNullableString(10),
                    playfieldMediumUrl = cursor.getNullableString(11),
                    playfieldLargeUrl = cursor.getNullableString(12),
                )
                out[machine.opdbMachineId] = machine
            }
            return out
        }
    }

    private fun preferredSeedMachineForBuiltInGame(
        requestedMachineId: String?,
        practiceIdentity: String,
        machinesByPracticeIdentity: Map<String, List<SeedMachine>>,
        machinesByOpdbId: Map<String, SeedMachine>,
    ): SeedMachine? {
        val preferredGroupMachine = preferredSeedGroupMachine(machinesByPracticeIdentity[practiceIdentity].orEmpty())
        val exactMachine = requestedMachineId?.let { machinesByOpdbId[it] } ?: return preferredGroupMachine
        if (seedMachineHasPrimaryImage(exactMachine)) return exactMachine
        val preferredExactGroupMachine = preferredSeedGroupMachine(machinesByPracticeIdentity[exactMachine.practiceIdentity].orEmpty())
        return preferredExactGroupMachine ?: preferredGroupMachine ?: exactMachine
    }

    private fun loadOverrideRulesheets(database: SQLiteDatabase): Map<String, List<ReferenceLink>> =
        loadRulesheetLinks(database, "override_rulesheet_links")

    private fun loadCatalogRulesheets(database: SQLiteDatabase): Map<String, List<ReferenceLink>> =
        loadRulesheetLinks(database, "catalog_rulesheet_links")

    private fun loadCatalogRulesheetRecords(database: SQLiteDatabase): Map<String, List<CatalogRulesheetLinkRecord>> {
        database.rawQuery(
            "SELECT practice_identity, provider, label, url, priority FROM catalog_rulesheet_links ORDER BY practice_identity ASC, priority ASC",
            emptyArray(),
        ).use { cursor ->
            val out = linkedMapOf<String, MutableList<CatalogRulesheetLinkRecord>>()
            while (cursor.moveToNext()) {
                val practiceIdentity = cursor.getString(0)
                out.getOrPut(practiceIdentity) { mutableListOf() }.add(
                    CatalogRulesheetLinkRecord(
                        practiceIdentity = practiceIdentity,
                        provider = cursor.getString(1).orEmpty(),
                        label = cursor.getNullableString(2) ?: "Rulesheet",
                        url = cursor.getNullableString(3),
                        localPath = null,
                        priority = cursor.getIntOrNull(4),
                    ),
                )
            }
            return out
        }
    }

    private fun loadRulesheetLinks(database: SQLiteDatabase, tableName: String): Map<String, List<ReferenceLink>> {
        database.rawQuery(
            "SELECT practice_identity, label, url FROM $tableName ORDER BY practice_identity ASC, priority ASC",
            emptyArray(),
        ).use { cursor ->
            val out = linkedMapOf<String, MutableList<ReferenceLink>>()
            while (cursor.moveToNext()) {
                val practiceIdentity = cursor.getString(0)
                val label = cursor.getString(1)
                val url = cursor.getNullableString(2) ?: continue
                out.getOrPut(practiceIdentity) { mutableListOf() }.add(ReferenceLink(label = label, url = url))
            }
            return out.mapValues { (_, links) -> dedupeRulesheetLinks(links) }
        }
    }

    private fun loadOverrideVideos(database: SQLiteDatabase): Map<String, List<Video>> =
        loadVideos(database, "override_videos")

    private fun loadCatalogVideos(database: SQLiteDatabase): Map<String, List<Video>> =
        loadVideos(database, "catalog_video_links")

    private fun loadCatalogVideoRecords(database: SQLiteDatabase): Map<String, List<CatalogVideoLinkRecord>> {
        database.rawQuery(
            "SELECT practice_identity, kind, label, url, priority FROM catalog_video_links ORDER BY practice_identity ASC, priority ASC",
            emptyArray(),
        ).use { cursor ->
            val out = linkedMapOf<String, MutableList<CatalogVideoLinkRecord>>()
            while (cursor.moveToNext()) {
                val practiceIdentity = cursor.getString(0)
                val url = cursor.getNullableString(3) ?: continue
                out.getOrPut(practiceIdentity) { mutableListOf() }.add(
                    CatalogVideoLinkRecord(
                        practiceIdentity = practiceIdentity,
                        provider = "matchplay",
                        kind = cursor.getNullableString(1),
                        label = cursor.getNullableString(2) ?: "Tutorial 1",
                        url = url,
                        priority = cursor.getIntOrNull(4),
                    ),
                )
            }
            return out
        }
    }

    private fun loadVideos(database: SQLiteDatabase, tableName: String): Map<String, List<Video>> {
        database.rawQuery(
            "SELECT practice_identity, kind, label, url FROM $tableName ORDER BY practice_identity ASC, priority ASC",
            emptyArray(),
        ).use { cursor ->
            val out = linkedMapOf<String, MutableList<Video>>()
            while (cursor.moveToNext()) {
                val practiceIdentity = cursor.getString(0)
                out.getOrPut(practiceIdentity) { mutableListOf() }.add(
                    Video(
                        kind = cursor.getNullableString(1),
                        label = cursor.getNullableString(2),
                        url = cursor.getNullableString(3),
                    ),
                )
            }
            return out
        }
    }

    private fun addGameRoomOverlay(
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
                    playfieldLocalOriginal = normalizeCachePath(template?.playfieldLocalOriginal ?: template?.playfieldLocal),
                    playfieldLocal = normalizePlayfieldLocalPath(template?.playfieldLocalOriginal ?: template?.playfieldLocal),
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
        return baseGames.firstOrNull { game ->
            normalizedOptionalString(game.practiceIdentity) == normalizedPracticeIdentity ||
                normalizedOptionalString(game.opdbGroupId) == normalizedCatalogID ||
                game.name.trim().lowercase() == normalizedTitle
        }
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

    private fun normalizedOptionalString(value: String?): String? =
        value?.trim()?.takeIf { it.isNotBlank() }

    private data class DecodedSeedOverlayState(
        val venueName: String,
        val areas: List<GameRoomArea>,
        val ownedMachines: List<OwnedMachine>,
    )

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

    private fun filterPayload(payload: ParsedLibraryData, state: LibrarySourceState): ParsedLibraryData {
        val enabled = state.enabledSourceIds.toSet()
        val hasGameRoomGames = payload.games.any { it.sourceId == GAME_ROOM_LIBRARY_SOURCE_ID }
        val filteredSources = payload.sources.filter { source ->
            enabled.contains(source.id) || (source.id == GAME_ROOM_LIBRARY_SOURCE_ID && hasGameRoomGames)
        }
        val sourceIds = filteredSources.map { it.id }.toSet()
        return ParsedLibraryData(
            games = payload.games.filter { sourceIds.contains(it.sourceId) },
            sources = filteredSources,
        )
    }

    private fun dedupedSources(sources: List<LibrarySource>): List<LibrarySource> {
        val seen = linkedMapOf<String, LibrarySource>()
        sources.forEach { source ->
            if (!seen.containsKey(source.id)) {
                seen[source.id] = source
            }
        }
        return seen.values.toList()
    }
}

private data class SeedManufacturer(
    val id: String,
    val name: String,
)

private data class SeedMachine(
    val opdbMachineId: String,
    val practiceIdentity: String,
    val opdbGroupId: String?,
    val slug: String,
    val name: String,
    val variant: String?,
    val manufacturerId: String?,
    val manufacturerName: String?,
    val year: Int?,
    val primaryImageMediumUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldMediumUrl: String?,
    val playfieldLargeUrl: String?,
)

private data class SeedOverride(
    val practiceIdentity: String,
    val nameOverride: String?,
    val variantOverride: String?,
    val manufacturerOverride: String?,
    val yearOverride: Int?,
    val playfieldLocalPath: String?,
    val playfieldSourceUrl: String?,
    val gameinfoLocalPath: String?,
    val rulesheetLocalPath: String?,
)

private fun seedMachineHasPrimaryImage(machine: SeedMachine): Boolean =
    machine.primaryImageMediumUrl != null || machine.primaryImageLargeUrl != null

private fun preferredSeedGroupMachine(group: List<SeedMachine>): SeedMachine? =
    group.minWithOrNull(
        compareByDescending<SeedMachine> { seedMachineHasPrimaryImage(it) }
            .thenBy { it.variant != null }
            .thenBy { it.year ?: Int.MAX_VALUE }
            .thenBy { it.name.lowercase() }
            .thenBy { it.opdbMachineId },
    )

private fun dedupeRulesheetLinks(links: List<ReferenceLink>): List<ReferenceLink> {
    val grouped = linkedMapOf<String, MutableList<ReferenceLink>>()
    links.forEach { link ->
        grouped.getOrPut(link.label) { mutableListOf() }.add(link)
    }
    return grouped.values.mapNotNull { group ->
        group.minWithOrNull(
            compareBy<ReferenceLink> { if (isCanonicalTiltForumsLink(it.url)) 0 else 1 }
                .thenBy { if (it.url?.startsWith("https://") == true) 0 else 1 }
                .thenBy { it.url ?: "" },
        )
    }
}

private fun isCanonicalTiltForumsLink(url: String?): Boolean {
    val normalized = url?.lowercase() ?: return false
    return normalized.contains("tiltforums.com/t/") && !normalized.contains(".json")
}

private fun SeedManufacturer.toCatalogManufacturerRecord(): CatalogManufacturerRecord =
    CatalogManufacturerRecord(
        id = id,
        name = name,
    )

private fun SeedMachine.toCatalogMachineRecord(): CatalogMachineRecord =
    CatalogMachineRecord(
        practiceIdentity = practiceIdentity,
        opdbMachineId = opdbMachineId,
        opdbGroupId = opdbGroupId,
        slug = slug,
        name = name,
        variant = variant,
        manufacturerId = manufacturerId,
        manufacturerName = manufacturerName,
        year = year,
        primaryImageMediumUrl = primaryImageMediumUrl,
        primaryImageLargeUrl = primaryImageLargeUrl,
        playfieldImageMediumUrl = playfieldMediumUrl,
        playfieldImageLargeUrl = playfieldLargeUrl,
    )

private fun SeedOverride.toLegacyCuratedOverride(
    rulesheetLinks: List<ReferenceLink>,
    videos: List<Video>,
): LegacyCuratedOverride =
    LegacyCuratedOverride(
        practiceIdentity = practiceIdentity,
        nameOverride = nameOverride,
        variantOverride = variantOverride,
        manufacturerOverride = manufacturerOverride,
        yearOverride = yearOverride,
        playfieldLocalPath = playfieldLocalPath,
        playfieldSourceUrl = playfieldSourceUrl,
        gameinfoLocalPath = gameinfoLocalPath,
        rulesheetLocalPath = rulesheetLocalPath,
        rulesheetLinks = rulesheetLinks,
        videos = videos,
    )

private fun android.database.Cursor.getNullableString(index: Int): String? =
    if (isNull(index)) null else getString(index)?.trim()?.ifBlank { null }

private fun android.database.Cursor.getIntOrNull(index: Int): Int? =
    if (isNull(index)) null else getInt(index)
