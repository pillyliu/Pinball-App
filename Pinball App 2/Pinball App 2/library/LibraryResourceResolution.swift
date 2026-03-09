import Foundation

private let librarySupportedPlayfieldOriginalExtensions = ["webp", "jpg", "jpeg", "png"]

enum LibraryLivePlayfieldKind: String {
    case pillyliu
    case opdb
    case external
    case missing
}

struct LibraryLivePlayfieldStatus: Equatable {
    let effectiveKind: LibraryLivePlayfieldKind
    let effectiveURL: URL?
}

struct LibraryPlayfieldOption: Identifiable, Equatable {
    let title: String
    let candidates: [URL]

    var id: String {
        title + "|" + candidates.map(\.absoluteString).joined(separator: "|")
    }
}

actor LibraryLivePlayfieldStatusStore {
    static let shared = LibraryLivePlayfieldStatusStore()

    func status(for practiceIdentity: String?) async -> LibraryLivePlayfieldStatus? {
        guard let practiceIdentity = practiceIdentity?.trimmingCharacters(in: .whitespacesAndNewlines),
              !practiceIdentity.isEmpty else {
            return nil
        }

        var components = URLComponents(string: "https://pillyliu.com/pinprof-admin/api.php")
        components?.queryItems = [
            URLQueryItem(name: "route", value: "public/playfield-status/\(practiceIdentity)")
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawKind = json["effectiveKind"] as? String,
                  let kind = LibraryLivePlayfieldKind(rawValue: rawKind) else {
                return nil
            }

            let effectiveURL = libraryResolveURL(pathOrURL: (json["effectiveUrl"] as? String) ?? "")
            return LibraryLivePlayfieldStatus(effectiveKind: kind, effectiveURL: effectiveURL)
        } catch {
            return nil
        }
    }
}

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

