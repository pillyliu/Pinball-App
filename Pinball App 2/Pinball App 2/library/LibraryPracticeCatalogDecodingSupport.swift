import Foundation

private func practiceCatalogSourceRecord() -> PinballImportedSourceRecord {
    PinballImportedSourceRecord(
        id: "catalog--opdb-practice",
        name: "All OPDB Games",
        type: .category,
        provider: .opdb,
        providerSourceID: "opdb-catalog",
        machineIDs: [],
        lastSyncedAt: nil,
        searchQuery: nil,
        distanceMiles: nil
    )
}

func decodePracticeCatalogGamesFromOPDBExport(
    data: Data,
    practiceIdentityCurationsData: Data? = nil
) throws -> [PinballGame] {
    let machines = try decodeOPDBExportCatalogMachines(data: data, practiceIdentityCurationsData: practiceIdentityCurationsData)
    guard !machines.isEmpty else { return [] }

    let source = practiceCatalogSourceRecord()

    return Dictionary(grouping: machines, by: \.practiceIdentity)
        .values
        .compactMap { group -> PinballGame? in
            guard let machine = group.min(by: catalogPreferredGroupDefaultMachine) else { return nil }
            let opdbPlayfieldImageURL = catalogNormalizedOptionalString(
                machine.playfieldImage?.largeURL ?? machine.playfieldImage?.mediumURL
            )
            let record = ResolvedCatalogRecord(
                sourceID: source.id,
                sourceName: source.name,
                sourceType: source.type,
                area: nil,
                areaOrder: nil,
                groupNumber: nil,
                position: nil,
                bank: nil,
                name: machine.name,
                variant: catalogNormalizedOptionalString(machine.variant),
                manufacturer: catalogNormalizedOptionalString(machine.manufacturerName),
                year: machine.year,
                slug: catalogNormalizedOptionalString(machine.slug) ?? machine.practiceIdentity,
                opdbID: catalogNormalizedOptionalString(machine.opdbMachineID),
                opdbMachineID: catalogNormalizedOptionalString(machine.opdbMachineID),
                practiceIdentity: machine.practiceIdentity,
                opdbName: machine.opdbName,
                opdbCommonName: machine.opdbCommonName,
                opdbShortname: machine.opdbShortname,
                opdbDescription: machine.opdbDescription,
                opdbType: machine.opdbType,
                opdbDisplay: machine.opdbDisplay,
                opdbPlayerCount: machine.opdbPlayerCount,
                opdbManufactureDate: machine.opdbManufactureDate,
                opdbIpdbID: machine.opdbIpdbID,
                opdbGroupShortname: machine.opdbGroupShortname,
                opdbGroupDescription: machine.opdbGroupDescription,
                primaryImageURL: catalogNormalizedOptionalString(machine.primaryImage?.mediumURL),
                primaryImageLargeURL: catalogNormalizedOptionalString(machine.primaryImage?.largeURL),
                playfieldImageURL: opdbPlayfieldImageURL,
                alternatePlayfieldImageURL: nil,
                playfieldLocalPath: nil,
                playfieldSourceLabel: machine.playfieldImage != nil ? "Playfield (OPDB)" : nil,
                gameinfoLocalPath: nil,
                rulesheetLocalPath: nil,
                rulesheetURL: nil,
                rulesheetLinks: [],
                videos: []
            )
            return PinballGame(record: record)
        }
        .sorted {
            let nameCompare = $0.name.localizedCaseInsensitiveCompare($1.name)
            if nameCompare != .orderedSame { return nameCompare == .orderedAscending }
            return $0.slug.localizedCaseInsensitiveCompare($1.slug) == .orderedAscending
        }
}
