import Foundation

struct LibraryPlayfieldOption: Identifiable, Equatable {
    let title: String
    let candidates: [URL]

    var id: String {
        title + "|" + candidates.map(\.absoluteString).joined(separator: "|")
    }
}

private struct LibraryPlayfieldCandidateGroup {
    let title: String
    let candidates: [URL]
}

extension PinballGame {
    nonisolated var usesBundledOnlyAppAssetException: Bool {
        [practiceIdentity, opdbGroupID]
            .compactMap { raw -> String? in
                guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                    return nil
                }
                if let dash = trimmed.firstIndex(of: "-") {
                    return String(trimmed[..<dash])
                }
                return trimmed
            }
            .contains(where: libraryBundledOnlyAppGroupIDs.contains)
    }

    nonisolated var localRulesheetChipTitle: String {
        usesBundledOnlyAppAssetException ? "Local" : "PinProf"
    }

    nonisolated var localPlayfieldChipTitle: String {
        usesBundledOnlyAppAssetException ? "Local" : "PinProf"
    }

    private var hasSplitPracticeIdentity: Bool {
        guard let practiceIdentity = practiceIdentity?.trimmingCharacters(in: .whitespacesAndNewlines),
              !practiceIdentity.isEmpty,
              let opdbGroupID = opdbGroupID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !opdbGroupID.isEmpty else {
            return false
        }
        return practiceIdentity.caseInsensitiveCompare(opdbGroupID) != .orderedSame
    }

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

    nonisolated var rulesheetSourceURL: URL? {
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

    nonisolated var rulesheetPathCandidates: [String] {
        guard let normalized = normalizeLibraryCachePath(rulesheetLocal) else { return [] }
        return [normalized]
    }

    nonisolated var hasLocalRulesheetResource: Bool {
        !rulesheetPathCandidates.isEmpty
    }

    nonisolated var hasRulesheetResource: Bool {
        hasLocalRulesheetResource || !rulesheetLinks.isEmpty || rulesheetSourceURL != nil
    }

    nonisolated var orderedRulesheetLinks: [ReferenceLink] {
        rulesheetLinks.sorted { lhs, rhs in
            lhs.rulesheetSortKey < rhs.rulesheetSortKey
        }
    }

    nonisolated var displayedRulesheetLinks: [ReferenceLink] {
        let localRulesheetBasenames = localRulesheetBasenames
        return orderedRulesheetLinks
            .filter { link in
                shouldDisplayRulesheetLink(link, localRulesheetBasenames: localRulesheetBasenames)
            }
            .filter { link in
                link.destinationURL != nil || link.embeddedRulesheetSource != nil
            }
    }

    var hasPlayfieldResource: Bool {
        !actualFullscreenPlayfieldCandidates.isEmpty
    }

    func resolvedPlayfieldCandidates(liveStatus: LibraryLivePlayfieldStatus?) -> [URL] {
        resolvedPlayfieldCandidateGroups(liveStatus: liveStatus).first?.candidates ?? []
    }

    func resolvedPlayfieldButtonLabel(liveStatus: LibraryLivePlayfieldStatus?) -> String {
        switch liveStatus?.effectiveKind {
        case .pillyliu:
            return usesBundledOnlyAppAssetException ? localPlayfieldChipTitle : "PinProf"
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
        resolvedPlayfieldCandidateGroups(liveStatus: liveStatus).map { group in
            LibraryPlayfieldOption(title: group.title, candidates: group.candidates)
        }
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
                return localPlayfieldChipTitle
            }
        }
        if !profPlayfieldBaseCandidates.isEmpty {
            return "PinProf"
        }
        if !localFallbackPlayfieldCandidates.isEmpty {
            return localPlayfieldChipTitle
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
        guard let practiceIdentity else { return nil }
        let trimmed = practiceIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var playfieldAssetKeys: [String] {
        var keys: [String] = []

        func append(_ raw: String?) {
            guard let raw else { return }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !keys.contains(trimmed) else { return }
            keys.append(trimmed)
        }

        append(opdbID)
        append(localAssetKey)
        if !hasSplitPracticeIdentity {
            append(opdbGroupID)
        }
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
        if usesBundledOnlyAppAssetException {
            return []
        }
        return deduplicatedPlayfieldURLs([
            libraryIsPinProfPlayfieldURL(playfieldLocalOriginalURL) ? playfieldLocalOriginalURL : nil,
            libraryIsPinProfPlayfieldURL(playfieldImageSourceURL) ? playfieldImageSourceURL : nil
        ])
    }

    private func profPlayfieldCandidates(liveStatus: LibraryLivePlayfieldStatus?) -> [URL] {
        if usesBundledOnlyAppAssetException {
            return []
        }
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

    private func resolvedPlayfieldCandidateGroups(
        liveStatus: LibraryLivePlayfieldStatus?
    ) -> [LibraryPlayfieldCandidateGroup] {
        if liveStatus?.effectiveKind == .missing,
           actualFullscreenPlayfieldCandidates.isEmpty {
            return []
        }

        var groups: [LibraryPlayfieldCandidateGroup] = []
        var usedCandidates = Set<URL>()

        func appendGroup(title: String, candidates: [URL]) {
            let filtered = candidates.filter { candidate in
                usedCandidates.insert(candidate).inserted
            }
            guard !filtered.isEmpty else { return }
            groups.append(LibraryPlayfieldCandidateGroup(title: title, candidates: filtered))
        }

        let profCandidates = profPlayfieldCandidates(liveStatus: liveStatus)
        if !profCandidates.isEmpty {
            appendGroup(title: "PinProf", candidates: profCandidates)
        } else {
            appendGroup(title: localPlayfieldChipTitle, candidates: localFallbackPlayfieldCandidates)
        }

        appendGroup(title: "OPDB", candidates: opdbPlayfieldCandidates(liveStatus: liveStatus))
        return groups
    }

    private var preferredLocalPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            explicitLocalPlayfieldCandidates.map(Optional.some) +
                localOriginalPlayfieldURLs().map(Optional.some) +
                localPlayfieldURLs(widths: [1400, 700]).map(Optional.some)
        )
    }

    nonisolated private var localRulesheetBasenames: Set<String> {
        Set(
            rulesheetPathCandidates.compactMap { candidate in
                normalizedRulesheetMarkdownPath(candidate)?
                    .components(separatedBy: "/")
                    .last?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .takeIfNonEmpty
            }
        )
    }

    nonisolated private func shouldDisplayRulesheetLink(
        _ link: ReferenceLink,
        localRulesheetBasenames: Set<String>
    ) -> Bool {
        guard hasLocalRulesheetResource else { return true }
        let destination = libraryResolveURL(pathOrURL: link.url)
        let destinationBasename = normalizedRulesheetMarkdownPath(destination?.absoluteString)?
            .components(separatedBy: "/")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .takeIfNonEmpty
        let shouldSuppress = link.rulesheetSourceKind == .prof ||
            link.rulesheetSourceKind == .local ||
            libraryIsPinProfRulesheetURL(destination) ||
            libraryIsLikelyPinProfMarkdownRulesheetURL(destination) ||
            destinationBasename.map(localRulesheetBasenames.contains) == true
        return !shouldSuppress
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

private extension String {
    nonisolated
    var takeIfNonEmpty: String? {
        isEmpty ? nil : self
    }
}
