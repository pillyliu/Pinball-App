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

    nonisolated var localPlayfieldChipTitle: String {
        usesBundledOnlyAppAssetException ? "Local" : "PinProf"
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
            primaryImageSourceURL,
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
}
