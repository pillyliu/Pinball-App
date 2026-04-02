import Foundation

extension PinballGame {
    var localAssetKey: String? {
        guard let practiceIdentity else { return nil }
        let trimmed = practiceIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedPlayfieldSourceLabel: String? {
        let trimmed = playfieldSourceLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    func isOPDBPlayfieldURL(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host.contains("opdb.org")
    }

    var supportedSourcePlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs([
            libraryIsPinProfPlayfieldURL(playfieldImageSourceURL) ? playfieldImageSourceURL : nil,
            isOPDBPlayfieldURL(playfieldImageSourceURL) ? playfieldImageSourceURL : nil,
            libraryIsPinProfPlayfieldURL(alternatePlayfieldImageSourceURL) ? alternatePlayfieldImageSourceURL : nil,
            isOPDBPlayfieldURL(alternatePlayfieldImageSourceURL) ? alternatePlayfieldImageSourceURL : nil,
        ])
    }

    var artworkCandidatesOrMissingArtwork: [URL] {
        let candidates = primaryArtworkCandidates
        if !candidates.isEmpty {
            return candidates
        }
        return deduplicatedPlayfieldURLs([libraryMissingArtworkURL()])
    }

    var explicitLocalPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs([
            playfieldLocalOriginalURL,
            playfieldLocalURL,
        ])
    }

    var profPlayfieldBaseCandidates: [URL] {
        if usesBundledOnlyAppAssetException {
            return []
        }
        return deduplicatedPlayfieldURLs([
            libraryIsPinProfPlayfieldURL(playfieldLocalURL) ? playfieldLocalURL : nil,
            libraryIsPinProfPlayfieldURL(playfieldImageSourceURL) ? playfieldImageSourceURL : nil,
        ])
    }

    func profPlayfieldCandidates(liveStatus: LibraryLivePlayfieldStatus?) -> [URL] {
        if usesBundledOnlyAppAssetException {
            return []
        }
        let liveURL = liveStatus?.effectiveKind == .pillyliu ? liveStatus?.effectiveURL : nil
        return deduplicatedPlayfieldURLs([liveURL] + profPlayfieldBaseCandidates.map(Optional.some))
    }

    func opdbPlayfieldCandidates(liveStatus: LibraryLivePlayfieldStatus?) -> [URL] {
        let liveURL = liveStatus?.effectiveKind == .opdb ? liveStatus?.effectiveURL : nil
        return deduplicatedPlayfieldURLs([
            liveURL,
            isOPDBPlayfieldURL(playfieldImageSourceURL) ? playfieldImageSourceURL : nil,
            isOPDBPlayfieldURL(alternatePlayfieldImageSourceURL) ? alternatePlayfieldImageSourceURL : nil,
        ])
    }

    var preferredLocalPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            explicitLocalPlayfieldCandidates.map(Optional.some) +
                inferredHostedPlayfieldURLs().map(Optional.some)
        )
    }

    var realPlayfieldCandidates: [URL] {
        deduplicatedPlayfieldURLs(
            preferredLocalPlayfieldCandidates.map(Optional.some) +
                supportedSourcePlayfieldCandidates.map(Optional.some)
        )
    }

    var realPlayfieldCandidatesOrMissingArtwork: [URL] {
        if !realPlayfieldCandidates.isEmpty {
            return realPlayfieldCandidates
        }
        return deduplicatedPlayfieldURLs([libraryMissingArtworkURL()])
    }

    var fullscreenArtworkCandidatesOrMissingArtwork: [URL] {
        if !actualFullscreenPlayfieldCandidates.isEmpty {
            return actualFullscreenPlayfieldCandidates
        }
        if !realPlayfieldCandidates.isEmpty {
            return realPlayfieldCandidates
        }
        return deduplicatedPlayfieldURLs([libraryMissingArtworkURL()])
    }

    func inferredHostedPlayfieldURLs() -> [URL] {
        deduplicatedPlayfieldURLs(
            playfieldAssetKeys.compactMap { assetKey in
                libraryResolveURL(pathOrURL: "/pinball/images/playfields/\(assetKey)-playfield.webp")
            }
        )
    }

    func deduplicatedPlayfieldURLs(_ candidates: [URL?]) -> [URL] {
        var seen: Set<String> = []
        var urls: [URL] = []
        for url in candidates.compactMap({ $0 }) {
            if seen.insert(url.absoluteString).inserted {
                urls.append(url)
            }
        }
        return urls
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
}
