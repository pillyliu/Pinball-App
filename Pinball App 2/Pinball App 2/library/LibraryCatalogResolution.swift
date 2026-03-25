import Foundation

nonisolated func resolveImportedGame(
    machine: CatalogMachineRecord,
    source: PinballImportedSourceRecord,
    manufacturerByID: [String: CatalogManufacturerRecord],
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheets: [CatalogRulesheetLinkRecord],
    opdbVideos: [CatalogVideoLinkRecord],
    venueMetadata: ResolvedImportedVenueMetadata?
) -> PinballGame {
    let manufacturerName = curatedOverride?.manufacturerOverride
        ?? machine.manufacturerName
        ?? machine.manufacturerID.flatMap { manufacturerByID[$0]?.name }
    let resolvedRulesheet = resolveImportedRulesheetLinks(
        curatedOverride: curatedOverride,
        opdbRulesheetLinks: opdbRulesheets
    )
    let resolvedVideos = resolveImportedVideos(
        curatedOverride: curatedOverride,
        opdbVideoLinks: opdbVideos
    )
    let playfieldLocalPath = curatedOverride?.playfieldLocalPath
    let opdbPlayfieldSourceURL = catalogNormalizedOptionalString(
        machine.playfieldImage?.largeURL ?? machine.playfieldImage?.mediumURL
    )
    let hasCuratedPlayfield = playfieldLocalPath != nil || curatedOverride?.playfieldSourceURL != nil
    let playfieldSourceURL = curatedOverride?.playfieldSourceURL ?? opdbPlayfieldSourceURL
    let record = ResolvedCatalogRecord(
        sourceID: source.id,
        sourceName: source.name,
        sourceType: source.type,
        area: venueMetadata?.area,
        areaOrder: venueMetadata?.areaOrder,
        groupNumber: venueMetadata?.groupNumber,
        position: venueMetadata?.position,
        bank: venueMetadata?.bank,
        name: curatedOverride?.nameOverride ?? catalogResolvedDisplayTitle(
            title: machine.name,
            explicitVariant: machine.variant
        ),
        variant: curatedOverride?.variantOverride ?? catalogNormalizedOptionalString(machine.variant),
        manufacturer: catalogNormalizedOptionalString(manufacturerName),
        year: curatedOverride?.yearOverride ?? machine.year,
        slug: machine.slug,
        opdbID: catalogNormalizedOptionalString(machine.opdbMachineID),
        opdbMachineID: catalogNormalizedOptionalString(machine.opdbMachineID),
        practiceIdentity: machine.practiceIdentity,
        opdbName: catalogNormalizedOptionalString(machine.opdbName),
        opdbCommonName: catalogNormalizedOptionalString(machine.opdbCommonName),
        opdbShortname: catalogNormalizedOptionalString(machine.opdbShortname),
        opdbDescription: catalogNormalizedOptionalString(machine.opdbDescription),
        opdbType: catalogNormalizedOptionalString(machine.opdbType),
        opdbDisplay: catalogNormalizedOptionalString(machine.opdbDisplay),
        opdbPlayerCount: machine.opdbPlayerCount,
        opdbManufactureDate: catalogNormalizedOptionalString(machine.opdbManufactureDate),
        opdbIpdbID: machine.opdbIpdbID,
        opdbGroupShortname: catalogNormalizedOptionalString(machine.opdbGroupShortname),
        opdbGroupDescription: catalogNormalizedOptionalString(machine.opdbGroupDescription),
        primaryImageURL: catalogNormalizedOptionalString(machine.primaryImage?.mediumURL),
        primaryImageLargeURL: catalogNormalizedOptionalString(machine.primaryImage?.largeURL),
        playfieldImageURL: playfieldSourceURL,
        alternatePlayfieldImageURL: hasCuratedPlayfield ? opdbPlayfieldSourceURL : nil,
        playfieldLocalPath: playfieldLocalPath,
        playfieldSourceLabel: hasCuratedPlayfield ? nil : (machine.playfieldImage != nil ? "Playfield (OPDB)" : nil),
        gameinfoLocalPath: curatedOverride?.gameinfoLocalPath,
        rulesheetLocalPath: resolvedRulesheet.localPath,
        rulesheetURL: resolvedRulesheet.links.first?.url,
        rulesheetLinks: resolvedRulesheet.links,
        videos: resolvedVideos
    )
    return PinballGame(record: record)
}

