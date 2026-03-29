import Foundation

private let syntheticPinProfLabsGroupID = "G900001"
private let syntheticPinProfLabsMachineID = "G900001-1"
private let syntheticPinProfLabsManufacturerID = "manufacturer-9001"
private let syntheticPinProfLabsBackglassPath = "/pinball/images/backglasses/G900001-1-backglass.webp"
private let syntheticPinProfLabsPlayfieldMediumPath = "/pinball/images/playfields/G900001-1-playfield_700.webp"
private let syntheticPinProfLabsPlayfieldLargePath = "/pinball/images/playfields/G900001-1-playfield_1400.webp"

private func syntheticPinProfLabsCatalogMachineRecord() -> CatalogMachineRecord {
    CatalogMachineRecord(
        practiceIdentity: syntheticPinProfLabsGroupID,
        opdbMachineID: syntheticPinProfLabsMachineID,
        opdbGroupID: syntheticPinProfLabsGroupID,
        slug: "pinprof",
        name: "PinProf: The Final Exam",
        variant: nil,
        manufacturerID: syntheticPinProfLabsManufacturerID,
        manufacturerName: "PinProf Labs",
        year: 1982,
        opdbName: "PinProf: The Final Exam",
        opdbCommonName: "PinProf: The Final Exam",
        opdbShortname: "PinProf",
        opdbDescription: "A long-lost pinball treasure.",
        opdbType: "ss",
        opdbDisplay: "alphanumeric",
        opdbPlayerCount: 4,
        opdbManufactureDate: "1982-09-03",
        opdbIpdbID: nil,
        opdbGroupShortname: "PinProf",
        opdbGroupDescription: "A long-lost pinball treasure.",
        primaryImage: CatalogMachineRecord.RemoteImageSet(
            mediumURL: syntheticPinProfLabsBackglassPath,
            largeURL: syntheticPinProfLabsBackglassPath
        ),
        playfieldImage: CatalogMachineRecord.RemoteImageSet(
            mediumURL: syntheticPinProfLabsPlayfieldMediumPath,
            largeURL: syntheticPinProfLabsPlayfieldLargePath
        )
    )
}

private func appendingSyntheticPinProfLabsMachine(to machines: [CatalogMachineRecord]) -> [CatalogMachineRecord] {
    let normalizedSyntheticMachineID = syntheticPinProfLabsMachineID.lowercased()
    let normalizedSyntheticGroupID = syntheticPinProfLabsGroupID.lowercased()
    guard !machines.contains(where: { machine in
        machine.opdbMachineID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedSyntheticMachineID ||
            machine.practiceIdentity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedSyntheticGroupID
    }) else {
        return machines
    }
    return machines + [syntheticPinProfLabsCatalogMachineRecord()]
}

nonisolated func opdbGroupID(from opdbID: String?) -> String? {
    guard let trimmed = catalogNormalizedOptionalString(opdbID),
          trimmed.hasPrefix("G") else {
        return nil
    }
    guard let dashIndex = trimmed.firstIndex(of: "-") else {
        return trimmed
    }
    let group = String(trimmed[..<dashIndex])
    return group.isEmpty ? nil : group
}

private struct PracticeIdentityCurationsRoot: Decodable {
    let splits: [PracticeIdentityCurationsSplit]?
}

private struct PracticeIdentityCurationsSplit: Decodable {
    let practiceEntries: [PracticeIdentityCurationsEntry]?
}

private struct PracticeIdentityCurationsEntry: Decodable {
    let practiceIdentity: String?
    let memberOpdbIds: [String]?
}

private struct PracticeIdentityCurations {
    let practiceIdentityByOpdbID: [String: String]

    static let empty = PracticeIdentityCurations(practiceIdentityByOpdbID: [:])
}

private func decodePracticeIdentityCurations(data: Data?) -> PracticeIdentityCurations {
    guard let data,
          !data.isEmpty,
          let root = try? JSONDecoder().decode(PracticeIdentityCurationsRoot.self, from: data) else {
        return .empty
    }

    var resolved: [String: String] = [:]
    for split in root.splits ?? [] {
        for entry in split.practiceEntries ?? [] {
            guard let practiceIdentity = catalogNormalizedOptionalString(entry.practiceIdentity) else { continue }
            for memberID in entry.memberOpdbIds ?? [] {
                guard let opdbID = catalogNormalizedOptionalString(memberID) else { continue }
                resolved[opdbID] = practiceIdentity
            }
        }
    }
    return PracticeIdentityCurations(practiceIdentityByOpdbID: resolved)
}

private func resolvePracticeIdentity(opdbID: String?, curations: PracticeIdentityCurations) -> String? {
    guard let normalized = catalogNormalizedOptionalString(opdbID) else { return nil }
    return curations.practiceIdentityByOpdbID[normalized] ?? opdbGroupID(from: normalized) ?? normalized
}

private func rawOPDBYear(from manufactureDate: String?) -> Int? {
    guard let prefix = manufactureDate?.prefix(4), prefix.count == 4 else { return nil }
    return Int(prefix)
}

private func rawOPDBImageSet(
    from images: [RawOPDBExportMachineRecord.ImageRecord]?,
    preferredType: String
) -> CatalogMachineRecord.RemoteImageSet? {
    let normalizedPreferredType = preferredType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let typedMatches = (images ?? []).filter { image in
        image.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedPreferredType
    }
    let selected = typedMatches.first(where: { $0.primary == true && ($0.urls?.medium != nil || $0.urls?.large != nil) })
        ?? typedMatches.first(where: { $0.urls?.medium != nil || $0.urls?.large != nil })
    guard let selected else { return nil }
    return CatalogMachineRecord.RemoteImageSet(
        mediumURL: catalogNormalizedOptionalString(selected.urls?.medium),
        largeURL: catalogNormalizedOptionalString(selected.urls?.large)
    )
}

