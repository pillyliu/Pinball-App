import Foundation
import CryptoKit

nonisolated func loadBundledPinballData(path: String) throws -> Data? {
    let normalizedPath = path.hasPrefix("/") ? path : "/" + path
    guard normalizedPath.hasPrefix("/pinball/"),
          let starterBundleURL = Bundle.main.url(forResource: "PinballStarter", withExtension: "bundle") else {
        return nil
    }

    let relativePath = String(normalizedPath.dropFirst("/pinball/".count))
    let fileURL = starterBundleURL
        .appendingPathComponent("pinball", isDirectory: true)
        .appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        return nil
    }
    return try Data(contentsOf: fileURL)
}

nonisolated func loadBundledPinballText(path: String) throws -> String? {
    guard let data = try loadBundledPinballData(path: path) else { return nil }
    return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode)
}

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

    private struct Manifest: Decodable {
        struct Entry: Decodable {
            let hash: String
            let size: Int
            let mtimeMs: Double
            let contentType: String
        }

        let schemaVersion: Int
        let generatedAt: String
        let totalFiles: Int
        let files: [String: Entry]
    }

    private struct UpdateLog: Decodable {
        struct Event: Decodable {
            let generatedAt: String
            let addedCount: Int
            let changedCount: Int
            let removedCount: Int
            let totalFiles: Int
            let added: [String]
            let changed: [String]
            let removed: [String]
        }

        let schemaVersion: Int
        let events: [Event]
    }

    private struct CacheIndex: Codable {
        struct Resource: Codable {
            let path: String
            var hash: String?
            var lastValidatedAt: TimeInterval
            var missing: Bool
        }

        var schemaVersion: Int = 1
        var lastManifestGeneratedAt: String?
        var lastUpdateScanAt: String?
        var lastMetaFetchAt: TimeInterval?
        var resources: [String: Resource] = [:]
    }

    private let baseURL = URL(string: "https://pillyliu.com")!
    private let manifestURL = URL(string: "https://pillyliu.com/pinball/cache-manifest.json")!
    private let updateLogURL = URL(string: "https://pillyliu.com/pinball/cache-update-log.json")!
    private let metadataRefreshInterval: TimeInterval = 300
    private let backgroundRevalidateInterval: TimeInterval = 180
    private let remoteImageDiskRevalidateInterval: TimeInterval = 6 * 60 * 60
    private let remoteImageDiskCacheSizeLimit: Int64 = 512 * 1024 * 1024
    private let starterPackBundleName = "PinballStarter"
    private let starterPackBundleExt = "bundle"
    private let starterPackBundlePath = "pinball"
    private let starterSeedMarkerName = "starter-pack-seeded-v3-only"
    private let legacyCacheResetMarkerName = "legacy-cache-reset-v3-assets-v1"
    private let starterPriorityPaths = [
        "/pinball/data/pinball_library_v3.json",
        "/pinball/data/lpl_targets_resolved_v1.json",
        "/pinball/data/LPL_Targets.csv",
        "/pinball/data/LPL_Stats.csv",
        "/pinball/data/LPL_Standings.csv",
        "/pinball/data/redacted_players.csv",
        "/pinball/data/lpl_stats.csv",
    ]

    private var isLoaded = false
    private var index = CacheIndex()
    private var manifest: Manifest?
    private var inFlightRevalidations: Set<String> = []
    private var inFlightRemoteImageRevalidations: Set<String> = []
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
        for path in hostedLibraryCatalogPaths {
            _ = try await fetchBinaryFromNetwork(path: path, allowMissing: path == hostedOPDBCatalogPath, allowStaleOnFailure: false)
        }
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

    func cachedUpdatedAt(path: String) async throws -> Date? {
        try await ensureLoaded()
        let normalizedPath = normalize(path)
        return cachedFileUpdatedAt(for: normalizedPath)
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
            try writeRemoteImage(data: data, for: url)
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
        if inFlightRemoteImageRevalidations.contains(key) {
            return
        }

        inFlightRemoteImageRevalidations.insert(key)
        Task.detached(priority: .utility) {
            await PinballDataCache.shared.runRemoteImageRevalidate(url: url)
        }
    }

    private func runRemoteImageRevalidate(url: URL) async {
        defer { inFlightRemoteImageRevalidations.remove(remoteImageCacheKey(for: url)) }
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
        if inFlightRevalidations.contains(path) {
            return
        }

        inFlightRevalidations.insert(path)
        Task.detached(priority: .utility) {
            await PinballDataCache.shared.runRevalidate(path: path, allowMissing: allowMissing)
        }
    }

    private func runRevalidate(path: String, allowMissing: Bool) async {
        defer { inFlightRevalidations.remove(path) }
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
        do {
            try await refreshMetadataIfNeeded(force: false)
        } catch {
            // Metadata refresh should not block serving cached/offline-first data.
        }

        if let manifest,
           manifest.files[path] == nil,
           allowMissing {
            index.resources[path] = CacheIndex.Resource(path: path, hash: nil, lastValidatedAt: Date().timeIntervalSince1970, missing: true)
            try persistIndex()
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
                    index.resources[path] = CacheIndex.Resource(path: path, hash: nil, lastValidatedAt: Date().timeIntervalSince1970, missing: true)
                    try persistIndex()
                    return nil
                }
                if !(200...299).contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
            }

            try write(data: data, for: path)
            let manifestHash = manifest?.files[path]?.hash
            index.resources[path] = CacheIndex.Resource(path: path, hash: manifestHash, lastValidatedAt: Date().timeIntervalSince1970, missing: false)
            try persistIndex()
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
            return nil
        }

        let url = fileURL(for: path)
        if fileManager.fileExists(atPath: url.path) {
            return try Data(contentsOf: url)
        }

        guard let bundled = try bundledStarterData(for: path) else { return nil }
        try write(data: bundled, for: path)
        return bundled
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
        if !force,
           let last = index.lastMetaFetchAt,
           now - last < metadataRefreshInterval {
            return
        }

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

        let newManifest = try decoder.decode(Manifest.self, from: manifestData)
        let updateLog = try decoder.decode(UpdateLog.self, from: updateData)

        manifest = newManifest
        index.lastMetaFetchAt = now
        index.lastManifestGeneratedAt = newManifest.generatedAt

        let lastScan = index.lastUpdateScanAt
        let updatedEvents = updateLog.events.filter { event in
            guard let lastScan else { return true }
            return event.generatedAt > lastScan
        }

        index.lastUpdateScanAt = updateLog.events.first?.generatedAt ?? lastScan

        // Ensure removed paths don't stay on disk forever.
        let removedPaths = updatedEvents.flatMap(\.removed)
        for removed in removedPaths {
            try? fileManager.removeItem(at: fileURL(for: removed))
            index.resources[removed] = CacheIndex.Resource(path: removed, hash: nil, lastValidatedAt: now, missing: true)
        }

        try persistIndex()
    }

    private func ensureLoaded() async throws {
        guard !isLoaded else { return }

        let root = cacheRootURL()
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        try purgeLegacyCachedPinballAssetsIfNeeded(root: root)

        let indexURL = root.appendingPathComponent("cache-index.json")
        if let data = try? Data(contentsOf: indexURL),
           let saved = try? decoder.decode(CacheIndex.self, from: data) {
            index = saved
        }

        do {
            try preloadStarterPriorityFilesIfNeeded()
        } catch {
            // Priority preload is best effort.
        }

        isLoaded = true

        Task.detached(priority: .utility) {
            await PinballDataCache.shared.seedStarterPackBestEffort()
        }

        Task.detached(priority: .utility) {
            await PinballDataCache.shared.refreshMetadataBestEffort(force: true)
        }
    }

    private func purgeLegacyCachedPinballAssetsIfNeeded(root: URL) throws {
        let markerURL = root.appendingPathComponent(legacyCacheResetMarkerName)
        guard !fileManager.fileExists(atPath: markerURL.path) else { return }

        let resourcesURL = root.appendingPathComponent("resources", isDirectory: true)
        let indexURL = root.appendingPathComponent("cache-index.json")
        let starterSeedMarkerURL = root.appendingPathComponent(starterSeedMarkerName)

        if fileManager.fileExists(atPath: resourcesURL.path) {
            try? fileManager.removeItem(at: resourcesURL)
        }
        if fileManager.fileExists(atPath: indexURL.path) {
            try? fileManager.removeItem(at: indexURL)
        }
        if fileManager.fileExists(atPath: starterSeedMarkerURL.path) {
            try? fileManager.removeItem(at: starterSeedMarkerURL)
        }

        index = CacheIndex()
        manifest = nil
        inFlightRevalidations.removeAll()

        try Data("ok".utf8).write(to: markerURL, options: .atomic)
    }

    private func preloadStarterPriorityFilesIfNeeded() throws {
        for path in starterPriorityPaths {
            _ = try cachedData(for: path)
        }
    }

    private func seedStarterPackBestEffort() async {
        do {
            try seedBundledStarterPackIfNeeded()
        } catch {
            // Starter pack seeding is best effort; runtime cache/network flow remains fallback.
        }
    }

    private func seedBundledStarterPackIfNeeded() throws {
        let markerURL = cacheRootURL().appendingPathComponent(starterSeedMarkerName)
        if fileManager.fileExists(atPath: markerURL.path) {
            return
        }

        guard let starterBundleURL = Bundle.main.url(
            forResource: starterPackBundleName,
            withExtension: starterPackBundleExt
        ) else {
            return
        }

        let starterRoot = starterBundleURL.appendingPathComponent(starterPackBundlePath, isDirectory: true)
        guard
              fileManager.fileExists(atPath: starterRoot.path) else {
            return
        }

        let enumerator = fileManager.enumerator(
            at: starterRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: starterRoot.path + "/", with: "")
            let cachePath = "/pinball/\(relativePath)"
            if try cachedData(for: cachePath) != nil {
                continue
            }

            let data = try Data(contentsOf: fileURL)
            try write(data: data, for: cachePath)
        }

        try Data("ok".utf8).write(to: markerURL, options: .atomic)
    }

    private func bundledStarterData(for path: String) throws -> Data? {
        guard path.hasPrefix("/pinball/"),
              let starterBundleURL = Bundle.main.url(
                forResource: starterPackBundleName,
                withExtension: starterPackBundleExt
              ) else {
            return nil
        }

        let relativePath = String(path.dropFirst("/pinball/".count))
        let fileURL = starterBundleURL
            .appendingPathComponent(starterPackBundlePath, isDirectory: true)
            .appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try Data(contentsOf: fileURL)
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
        let data = try encoder.encode(index)
        try data.write(to: cacheRootURL().appendingPathComponent("cache-index.json"), options: .atomic)
    }

    private func cacheRootURL() -> URL {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("pinball-data-cache", isDirectory: true)
    }

    private func remoteImagesRootURL() -> URL {
        cacheRootURL().appendingPathComponent("remote-images", isDirectory: true)
    }

    private func fileURL(for path: String) -> URL {
        let ext = URL(fileURLWithPath: path).pathExtension
        let digest = SHA256.hash(data: Data(path.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        let fileName = ext.isEmpty ? digest : "\(digest).\(ext)"
        return cacheRootURL().appendingPathComponent("resources", isDirectory: true).appendingPathComponent(fileName)
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

    private func writeRemoteImage(data: Data, for url: URL) throws {
        let fileURL = remoteImageFileURL(for: url)
        let dir = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: fileURL, options: .atomic)
        try pruneRemoteImageCacheIfNeeded()
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
        if path.hasPrefix("/") { return path }
        return "/" + path
    }

    private func shouldUseManifestCache(for url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "pillyliu.com" && url.path.hasPrefix("/pinball/")
    }
}
