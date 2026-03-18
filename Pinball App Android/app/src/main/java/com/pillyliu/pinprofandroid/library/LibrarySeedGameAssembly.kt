package com.pillyliu.pinprofandroid.library

import android.database.sqlite.SQLiteDatabase

internal fun loadLibrarySeedBuiltInGames(database: SQLiteDatabase): List<PinballGame> {
    val rulesheetsByEntry = loadBuiltInRulesheets(database)
    val videosByEntry = loadBuiltInVideos(database)
    val machineById = loadMachinesById(database)
    val machinesByPracticeIdentity = machineById.values.groupBy { it.practiceIdentity }
    val machinesByOpdbId = machineById
    return loadBuiltInGameRows(database).map { row ->
        val resolvedMachine = preferredSeedMachineForBuiltInGame(
            requestedMachineId = row.opdbId,
            requestedVariant = row.variant,
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

internal fun loadBuiltInRulesheets(database: SQLiteDatabase): Map<String, List<ReferenceLink>> =
    loadEntryScopedRulesheetLinks(database, "built_in_rulesheet_links")

internal fun loadBuiltInVideos(database: SQLiteDatabase): Map<String, List<Video>> =
    loadEntryScopedVideos(database, "built_in_videos")

internal fun loadBuiltInGameRows(database: SQLiteDatabase): List<SeedBuiltInGameRow> {
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

internal fun loadLibrarySeedImportedGames(
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
    val venueMetadataByKey = loadSeedVenueMachineMetadata(database)
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
                            venueMetadata = null,
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
                        venueMetadata = resolveSeedImportedVenueMetadata(
                            sourceId = source.id,
                            requestedOpdbId = machineId,
                            machine = preferred,
                            metadataByKey = venueMetadataByKey,
                        ),
                    )
                }
            }

            LibrarySourceType.CATEGORY -> Unit
        }
    }
    return out
}

private data class SeedVenueMachineMetadataRow(
    val sourceId: String,
    val opdbId: String,
    val area: String?,
    val areaOrder: Int?,
    val group: Int?,
    val position: Int?,
    val bank: Int?,
)

private fun loadSeedVenueMachineMetadata(database: SQLiteDatabase): Map<String, SeedVenueMachineMetadataRow> {
    database.rawQuery(
        """
        SELECT source_id, opdb_id, area, area_order, group_number, position, bank
        FROM venue_machine_metadata
        """.trimIndent(),
        emptyArray(),
    ).use { cursor ->
        val out = linkedMapOf<String, SeedVenueMachineMetadataRow>()
        while (cursor.moveToNext()) {
            val sourceId = cursor.getString(0).orEmpty()
            val opdbId = cursor.getString(1).orEmpty()
            out["$sourceId|$opdbId"] = SeedVenueMachineMetadataRow(
                sourceId = sourceId,
                opdbId = opdbId,
                area = cursor.getNullableString(2),
                areaOrder = cursor.getIntOrNull(3),
                group = cursor.getIntOrNull(4),
                position = cursor.getIntOrNull(5),
                bank = cursor.getIntOrNull(6),
            )
        }
        return out
    }
}

private fun resolveSeedImportedVenueMetadata(
    sourceId: String,
    requestedOpdbId: String,
    machine: CatalogMachineRecord,
    metadataByKey: Map<String, SeedVenueMachineMetadataRow>,
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
            if (!contains(candidate)) add(candidate)
        }
    }
    for (candidateId in candidateIds) {
        val row = metadataByKey["$sourceId|$candidateId"] ?: continue
        return ResolvedImportedVenueMetadata(
            area = normalizedOptionalString(row.area),
            areaOrder = row.areaOrder,
            group = row.group,
            position = row.position,
            bank = row.bank,
        )
    }
    return null
}

internal fun loadManufacturers(database: SQLiteDatabase): Map<String, SeedManufacturer> {
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

internal fun loadOverrides(database: SQLiteDatabase): Map<String, SeedOverride> {
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

internal fun loadMachinesById(database: SQLiteDatabase): Map<String, SeedMachine> {
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
                variant = resolvedCatalogVariantLabel(
                    title = cursor.getString(4),
                    explicitVariant = cursor.getNullableString(5),
                ),
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

internal fun preferredSeedMachineForBuiltInGame(
    requestedMachineId: String?,
    requestedVariant: String?,
    practiceIdentity: String,
    machinesByPracticeIdentity: Map<String, List<SeedMachine>>,
    machinesByOpdbId: Map<String, SeedMachine>,
): SeedMachine? {
    val groupCandidates = machinesByPracticeIdentity[practiceIdentity].orEmpty()
    val preferredGroupMachine = preferredSeedGroupMachine(groupCandidates)
    val groupArtFallback = groupCandidates
        .filter(::seedMachineHasPrimaryImage)
        .minWithOrNull(::compareSeedPreferredMachine)
    val normalizedRequestedVariant = normalizedOptionalString(requestedVariant)?.lowercase()
    val exactMachine = requestedMachineId?.let { machinesByOpdbId[it] } ?: run {
        val variantMatch = preferredSeedMachineForVariant(groupCandidates, normalizedRequestedVariant)
        return when {
            variantMatch != null && seedMachineHasPrimaryImage(variantMatch) -> variantMatch
            preferredGroupMachine != null && seedMachineHasPrimaryImage(preferredGroupMachine) -> preferredGroupMachine
            groupArtFallback != null -> groupArtFallback
            else -> preferredGroupMachine
        }
    }

    val variantCandidates = machinesByPracticeIdentity[exactMachine.practiceIdentity].orEmpty().ifEmpty { groupCandidates }
    val variantMatch = preferredSeedMachineForVariant(variantCandidates, normalizedRequestedVariant)
    if (variantMatch != null && seedMachineHasPrimaryImage(variantMatch)) return variantMatch
    if (seedMachineHasPrimaryImage(exactMachine)) return exactMachine

    val preferredExactGroupMachine = preferredSeedGroupMachine(machinesByPracticeIdentity[exactMachine.practiceIdentity].orEmpty())
    return when {
        preferredExactGroupMachine != null && seedMachineHasPrimaryImage(preferredExactGroupMachine) -> preferredExactGroupMachine
        preferredGroupMachine != null && seedMachineHasPrimaryImage(preferredGroupMachine) -> preferredGroupMachine
        groupArtFallback != null -> groupArtFallback
        else -> preferredExactGroupMachine ?: preferredGroupMachine ?: variantMatch ?: exactMachine
    }
}

internal fun loadOverrideRulesheets(database: SQLiteDatabase): Map<String, List<ReferenceLink>> =
    loadPracticeScopedRulesheetLinks(database, "override_rulesheet_links")

internal fun loadCatalogRulesheets(database: SQLiteDatabase): Map<String, List<ReferenceLink>> =
    loadPracticeScopedRulesheetLinks(database, "catalog_rulesheet_links")

internal fun loadOverrideVideos(database: SQLiteDatabase): Map<String, List<Video>> =
    loadPracticeScopedVideos(database, "override_videos")

internal fun loadCatalogVideos(database: SQLiteDatabase): Map<String, List<Video>> =
    loadPracticeScopedVideos(database, "catalog_video_links")