nonisolated func catalogPreferredManufacturerMachine(_ lhs: CatalogMachineRecord, _ rhs: CatalogMachineRecord) -> Bool {
    let lhsHasPrimary = lhs.primaryImage?.mediumURL != nil || lhs.primaryImage?.largeURL != nil
    let rhsHasPrimary = rhs.primaryImage?.mediumURL != nil || rhs.primaryImage?.largeURL != nil
    if lhsHasPrimary != rhsHasPrimary {
        return lhsHasPrimary
    }

    let lhsVariant = catalogNormalizedVariant(lhs.variant)
    let rhsVariant = catalogNormalizedVariant(rhs.variant)
    if (lhsVariant == nil) != (rhsVariant == nil) {
        return lhsVariant == nil
    }

    let leftYear = lhs.year ?? Int.max
    let rightYear = rhs.year ?? Int.max
    if leftYear != rightYear {
        return leftYear < rightYear
    }

    let leftName = lhs.name.lowercased()
    let rightName = rhs.name.lowercased()
    if leftName != rightName {
        return leftName < rightName
    }

    return (lhs.opdbMachineID ?? lhs.practiceIdentity) < (rhs.opdbMachineID ?? rhs.practiceIdentity)
}

nonisolated func catalogPreferredGroupDefaultMachine(_ lhs: CatalogMachineRecord, _ rhs: CatalogMachineRecord) -> Bool {
    let lhsVariant = catalogNormalizedVariant(lhs.variant)
    let rhsVariant = catalogNormalizedVariant(rhs.variant)
    if (lhsVariant == nil) != (rhsVariant == nil) {
        return lhsVariant == nil
    }

    let leftYear = lhs.year ?? Int.max
    let rightYear = rhs.year ?? Int.max
    if leftYear != rightYear {
        return leftYear < rightYear
    }

    let leftName = lhs.name.lowercased()
    let rightName = rhs.name.lowercased()
    if leftName != rightName {
        return leftName < rightName
    }

    return (lhs.opdbMachineID ?? lhs.practiceIdentity) < (rhs.opdbMachineID ?? rhs.practiceIdentity)
}

