package com.pillyliu.pinprofandroid.library

internal fun resolveImportedGame(
    machine: CatalogMachineRecord,
    source: ImportedSourceRecord,
    manufacturerById: Map<String, CatalogManufacturerRecord>,
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheets: List<CatalogRulesheetLinkRecord>,
    opdbVideos: List<CatalogVideoLinkRecord>,
    venueMetadata: ResolvedImportedVenueMetadata?,
): PinballGame {
    val manufacturerName = curatedOverride?.manufacturerOverride
        ?: machine.manufacturerName
        ?: machine.manufacturerId?.let { manufacturerById[it]?.name }
    val resolvedCatalogRulesheet = resolveRulesheetLinks(opdbRulesheets)
    val resolvedRulesheet = if (!curatedOverride?.rulesheetLocalPath.isNullOrBlank()) {
        val primaryLinks = curatedOverride?.rulesheetLinks.orEmpty()
            .filterNot(::shouldSuppressLocalMarkdownRulesheetLink)
        val mergedLinks = mergeRulesheetLinks(
            primaryLinks,
            resolvedCatalogRulesheet.links,
        )
        normalizedOptionalString(curatedOverride?.rulesheetLocalPath) to mergedLinks
    } else if (!curatedOverride?.rulesheetLinks.isNullOrEmpty()) {
        null to mergeRulesheetLinks(curatedOverride!!.rulesheetLinks, resolvedCatalogRulesheet.links)
    } else {
        resolvedCatalogRulesheet.localPath to resolvedCatalogRulesheet.links
    }
    val resolvedVideos = mergeResolvedVideos(
        primary = curatedOverride?.videos.orEmpty(),
        secondary = resolveVideoLinks(opdbVideos),
    )
    val playfieldLocalPath = curatedOverride?.playfieldLocalPath
    val opdbPlayfieldSourceUrl = normalizedOptionalString(machine.playfieldImageLargeUrl ?: machine.playfieldImageMediumUrl)
    val hasCuratedPlayfield = playfieldLocalPath != null || !curatedOverride?.playfieldSourceUrl.isNullOrBlank()
    val playfieldSourceUrl = curatedOverride?.playfieldSourceUrl ?: opdbPlayfieldSourceUrl
    return PinballGame(
        libraryEntryId = "${source.id}:${machine.practiceIdentity}",
        practiceIdentity = machine.practiceIdentity,
        opdbId = machine.opdbMachineId,
        opdbGroupId = machine.opdbGroupId,
        opdbMachineId = machine.opdbMachineId,
        variant = curatedOverride?.variantOverride ?: normalizedOptionalString(machine.variant),
        sourceId = source.id,
        sourceName = source.name,
        sourceType = source.type,
        area = venueMetadata?.area,
        areaOrder = venueMetadata?.areaOrder,
        group = venueMetadata?.group,
        position = venueMetadata?.position,
        bank = venueMetadata?.bank,
        name = curatedOverride?.nameOverride ?: resolvedCatalogDisplayTitle(
            title = machine.name,
            explicitVariant = machine.variant,
        ),
        manufacturer = normalizedOptionalString(manufacturerName),
        year = curatedOverride?.yearOverride ?: machine.year,
        slug = normalizedOptionalString(machine.slug) ?: machine.practiceIdentity,
        opdbName = normalizedOptionalString(machine.opdbName),
        opdbCommonName = normalizedOptionalString(machine.opdbCommonName),
        opdbShortname = normalizedOptionalString(machine.opdbShortname),
        opdbDescription = normalizedOptionalString(machine.opdbDescription),
        opdbType = normalizedOptionalString(machine.opdbType),
        opdbDisplay = normalizedOptionalString(machine.opdbDisplay),
        opdbPlayerCount = machine.opdbPlayerCount,
        opdbManufactureDate = normalizedOptionalString(machine.opdbManufactureDate),
        opdbIpdbId = machine.opdbIpdbId,
        opdbGroupShortname = normalizedOptionalString(machine.opdbGroupShortname),
        opdbGroupDescription = normalizedOptionalString(machine.opdbGroupDescription),
        primaryImageUrl = normalizedOptionalString(machine.primaryImageMediumUrl),
        primaryImageLargeUrl = normalizedOptionalString(machine.primaryImageLargeUrl),
        playfieldImageUrl = playfieldSourceUrl,
        alternatePlayfieldImageUrl = if (hasCuratedPlayfield) opdbPlayfieldSourceUrl else null,
        playfieldLocalOriginal = normalizeLibraryCachePath(playfieldLocalPath),
        playfieldLocal = normalizeLibraryPlayfieldLocalPath(playfieldLocalPath),
        playfieldSourceLabel = if (hasCuratedPlayfield) null else if (machine.playfieldImageLargeUrl != null || machine.playfieldImageMediumUrl != null) "Playfield (OPDB)" else null,
        gameinfoLocal = curatedOverride?.gameinfoLocalPath,
        rulesheetLocal = resolvedRulesheet.first,
        rulesheetUrl = resolvedRulesheet.second.firstOrNull()?.url,
        rulesheetLinks = resolvedRulesheet.second,
        videos = resolvedVideos,
    )
}

internal fun normalizedOptionalString(value: String?): String? =
    value
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?.takeUnless {
            val lowered = it.lowercase()
            lowered == "null" || lowered == "none"
        }
