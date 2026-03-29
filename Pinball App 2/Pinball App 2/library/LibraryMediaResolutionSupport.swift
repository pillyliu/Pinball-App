import Foundation

nonisolated func resolveImportedRulesheetLinks(
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheetLinks: [CatalogRulesheetLinkRecord]
) -> (localPath: String?, links: [PinballGame.ReferenceLink]) {
    let resolvedCatalogRulesheets = resolveRulesheetLinks(override: nil, rulesheetLinks: opdbRulesheetLinks)
    if let localPath = catalogNormalizedOptionalString(curatedOverride?.rulesheetLocalPath) {
        let primaryLinks = (curatedOverride?.rulesheetLinks ?? []).filter {
            !shouldSuppressLocalMarkdownRulesheetLink($0)
        }
        let mergedLinks = mergeRulesheetLinks(
            primary: primaryLinks,
            secondary: resolvedCatalogRulesheets.links
        )
        return (localPath, mergedLinks)
    }

    if let curatedOverride, !curatedOverride.rulesheetLinks.isEmpty {
        return (nil, mergeRulesheetLinks(primary: curatedOverride.rulesheetLinks, secondary: resolvedCatalogRulesheets.links))
    }

    return resolvedCatalogRulesheets
}

nonisolated func resolveImportedVideos(
    curatedOverride: LegacyCuratedOverride?,
    opdbVideoLinks: [CatalogVideoLinkRecord]
) -> [PinballGame.Video] {
    mergeResolvedVideos(
        primary: curatedOverride?.videos ?? [],
        secondary: resolveVideoLinks(videoLinks: opdbVideoLinks)
    )
}

nonisolated func resolveRulesheetLinks(
    override: CatalogOverrideRecord?,
    rulesheetLinks: [CatalogRulesheetLinkRecord]
) -> (localPath: String?, links: [PinballGame.ReferenceLink]) {
    let sortedLinks = rulesheetLinks.sorted(by: compareCatalogRulesheetLinks)
    let links = sortedLinks.compactMap { link -> PinballGame.ReferenceLink? in
        guard let url = catalogNormalizedOptionalString(link.url) else { return nil }
        return PinballGame.ReferenceLink(
            label: catalogRulesheetLabel(
                providerRawValue: link.provider,
                fallback: link.label,
                url: url
            ),
            url: url
        )
    }
    let preferredLocalPath = sortedLinks.lazy.compactMap { link in
        catalogNormalizedOptionalString(link.localPath)
    }.first
    let resolvedLocalPath = catalogNormalizedOptionalString(override?.rulesheetLocalPath) ?? preferredLocalPath
    return (resolvedLocalPath, links)
}

nonisolated func mergeRulesheetLinks(
    primary: [PinballGame.ReferenceLink],
    secondary: [PinballGame.ReferenceLink]
) -> [PinballGame.ReferenceLink] {
    var seen = Set<String>()
    var merged: [PinballGame.ReferenceLink] = []
    for link in primary + secondary {
        let key = canonicalRulesheetMergeKey(link)
        if seen.contains(key) { continue }
        seen.insert(key)
        merged.append(link)
    }
    return merged
}

nonisolated private func canonicalRulesheetMergeKey(_ link: PinballGame.ReferenceLink) -> String {
    let url = link.url.trimmingCharacters(in: .whitespacesAndNewlines)
    if !url.isEmpty {
        return "url|\(url.lowercased())"
    }
    let label = link.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return "label|\(label)"
}

nonisolated private func shouldSuppressLocalMarkdownRulesheetLink(
    _ link: PinballGame.ReferenceLink
) -> Bool {
    let destination = libraryResolveURL(pathOrURL: link.url)
    return link.rulesheetSourceKind == .prof ||
        link.rulesheetSourceKind == .local ||
        libraryIsPinProfRulesheetURL(destination) ||
        libraryIsLikelyPinProfMarkdownRulesheetURL(destination)
}

nonisolated func compareCatalogRulesheetLinks(_ lhs: CatalogRulesheetLinkRecord, _ rhs: CatalogRulesheetLinkRecord) -> Bool {
    let leftRank = catalogResolvedRulesheetSourceKind(
        providerRawValue: lhs.provider,
        fallbackLabel: lhs.label,
        url: lhs.url
    ).rawValue
    let rightRank = catalogResolvedRulesheetSourceKind(
        providerRawValue: rhs.provider,
        fallbackLabel: rhs.label,
        url: rhs.url
    ).rawValue
    if leftRank != rightRank {
        return leftRank < rightRank
    }

    let leftPriority = lhs.priority ?? Int.max
    let rightPriority = rhs.priority ?? Int.max
    if leftPriority != rightPriority {
        return leftPriority < rightPriority
    }

    let leftLabel = lhs.label.lowercased()
    let rightLabel = rhs.label.lowercased()
    if leftLabel != rightLabel {
        return leftLabel < rightLabel
    }

    return (lhs.url ?? "") < (rhs.url ?? "")
}

nonisolated func catalogRulesheetSortRank(providerRawValue: String, label: String, url: String?) -> Int {
    catalogResolvedRulesheetSourceKind(
        providerRawValue: providerRawValue,
        fallbackLabel: label,
        url: url
    ).rawValue
}

nonisolated func catalogRulesheetLabel(providerRawValue: String, fallback: String, url: String? = nil) -> String {
    let kind = catalogResolvedRulesheetSourceKind(
        providerRawValue: providerRawValue,
        fallbackLabel: fallback,
        url: url
    )
    return kind == .other ? fallback : "Rulesheet (\(kind.shortTitle))"
}

nonisolated private func catalogResolvedRulesheetSourceKind(
    providerRawValue: String,
    fallbackLabel: String,
    url: String?
) -> LibraryRulesheetSourceKind {
    let normalizedProvider = providerRawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalizedProvider == "pinprof" {
        return .prof
    }

    switch CatalogRulesheetProvider(rawValue: normalizedProvider) {
    case .local:
        return .local
    case .prof:
        return .prof
    case .bob:
        return .bob
    case .papa:
        return .papa
    case .pp:
        return .pp
    case .tf:
        return .tf
    case .opdb:
        return .opdb
    case nil:
        return PinballGame.ReferenceLink(label: fallbackLabel, url: url ?? "").rulesheetSourceKind
    }
}
