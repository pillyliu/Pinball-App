import Foundation

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

func rawOPDBCatalogMachineRecord(
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
