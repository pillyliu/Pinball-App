import Foundation

extension PinballImportedSourcesStore {
    static func loadBundledDefaults() -> [PinballImportedSourceRecord] {
        guard !PinballLibrarySourceStateStore.hasPersistedState() else {
            return []
        }

        return [
            PinballImportedSourceRecord(
                id: pmAvenueLibrarySourceID,
                name: pmAvenueLibrarySourceName,
                type: .venue,
                provider: .pinballMap,
                providerSourceID: "8760",
                machineIDs: bundledAvenueVenueMachineIDs,
                lastSyncedAt: nil,
                searchQuery: nil,
                distanceMiles: nil
            ),
            PinballImportedSourceRecord(
                id: pmElectricBatLibrarySourceID,
                name: pmElectricBatLibrarySourceName,
                type: .venue,
                provider: .pinballMap,
                providerSourceID: "10819",
                machineIDs: bundledElectricBatVenueMachineIDs,
                lastSyncedAt: nil,
                searchQuery: nil,
                distanceMiles: nil
            ),
            PinballImportedSourceRecord(
                id: sternManufacturerLibrarySourceID,
                name: sternManufacturerLibrarySourceName,
                type: .manufacturer,
                provider: .opdb,
                providerSourceID: "manufacturer-12",
                machineIDs: [],
                lastSyncedAt: nil,
                searchQuery: nil,
                distanceMiles: nil
            ),
            PinballImportedSourceRecord(
                id: jerseyJackManufacturerLibrarySourceID,
                name: jerseyJackManufacturerLibrarySourceName,
                type: .manufacturer,
                provider: .opdb,
                providerSourceID: "manufacturer-74",
                machineIDs: [],
                lastSyncedAt: nil,
                searchQuery: nil,
                distanceMiles: nil
            ),
            PinballImportedSourceRecord(
                id: spookyManufacturerLibrarySourceID,
                name: spookyManufacturerLibrarySourceName,
                type: .manufacturer,
                provider: .opdb,
                providerSourceID: "manufacturer-95",
                machineIDs: [],
                lastSyncedAt: nil,
                searchQuery: nil,
                distanceMiles: nil
            ),
        ]
    }
}
