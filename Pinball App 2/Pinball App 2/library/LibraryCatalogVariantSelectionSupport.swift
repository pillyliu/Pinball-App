import Foundation

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
