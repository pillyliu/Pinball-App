import Foundation

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
