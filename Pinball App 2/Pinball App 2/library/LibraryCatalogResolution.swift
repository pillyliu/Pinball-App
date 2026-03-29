import Foundation

nonisolated func resolveImportedGame(
    machine: CatalogMachineRecord,
    source: PinballImportedSourceRecord,
    manufacturerByID: [String: CatalogManufacturerRecord],
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheets: [CatalogRulesheetLinkRecord],
    opdbVideos: [CatalogVideoLinkRecord],
    venueMetadata: ResolvedImportedVenueMetadata?
) -> PinballGame {
    let manufacturerName = curatedOverride?.manufacturerOverride
        ?? machine.manufacturerName
        ?? machine.manufacturerID.flatMap { manufacturerByID[$0]?.name }
    let resolvedRulesheet = resolveImportedRulesheetLinks(
        curatedOverride: curatedOverride,
        opdbRulesheetLinks: opdbRulesheets
    )
    let resolvedVideos = resolveImportedVideos(
        curatedOverride: curatedOverride,
        opdbVideoLinks: opdbVideos
    )
    let playfieldLocalPath = curatedOverride?.playfieldLocalPath
    let opdbPlayfieldSourceURL = catalogNormalizedOptionalString(
        machine.playfieldImage?.largeURL ?? machine.playfieldImage?.mediumURL
    )
    let hasCuratedPlayfield = playfieldLocalPath != nil || curatedOverride?.playfieldSourceURL != nil
    let playfieldSourceURL = curatedOverride?.playfieldSourceURL ?? opdbPlayfieldSourceURL
    let record = ResolvedCatalogRecord(
        sourceID: source.id,
        sourceName: source.name,
        sourceType: source.type,
        area: venueMetadata?.area,
        areaOrder: venueMetadata?.areaOrder,
        groupNumber: venueMetadata?.groupNumber,
        position: venueMetadata?.position,
        bank: venueMetadata?.bank,
        name: curatedOverride?.nameOverride ?? catalogResolvedDisplayTitle(
            title: machine.name,
            explicitVariant: machine.variant
        ),
        variant: curatedOverride?.variantOverride ?? catalogNormalizedOptionalString(machine.variant),
        manufacturer: catalogNormalizedOptionalString(manufacturerName),
        year: curatedOverride?.yearOverride ?? machine.year,
        slug: machine.slug,
        opdbID: catalogNormalizedOptionalString(machine.opdbMachineID),
        opdbMachineID: catalogNormalizedOptionalString(machine.opdbMachineID),
        practiceIdentity: machine.practiceIdentity,
        opdbName: catalogNormalizedOptionalString(machine.opdbName),
        opdbCommonName: catalogNormalizedOptionalString(machine.opdbCommonName),
        opdbShortname: catalogNormalizedOptionalString(machine.opdbShortname),
        opdbDescription: catalogNormalizedOptionalString(machine.opdbDescription),
        opdbType: catalogNormalizedOptionalString(machine.opdbType),
        opdbDisplay: catalogNormalizedOptionalString(machine.opdbDisplay),
        opdbPlayerCount: machine.opdbPlayerCount,
        opdbManufactureDate: catalogNormalizedOptionalString(machine.opdbManufactureDate),
        opdbIpdbID: machine.opdbIpdbID,
        opdbGroupShortname: catalogNormalizedOptionalString(machine.opdbGroupShortname),
        opdbGroupDescription: catalogNormalizedOptionalString(machine.opdbGroupDescription),
        primaryImageURL: catalogNormalizedOptionalString(machine.primaryImage?.mediumURL),
        primaryImageLargeURL: catalogNormalizedOptionalString(machine.primaryImage?.largeURL),
        playfieldImageURL: playfieldSourceURL,
        alternatePlayfieldImageURL: hasCuratedPlayfield ? opdbPlayfieldSourceURL : nil,
        playfieldLocalPath: playfieldLocalPath,
        playfieldSourceLabel: hasCuratedPlayfield ? nil : (machine.playfieldImage != nil ? "Playfield (OPDB)" : nil),
        gameinfoLocalPath: curatedOverride?.gameinfoLocalPath,
        rulesheetLocalPath: resolvedRulesheet.localPath,
        rulesheetURL: resolvedRulesheet.links.first?.url,
        rulesheetLinks: resolvedRulesheet.links,
        videos: resolvedVideos
    )
    return PinballGame(record: record)
}

nonisolated func catalogPreferredMachineForSourceLookup(
    requestedMachineID: String,
    machineByOPDBID: [String: CatalogMachineRecord],
    machineByPracticeIdentity: [String: [CatalogMachineRecord]]
) -> CatalogMachineRecord? {
    let normalizedMachineID = catalogNormalizedOptionalString(requestedMachineID)
    let preferredGroupMachine = normalizedMachineID
        .flatMap { machineByPracticeIdentity[$0]?.min(by: catalogPreferredManufacturerMachine) }
    guard let normalizedMachineID,
          let exactMachine = machineByOPDBID[normalizedMachineID] else {
        return preferredGroupMachine
    }
    if catalogMachineHasPrimaryImage(exactMachine) {
        return exactMachine
    }
    let exactGroupMachine = machineByPracticeIdentity[exactMachine.practiceIdentity]?.min(by: catalogPreferredManufacturerMachine)
    return exactGroupMachine ?? preferredGroupMachine ?? exactMachine
}

nonisolated func catalogDedupedSources(_ sources: [PinballLibrarySource]) -> [PinballLibrarySource] {
    var seen = Set<String>()
    return sources.filter { source in
        seen.insert(source.id).inserted
    }
}
