import Foundation

struct SettingsDataSnapshot {
    let manufacturers: [PinballCatalogManufacturerOption]
    let importedSources: [PinballImportedSourceRecord]
    let sourceState: PinballLibrarySourceState
}

struct SettingsSourceSnapshot {
    let importedSources: [PinballImportedSourceRecord]
    let sourceState: PinballLibrarySourceState
}

func loadSettingsDataSnapshot() async throws -> SettingsDataSnapshot {
    SettingsDataSnapshot(
        manufacturers: try await loadHostedCatalogManufacturerOptions(),
        importedSources: PinballImportedSourcesStore.load(),
        sourceState: PinballLibrarySourceStateStore.load()
    )
}

func forceRefreshHostedSettingsData() async throws -> SettingsDataSnapshot {
    try await PinballDataCache.shared.forceRefreshHostedLibraryData()
    return try await loadSettingsDataSnapshot()
}

func addManufacturerSource(_ manufacturer: PinballCatalogManufacturerOption) -> SettingsSourceSnapshot {
    let sourceID = "manufacturer--\(manufacturer.id)"
    let record = PinballImportedSourceRecord(
        id: sourceID,
        name: manufacturer.name,
        type: .manufacturer,
        provider: .opdb,
        providerSourceID: manufacturer.id,
        machineIDs: [],
        lastSyncedAt: Date(),
        searchQuery: nil,
        distanceMiles: nil
    )
    PinballImportedSourcesStore.upsert(record)
    PinballLibrarySourceStateStore.upsertSource(id: sourceID, enable: true, pinIfPossible: true)
    return settingsSourceSnapshot()
}

func addVenueSource(
    result: PinballLibraryVenueSearchResult,
    machineIDs: [String],
    searchQuery: String,
    radiusMiles: Int
) -> SettingsSourceSnapshot {
    let locationID = result.id.replacingOccurrences(of: "venue--pm-", with: "")
    let record = PinballImportedSourceRecord(
        id: result.id,
        name: result.name,
        type: .venue,
        provider: .pinballMap,
        providerSourceID: locationID,
        machineIDs: machineIDs,
        lastSyncedAt: Date(),
        searchQuery: searchQuery,
        distanceMiles: radiusMiles
    )
    PinballImportedSourcesStore.upsert(record)
    PinballLibrarySourceStateStore.upsertSource(id: result.id, enable: true, pinIfPossible: true)
    return settingsSourceSnapshot()
}

func addTournamentSource(_ result: MatchPlayTournamentImportResult) -> SettingsSourceSnapshot {
    let sourceID = "tournament--mp-\(result.id)"
    let record = PinballImportedSourceRecord(
        id: sourceID,
        name: result.name,
        type: .tournament,
        provider: .matchPlay,
        providerSourceID: result.id,
        machineIDs: result.machineIDs,
        lastSyncedAt: Date(),
        searchQuery: nil,
        distanceMiles: nil
    )
    PinballImportedSourcesStore.upsert(record)
    PinballLibrarySourceStateStore.upsertSource(id: sourceID, enable: true, pinIfPossible: true)
    return settingsSourceSnapshot()
}

func removeSettingsSource(_ sourceID: String) -> SettingsSourceSnapshot {
    PinballImportedSourcesStore.remove(id: sourceID)
    return settingsSourceSnapshot()
}

func refreshVenueSource(_ source: PinballImportedSourceRecord) async throws -> SettingsSourceSnapshot {
    let machineIDs = try await PinballMapClient.fetchVenueMachineIDs(locationID: source.providerSourceID)
    var updated = source
    updated.machineIDs = machineIDs
    updated.lastSyncedAt = Date()
    PinballImportedSourcesStore.upsert(updated)
    return settingsSourceSnapshot()
}

func refreshTournamentSource(_ source: PinballImportedSourceRecord) async throws -> SettingsSourceSnapshot {
    let tournament = try await MatchPlayClient.fetchTournament(id: source.providerSourceID)
    var updated = source
    updated.name = tournament.name
    updated.machineIDs = tournament.machineIDs
    updated.lastSyncedAt = Date()
    PinballImportedSourcesStore.upsert(updated)
    return settingsSourceSnapshot()
}

private func settingsSourceSnapshot() -> SettingsSourceSnapshot {
    SettingsSourceSnapshot(
        importedSources: PinballImportedSourcesStore.load(),
        sourceState: PinballLibrarySourceStateStore.load()
    )
}
