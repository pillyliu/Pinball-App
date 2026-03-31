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

    let baseURL = URL(string: "https://pillyliu.com")!
    private let manifestURL = URL(string: "https://pillyliu.com/pinball/cache-manifest.json")!
    private let updateLogURL = URL(string: "https://pillyliu.com/pinball/cache-update-log.json")!
    private let metadataRefreshInterval: TimeInterval = 300
    let backgroundRevalidateInterval: TimeInterval = 180
    private let remoteImageDiskRevalidateInterval: TimeInterval = 6 * 60 * 60
    private let remoteImageDiskCacheSizeLimit: Int64 = 512 * 1024 * 1024
    private let legacyCacheResetMarkerName = "legacy-cache-reset-v3-assets-v1"

    private var isLoaded = false
    var index = PinballCacheIndex()
    var manifest: PinballCacheManifest?
    var cacheGeneration: UInt64 = 0
    var inFlightRevalidations: [String: UInt64] = [:]
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

    func loadRemoteImageData(url: URL) async throws -> Data {
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

    func cachedText(for path: String) throws -> CachedTextResult? {
        guard let data = try cachedData(for: path) else { return nil }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else { return nil }

        return CachedTextResult(
            text: text,
            isMissing: false,
            updatedAt: cachedFileUpdatedAt(for: path)
        )
    }

    func cachedData(for path: String) throws -> Data? {
        if index.resources[path]?.missing == true {
            try? fileManager.removeItem(at: fileURL(for: path))
        }

        let url = fileURL(for: path)
        if fileManager.fileExists(atPath: url.path) {
            return try Data(contentsOf: url)
        }
        return nil
    }

    func write(data: Data, for path: String) throws {
        let url = fileURL(for: path)
        let dir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: url, options: .atomic)
    }

    func cachedFileUpdatedAt(for path: String) -> Date? {
        let url = fileURL(for: path)
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date else {
            return nil
        }
        return modified
    }

    func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func refreshMetadataIfNeeded(force: Bool) async throws {
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

    func ensureLoaded() async throws {
        guard !isLoaded else { return }

        let root = cacheRootURL()
        try PinballDataCacheBootstrapSupport.ensureCacheRootExists(root, fileManager: fileManager)
        let didReset = try PinballDataCacheBootstrapSupport.purgeLegacyCachedPinballAssetsIfNeeded(
            root: root,
            markerName: legacyCacheResetMarkerName,
            fileManager: fileManager
        )
        if didReset {
            cacheGeneration &+= 1
            index = PinballCacheIndex()
            manifest = nil
            inFlightRevalidations.removeAll()
            inFlightRemoteImageRevalidations.removeAll()
        }

        if let saved = PinballDataCacheBootstrapSupport.loadSavedIndex(from: root, decoder: decoder) {
            index = saved
        }

        let didSeed = try PinballDataCacheBootstrapSupport.seedBundledPreloadIfNeeded(
            index: &index,
            now: Date().timeIntervalSince1970,
            fileManager: fileManager,
            writeData: { [self] data, path in
                try write(data: data, for: path)
            }
        )
        if didSeed {
            try persistIndex()
        }

        isLoaded = true

        Task.detached(priority: .utility) {
            await PinballDataCache.shared.refreshMetadataBestEffort(force: true)
        }
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

    func persistIndex() throws {
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

    func normalize(_ path: String) -> String {
        normalizedPinballCachePath(path)
    }

    func shouldUseManifestCache(for url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "pillyliu.com" && url.path.hasPrefix("/pinball/")
    }
}
