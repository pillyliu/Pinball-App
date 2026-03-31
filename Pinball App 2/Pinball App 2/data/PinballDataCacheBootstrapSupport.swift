import Foundation

enum PinballDataCacheBootstrapSupport {
    nonisolated static func ensureCacheRootExists(
        _ root: URL,
        fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
    }

    nonisolated static func purgeLegacyCachedPinballAssetsIfNeeded(
        root: URL,
        markerName: String,
        fileManager: FileManager
    ) throws -> Bool {
        let markerURL = root.appendingPathComponent(markerName)
        guard !fileManager.fileExists(atPath: markerURL.path) else { return false }

        let resourcesURL = root.appendingPathComponent("resources", isDirectory: true)
        let indexURL = root.appendingPathComponent("cache-index.json")

        if fileManager.fileExists(atPath: resourcesURL.path) {
            try? fileManager.removeItem(at: resourcesURL)
        }
        if fileManager.fileExists(atPath: indexURL.path) {
            try? fileManager.removeItem(at: indexURL)
        }

        try Data("ok".utf8).write(to: markerURL, options: .atomic)
        return true
    }

    nonisolated static func loadSavedIndex(
        from root: URL,
        decoder: JSONDecoder
    ) -> PinballCacheIndex? {
        loadPinballCacheIndex(from: root, decoder: decoder)
    }

    nonisolated static func seedBundledPreloadIfNeeded(
        index: inout PinballCacheIndex,
        now: TimeInterval,
        fileManager: FileManager,
        writeData: (Data, String) throws -> Void
    ) throws -> Bool {
        guard let preloadManifest = bundledPinballPreloadManifest() else { return false }

        var didChangeIndex = false

        for rawPath in preloadManifest.paths {
            let normalizedPath = normalizedPinballCachePath(rawPath)
            if index.resources[normalizedPath]?.missing == true {
                index.resources[normalizedPath] = PinballCacheIndex.Resource(
                    path: normalizedPath,
                    hash: index.resources[normalizedPath]?.hash,
                    lastValidatedAt: now,
                    missing: false
                )
                didChangeIndex = true
            }

            let targetURL = pinballCachedFileURL(path: normalizedPath, fileManager: fileManager)
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
            try writeData(data, normalizedPath)
            index.resources[normalizedPath] = PinballCacheIndex.Resource(
                path: normalizedPath,
                hash: index.resources[normalizedPath]?.hash,
                lastValidatedAt: now,
                missing: false
            )
            didChangeIndex = true
        }

        return didChangeIndex
    }
}
