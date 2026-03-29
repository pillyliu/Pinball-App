import Foundation

extension PinballGame {
    nonisolated var localRulesheetChipTitle: String {
        usesBundledOnlyAppAssetException ? "Local" : "PinProf"
    }

    nonisolated var rulesheetSourceURL: URL? {
        guard let rulesheetUrl else { return nil }
        return libraryResolveURL(pathOrURL: rulesheetUrl)
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
}

private extension String {
    nonisolated
    var takeIfNonEmpty: String? {
        isEmpty ? nil : self
    }
}
