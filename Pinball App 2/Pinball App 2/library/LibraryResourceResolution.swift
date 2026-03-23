import Foundation

nonisolated private let librarySupportedPlayfieldOriginalExtensions = ["webp", "jpg", "jpeg", "png"]
nonisolated let libraryMissingArtworkPath = "/pinball/images/playfields/fallback-image-not-available_2048.webp"
nonisolated private let libraryPinProfHosts: Set<String> = [
    "pillyliu.com",
    "www.pillyliu.com",
    "pinprof.com",
    "www.pinprof.com"
]

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

enum LibraryRulesheetSourceKind: Int {
    case local = 0
    case tf = 1
    case prof = 2
    case bob = 3
    case papa = 4
    case pp = 5
    case opdb = 6
    case other = 7

    nonisolated var shortTitle: String {
        switch self {
        case .local:
            return "Local"
        case .prof:
            return "PinProf"
        case .bob:
            return "Bob"
        case .papa:
            return "PAPA"
        case .pp:
            return "PP"
        case .tf:
            return "TF"
        case .opdb:
            return "OPDB"
        case .other:
            return "Other"
        }
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

nonisolated func libraryIsPinProfHost(_ host: String?) -> Bool {
    guard let host = host?.lowercased() else { return false }
    return libraryPinProfHosts.contains(host)
}

nonisolated func libraryIsPinProfPlayfieldURL(_ url: URL?) -> Bool {
    guard let url,
          libraryIsPinProfHost(url.host) else {
        return false
    }
    return url.path.hasPrefix("/pinball/images/playfields/")
}

nonisolated func libraryIsPinProfRulesheetURL(_ url: URL?) -> Bool {
    guard let url,
          libraryIsPinProfHost(url.host) else {
        return false
    }
    return url.path.hasPrefix("/pinball/rulesheets/")
}

nonisolated func normalizeLibraryCachePath(_ pathOrURL: String?) -> String? {
    guard let raw = pathOrURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return nil
    }
    func normalizePlayfieldPublishedPath(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"(/pinball/images/playfields/.+?)(?:_(700|1400))?\.[A-Za-z0-9]+$"#,
            with: "$1.webp",
            options: .regularExpression
        )
    }
    if let url = URL(string: raw), let host = url.host?.lowercased(), host == "pillyliu.com" {
        return url.path.contains("/pinball/images/playfields/") ? normalizePlayfieldPublishedPath(url.path) : url.path
    }
    if raw.hasPrefix("/") {
        return raw.contains("/pinball/images/playfields/") ? normalizePlayfieldPublishedPath(raw) : raw
    }
    let normalized = "/" + raw
    return normalized.contains("/pinball/images/playfields/") ? normalizePlayfieldPublishedPath(normalized) : normalized
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
    libraryResolveURL(pathOrURL: libraryMissingArtworkPath)
}

