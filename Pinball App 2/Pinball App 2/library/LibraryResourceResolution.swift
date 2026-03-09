import Foundation

private let librarySupportedPlayfieldOriginalExtensions = ["webp", "jpg", "jpeg", "png"]

nonisolated func libraryResolveURL(pathOrURL: String) -> URL? {
    if let direct = URL(string: pathOrURL), direct.scheme != nil {
        return direct
    }

    if pathOrURL.hasPrefix("/") {
        return URL(string: "https://pillyliu.com\(pathOrURL)")
    }

    return URL(string: "https://pillyliu.com/\(pathOrURL)")
}

nonisolated func normalizeLibraryCachePath(_ pathOrURL: String?) -> String? {
    guard let raw = pathOrURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return nil
    }
    if let url = URL(string: raw), let host = url.host?.lowercased(), host == "pillyliu.com" {
        return url.path
    }
    if raw.hasPrefix("/") { return raw }
    return "/" + raw
}

nonisolated func normalizeLibraryPlayfieldLocalPath(_ pathOrURL: String?) -> String? {
    guard let raw = pathOrURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return nil
    }
    if raw.localizedCaseInsensitiveContains("/pinball/images/playfields/") {
        if raw.lowercased().hasSuffix("_700.webp") { return raw }
        if raw.lowercased().hasSuffix("_1400.webp") {
            return raw.replacingOccurrences(of: "_1400.webp", with: "_700.webp", options: [.caseInsensitive])
        }
        if let dot = raw.lastIndex(of: ".") {
            return String(raw[..<dot]) + "_700.webp"
        }
    }
    return raw
}

nonisolated func libraryFallbackPlayfieldURL(width: Int) -> URL? {
    libraryResolveURL(pathOrURL: "/pinball/images/playfields/fallback-whitewood-playfield_\(width).webp")
}

extension PinballGame {
    var opdbGroupID: String? {
        guard let opdbID else { return nil }
        let trimmed = opdbID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("G") else { return nil }
        if let dash = trimmed.firstIndex(of: "-") {
            return String(trimmed[..<dash])
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    var playfieldImageSourceURL: URL? {
        guard let playfieldImageUrl else { return nil }
        return libraryResolveURL(pathOrURL: playfieldImageUrl)
    }

    var rulesheetSourceURL: URL? {
        guard let rulesheetUrl else { return nil }
        return libraryResolveURL(pathOrURL: rulesheetUrl)
    }

    var playfieldLocalURL: URL? {
        guard let playfieldLocal else { return nil }
        return libraryResolveURL(pathOrURL: playfieldLocal)
    }

    var playfieldLocalOriginalURL: URL? {
        guard let playfieldLocalOriginal else { return nil }
        return libraryResolveURL(pathOrURL: playfieldLocalOriginal)
    }

    var libraryPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            preferredLocalPlayfieldCandidates.map(Optional.some) +
                remotePlayfieldCandidates.map(Optional.some) + [
                    libraryFallbackPlayfieldURL(width: 700)
                ]
        )
    }

    var primaryArtworkCandidates: [URL] {
        deduplicatedPlayfieldURLs([
            primaryImageLargeSourceURL,
            primaryImageSourceURL
        ])
    }

