import Foundation

extension PinballDataCache {
    func refreshHostedResourcesIfNeeded(
        targets: [(path: String, allowMissing: Bool)],
        forceMetadataRefresh: Bool = true
    ) async throws -> Set<String> {
        try await ensureLoaded()

        let trackedPaths = Set(targets.map { normalize($0.path) })
        let removedPaths = try await refreshMetadataIfNeeded(force: forceMetadataRefresh)
        var changedPaths = Set(removedPaths.filter(trackedPaths.contains))

        for target in targets {
            let normalizedPath = normalize(target.path)
            if changedPaths.contains(normalizedPath) {
                continue
            }
            guard try hostedResourceNeedsRefresh(path: normalizedPath, allowMissing: target.allowMissing) else {
                continue
            }

            let previousData = try cachedData(for: normalizedPath)
            _ = try await fetchBinaryFromNetwork(
                path: normalizedPath,
                allowMissing: target.allowMissing,
                allowStaleOnFailure: false
            )
            let refreshedData = try cachedData(for: normalizedPath)
            if previousData != refreshedData {
                changedPaths.insert(normalizedPath)
            }
        }

        return changedPaths
    }

    func hasRemoteUpdate(path: String) async throws -> Bool {
        try await ensureLoaded()
        let normalizedPath = normalize(path)
        _ = try await refreshMetadataIfNeeded(force: true)

        guard let remoteHash = manifest?.files[normalizedPath]?.hash else {
            return false
        }
        guard let localData = try cachedData(for: normalizedPath) else {
            return false
        }
        return sha256Hex(localData) != remoteHash
    }

    func loadData(url: URL) async throws -> Data {
        try await ensureLoaded()

        guard shouldUseManifestCache(for: url) else {
            return try await loadRemoteImageData(url: url)
        }

        let path = normalize(url.path)
        if let cached = try cachedData(for: path) {
            scheduleRevalidateIfNeeded(path: path, allowMissing: false)
            return cached
        }

        let fetched = try await fetchBinaryFromNetwork(path: path, allowMissing: false)
        guard let data = fetched else {
            throw URLError(.resourceUnavailable)
        }
        return data
    }

    func revalidate(path: String, allowMissing: Bool) async {
        do {
            _ = try await fetchBinaryFromNetwork(path: path, allowMissing: allowMissing)
        } catch {
            // Keep stale data on revalidation failures.
        }
    }

    func scheduleRevalidateIfNeeded(path: String, allowMissing: Bool) {
        let now = Date().timeIntervalSince1970
        if let resource = index.resources[path],
           now - resource.lastValidatedAt < backgroundRevalidateInterval {
            return
        }
        if inFlightRevalidations[path] != nil {
            return
        }

        let generation = cacheGeneration
        inFlightRevalidations[path] = generation
        Task.detached(priority: .utility) {
            await PinballDataCache.shared.runRevalidate(path: path, allowMissing: allowMissing, generation: generation)
        }
    }

    func runRevalidate(path: String, allowMissing: Bool, generation: UInt64) async {
        defer { finishRevalidate(path: path, generation: generation) }
        await revalidate(path: path, allowMissing: allowMissing)
    }

    func fetchTextFromNetwork(path: String, allowMissing: Bool, allowStaleOnFailure: Bool = true) async throws -> CachedTextResult {
        let data = try await fetchBinaryFromNetwork(path: path, allowMissing: allowMissing, allowStaleOnFailure: allowStaleOnFailure)
        if data == nil {
            return CachedTextResult(text: nil, isMissing: true, updatedAt: nil)
        }

        guard let data,
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            throw URLError(.cannotDecodeRawData)
        }

        return CachedTextResult(
            text: text,
            isMissing: false,
            updatedAt: cachedFileUpdatedAt(for: path)
        )
    }

    func fetchBinaryFromNetwork(path: String, allowMissing: Bool, allowStaleOnFailure: Bool = true) async throws -> Data? {
        let expectedGeneration = cacheGeneration
        do {
            _ = try await refreshMetadataIfNeeded(force: false)
        } catch {
            // Metadata refresh should not block serving cached/offline-first data.
        }

        if let manifest,
           manifest.files[path] == nil,
           allowMissing {
            try markResourceMissing(path: path, validatedAt: Date().timeIntervalSince1970, expectedGeneration: expectedGeneration)
            return nil
        }

        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 404, allowMissing {
                    try markResourceMissing(path: path, validatedAt: Date().timeIntervalSince1970, expectedGeneration: expectedGeneration)
                    return nil
                }
                if !(200...299).contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
            }

            try storeFetchedResource(
                data: data,
                path: path,
                manifestHash: manifest?.files[path]?.hash,
                validatedAt: Date().timeIntervalSince1970,
                expectedGeneration: expectedGeneration
            )
            return data
        } catch {
            if allowStaleOnFailure, let stale = try cachedData(for: path) {
                return stale
            }
            throw error
        }
    }

    func finishRevalidate(path: String, generation: UInt64) {
        guard inFlightRevalidations[path] == generation else { return }
        inFlightRevalidations.removeValue(forKey: path)
    }

    private func hostedResourceNeedsRefresh(path: String, allowMissing: Bool) throws -> Bool {
        if let remoteHash = manifest?.files[path]?.hash {
            guard let localData = try cachedData(for: path) else {
                return true
            }
            return sha256Hex(localData) != remoteHash
        }

        return !allowMissing
    }

    func markResourceMissing(path: String, validatedAt: TimeInterval, expectedGeneration: UInt64) throws {
        guard cacheGeneration == expectedGeneration else { return }
        index.resources[path] = PinballCacheIndex.Resource(
            path: path,
            hash: nil,
            lastValidatedAt: validatedAt,
            missing: true
        )
        try persistIndex()
    }

    func storeFetchedResource(
        data: Data,
        path: String,
        manifestHash: String?,
        validatedAt: TimeInterval,
        expectedGeneration: UInt64
    ) throws {
        guard cacheGeneration == expectedGeneration else { return }
        try write(data: data, for: path)
        index.resources[path] = PinballCacheIndex.Resource(
            path: path,
            hash: manifestHash,
            lastValidatedAt: validatedAt,
            missing: false
        )
        try persistIndex()
    }
}
