import Foundation

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