    var cardArtworkCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            primaryArtworkCandidates.map(Optional.some) +
                miniPlayfieldCandidates.map(Optional.some)
        )
    }

    var detailArtworkCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            primaryArtworkCandidates.map(Optional.some) +
                gamePlayfieldCandidates.map(Optional.some)
        )
    }

    var miniPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            preferredLocalPlayfieldCandidates.map(Optional.some) +
                remotePlayfieldCandidates.map(Optional.some) + [
                    libraryFallbackPlayfieldURL(width: 700),
                    libraryFallbackPlayfieldURL(width: 1400)
                ]
        )
    }

    var gamePlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            actualFullscreenPlayfieldCandidates.map(Optional.some) + [
                libraryFallbackPlayfieldURL(width: 700)
            ]
        )
    }

    var fullscreenPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            actualFullscreenPlayfieldCandidates.map(Optional.some) + [
                libraryFallbackPlayfieldURL(width: 700)
            ]
        )
    }

    var actualFullscreenPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            preferredLocalPlayfieldCandidates.map(Optional.some) +
                remotePlayfieldCandidates.map(Optional.some)
        )
    }

    var gameinfoPathCandidates: [String] {
        var paths: [String] = []
        if let localAssetKey {
            paths.append("/pinball/gameinfo/\(localAssetKey)-gameinfo.md")
        }
        return Array(NSOrderedSet(array: paths)) as? [String] ?? paths
    }

    var rulesheetPathCandidates: [String] {
        var paths: [String] = []
        if let localAssetKey {
            paths.append("/pinball/rulesheets/\(localAssetKey)-rulesheet.md")
        }
        return Array(NSOrderedSet(array: paths)) as? [String] ?? paths
    }

    var hasRulesheetResource: Bool {
        !rulesheetPathCandidates.isEmpty || !rulesheetLinks.isEmpty || rulesheetSourceURL != nil
    }

    var hasPlayfieldResource: Bool {
        !actualFullscreenPlayfieldCandidates.isEmpty
    }

    var playfieldButtonLabel: String {
        if let explicit = normalizedPlayfieldSourceLabel {
            return explicit == "Playfield (OPDB)" ? "OPDB" : "Local"
        }
        if hasCuratedPlayfieldSource {
            return "Local"
        }
        return playfieldImageSourceURL == nil ? "View" : "OPDB"
    }

    var localAssetKey: String? {
        if let practiceIdentity {
            let trimmed = practiceIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let opdbGroupID {
            let trimmed = opdbGroupID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private var playfieldAssetKeys: [String] {
        var keys: [String] = []

        func append(_ raw: String?) {
            guard let raw else { return }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !keys.contains(trimmed) else { return }
            keys.append(trimmed)
        }

        if let opdbID {
            let components = opdbID
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "-")
                .map(String.init)
            if !components.isEmpty {
                for count in stride(from: components.count, through: 1, by: -1) {
                    append(components.prefix(count).joined(separator: "-"))
                }
            }
        }

        append(localAssetKey)
        append(opdbGroupID)
        return keys
    }

    private var normalizedPlayfieldSourceLabel: String? {
        let trimmed = playfieldSourceLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private var hasCuratedPlayfieldSource: Bool {
        playfieldLocalURL != nil ||
            playfieldLocalOriginalURL != nil ||
            isPillyliuPlayfieldURL(playfieldImageSourceURL)
    }

    private func isPillyliuPlayfieldURL(_ url: URL?) -> Bool {
        guard let url,
              let host = url.host?.lowercased() else {
            return false
        }
        return host == "pillyliu.com" && url.path.hasPrefix("/pinball/images/playfields/")
    }

    private var remotePlayfieldCandidates: [URL] {
        guard let playfieldImageSourceURL else { return [] }
        return [playfieldImageSourceURL]
    }

    private var preferredLocalPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            [playfieldLocalOriginalURL] +
                localOriginalPlayfieldURLs().map(Optional.some) +
                localPlayfieldURLs(widths: [1400, 700]).map(Optional.some)
        )
    }

    private func localOriginalPlayfieldURLs() -> [URL] {
        deduplicatedPlayfieldURLs(
            playfieldAssetKeys.flatMap { assetKey in
                librarySupportedPlayfieldOriginalExtensions.compactMap { ext in
                    libraryResolveURL(pathOrURL: "/pinball/images/playfields/\(assetKey)-playfield.\(ext)")
                }
            }
        )
    }

    private func localPlayfieldURLs(widths: [Int]) -> [URL] {
        deduplicatedPlayfieldURLs(
            playfieldAssetKeys.flatMap { assetKey in
                widths.compactMap { width in
                    let path = "/pinball/images/playfields/\(assetKey)-playfield_\(width).webp"
                    return libraryResolveURL(pathOrURL: path)
                }
            }
        )
    }

    private func deduplicatedPlayfieldURLs(_ candidates: [URL?]) -> [URL] {
        var seen: Set<String> = []
        var urls: [URL] = []
        for url in candidates.compactMap({ $0 }) {
            if seen.insert(url.absoluteString).inserted {
                urls.append(url)
            }
        }
        return urls
    }
}