extension PinballGame {
    nonisolated var opdbGroupID: String? {
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
                supportedSourcePlayfieldCandidates.map(Optional.some)
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

    nonisolated var orderedRulesheetLinks: [ReferenceLink] {
        rulesheetLinks.sorted { lhs, rhs in
            lhs.rulesheetSortKey < rhs.rulesheetSortKey
        }
    }

    var hasPlayfieldResource: Bool {
        !actualFullscreenPlayfieldCandidates.isEmpty
    }

    func resolvedPlayfieldCandidates(liveStatus: LibraryLivePlayfieldStatus?) -> [URL] {
        let prof = profPlayfieldCandidates(liveStatus: liveStatus)
        if !prof.isEmpty { return prof }

        let local = localFallbackPlayfieldCandidates
        if !local.isEmpty { return local }

        let opdb = opdbPlayfieldCandidates(liveStatus: liveStatus)
        if !opdb.isEmpty { return opdb }

        return liveStatus?.effectiveKind == .missing ? [] : []
    }

    func resolvedPlayfieldButtonLabel(liveStatus: LibraryLivePlayfieldStatus?) -> String {
        switch liveStatus?.effectiveKind {
        case .pillyliu:
            return "PinProf"
        case .opdb:
            return "OPDB"
        case .external:
            return playfieldButtonLabel
        case .missing:
            return actualFullscreenPlayfieldCandidates.isEmpty ? "Unavailable" : playfieldButtonLabel
        case nil:
            return playfieldButtonLabel
        }
    }

    func resolvedPlayfieldOptions(liveStatus: LibraryLivePlayfieldStatus?) -> [LibraryPlayfieldOption] {
        var options: [LibraryPlayfieldOption] = []
        var usedCandidates = Set<URL>()

        func appendOption(title: String, candidates: [URL]) {
            let filtered = candidates.filter { candidate in
                usedCandidates.insert(candidate).inserted
            }
            guard !filtered.isEmpty else { return }
            options.append(
                LibraryPlayfieldOption(
                    title: title,
                    candidates: filtered
                )
            )
        }

        if liveStatus?.effectiveKind == .missing,
           actualFullscreenPlayfieldCandidates.isEmpty,
           resolvedPlayfieldCandidates(liveStatus: liveStatus).isEmpty {
            return []
        }

        let profCandidates = profPlayfieldCandidates(liveStatus: liveStatus)
        if !profCandidates.isEmpty {
            appendOption(title: "PinProf", candidates: profCandidates)
        } else {
            appendOption(title: "Local", candidates: localFallbackPlayfieldCandidates)
        }

        appendOption(title: "OPDB", candidates: opdbPlayfieldCandidates(liveStatus: liveStatus))

        return options
    }

    var playfieldButtonLabel: String {
        if let explicit = normalizedPlayfieldSourceLabel {
            let normalized = explicit.lowercased()
            if normalized.contains("opdb") {
                return "OPDB"
            }
            if normalized.contains("prof") {
                return "PinProf"
            }
            if normalized.contains("local") {
                return "Local"
            }
        }
        if !profPlayfieldBaseCandidates.isEmpty {
            return "PinProf"
        }
        if !localFallbackPlayfieldCandidates.isEmpty {
            return "Local"
        }
        if let playfieldImageSourceURL {
            if libraryIsPinProfPlayfieldURL(playfieldImageSourceURL) {
                return "PinProf"
            }
            if isOPDBPlayfieldURL(playfieldImageSourceURL) {
                return "OPDB"
            }
        }
        if let alternatePlayfieldImageSourceURL, isOPDBPlayfieldURL(alternatePlayfieldImageSourceURL) {
            return "OPDB"
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

    private func isOPDBPlayfieldURL(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host.contains("opdb.org")
    }

    private var supportedSourcePlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs([
            libraryIsPinProfPlayfieldURL(playfieldImageSourceURL) ? playfieldImageSourceURL : nil,
            isOPDBPlayfieldURL(playfieldImageSourceURL) ? playfieldImageSourceURL : nil,
            libraryIsPinProfPlayfieldURL(alternatePlayfieldImageSourceURL) ? alternatePlayfieldImageSourceURL : nil,
            isOPDBPlayfieldURL(alternatePlayfieldImageSourceURL) ? alternatePlayfieldImageSourceURL : nil
        ])
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

    private var localFallbackPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs([
            playfieldLocalURL
        ])
    }

    private var profPlayfieldBaseCandidates: [URL] {
        deduplicatedPlayfieldURLs([
            libraryIsPinProfPlayfieldURL(playfieldLocalOriginalURL) ? playfieldLocalOriginalURL : nil,
            libraryIsPinProfPlayfieldURL(playfieldImageSourceURL) ? playfieldImageSourceURL : nil
        ])
    }

    private func profPlayfieldCandidates(liveStatus: LibraryLivePlayfieldStatus?) -> [URL] {
        let liveURL = liveStatus?.effectiveKind == .pillyliu ? liveStatus?.effectiveURL : nil
        let hasHostedCandidate = liveURL != nil || !profPlayfieldBaseCandidates.isEmpty
        return deduplicatedPlayfieldURLs(
            [liveURL] +
                profPlayfieldBaseCandidates.map(Optional.some) +
                (hasHostedCandidate ? localFallbackPlayfieldCandidates.map(Optional.some) : [])
        )
    }

    private func opdbPlayfieldCandidates(liveStatus: LibraryLivePlayfieldStatus?) -> [URL] {
        let liveURL = liveStatus?.effectiveKind == .opdb ? liveStatus?.effectiveURL : nil
        return deduplicatedPlayfieldURLs([
            liveURL,
            isOPDBPlayfieldURL(playfieldImageSourceURL) ? playfieldImageSourceURL : nil,
            isOPDBPlayfieldURL(alternatePlayfieldImageSourceURL) ? alternatePlayfieldImageSourceURL : nil
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
                supportedSourcePlayfieldCandidates.map(Optional.some)
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

extension PinballGame.ReferenceLink {
    nonisolated var rulesheetSourceKind: LibraryRulesheetSourceKind {
        let normalizedLabel = label.lowercased()
        let resolvedURL = libraryResolveURL(pathOrURL: url)

        if libraryIsPinProfRulesheetURL(resolvedURL) || normalizedLabel.contains("(prof)") {
            return .prof
        }
        if resolvedURL?.host?.lowercased().contains("tiltforums.com") == true || normalizedLabel.contains("(tf)") {
            return .tf
        }
        if resolvedURL?.host?.lowercased().contains("pinballprimer.github.io") == true
            || resolvedURL?.host?.lowercased().contains("pinballprimer.com") == true
            || normalizedLabel.contains("(pp)") {
            return .pp
        }
        if resolvedURL?.host?.lowercased().contains("pinball.org") == true
            || resolvedURL?.host?.lowercased().contains("replayfoundation.org") == true
            || normalizedLabel.contains("(papa)") {
            return .papa
        }
        if resolvedURL?.host?.lowercased().contains("silverballmania.com") == true
            || resolvedURL?.host?.lowercased().contains("flippers.be") == true
            || normalizedLabel.contains("(bob)") {
            return .bob
        }
        if normalizedLabel.contains("(opdb)") {
            return .opdb
        }
        if normalizedLabel.contains("(local)") || normalizedLabel.contains("(source)") {
            return .local
        }
        if resolvedURL == nil && embeddedRulesheetSource == nil {
            return .local
        }
        return .other
    }

    nonisolated var shortRulesheetTitle: String {
        rulesheetSourceKind.shortTitle
    }

    nonisolated fileprivate var rulesheetSortKey: (Int, String, String) {
        (
            rulesheetSourceKind.rawValue,
            label.lowercased(),
            (libraryResolveURL(pathOrURL: url)?.absoluteString ?? url).lowercased()
        )
    }
}
