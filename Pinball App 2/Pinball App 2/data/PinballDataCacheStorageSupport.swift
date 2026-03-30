import Foundation
import CryptoKit

nonisolated struct BundledPinballPreloadManifest: Decodable {
    let schemaVersion: Int
    let generatedAt: String
    let paths: [String]
}

nonisolated struct PinballCacheManifest: Decodable {
    nonisolated struct Entry: Decodable {
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

nonisolated struct PinballCacheUpdateLog: Decodable {
    nonisolated struct Event: Decodable {
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

nonisolated struct PinballCacheIndex: Codable {
    nonisolated struct Resource: Codable {
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

nonisolated func normalizedPinballCachePath(_ path: String) -> String {
    if path.hasPrefix("/") { return path }
    return "/" + path
}

nonisolated func bundledPinballPreloadBundleURL() -> URL? {
    Bundle.main.url(forResource: "PinballPreload", withExtension: "bundle")
}

nonisolated func bundledPinballPreloadManifest() -> BundledPinballPreloadManifest? {
    guard let bundleURL = bundledPinballPreloadBundleURL() else { return nil }
    let manifestURL = bundleURL.appendingPathComponent("preload-manifest.json")
    guard let data = try? Data(contentsOf: manifestURL) else { return nil }
    return try? JSONDecoder().decode(BundledPinballPreloadManifest.self, from: data)
}

nonisolated func bundledPinballPreloadFileURL(path: String) -> URL? {
    guard let bundleURL = bundledPinballPreloadBundleURL() else { return nil }
    let normalizedPath = normalizedPinballCachePath(path)
    let relativePath = String(normalizedPath.dropFirst())
    let fileURL = bundleURL.appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    return fileURL
}

nonisolated func pinballCacheRootURL(fileManager: FileManager = .default) -> URL {
    let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
    return base.appendingPathComponent("pinball-data-cache", isDirectory: true)
}

nonisolated func pinballCacheIndexURL(cacheRootURL: URL) -> URL {
    cacheRootURL.appendingPathComponent("cache-index.json")
}

nonisolated func pinballCachedFileURL(path: String, fileManager: FileManager = .default) -> URL {
    let normalizedPath = normalizedPinballCachePath(path)
    let ext = URL(fileURLWithPath: normalizedPath).pathExtension
    let digest = SHA256.hash(data: Data(normalizedPath.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    let fileName = ext.isEmpty ? digest : "\(digest).\(ext)"
    return pinballCacheRootURL(fileManager: fileManager)
        .appendingPathComponent("resources", isDirectory: true)
        .appendingPathComponent(fileName)
}

nonisolated func cachedPinballDataURL(path: String) -> URL? {
    let fileURL = pinballCachedFileURL(path: path)
    if FileManager.default.fileExists(atPath: fileURL.path) {
        return fileURL
    }
    return bundledPinballPreloadFileURL(path: path)
}

nonisolated func loadCachedPinballData(path: String) throws -> Data? {
    if let fileURL = cachedPinballDataURL(path: path) {
        return try Data(contentsOf: fileURL)
    }
    return nil
}

nonisolated func pinballCacheLatestUpdateScanAt(
    eventGeneratedAts: [String],
    existingLastScan: String?
) -> String? {
    var latest = existingLastScan

    for generatedAt in eventGeneratedAts {
        guard let currentLatest = latest else {
            latest = generatedAt
            continue
        }
        if generatedAt > currentLatest {
            latest = generatedAt
        }
    }

    return latest
}

nonisolated func loadPinballCacheIndex(from cacheRootURL: URL, decoder: JSONDecoder) -> PinballCacheIndex? {
    let indexURL = pinballCacheIndexURL(cacheRootURL: cacheRootURL)
    guard let data = try? Data(contentsOf: indexURL) else { return nil }
    return try? decoder.decode(PinballCacheIndex.self, from: data)
}

nonisolated func persistPinballCacheIndex(
    _ index: PinballCacheIndex,
    cacheRootURL: URL,
    encoder: JSONEncoder
) throws {
    let data = try encoder.encode(index)
    try data.write(to: pinballCacheIndexURL(cacheRootURL: cacheRootURL), options: .atomic)
}
