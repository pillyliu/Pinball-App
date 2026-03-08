package com.pillyliu.pinprofandroid.library

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.security.MessageDigest

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
            val payloadWithGameRoom = addSeedGameRoomOverlay(context = context, basePayload = payload)
            val state = LibrarySourceStateStore.synchronize(context, payloadWithGameRoom.sources)
            return LegacyCatalogExtraction(
                payload = filterSeedLibraryPayload(payloadWithGameRoom, state),
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
        return loadBuiltInGameRows(database).map { row ->
            val resolvedMachine = preferredSeedMachineForBuiltInGame(
                requestedMachineId = row.opdbId,
                practiceIdentity = row.practiceIdentity,
                machinesByPracticeIdentity = machinesByPracticeIdentity,
                machinesByOpdbId = machinesByOpdbId,
            )
            row.toPinballGame(
                resolvedMachine = resolvedMachine,
                rulesheetLinks = rulesheetsByEntry[row.libraryEntryId].orEmpty(),
                videos = videosByEntry[row.libraryEntryId].orEmpty(),
            )
        }
    }

    private fun loadBuiltInRulesheets(database: SQLiteDatabase): Map<String, List<ReferenceLink>> {
        return loadEntryScopedRulesheetLinks(database, "built_in_rulesheet_links")
    }

    private fun loadBuiltInVideos(database: SQLiteDatabase): Map<String, List<Video>> {
        return loadEntryScopedVideos(database, "built_in_videos")
    }

    private fun loadBuiltInGameRows(database: SQLiteDatabase): List<SeedBuiltInGameRow> {
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
                    val opdbId = cursor.getNullableString(5)
                    add(
                        SeedBuiltInGameRow(
                            libraryEntryId = libraryEntryId,
                            sourceId = cursor.getString(1).orEmpty(),
                            sourceName = cursor.getString(2).orEmpty(),
                            sourceType = LibrarySourceType.fromRaw(cursor.getString(3)) ?: LibrarySourceType.VENUE,
                            practiceIdentity = cursor.getNullableString(4)
                                ?: opdbId?.substringBefore('-')
                                ?: libraryEntryId,
                            opdbId = opdbId,
                            area = cursor.getNullableString(6),
                            areaOrder = cursor.getIntOrNull(7),
                            group = cursor.getIntOrNull(8),
                            position = cursor.getIntOrNull(9),
                            bank = cursor.getIntOrNull(10),
                            name = cursor.getString(11).orEmpty(),
                            variant = cursor.getNullableString(12),
                            manufacturer = cursor.getNullableString(13),
                            year = cursor.getIntOrNull(14),
                            slug = cursor.getString(15).orEmpty(),
                            primaryImageUrl = cursor.getNullableString(16),
                            primaryImageLargeUrl = cursor.getNullableString(17),
                            playfieldImageUrl = cursor.getNullableString(18),
                            playfieldLocalPath = cursor.getNullableString(19),
                            playfieldSourceLabel = cursor.getNullableString(20),
                            gameinfoLocalPath = cursor.getNullableString(21),
                            rulesheetLocalPath = cursor.getNullableString(22),
                            rulesheetUrl = cursor.getNullableString(23),
                        ),
                    )
                }
            }
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
        loadPracticeScopedRulesheetLinks(database, "override_rulesheet_links")

    private fun loadCatalogRulesheets(database: SQLiteDatabase): Map<String, List<ReferenceLink>> =
        loadPracticeScopedRulesheetLinks(database, "catalog_rulesheet_links")

    private fun loadOverrideVideos(database: SQLiteDatabase): Map<String, List<Video>> =
        loadPracticeScopedVideos(database, "override_videos")

    private fun loadCatalogVideos(database: SQLiteDatabase): Map<String, List<Video>> =
        loadPracticeScopedVideos(database, "catalog_video_links")

}