nonisolated func catalogNormalizedVariant(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

nonisolated func catalogResolvedVariantLabel(title: String, explicitVariant: String?) -> String? {
    if let explicitVariant = catalogNormalizedVariantLabel(explicitVariant) {
        return explicitVariant
    }

    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedTitle.hasSuffix(")") else { return nil }
    guard let openParenIndex = trimmedTitle.lastIndex(of: "("), openParenIndex > trimmedTitle.startIndex else {
        return nil
    }

    let rawSuffix = trimmedTitle[trimmedTitle.index(after: openParenIndex)..<trimmedTitle.index(before: trimmedTitle.endIndex)]
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard catalogLooksLikeVariantSuffix(rawSuffix) else { return nil }
    return catalogNormalizedVariantLabel(rawSuffix)
}

nonisolated func catalogResolvedDisplayTitle(title: String, explicitVariant: String?) -> String {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedTitle.hasSuffix(")") else { return trimmedTitle }
    guard let openParenIndex = trimmedTitle.lastIndex(of: "("), openParenIndex > trimmedTitle.startIndex else {
        return trimmedTitle
    }

    let rawSuffix = trimmedTitle[trimmedTitle.index(after: openParenIndex)..<trimmedTitle.index(before: trimmedTitle.endIndex)]
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard catalogLooksLikeVariantSuffix(rawSuffix) else { return trimmedTitle }

    let normalizedSuffix = catalogNormalizedVariantLabel(rawSuffix)
    let normalizedExplicit = catalogNormalizedVariantLabel(explicitVariant)
    if let normalizedExplicit, let normalizedSuffix, normalizedExplicit != normalizedSuffix {
        return trimmedTitle
    }

    let baseTitle = trimmedTitle[..<openParenIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    return baseTitle.isEmpty ? trimmedTitle : baseTitle
}

nonisolated func catalogNormalizedVariantLabel(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    let lowered = trimmed.localizedLowercase
    if lowered == "null" || lowered == "none" {
        return nil
    }
    if lowered == "premium" { return "Premium" }
    if lowered == "pro" { return "Pro" }
    if lowered == "le" || lowered.contains("limited edition") { return "LE" }
    if lowered == "ce" || lowered.contains("collector") { return "CE" }
    if lowered == "se" || lowered.contains("special edition") { return "SE" }
    if lowered == "arcade" { return "Arcade" }
    if lowered == "wizard" { return "Wizard" }
    if lowered == "premium/le" || lowered == "premium le" || lowered == "premium-le" {
        return "Premium/LE"
    }
    if lowered.contains("anniversary") {
        return trimmed
            .split(separator: " ")
            .map { token in
                let loweredToken = token.localizedLowercase
                switch loweredToken {
                case "le", "ce", "se":
                    return loweredToken.uppercased()
                default:
                    return token.prefix(1).uppercased() + token.dropFirst()
                }
            }
            .joined(separator: " ")
    }
    return trimmed
}

private nonisolated func catalogLooksLikeVariantSuffix(_ value: String) -> Bool {
    let lowered = value.localizedLowercase
    return lowered == "premium" ||
        lowered == "pro" ||
        lowered == "le" ||
        lowered == "ce" ||
        lowered == "se" ||
        lowered == "home" ||
        lowered == "arcade" ||
        lowered == "wizard" ||
        lowered.contains("anniversary") ||
        lowered.contains("limited edition") ||
        lowered.contains("special edition") ||
        lowered.contains("collector") ||
        lowered == "premium/le" ||
        lowered == "premium le" ||
        lowered == "premium-le"
}

nonisolated func catalogPreferredMachineForVariant(
    candidates: [CatalogMachineRecord],
    requestedVariant: String?
) -> CatalogMachineRecord? {
    guard !candidates.isEmpty else { return nil }
    guard let requestedVariant = requestedVariant?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
          !requestedVariant.isEmpty else {
        return candidates.min(by: catalogPreferredManufacturerMachine)
    }
    let ranked = candidates.sorted { lhs, rhs in
        let lhsScore = catalogVariantMatchScore(machineVariant: lhs.variant, requestedVariant: requestedVariant)
        let rhsScore = catalogVariantMatchScore(machineVariant: rhs.variant, requestedVariant: requestedVariant)
        if lhsScore != rhsScore { return lhsScore > rhsScore }

        let lhsHasPrimary = catalogMachineHasPrimaryImage(lhs)
        let rhsHasPrimary = catalogMachineHasPrimaryImage(rhs)
        if lhsHasPrimary != rhsHasPrimary { return lhsHasPrimary }

        let lhsYear = lhs.year ?? Int.max
        let rhsYear = rhs.year ?? Int.max
        if lhsYear != rhsYear { return lhsYear < rhsYear }

        return (lhs.opdbMachineID ?? lhs.practiceIdentity) < (rhs.opdbMachineID ?? rhs.practiceIdentity)
    }
    guard let best = ranked.first else { return nil }
    let bestScore = catalogVariantMatchScore(machineVariant: best.variant, requestedVariant: requestedVariant)
    guard bestScore > 0 else { return nil }
    return best
}

nonisolated func catalogPreferredMachineForSourceLookup(
    requestedMachineID: String,
    machineByOPDBID: [String: CatalogMachineRecord],
    machineByPracticeIdentity: [String: [CatalogMachineRecord]]
) -> CatalogMachineRecord? {
    let normalizedMachineID = catalogNormalizedOptionalString(requestedMachineID)
    let preferredGroupMachine = normalizedMachineID
        .flatMap { machineByPracticeIdentity[$0]?.min(by: catalogPreferredManufacturerMachine) }
    guard let normalizedMachineID,
          let exactMachine = machineByOPDBID[normalizedMachineID] else {
        return preferredGroupMachine
    }
    if catalogMachineHasPrimaryImage(exactMachine) {
        return exactMachine
    }
    let exactGroupMachine = machineByPracticeIdentity[exactMachine.practiceIdentity]?.min(by: catalogPreferredManufacturerMachine)
    return exactGroupMachine ?? preferredGroupMachine ?? exactMachine
}

nonisolated func catalogMachineHasPrimaryImage(_ machine: CatalogMachineRecord) -> Bool {
    machine.primaryImage?.mediumURL != nil || machine.primaryImage?.largeURL != nil
}

nonisolated func catalogVariantMatchScore(machineVariant: String?, requestedVariant: String) -> Int {
    let normalizedMachineVariant = machineVariant?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() ?? ""
    guard !normalizedMachineVariant.isEmpty else { return 0 }
    if normalizedMachineVariant == requestedVariant { return 200 }

    let machineTokens = Set(
        normalizedMachineVariant
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    )
    let requestTokens = Set(
        requestedVariant
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    )
    let sharedTokens = machineTokens.intersection(requestTokens)
    if !sharedTokens.isEmpty {
        var score = 100 + (sharedTokens.count * 20)
        if sharedTokens.contains("anniversary") { score += 200 }
        if sharedTokens.contains(where: { $0.hasSuffix("th") || Int($0) != nil }) { score += 120 }
        if sharedTokens.contains("premium") { score += 40 }
        if sharedTokens.contains("le") { score += 40 }
        return score
    }
    if normalizedMachineVariant.contains(requestedVariant) || requestedVariant.contains(normalizedMachineVariant) {
        return 80
    }
    return 0
}

nonisolated func resolveImportedRulesheetLinks(
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheetLinks: [CatalogRulesheetLinkRecord]
) -> (localPath: String?, links: [PinballGame.ReferenceLink]) {
    let resolvedCatalogRulesheets = resolveRulesheetLinks(override: nil, rulesheetLinks: opdbRulesheetLinks)
    if let localPath = catalogNormalizedOptionalString(curatedOverride?.rulesheetLocalPath) {
        return (localPath, mergeRulesheetLinks(
            primary: curatedOverride?.rulesheetLinks ?? [],
            secondary: resolvedCatalogRulesheets.links
        ))
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

nonisolated func catalogDedupedSources(_ sources: [PinballLibrarySource]) -> [PinballLibrarySource] {
    var seen = Set<String>()
    return sources.filter { source in
        seen.insert(source.id).inserted
    }
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
    return (
        catalogNormalizedOptionalString(override?.rulesheetLocalPath) ?? preferredLocalPath,
        links
    )
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
    let leftRank = catalogRulesheetSortRank(providerRawValue: lhs.provider, label: lhs.label, url: lhs.url)
    let rightRank = catalogRulesheetSortRank(providerRawValue: rhs.provider, label: rhs.label, url: rhs.url)
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
    switch providerRawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "pinprof":
        return LibraryRulesheetSourceKind.prof.rawValue
    default:
        break
    }
    switch CatalogRulesheetProvider(rawValue: providerRawValue.lowercased()) {
    case .local:
        return LibraryRulesheetSourceKind.local.rawValue
    case .prof:
        return LibraryRulesheetSourceKind.prof.rawValue
    case .bob:
        return LibraryRulesheetSourceKind.bob.rawValue
    case .papa:
        return LibraryRulesheetSourceKind.papa.rawValue
    case .pp:
        return LibraryRulesheetSourceKind.pp.rawValue
    case .tf:
        return LibraryRulesheetSourceKind.tf.rawValue
    case .opdb:
        return LibraryRulesheetSourceKind.opdb.rawValue
    case nil:
        let inferred = PinballGame.ReferenceLink(label: label, url: url ?? "").rulesheetSourceKind
        return inferred.rawValue
    }
}

nonisolated func catalogRulesheetLabel(providerRawValue: String, fallback: String, url: String? = nil) -> String {
    switch providerRawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "pinprof":
        return "Rulesheet (PinProf)"
    default:
        break
    }
    switch CatalogRulesheetProvider(rawValue: providerRawValue.lowercased()) {
    case .tf:
        return "Rulesheet (TF)"
    case .pp:
        return "Rulesheet (PP)"
    case .bob:
        return "Rulesheet (Bob)"
    case .papa:
        return "Rulesheet (PAPA)"
    case .prof:
        return "Rulesheet (PinProf)"
    case .opdb:
        return "Rulesheet (OPDB)"
    case .local:
        return "Rulesheet (Local)"
    case nil:
        let inferred = PinballGame.ReferenceLink(label: fallback, url: url ?? "").rulesheetSourceKind
        switch inferred {
        case .prof:
            return "Rulesheet (PinProf)"
        case .bob:
            return "Rulesheet (Bob)"
        case .papa:
            return "Rulesheet (PAPA)"
        case .pp:
            return "Rulesheet (PP)"
        case .tf:
            return "Rulesheet (TF)"
        case .opdb:
            return "Rulesheet (OPDB)"
        case .local:
            return "Rulesheet (Local)"
        case .other:
            return fallback
        }
    }
}
