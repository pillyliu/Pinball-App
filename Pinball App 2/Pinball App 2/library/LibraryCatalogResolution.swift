import Foundation

nonisolated func resolveImportedGame(
    machine: CatalogMachineRecord,
    source: PinballImportedSourceRecord,
    manufacturerByID: [String: CatalogManufacturerRecord],
    curatedOverride: LegacyCuratedOverride?,
    opdbRulesheets: [CatalogRulesheetLinkRecord],
    opdbVideos: [CatalogVideoLinkRecord]
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
        area: nil,
        areaOrder: nil,
        groupNumber: nil,
        position: nil,
        bank: nil,
        name: curatedOverride?.nameOverride ?? catalogResolvedDisplayTitle(
            title: machine.name,
            explicitVariant: machine.variant
        ),
        variant: curatedOverride?.variantOverride ?? catalogNormalizedOptionalString(machine.variant),
        manufacturer: catalogNormalizedOptionalString(manufacturerName),
        year: curatedOverride?.yearOverride ?? machine.year,
        slug: machine.slug,
        opdbID: catalogNormalizedOptionalString(machine.opdbMachineID),
        practiceIdentity: machine.practiceIdentity,
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
    if let localPath = catalogNormalizedOptionalString(curatedOverride?.rulesheetLocalPath) {
        return (localPath, [])
    }

    if let curatedOverride, !curatedOverride.rulesheetLinks.isEmpty {
        return (nil, curatedOverride.rulesheetLinks)
    }

    return resolveRulesheetLinks(override: nil, rulesheetLinks: opdbRulesheetLinks)
}

nonisolated func resolveImportedVideos(
    curatedOverride: LegacyCuratedOverride?,
    opdbVideoLinks: [CatalogVideoLinkRecord]
) -> [PinballGame.Video] {
    if let curatedOverride, !curatedOverride.videos.isEmpty {
        return curatedOverride.videos
    }
    return resolveVideoLinks(videoLinks: opdbVideoLinks)
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
    if let local = catalogNormalizedOptionalString(override?.rulesheetLocalPath) {
        return (local, [])
    }

    let sortedLinks = rulesheetLinks.sorted {
        ($0.priority ?? Int.max, $0.label) < ($1.priority ?? Int.max, $1.label)
    }
    let links = sortedLinks.compactMap { link -> PinballGame.ReferenceLink? in
        guard let url = catalogNormalizedOptionalString(link.url) else { return nil }
        return PinballGame.ReferenceLink(label: catalogRulesheetLabel(providerRawValue: link.provider, fallback: link.label), url: url)
    }
    return (catalogNormalizedOptionalString(sortedLinks.first?.localPath), links)
}

nonisolated func resolveVideoLinks(videoLinks: [CatalogVideoLinkRecord]) -> [PinballGame.Video] {
    let groupedByProvider = Dictionary(grouping: videoLinks) { link in
        CatalogVideoProvider(rawValue: link.provider.lowercased()) ?? .matchplay
    }
    let preferred = groupedByProvider[.local]?.sorted(by: compareVideoLinks)
        ?? groupedByProvider[.matchplay]?.sorted(by: compareVideoLinks)
        ?? []
    return preferred.map { link in
        PinballGame.Video(kind: link.kind, label: link.label, url: link.url)
    }
}

nonisolated func compareVideoLinks(_ lhs: CatalogVideoLinkRecord, _ rhs: CatalogVideoLinkRecord) -> Bool {
    let left = lhs.priority ?? Int.max
    let right = rhs.priority ?? Int.max
    if left != right { return left < right }
    return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
}

nonisolated func catalogRulesheetLabel(providerRawValue: String, fallback: String) -> String {
    switch CatalogRulesheetProvider(rawValue: providerRawValue.lowercased()) {
    case .tf:
        return "Rulesheet (TF)"
    case .pp:
        return "Rulesheet (PP)"
    case .bob:
        return "Rulesheet (Bob)"
    case .papa:
        return "Rulesheet (PAPA)"
    case .opdb:
        return "Rulesheet (OPDB)"
    case .local:
        return "Rulesheet"
    case nil:
        return fallback
    }
}