private func rawOPDBCatalogMachineRecord(
    from machine: RawOPDBExportMachineRecord,
    curations: PracticeIdentityCurations
) -> CatalogMachineRecord? {
    if machine.isMachine == false {
        return nil
    }

    guard let practiceIdentity = resolvePracticeIdentity(opdbID: machine.opdbID, curations: curations) else {
        return nil
    }
    let resolvedGroupID = opdbGroupID(from: machine.opdbID) ?? practiceIdentity
    return CatalogMachineRecord(
        practiceIdentity: practiceIdentity,
        opdbMachineID: catalogNormalizedOptionalString(machine.opdbID),
        opdbGroupID: catalogNormalizedOptionalString(resolvedGroupID),
        slug: practiceIdentity,
        name: machine.name,
        variant: nil,
        manufacturerID: machine.manufacturer?.manufacturerID.map { "manufacturer-\($0)" },
        manufacturerName: catalogNormalizedOptionalString(machine.manufacturer?.name),
        year: rawOPDBYear(from: machine.manufactureDate),
        opdbName: catalogNormalizedOptionalString(machine.name),
        opdbCommonName: catalogNormalizedOptionalString(machine.commonName),
        opdbShortname: catalogNormalizedOptionalString(machine.shortname),
        opdbDescription: catalogNormalizedOptionalString(machine.description),
        opdbType: catalogNormalizedOptionalString(machine.type),
        opdbDisplay: catalogNormalizedOptionalString(machine.display),
        opdbPlayerCount: machine.playerCount,
        opdbManufactureDate: catalogNormalizedOptionalString(machine.manufactureDate),
        opdbIpdbID: machine.ipdbID,
        opdbGroupShortname: nil,
        opdbGroupDescription: nil,
        primaryImage: rawOPDBImageSet(from: machine.images, preferredType: "backglass"),
        playfieldImage: rawOPDBImageSet(from: machine.images, preferredType: "playfield")
    )
}

func decodeOPDBExportCatalogMachines(data: Data, practiceIdentityCurationsData: Data? = nil) throws -> [CatalogMachineRecord] {
    let machines = try JSONDecoder().decode([RawOPDBExportMachineRecord].self, from: data)
    let curations = decodePracticeIdentityCurations(data: practiceIdentityCurationsData)
    return catalogResolvedMachines(
        appendingSyntheticPinProfLabsMachine(to: machines.compactMap { rawOPDBCatalogMachineRecord(from: $0, curations: curations) })
    )
}

func decodeCatalogManufacturerOptionsFromOPDBExport(
    data: Data,
    practiceIdentityCurationsData: Data? = nil
) throws -> [PinballCatalogManufacturerOption] {
    let machines = try decodeOPDBExportCatalogMachines(data: data, practiceIdentityCurationsData: practiceIdentityCurationsData)
    let modernLookup = Dictionary(uniqueKeysWithValues: curatedModernManufacturerNames.enumerated().map { ($1, $0 + 1) })
    let groupedMachines = Dictionary(grouping: machines.compactMap { machine -> (manufacturerID: String, manufacturerName: String, machine: CatalogMachineRecord)? in
        guard let manufacturerID = catalogNormalizedOptionalString(machine.manufacturerID),
              let manufacturerName = catalogNormalizedOptionalString(machine.manufacturerName) else {
            return nil
        }
        return (manufacturerID, manufacturerName, machine)
    }, by: \.manufacturerID)

    return groupedMachines.compactMap { manufacturerID, entries -> PinballCatalogManufacturerOption? in
        guard let manufacturerName = entries.first?.manufacturerName else { return nil }
        let gameCount = Set(entries.map { $0.machine.practiceIdentity }).count
        let normalizedName = manufacturerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let modernRank = modernLookup[normalizedName]
        let isModern = modernRank != nil
        return PinballCatalogManufacturerOption(
            id: manufacturerID,
            name: manufacturerName,
            gameCount: gameCount,
            isModern: isModern,
            featuredRank: modernRank,
            sortBucket: isModern ? 0 : 1
        )
    }
    .sorted {
        ($0.sortBucket, $0.featuredRank ?? Int.max, $0.name.lowercased())
            < ($1.sortBucket, $1.featuredRank ?? Int.max, $1.name.lowercased())
    }
}

func catalogResolvedMachines(_ machines: [CatalogMachineRecord]) -> [CatalogMachineRecord] {
    machines.map { machine in
        CatalogMachineRecord(
            practiceIdentity: machine.practiceIdentity,
            opdbMachineID: machine.opdbMachineID,
            opdbGroupID: machine.opdbGroupID,
            slug: machine.slug,
            name: machine.name,
            variant: catalogResolvedVariantLabel(title: machine.name, explicitVariant: machine.variant),
            manufacturerID: machine.manufacturerID,
            manufacturerName: machine.manufacturerName,
            year: machine.year,
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
            primaryImage: machine.primaryImage,
            playfieldImage: machine.playfieldImage
        )
    }
}

func decodePracticeCatalogGamesFromOPDBExport(
    data: Data,
    practiceIdentityCurationsData: Data? = nil
) throws -> [PinballGame] {
    let machines = try decodeOPDBExportCatalogMachines(data: data, practiceIdentityCurationsData: practiceIdentityCurationsData)
    guard !machines.isEmpty else { return [] }

    let source = PinballImportedSourceRecord(
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
