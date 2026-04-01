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

// Refresh saved Pinball Map venue imports that were synced before the machine-ID replacement fix shipped.
nonisolated let staleImportedPinballMapVenueRefreshCutoff: Date = {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: "2026-04-01T08:00:00-04:00") else {
        fatalError("Invalid stale imported Pinball Map venue refresh cutoff")
    }
    return date
}()

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

nonisolated func importedPinballMapVenueNeedsStaleRefresh(_ source: PinballImportedSourceRecord) -> Bool {
    guard source.type == .venue else { return false }
    guard source.provider == .pinballMap || isImportedPinballMapSourceID(source.id) else { return false }
    guard !source.providerSourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
    guard let lastSyncedAt = source.lastSyncedAt else { return false }
    return lastSyncedAt < staleImportedPinballMapVenueRefreshCutoff
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

    var didChange = false
    if !targets.isEmpty {
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
    }

    let didRefreshStaleVenueImports = await refreshStaleImportedPinballMapVenueImportsIfNeeded(
        importedSources: PinballImportedSourcesStore.load()
    )

    if didChange || didRefreshStaleVenueImports {
        postPinballLibrarySourcesDidChange()
    }
}

private func refreshStaleImportedPinballMapVenueImportsIfNeeded(
    importedSources: [PinballImportedSourceRecord]
) async -> Bool {
    let staleSources = importedSources.filter(importedPinballMapVenueNeedsStaleRefresh)
    guard !staleSources.isEmpty else { return false }

    var didChange = false
    for source in staleSources {
        do {
            let machineIDs = try await PinballMapClient.fetchVenueMachineIDs(locationID: source.providerSourceID)
            let previousMachineIDs = Array(
                NSOrderedSet(array: source.machineIDs.compactMap(catalogNormalizedOptionalString))
            ) as? [String] ?? []

            var updated = source
            updated.machineIDs = machineIDs
            updated.lastSyncedAt = Date()
            PinballImportedSourcesStore.upsert(updated)

            if previousMachineIDs != machineIDs {
                didChange = true
            }
        } catch {
            continue
        }
    }

    return didChange
}
