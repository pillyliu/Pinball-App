import Foundation

enum PinballCacheMetadataSupport {
    nonisolated struct Refresh {
        let manifest: PinballCacheManifest
        let updateLog: PinballCacheUpdateLog
        let fetchedAt: TimeInterval
    }

    nonisolated static func shouldRefresh(
        lastFetchedAt: TimeInterval?,
        now: TimeInterval,
        refreshInterval: TimeInterval,
        force: Bool
    ) -> Bool {
        guard !force else { return true }
        guard let lastFetchedAt else { return true }
        return now - lastFetchedAt >= refreshInterval
    }

    nonisolated static func fetchRefresh(
        manifestURL: URL,
        updateLogURL: URL,
        decoder: JSONDecoder
    ) async throws -> Refresh {
        let fetchedAt = Date().timeIntervalSince1970

        async let manifestDataTask = URLSession.shared.data(from: manifestURL)
        async let updateDataTask = URLSession.shared.data(from: updateLogURL)

        let (manifestData, manifestResponse) = try await manifestDataTask
        let (updateData, updateResponse) = try await updateDataTask

        if let http = manifestResponse as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        if let http = updateResponse as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return Refresh(
            manifest: try decoder.decode(PinballCacheManifest.self, from: manifestData),
            updateLog: try decoder.decode(PinballCacheUpdateLog.self, from: updateData),
            fetchedAt: fetchedAt
        )
    }

    nonisolated static func applyRefresh(
        _ refresh: Refresh,
        to index: inout PinballCacheIndex
    ) -> [String] {
        let lastScan = index.lastUpdateScanAt
        let updatedEvents = refresh.updateLog.events.filter { event in
            guard let lastScan else { return true }
            return event.generatedAt > lastScan
        }

        index.lastMetaFetchAt = refresh.fetchedAt
        index.lastManifestGeneratedAt = refresh.manifest.generatedAt
        index.lastUpdateScanAt = pinballCacheLatestUpdateScanAt(
            eventGeneratedAts: refresh.updateLog.events.map(\.generatedAt),
            existingLastScan: lastScan
        )

        return updatedEvents.flatMap(\.removed)
    }
}
