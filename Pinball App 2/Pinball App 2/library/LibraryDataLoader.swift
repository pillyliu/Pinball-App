import Foundation

func loadLibraryExtraction() async throws -> LibraryExtraction {
    try await loadLibraryExtraction(filterBySourceState: true)
}

func loadFullLibraryExtraction() async throws -> LibraryExtraction {
    try await loadLibraryExtraction(filterBySourceState: false)
}

func loadPracticeCatalogGames() async throws -> [PinballGame] {
    if let hostedExport = try await loadHostedOrCachedPinballJSONData(
        path: hostedOPDBExportPath,
        allowMissing: true
    ) {
        let practiceIdentityCurationsData = try await loadHostedOrCachedPinballJSONData(
            path: hostedPracticeIdentityCurationsPath,
            allowMissing: true
        )
        return try decodePracticeCatalogGamesFromOPDBExport(
            data: hostedExport,
            practiceIdentityCurationsData: practiceIdentityCurationsData
        )
    }
    return []
}

private func loadLibraryExtraction(filterBySourceState: Bool) async throws -> LibraryExtraction {
    try await loadCAFLibraryExtraction(filterBySourceState: filterBySourceState)
}

private func loadCAFLibraryExtraction(filterBySourceState: Bool) async throws -> LibraryExtraction {
    guard let opdbExportData = try await loadHostedOrCachedPinballJSONData(
        path: hostedOPDBExportPath,
        allowMissing: true
    ),
    !opdbExportData.isEmpty else {
        throw URLError(.resourceUnavailable)
    }

    async let rulesheetAssetsTask = loadHostedOrCachedPinballJSONData(
        path: hostedRulesheetAssetsPath,
        allowMissing: true
    )
    async let practiceIdentityCurationsTask = loadHostedOrCachedPinballJSONData(
        path: hostedPracticeIdentityCurationsPath,
        allowMissing: true
    )
    async let videoAssetsTask = loadHostedOrCachedPinballJSONData(
        path: hostedVideoAssetsPath,
        allowMissing: true
    )
    async let playfieldAssetsTask = loadHostedOrCachedPinballJSONData(
        path: hostedPlayfieldAssetsPath,
        allowMissing: true
    )
    async let gameinfoAssetsTask = loadHostedOrCachedPinballJSONData(
        path: hostedGameinfoAssetsPath,
        allowMissing: true
    )
    async let venueLayoutAssetsTask = loadHostedOrCachedPinballJSONData(
        path: hostedVenueLayoutAssetsPath,
        allowMissing: true
    )

    let gameRoomImport = loadGameRoomLibrarySyntheticImport()
    let importedSources = mergedImportedSources(
        PinballImportedSourcesStore.load(),
        syntheticGameRoomImport: gameRoomImport
    )
    let venueMetadataOverlays = mergeVenueMetadataOverlayIndices(
        parseCAFVenueLayoutAssets(data: try await venueLayoutAssetsTask),
        gameRoomImport?.venueMetadataOverlays ?? emptyVenueMetadataOverlayIndex
    )

    return try buildCAFLibraryExtraction(
        opdbExportData: opdbExportData,
        practiceIdentityCurationsData: try await practiceIdentityCurationsTask,
        rulesheetAssetsData: try await rulesheetAssetsTask,
        videoAssetsData: try await videoAssetsTask,
        playfieldAssetsData: try await playfieldAssetsTask,
        gameinfoAssetsData: try await gameinfoAssetsTask,
        importedSources: importedSources,
        venueMetadataOverlays: venueMetadataOverlays,
        filterBySourceState: filterBySourceState
    )
}

private func mergedImportedSources(
    _ importedSources: [PinballImportedSourceRecord],
    syntheticGameRoomImport: GameRoomLibrarySyntheticImport?
) -> [PinballImportedSourceRecord] {
    var merged = importedSources.filter { $0.id != gameRoomLibrarySourceID }
    if let syntheticGameRoomImport {
        merged.append(syntheticGameRoomImport.importedSource)
    }
    return merged
}
