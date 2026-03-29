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

nonisolated func resolveVideoLinks(videoLinks: [CatalogVideoLinkRecord]) -> [PinballGame.Video] {
    var selected: [String: CatalogVideoLinkRecord] = [:]
    for link in videoLinks.sorted(by: { compareVideoLinks($0, $1) }) {
        let key = canonicalVideoMergeKey(kind: link.kind, url: link.url)
        if selected[key] == nil {
            selected[key] = link
        }
    }
    return selected.values.sorted(by: { compareVideoLinks($0, $1) }).map { link in
        PinballGame.Video(kind: link.kind, label: link.label, url: link.url)
    }
}

nonisolated func compareVideoLinks(_ lhs: CatalogVideoLinkRecord, _ rhs: CatalogVideoLinkRecord) -> Bool {
    let leftKind = videoKindOrder(lhs.kind)
    let rightKind = videoKindOrder(rhs.kind)
    if leftKind != rightKind { return leftKind < rightKind }
    let left = lhs.priority ?? Int.max
    let right = rhs.priority ?? Int.max
    if left != right { return left < right }
    let labelComparison = naturalVideoLabelComparison(lhs.label, rhs.label)
    if labelComparison != .orderedSame { return labelComparison == .orderedAscending }
    let leftProvider = videoProviderOrder(lhs.provider)
    let rightProvider = videoProviderOrder(rhs.provider)
    if leftProvider != rightProvider { return leftProvider < rightProvider }
    let leftURL = lhs.url.trimmingCharacters(in: .whitespacesAndNewlines)
    let rightURL = rhs.url.trimmingCharacters(in: .whitespacesAndNewlines)
    if leftURL != rightURL {
        return leftURL.localizedCaseInsensitiveCompare(rightURL) == .orderedAscending
    }
    return false
}

nonisolated private func videoProviderOrder(_ provider: String) -> Int {
    switch provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "local", "pinprof":
        return 0
    case "matchplay":
        return 1
    default:
        return 99
    }
}

nonisolated private func videoKindOrder(_ kind: String?) -> Int {
    switch kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "tutorial":
        return 0
    case "gameplay":
        return 1
    case "competition":
        return 2
    default:
        return 99
    }
}

nonisolated private func extractYouTubeVideoID(from rawURL: String) -> String? {
    guard let components = URLComponents(string: rawURL),
          let host = components.host?.lowercased() else {
        return nil
    }
    let pathComponents = components.path.split(separator: "/").map(String.init)
    if host == "youtu.be" || host == "www.youtu.be" {
        return pathComponents.first
    }
    if host == "youtube.com" || host == "www.youtube.com" || host == "m.youtube.com" || host == "music.youtube.com" || host == "youtube-nocookie.com" || host == "www.youtube-nocookie.com" || host.hasSuffix(".youtube.com") || host.hasSuffix(".youtube-nocookie.com") {
        if pathComponents.first == "watch" {
            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }
        if let first = pathComponents.first, ["embed", "shorts", "live"].contains(first), pathComponents.count >= 2 {
            return pathComponents[1]
        }
        return components.queryItems?.first(where: { $0.name == "v" })?.value
    }
    return nil
}

nonisolated private func canonicalVideoIdentity(url: String) -> String {
    if let youtubeID = extractYouTubeVideoID(from: url) {
        return "youtube:\(youtubeID)"
    }
    return "url:\(url.trimmingCharacters(in: .whitespacesAndNewlines))"
}

nonisolated private func canonicalVideoMergeKey(kind: String?, url: String) -> String {
    let normalizedKind = kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    return "\(normalizedKind)::\(canonicalVideoIdentity(url: url))"
}

nonisolated func mergeResolvedVideos(
    primary: [PinballGame.Video],
    secondary: [PinballGame.Video]
) -> [PinballGame.Video] {
    var merged: [String: PinballGame.Video] = [:]
    var orderedKeys: [String] = []

    for video in primary + secondary {
        guard let url = catalogNormalizedOptionalString(video.url) else {
            continue
        }
        let key = canonicalVideoMergeKey(kind: video.kind, url: url)
        if merged[key] == nil {
            orderedKeys.append(key)
            merged[key] = video
        }
    }

    return orderedKeys
        .compactMap { merged[$0] }
        .sorted(by: { compareResolvedVideos($0, $1) })
}

nonisolated private func compareResolvedVideos(_ lhs: PinballGame.Video, _ rhs: PinballGame.Video) -> Bool {
    let leftKind = videoKindOrder(lhs.kind)
    let rightKind = videoKindOrder(rhs.kind)
    if leftKind != rightKind { return leftKind < rightKind }

    let leftLabel = resolvedVideoSortLabel(label: lhs.label, kind: lhs.kind)
    let rightLabel = resolvedVideoSortLabel(label: rhs.label, kind: rhs.kind)
    let labelComparison = naturalVideoLabelComparison(leftLabel, rightLabel)
    if labelComparison != .orderedSame { return labelComparison == .orderedAscending }

    let leftURL = catalogNormalizedOptionalString(lhs.url) ?? ""
    let rightURL = catalogNormalizedOptionalString(rhs.url) ?? ""
    if leftURL != rightURL {
        return leftURL.localizedCaseInsensitiveCompare(rightURL) == .orderedAscending
    }

    return false
}

nonisolated private func resolvedVideoSortLabel(label: String?, kind: String?) -> String {
    if let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedLabel.isEmpty {
        return trimmedLabel
    }
    if let trimmedKind = kind?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedKind.isEmpty {
        return trimmedKind.replacingOccurrences(of: "_", with: " ")
    }
    return ""
}

nonisolated private func naturalVideoLabelComparison(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let leftTokens = naturalVideoLabelTokens(lhs)
    let rightTokens = naturalVideoLabelTokens(rhs)
    let count = min(leftTokens.count, rightTokens.count)

    for index in 0..<count {
        let left = leftTokens[index]
        let right = rightTokens[index]

        if left.isNumber && right.isNumber {
            let leftValue = Int(left.text) ?? Int.max
            let rightValue = Int(right.text) ?? Int.max
            if leftValue != rightValue {
                return leftValue < rightValue ? .orderedAscending : .orderedDescending
            }
            if left.text.count != right.text.count {
                return left.text.count < right.text.count ? .orderedAscending : .orderedDescending
            }
            continue
        }

        let comparison = left.text.localizedCaseInsensitiveCompare(right.text)
        if comparison != .orderedSame {
            return comparison
        }
    }

    if leftTokens.count != rightTokens.count {
        return leftTokens.count < rightTokens.count ? .orderedAscending : .orderedDescending
    }

    return lhs.localizedCaseInsensitiveCompare(rhs)
}

nonisolated private struct NaturalVideoLabelToken {
    let text: String
    let isNumber: Bool
}

nonisolated private func naturalVideoLabelTokens(_ label: String) -> [NaturalVideoLabelToken] {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return [] }

    var tokens: [NaturalVideoLabelToken] = []
    var current = String(first)
    var currentIsNumber = first.isNumber

    for character in trimmed.dropFirst() {
        if character.isNumber == currentIsNumber {
            current.append(character)
        } else {
            tokens.append(NaturalVideoLabelToken(text: current, isNumber: currentIsNumber))
            current = String(character)
            currentIsNumber = character.isNumber
        }
    }

    tokens.append(NaturalVideoLabelToken(text: current, isNumber: currentIsNumber))
    return tokens
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
