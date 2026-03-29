import Foundation

func decodeOPDBExportCatalogMachines(data: Data, practiceIdentityCurationsData: Data? = nil) throws -> [CatalogMachineRecord] {
    let machines = try JSONDecoder().decode([RawOPDBExportMachineRecord].self, from: data)
    let curations = decodePracticeIdentityCurations(data: practiceIdentityCurationsData)
    return catalogResolvedMachines(
        appendingSyntheticPinProfLabsMachine(to: machines.compactMap { rawOPDBCatalogMachineRecord(from: $0, curations: curations) })
    )
}
