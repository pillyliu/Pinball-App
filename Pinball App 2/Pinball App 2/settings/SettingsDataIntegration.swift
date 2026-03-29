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
    notifyLeaguePreviewNeedsRefresh()
    return try await loadSettingsDataSnapshot()
}

func clearAppRuntimeCaches() async throws {
    try await PinballDataCache.shared.clearAllCachedData()
    try await RemoteRulesheetLoader.clearCache()
    RemoteUIImageMemoryCache.shared.removeAll()
    URLCache.shared.removeAllCachedResponses()
}

func addManufacturerSource(_ manufacturer: PinballCatalogManufacturerOption) -> SettingsSourceSnapshot {
    persistSettingsSource(
        PinballImportedSourceRecord(
            id: "manufacturer--\(manufacturer.id)",
            name: manufacturer.name,
            type: .manufacturer,
            provider: .opdb,
            providerSourceID: manufacturer.id,
            machineIDs: [],
            lastSyncedAt: Date(),
            searchQuery: nil,
            distanceMiles: nil
        )
    )
}

func addVenueSource(
    result: PinballLibraryVenueSearchResult,
    machineIDs: [String],
    searchQuery: String,
    radiusMiles: Int
) -> SettingsSourceSnapshot {
    persistSettingsSource(
        PinballImportedSourceRecord(
            id: result.id,
            name: result.name,
            type: .venue,
            provider: .pinballMap,
            providerSourceID: venueProviderSourceID(result.id),
            machineIDs: machineIDs,
            lastSyncedAt: Date(),
            searchQuery: searchQuery,
            distanceMiles: radiusMiles
        )
    )
}

func addTournamentSource(_ result: MatchPlayTournamentImportResult) -> SettingsSourceSnapshot {
    persistSettingsSource(
        PinballImportedSourceRecord(
            id: "tournament--mp-\(result.id)",
            name: result.name,
            type: .tournament,
            provider: .matchPlay,
            providerSourceID: result.id,
            machineIDs: result.machineIDs,
            lastSyncedAt: Date(),
            searchQuery: nil,
            distanceMiles: nil
        )
    )
}

func removeSettingsSource(_ sourceID: String) -> SettingsSourceSnapshot {
    PinballImportedSourcesStore.remove(id: sourceID)
    return settingsSourceSnapshot()
}

func refreshVenueSource(_ source: PinballImportedSourceRecord) async throws -> SettingsSourceSnapshot {
    let machineIDs = try await PinballMapClient.fetchVenueMachineIDs(locationID: source.providerSourceID)
    return updateSettingsSource(source) { updated in
        updated.machineIDs = machineIDs
        updated.lastSyncedAt = Date()
    }
}

func refreshTournamentSource(_ source: PinballImportedSourceRecord) async throws -> SettingsSourceSnapshot {
    let tournament = try await MatchPlayClient.fetchTournament(id: source.providerSourceID)
    return updateSettingsSource(source) { updated in
        updated.name = tournament.name
        updated.machineIDs = tournament.machineIDs
        updated.lastSyncedAt = Date()
    }
}

private func persistSettingsSource(
    _ record: PinballImportedSourceRecord,
    enableAndPin: Bool = true
) -> SettingsSourceSnapshot {
    PinballImportedSourcesStore.upsert(record)
    if enableAndPin {
        PinballLibrarySourceStateStore.upsertSource(id: record.id, enable: true, pinIfPossible: true)
    }
    return settingsSourceSnapshot()
}

private func updateSettingsSource(
    _ source: PinballImportedSourceRecord,
    update: (inout PinballImportedSourceRecord) -> Void
) -> SettingsSourceSnapshot {
    var updated = source
    update(&updated)
    PinballImportedSourcesStore.upsert(updated)
    return settingsSourceSnapshot()
}

private func venueProviderSourceID(_ sourceID: String) -> String {
    sourceID.replacingOccurrences(of: "venue--pm-", with: "")
}

private func settingsSourceSnapshot() -> SettingsSourceSnapshot {
    SettingsSourceSnapshot(
        importedSources: PinballImportedSourcesStore.load(),
        sourceState: PinballLibrarySourceStateStore.load()
    )
}
