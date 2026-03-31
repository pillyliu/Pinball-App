import Foundation
import CryptoKit

struct CachedTextResult {
    let text: String?
    let isMissing: Bool
    let updatedAt: Date?
}

actor PinballDataCache {
    static let shared = PinballDataCache()

    private actor RequestLimiter {
        private let limit: Int
        private var inFlight = 0
        private var waiters: [CheckedContinuation<Void, Never>] = []

        init(limit: Int) {
            self.limit = max(1, limit)
        }

        func acquire() async {
            if inFlight < limit {
                inFlight += 1
                return
            }

            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        func release() {
            if let waiter = waiters.first {
                waiters.removeFirst()
                waiter.resume()
                return
            }

            inFlight = max(0, inFlight - 1)
        }
    }

    private let baseURL = URL(string: "https://pillyliu.com")!
    private let manifestURL = URL(string: "https://pillyliu.com/pinball/cache-manifest.json")!
    private let updateLogURL = URL(string: "https://pillyliu.com/pinball/cache-update-log.json")!
    private let metadataRefreshInterval: TimeInterval = 300
    private let backgroundRevalidateInterval: TimeInterval = 180
    private let remoteImageDiskRevalidateInterval: TimeInterval = 6 * 60 * 60
    private let remoteImageDiskCacheSizeLimit: Int64 = 512 * 1024 * 1024
    private let legacyCacheResetMarkerName = "legacy-cache-reset-v3-assets-v1"

    private var isLoaded = false
    private var index = PinballCacheIndex()
    private var manifest: PinballCacheManifest?
    private var cacheGeneration: UInt64 = 0
    private var inFlightRevalidations: [String: UInt64] = [:]
    private var inFlightRemoteImageRevalidations: [String: UInt64] = [:]
    private let remoteImageLimiter = RequestLimiter(limit: 8)

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    func loadText(path: String, allowMissing: Bool = false) async throws -> CachedTextResult {
        try await ensureLoaded()
        let normalizedPath = normalize(path)

        if let cached = try cachedText(for: normalizedPath) {
            scheduleRevalidateIfNeeded(path: normalizedPath, allowMissing: allowMissing)
            return cached
        }

        return try await fetchTextFromNetwork(path: normalizedPath, allowMissing: allowMissing)
    }

    func forceRefreshText(path: String, allowMissing: Bool = false) async throws -> CachedTextResult {
        try await ensureLoaded()
        let normalizedPath = normalize(path)
        return try await fetchTextFromNetwork(path: normalizedPath, allowMissing: allowMissing, allowStaleOnFailure: false)
    }

    func forceRefreshHostedLibraryData() async throws {
        try await ensureLoaded()
        try await refreshMetadataIfNeeded(force: true)
        for target in hostedPinballRefreshTargets {
            _ = try await fetchBinaryFromNetwork(
                path: target.path,
                allowMissing: target.allowMissing,
                allowStaleOnFailure: false
            )
        }
    }

    func clearAllCachedData() async throws {
        try await ensureLoaded()

        let root = cacheRootURL()
        let resourcesURL = root.appendingPathComponent("resources", isDirectory: true)
        let remoteImagesURL = root.appendingPathComponent("remote-images", isDirectory: true)
        let indexURL = root.appendingPathComponent("cache-index.json")

        if fileManager.fileExists(atPath: resourcesURL.path) {
            try? fileManager.removeItem(at: resourcesURL)
        }
        if fileManager.fileExists(atPath: remoteImagesURL.path) {
            try? fileManager.removeItem(at: remoteImagesURL)
        }
        if fileManager.fileExists(atPath: indexURL.path) {
            try? fileManager.removeItem(at: indexURL)
        }

        cacheGeneration &+= 1
        index = PinballCacheIndex()
        manifest = nil
        inFlightRevalidations.removeAll()
        inFlightRemoteImageRevalidations.removeAll()

        try fileManager.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        try persistIndex()
    }

    func loadText(path: String, allowMissing: Bool = false, maxCacheAge: TimeInterval) async throws -> CachedTextResult {
        try await ensureLoaded()
        let normalizedPath = normalize(path)

        if let resource = index.resources[normalizedPath],
           resource.missing,
           Date().timeIntervalSince1970 - resource.lastValidatedAt < maxCacheAge {
            return CachedTextResult(text: nil, isMissing: true, updatedAt: nil)
        }

        if let cached = try cachedText(for: normalizedPath),
           let updatedAt = cached.updatedAt,
           Date().timeIntervalSince(updatedAt) < maxCacheAge {
            return cached
        }

        return try await fetchTextFromNetwork(path: normalizedPath, allowMissing: allowMissing)
    }

    func hasRemoteUpdate(path: String) async throws -> Bool {
        try await ensureLoaded()
        let normalizedPath = normalize(path)
        try await refreshMetadataIfNeeded(force: true)

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

    private func loadRemoteImageData(url: URL) async throws -> Data {
        if let cached = try cachedRemoteImageData(for: url) {
            scheduleRemoteImageRevalidateIfNeeded(url: url)
            return cached
        }

        return try await fetchRemoteImageFromNetwork(url: url, allowStaleOnFailure: false)
    }

    private func fetchRemoteImageFromNetwork(url: URL, allowStaleOnFailure: Bool = true) async throws -> Data {
        let expectedGeneration = cacheGeneration
        await remoteImageLimiter.acquire()
        defer {
            Task {
                await remoteImageLimiter.release()
            }
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            try writeRemoteImage(data: data, for: url, expectedGeneration: expectedGeneration)
            return data
        } catch {
            if allowStaleOnFailure, let stale = try cachedRemoteImageData(for: url) {
                return stale
            }
            throw error
        }
    }

    private func scheduleRemoteImageRevalidateIfNeeded(url: URL) {
        let key = remoteImageCacheKey(for: url)
        guard let updatedAt = remoteImageFileUpdatedAt(for: url),
              Date().timeIntervalSince(updatedAt) >= remoteImageDiskRevalidateInterval else {
            return
        }
        if inFlightRemoteImageRevalidations[key] != nil {
            return
        }

        let generation = cacheGeneration
        inFlightRemoteImageRevalidations[key] = generation
        Task.detached(priority: .utility) {
            await PinballDataCache.shared.runRemoteImageRevalidate(url: url, generation: generation)
        }
    }

    private func runRemoteImageRevalidate(url: URL, generation: UInt64) async {
        defer { finishRemoteImageRevalidate(url: url, generation: generation) }
        do {
            _ = try await fetchRemoteImageFromNetwork(url: url)
        } catch {
            // Keep stale data if revalidation fails.
        }
    }

    private func revalidate(path: String, allowMissing: Bool) async {
        do {
            _ = try await fetchBinaryFromNetwork(path: path, allowMissing: allowMissing)
        } catch {
            // Keep stale data on revalidation failures.
        }
    }

    private func scheduleRevalidateIfNeeded(path: String, allowMissing: Bool) {
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

    private func runRevalidate(path: String, allowMissing: Bool, generation: UInt64) async {
        defer { finishRevalidate(path: path, generation: generation) }
        await revalidate(path: path, allowMissing: allowMissing)
    }

    private func fetchTextFromNetwork(path: String, allowMissing: Bool, allowStaleOnFailure: Bool = true) async throws -> CachedTextResult {
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

    private func fetchBinaryFromNetwork(path: String, allowMissing: Bool, allowStaleOnFailure: Bool = true) async throws -> Data? {
        let expectedGeneration = cacheGeneration
        do {
            try await refreshMetadataIfNeeded(force: false)
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

    private func cachedText(for path: String) throws -> CachedTextResult? {
        guard let data = try cachedData(for: path) else { return nil }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else { return nil }

        return CachedTextResult(
            text: text,
            isMissing: false,
            updatedAt: cachedFileUpdatedAt(for: path)
        )
    }

    private func cachedData(for path: String) throws -> Data? {
        if index.resources[path]?.missing == true {
            try? fileManager.removeItem(at: fileURL(for: path))
        }

        let url = fileURL(for: path)
        if fileManager.fileExists(atPath: url.path) {
            return try Data(contentsOf: url)
        }
        return nil
    }

    private func write(data: Data, for path: String) throws {
        let url = fileURL(for: path)
        let dir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: url, options: .atomic)
    }

    private func cachedFileUpdatedAt(for path: String) -> Date? {
        let url = fileURL(for: path)
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date else {
            return nil
        }
        return modified
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func refreshMetadataIfNeeded(force: Bool) async throws {
        let now = Date().timeIntervalSince1970
        guard PinballCacheMetadataSupport.shouldRefresh(
            lastFetchedAt: index.lastMetaFetchAt,
            now: now,
            refreshInterval: metadataRefreshInterval,
            force: force
        ) else {
            return
        }

        let refresh = try await PinballCacheMetadataSupport.fetchRefresh(
            manifestURL: manifestURL,
            updateLogURL: updateLogURL,
            decoder: decoder
        )
        manifest = refresh.manifest

        let removedPaths = PinballCacheMetadataSupport.applyRefresh(refresh, to: &index)
        for removed in removedPaths {
            try? fileManager.removeItem(at: fileURL(for: removed))
            index.resources[removed] = PinballCacheIndex.Resource(
                path: removed,
                hash: nil,
                lastValidatedAt: refresh.fetchedAt,
                missing: true
            )
        }

        try persistIndex()
    }

    private func ensureLoaded() async throws {
        guard !isLoaded else { return }

        let root = cacheRootURL()
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        try purgeLegacyCachedPinballAssetsIfNeeded(root: root)

        if let saved = loadPinballCacheIndex(from: root, decoder: decoder) {
            index = saved
        }

        try seedBundledPreloadIntoCacheIfNeeded()

        isLoaded = true

        Task.detached(priority: .utility) {
            await PinballDataCache.shared.refreshMetadataBestEffort(force: true)
        }
    }

    private func seedBundledPreloadIntoCacheIfNeeded() throws {
        guard let preloadManifest = bundledPinballPreloadManifest() else { return }

        let now = Date().timeIntervalSince1970
        var didChangeIndex = false

        for rawPath in preloadManifest.paths {
            let normalizedPath = normalize(rawPath)
            if index.resources[normalizedPath]?.missing == true {
                index.resources[normalizedPath] = PinballCacheIndex.Resource(
                    path: normalizedPath,
                    hash: index.resources[normalizedPath]?.hash,
                    lastValidatedAt: now,
                    missing: false
                )
                didChangeIndex = true
            }

            let targetURL = fileURL(for: normalizedPath)
            if fileManager.fileExists(atPath: targetURL.path) {
                continue
            }

            guard let sourceURL = bundledPinballPreloadFileURL(path: normalizedPath) else {
                throw NSError(
                    domain: "PinballPreload",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Missing bundled preload file for \(normalizedPath)"]
                )
            }

            let data = try Data(contentsOf: sourceURL)
            try write(data: data, for: normalizedPath)
            index.resources[normalizedPath] = PinballCacheIndex.Resource(
                path: normalizedPath,
                hash: index.resources[normalizedPath]?.hash,
                lastValidatedAt: now,
                missing: false
            )
            didChangeIndex = true
        }

        if didChangeIndex {
            try persistIndex()
        }
    }

    private func purgeLegacyCachedPinballAssetsIfNeeded(root: URL) throws {
        let markerURL = root.appendingPathComponent(legacyCacheResetMarkerName)
        guard !fileManager.fileExists(atPath: markerURL.path) else { return }

        let resourcesURL = root.appendingPathComponent("resources", isDirectory: true)
        let indexURL = root.appendingPathComponent("cache-index.json")

        if fileManager.fileExists(atPath: resourcesURL.path) {
            try? fileManager.removeItem(at: resourcesURL)
        }
        if fileManager.fileExists(atPath: indexURL.path) {
            try? fileManager.removeItem(at: indexURL)
        }

        cacheGeneration &+= 1
        index = PinballCacheIndex()
        manifest = nil
        inFlightRevalidations.removeAll()
        inFlightRemoteImageRevalidations.removeAll()

        try Data("ok".utf8).write(to: markerURL, options: .atomic)
    }

    private func refreshMetadataBestEffort(force: Bool) async {
        do {
            try await refreshMetadataIfNeeded(force: force)
        } catch {
            // Allow offline/slow-network startup without stalling UI.
        }
    }

    func refreshMetadataFromForeground() async {
        await refreshMetadataBestEffort(force: true)
    }

    private func persistIndex() throws {
        try persistPinballCacheIndex(index, cacheRootURL: cacheRootURL(), encoder: encoder)
    }

    private func cacheRootURL() -> URL {
        pinballCacheRootURL(fileManager: fileManager)
    }

    private func remoteImagesRootURL() -> URL {
        cacheRootURL().appendingPathComponent("remote-images", isDirectory: true)
    }

    private func fileURL(for path: String) -> URL {
        pinballCachedFileURL(path: path, fileManager: fileManager)
    }

    private func remoteImageFileURL(for url: URL) -> URL {
        let ext = url.pathExtension
        let digest = remoteImageCacheKey(for: url)
        let fileName = ext.isEmpty ? digest : "\(digest).\(ext)"
        return remoteImagesRootURL().appendingPathComponent(fileName)
    }

    private func remoteImageCacheKey(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }

    private func cachedRemoteImageData(for url: URL) throws -> Data? {
        let fileURL = remoteImageFileURL(for: url)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try Data(contentsOf: fileURL)
    }

    private func remoteImageFileUpdatedAt(for url: URL) -> Date? {
        let fileURL = remoteImageFileURL(for: url)
        guard let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modified = attrs[.modificationDate] as? Date else {
            return nil
        }
        return modified
    }

    private func writeRemoteImage(data: Data, for url: URL, expectedGeneration: UInt64) throws {
        guard cacheGeneration == expectedGeneration else { return }
        let fileURL = remoteImageFileURL(for: url)
        let dir = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: fileURL, options: .atomic)
        try pruneRemoteImageCacheIfNeeded()
    }

    private func finishRemoteImageRevalidate(url: URL, generation: UInt64) {
        let key = remoteImageCacheKey(for: url)
        guard inFlightRemoteImageRevalidations[key] == generation else { return }
        inFlightRemoteImageRevalidations.removeValue(forKey: key)
    }

    private func finishRevalidate(path: String, generation: UInt64) {
        guard inFlightRevalidations[path] == generation else { return }
        inFlightRevalidations.removeValue(forKey: path)
    }

    private func markResourceMissing(path: String, validatedAt: TimeInterval, expectedGeneration: UInt64) throws {
        guard cacheGeneration == expectedGeneration else { return }
        index.resources[path] = PinballCacheIndex.Resource(path: path, hash: nil, lastValidatedAt: validatedAt, missing: true)
        try persistIndex()
    }

    private func storeFetchedResource(
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

    private func pruneRemoteImageCacheIfNeeded() throws {
        let root = remoteImagesRootURL()
        guard fileManager.fileExists(atPath: root.path) else { return }

        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let files = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        var totalSize: Int64 = 0
        var regularFiles: [(url: URL, size: Int64, modified: Date)] = []

        for file in files {
            let values = try file.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else { continue }
            let size = Int64(values.fileSize ?? 0)
            totalSize += size
            regularFiles.append((file, size, values.contentModificationDate ?? .distantPast))
        }

        guard totalSize > remoteImageDiskCacheSizeLimit else { return }

        for file in regularFiles.sorted(by: { $0.modified < $1.modified }) {
            try? fileManager.removeItem(at: file.url)
            totalSize -= file.size
            if totalSize <= remoteImageDiskCacheSizeLimit {
                break
            }
        }
    }

    private func normalize(_ path: String) -> String {
        normalizedPinballCachePath(path)
    }

    private func shouldUseManifestCache(for url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "pillyliu.com" && url.path.hasPrefix("/pinball/")
    }
}