nonisolated func libraryMissingArtworkURL() -> URL? {
    libraryResolveURL(pathOrURL: "/pinball/images/playfields/fallback-image-not-available_2048.webp")
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

    var alternatePlayfieldImageSourceURL: URL? {
        guard let alternatePlayfieldImageUrl else { return nil }
        return libraryResolveURL(pathOrURL: alternatePlayfieldImageUrl)
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
        realPlayfieldCandidatesOrMissingArtwork
    }

    var primaryArtworkCandidates: [URL] {
        deduplicatedPlayfieldURLs([
            primaryImageLargeSourceURL,
            primaryImageSourceURL
        ])
    }

    var cardArtworkCandidates: [URL] {
        artworkCandidatesOrMissingArtwork
    }

    var detailArtworkCandidates: [URL] {
        artworkCandidatesOrMissingArtwork
    }

    var miniPlayfieldCandidates: [URL] {
        realPlayfieldCandidatesOrMissingArtwork
    }

    var gamePlayfieldCandidates: [URL] {
        fullscreenArtworkCandidatesOrMissingArtwork
    }

    var fullscreenPlayfieldCandidates: [URL] {
        fullscreenArtworkCandidatesOrMissingArtwork
    }

    var actualFullscreenPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            explicitLocalPlayfieldCandidates.map(Optional.some) +
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
        guard let normalized = normalizeLibraryCachePath(rulesheetLocal) else { return [] }
        return [normalized]
    }

    var hasLocalRulesheetResource: Bool {
        !rulesheetPathCandidates.isEmpty
    }

    var hasRulesheetResource: Bool {
        hasLocalRulesheetResource || !rulesheetLinks.isEmpty || rulesheetSourceURL != nil
    }

    var hasPlayfieldResource: Bool {
        !actualFullscreenPlayfieldCandidates.isEmpty
    }

    func resolvedPlayfieldCandidates(liveStatus: LibraryLivePlayfieldStatus?) -> [URL] {
        if liveStatus?.effectiveKind == .missing,
           actualFullscreenPlayfieldCandidates.isEmpty {
            return []
        }
        return deduplicatedPlayfieldURLs(
            [liveStatus?.effectiveURL] +
                actualFullscreenPlayfieldCandidates.map(Optional.some)
        )
    }

    func resolvedPlayfieldButtonLabel(liveStatus: LibraryLivePlayfieldStatus?) -> String {
        switch liveStatus?.effectiveKind {
        case .pillyliu:
            return "Local"
        case .opdb:
            return "OPDB"
        case .external:
            return "Remote"
        case .missing:
            return actualFullscreenPlayfieldCandidates.isEmpty ? "Unavailable" : playfieldButtonLabel
        case nil:
            return playfieldButtonLabel
        }
    }

    func resolvedPlayfieldOptions(liveStatus: LibraryLivePlayfieldStatus?) -> [LibraryPlayfieldOption] {
        var options: [LibraryPlayfieldOption] = []
        var usedCandidates = Set<URL>()
        let explicitCandidates = actualFullscreenPlayfieldCandidates
        if liveStatus?.effectiveKind == .missing,
           explicitCandidates.isEmpty {
            return []
        }

        if !explicitCandidates.isEmpty {
            options.append(
                LibraryPlayfieldOption(
                    title: playfieldButtonLabel,
                    candidates: explicitCandidates
                )
            )
            usedCandidates.formUnion(explicitCandidates)
        } else {
            let primaryCandidates = resolvedPlayfieldCandidates(liveStatus: liveStatus)
            if !primaryCandidates.isEmpty {
                options.append(
                    LibraryPlayfieldOption(
                        title: resolvedPlayfieldButtonLabel(liveStatus: liveStatus),
                        candidates: primaryCandidates
                    )
                )
                usedCandidates.formUnion(primaryCandidates)
            }
        }

        if let liveURL = liveStatus?.effectiveURL,
           liveStatus?.effectiveKind != .missing,
           !usedCandidates.contains(liveURL) {
            options.append(
                LibraryPlayfieldOption(
                    title: resolvedPlayfieldButtonLabel(liveStatus: liveStatus),
                    candidates: [liveURL]
                )
            )
            usedCandidates.insert(liveURL)
        }

        if let alternateURL = alternatePlayfieldImageSourceURL,
           !usedCandidates.contains(alternateURL) {
            options.append(
                LibraryPlayfieldOption(
                    title: "OPDB",
                    candidates: [alternateURL]
                )
            )
            usedCandidates.insert(alternateURL)
        }

        return options
    }

    var playfieldButtonLabel: String {
        if let explicit = normalizedPlayfieldSourceLabel {
            return explicit == "Playfield (OPDB)" ? "OPDB" : "Local"
        }
        if playfieldLocalURL != nil || playfieldLocalOriginalURL != nil {
            return "Local"
        }
        if let playfieldImageSourceURL {
            if isPillyliuPlayfieldURL(playfieldImageSourceURL) {
                return "Local"
            }
            return isOPDBPlayfieldURL(playfieldImageSourceURL) ? "OPDB" : "Remote"
        }
        return "View"
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

    private func isPillyliuPlayfieldURL(_ url: URL?) -> Bool {
        guard let url,
              let host = url.host?.lowercased() else {
            return false
        }
        return host == "pillyliu.com" && url.path.hasPrefix("/pinball/images/playfields/")
    }

    private func isOPDBPlayfieldURL(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host.contains("opdb.org")
    }

    private var remotePlayfieldCandidates: [URL] {
        guard let playfieldImageSourceURL else { return [] }
        return [playfieldImageSourceURL]
    }

    private var artworkCandidatesOrMissingArtwork: [URL] {
        let candidates = primaryArtworkCandidates
        if !candidates.isEmpty {
            return candidates
        }
        return deduplicatedPlayfieldURLs([libraryMissingArtworkURL()])
    }

    private var explicitLocalPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs([
            playfieldLocalOriginalURL,
            playfieldLocalURL
        ])
    }

    private var preferredLocalPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            explicitLocalPlayfieldCandidates.map(Optional.some) +
                localOriginalPlayfieldURLs().map(Optional.some) +
                localPlayfieldURLs(widths: [1400, 700]).map(Optional.some)
        )
    }

    private var realPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            preferredLocalPlayfieldCandidates.map(Optional.some) +
                remotePlayfieldCandidates.map(Optional.some)
        )
    }

    private var realPlayfieldCandidatesOrMissingArtwork: [URL] {
        if !realPlayfieldCandidates.isEmpty {
            return realPlayfieldCandidates
        }
        return deduplicatedPlayfieldURLs([libraryMissingArtworkURL()])
    }

    private var fullscreenArtworkCandidatesOrMissingArtwork: [URL] {
        if !actualFullscreenPlayfieldCandidates.isEmpty {
            return actualFullscreenPlayfieldCandidates
        }
        if !realPlayfieldCandidates.isEmpty {
            return realPlayfieldCandidates
        }
        return deduplicatedPlayfieldURLs([libraryMissingArtworkURL()])
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
