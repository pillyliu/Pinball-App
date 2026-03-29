import Foundation

nonisolated let pmAvenueLibrarySourceID = "venue--pm-8760"
nonisolated let pmElectricBatLibrarySourceID = "venue--pm-10819"
nonisolated let pmRLMLibrarySourceID = "venue--pm-16470"
nonisolated let gameRoomLibrarySourceID = "venue--gameroom"
nonisolated let sternManufacturerLibrarySourceID = "manufacturer-12"
nonisolated let jerseyJackManufacturerLibrarySourceID = "manufacturer-74"
nonisolated let spookyManufacturerLibrarySourceID = "manufacturer-95"
nonisolated let pmAvenueLibrarySourceName = "The Avenue Cafe"
nonisolated let pmElectricBatLibrarySourceName = "Electric Bat Arcade"
nonisolated let pmRLMLibrarySourceName = "RLM Amusements"
nonisolated let sternManufacturerLibrarySourceName = "Stern"
nonisolated let jerseyJackManufacturerLibrarySourceName = "Jersey Jack Pinball"
nonisolated let spookyManufacturerLibrarySourceName = "Spooky Pinball"
nonisolated let defaultSeededLibrarySourceIDs: [String] = [
    pmAvenueLibrarySourceID,
    pmElectricBatLibrarySourceID,
    sternManufacturerLibrarySourceID,
    jerseyJackManufacturerLibrarySourceID,
    spookyManufacturerLibrarySourceID,
]

nonisolated private let legacyLibrarySourceIDAliases: [String: String] = [
    "the-avenue": pmAvenueLibrarySourceID,
    "the-avenue-cafe": pmAvenueLibrarySourceID,
    "venue--the-avenue-cafe": pmAvenueLibrarySourceID,
    "rlm-amusements": pmRLMLibrarySourceID,
    "venue--rlm-amusements": pmRLMLibrarySourceID
]

private struct LegacyPinballMapVenueMigrationTarget {
    let id: String
    let name: String
    let providerSourceID: String
}

nonisolated private let legacyPinballMapVenueMigrationTargets: [LegacyPinballMapVenueMigrationTarget] = [
    LegacyPinballMapVenueMigrationTarget(
        id: pmAvenueLibrarySourceID,
        name: pmAvenueLibrarySourceName,
        providerSourceID: "8760"
    ),
    LegacyPinballMapVenueMigrationTarget(
        id: pmRLMLibrarySourceID,
        name: pmRLMLibrarySourceName,
        providerSourceID: "16470"
    )
]

nonisolated func canonicalLegacyLibrarySourceAliasID(_ rawID: String?) -> String? {
    guard let trimmed = rawID?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return legacyLibrarySourceIDAliases[trimmed]
}

nonisolated func canonicalLibrarySourceID(_ rawID: String?) -> String? {
    guard let trimmed = rawID?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return canonicalLegacyLibrarySourceAliasID(trimmed) ?? trimmed
}

nonisolated func isAvenueLibrarySourceID(_ rawID: String?) -> Bool {
    canonicalLibrarySourceID(rawID) == pmAvenueLibrarySourceID
}

nonisolated func isImportedPinballMapSourceID(_ rawID: String?) -> Bool {
    canonicalLibrarySourceID(rawID)?.lowercased().hasPrefix("venue--pm-") == true
}

func migrateLegacyPinnedVenueImportsIfNeeded() async {
    let sourceState = PinballLibrarySourceStateStore.load()
    let importedSources = PinballImportedSourcesStore.load()
    let importedIDs = Set(importedSources.map(\.id))
    let referencedSourceIDs = Set(
        sourceState.enabledSourceIDs +
        sourceState.pinnedSourceIDs +
        [sourceState.selectedSourceID].compactMap { $0 }
    )

    let targets = legacyPinballMapVenueMigrationTargets.filter { target in
        referencedSourceIDs.contains(target.id) && !importedIDs.contains(target.id)
    }
    guard !targets.isEmpty else { return }

    var didChange = false
    for target in targets {
        do {
            let machineIDs = try await PinballMapClient.fetchVenueMachineIDs(locationID: target.providerSourceID)
            let record = PinballImportedSourceRecord(
                id: target.id,
                name: target.name,
                type: .venue,
                provider: .pinballMap,
                providerSourceID: target.providerSourceID,
                machineIDs: machineIDs,
                lastSyncedAt: Date(),
                searchQuery: nil,
                distanceMiles: nil
            )
            PinballImportedSourcesStore.upsert(record)
            didChange = true
        } catch {
            continue
        }
    }

    if didChange {
        postPinballLibrarySourcesDidChange()
    }
}
