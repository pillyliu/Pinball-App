import Foundation

nonisolated let hostedLibraryPath = "/pinball/data/pinball_library_v3.json"
nonisolated let hostedOPDBCatalogPath = "/pinball/data/opdb_catalog_v1.json"
nonisolated let hostedLibraryCatalogPaths = [
    hostedLibraryPath,
    hostedOPDBCatalogPath,
]

private let hostedLibraryRefreshInterval: TimeInterval = 24 * 60 * 60

func loadHostedLibraryExtraction() async throws -> LegacyCatalogExtraction {
    async let libraryResult = PinballDataCache.shared.loadText(
        path: hostedLibraryPath,
        allowMissing: false,
        maxCacheAge: hostedLibraryRefreshInterval
    )
    async let opdbResult = PinballDataCache.shared.loadText(
        path: hostedOPDBCatalogPath,
        allowMissing: true,
        maxCacheAge: hostedLibraryRefreshInterval
    )
    let (libraryCached, opdbCached) = try await (libraryResult, opdbResult)
    guard let libraryText = libraryCached.text,
          let libraryData = libraryText.data(using: .utf8) else {
        throw URLError(.cannotDecodeRawData)
    }
    if let opdbText = opdbCached.text,
       let opdbData = opdbText.data(using: .utf8),
       !opdbData.isEmpty {
        return try decodeMergedLibraryPayloadWithState(libraryData: libraryData, opdbCatalogData: opdbData)
    }
    if let bundledOPDBText = try loadBundledPinballText(path: hostedOPDBCatalogPath),
       let bundledOPDBData = bundledOPDBText.data(using: .utf8),
       !bundledOPDBData.isEmpty {
        return try decodeMergedLibraryPayloadWithState(libraryData: libraryData, opdbCatalogData: bundledOPDBData)
    }
    return try await LibrarySeedDatabase.shared.loadExtraction()
}

func loadBundledLibraryExtraction() throws -> LegacyCatalogExtraction? {
    guard let bundledLibraryText = try loadBundledPinballText(path: hostedLibraryPath),
          let bundledLibraryData = bundledLibraryText.data(using: .utf8) else {
        return nil
    }
    if let bundledOPDBText = try loadBundledPinballText(path: hostedOPDBCatalogPath),
       let bundledOPDBData = bundledOPDBText.data(using: .utf8),
       !bundledOPDBData.isEmpty {
        return try decodeMergedLibraryPayloadWithState(libraryData: bundledLibraryData, opdbCatalogData: bundledOPDBData)
    }
    return try decodeLibraryPayloadWithState(data: bundledLibraryData)
}

func loadHostedCatalogManufacturerOptions() async throws -> [PinballCatalogManufacturerOption] {
    let cached = try await PinballDataCache.shared.loadText(path: hostedOPDBCatalogPath, allowMissing: true)
    if let opdbText = cached.text,
       let opdbData = opdbText.data(using: .utf8),
       !opdbData.isEmpty {
        return try decodeCatalogManufacturerOptions(data: opdbData)
    }

    do {
        return try await LibrarySeedDatabase.shared.loadManufacturerOptions()
    } catch {
        if let bundledText = try loadBundledPinballText(path: hostedOPDBCatalogPath),
           let bundledData = bundledText.data(using: .utf8),
           !bundledData.isEmpty {
            return try decodeCatalogManufacturerOptions(data: bundledData)
        }
        return []
    }
}
