import Foundation
import SQLite3

actor LibrarySeedDatabase {
    static let shared = LibrarySeedDatabase()

    func loadExtraction() async throws -> LegacyCatalogExtraction {
        let payload = try await loadSeedPayload()
        let state = await MainActor.run { PinballLibrarySourceStateStore.synchronize(with: payload.sources) }
        let enabled = Set(state.enabledSourceIDs)
        let filteredSources = payload.sources.filter { enabled.contains($0.id) }
        let filteredSourceIDs = Set(filteredSources.map(\.id))
        let filteredGames = payload.games.filter { filteredSourceIDs.contains($0.sourceId) }
        return LegacyCatalogExtraction(payload: PinballLibraryPayload(games: filteredGames, sources: filteredSources), state: state)
    }

    func loadManufacturerOptions() async throws -> [PinballCatalogManufacturerOption] {
        try withReadOnlyDatabase { database in
            try loadManufacturerOptionsRows(database)
        }
    }

    func loadSeedPayload() async throws -> PinballLibraryPayload {
        let importedSources = await MainActor.run { PinballImportedSourcesStore.load() }
        return try withReadOnlyDatabase { database in
            let builtInSources = try loadBuiltInSources(database)
            let builtInGames = try loadBuiltInGames(database)
            let importedGames = try loadImportedGames(database, importedSources: importedSources)

            return PinballLibraryPayload(
                games: builtInGames + importedGames,
                sources: dedupedSources(builtInSources + importedSources.map {
                    PinballLibrarySource(id: $0.id, name: $0.name, type: $0.type)
                })
            )
        }
    }

    private func dedupedSources(_ sources: [PinballLibrarySource]) -> [PinballLibrarySource] {
        var seen = Set<String>()
        return sources.filter { seen.insert($0.id).inserted }
    }
}
