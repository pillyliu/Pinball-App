import Foundation

private enum LibraryDataLoader {
    static let libraryPath = "/pinball/data/pinball_library_v3.json"
    static let opdbCatalogPath = "/pinball/data/opdb_catalog_v1.json"
    static let hostedRefreshInterval: TimeInterval = 24 * 60 * 60
}

func loadLibraryExtraction() async throws -> LegacyCatalogExtraction {
    do {
        return try await loadHostedLibraryExtraction()
    } catch {
        if let bundled = try loadBundledLibraryExtraction() {
            return bundled
        }
        return try await LibrarySeedDatabase.shared.loadExtraction()
    }
}

private func loadHostedLibraryExtraction() async throws -> LegacyCatalogExtraction {
    async let libraryResult = PinballDataCache.shared.loadText(
        path: LibraryDataLoader.libraryPath,
        allowMissing: false,
        maxCacheAge: LibraryDataLoader.hostedRefreshInterval
    )
    async let opdbResult = PinballDataCache.shared.loadText(
        path: LibraryDataLoader.opdbCatalogPath,
        allowMissing: true,
        maxCacheAge: LibraryDataLoader.hostedRefreshInterval
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
    return try decodeLibraryPayloadWithState(data: libraryData)
}

private func loadBundledLibraryExtraction() throws -> LegacyCatalogExtraction? {
    guard let bundledLibraryText = try loadBundledPinballText(path: LibraryDataLoader.libraryPath),
          let bundledLibraryData = bundledLibraryText.data(using: .utf8) else {
        return nil
    }
    if let bundledOPDBText = try loadBundledPinballText(path: LibraryDataLoader.opdbCatalogPath),
       let bundledOPDBData = bundledOPDBText.data(using: .utf8),
       !bundledOPDBData.isEmpty {
        return try decodeMergedLibraryPayloadWithState(libraryData: bundledLibraryData, opdbCatalogData: bundledOPDBData)
    }
    return try decodeLibraryPayloadWithState(data: bundledLibraryData)
}
