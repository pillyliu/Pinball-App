import Foundation

func practiceDisplayTitleForGames(_ games: [PinballGame]) -> String {
    let baseCandidates = games
        .map(\.name)
        .map(practiceNormalizedDisplayBaseTitle)
        .filter { !$0.isEmpty }
    if let best = practicePreferredDisplayTitleCandidate(from: baseCandidates) {
        return best
    }

    let opdbCandidates = games
        .compactMap(\.opdbName)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .map(practiceNormalizedDisplayBaseTitle)
        .filter { !$0.isEmpty }
    if let best = practicePreferredDisplayTitleCandidate(from: opdbCandidates) {
        return best
    }

    return games.map(\.name).min(by: practiceDisplayTitleOrder) ?? games.first?.name ?? "Unknown Game"
}

func practiceDisplayTitle(for canonicalGameID: String, in games: [PinballGame]) -> String? {
    let trimmed = canonicalGameID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let grouped = games.filter { $0.canonicalPracticeKey == trimmed }
    guard !grouped.isEmpty else { return nil }
    return practiceDisplayTitleForGames(grouped)
}

private func practiceNormalizedDisplayBaseTitle(_ raw: String) -> String {
    var current = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !current.isEmpty else { return "" }

    let pattern = #"\s*\([^()]*\)\s*$"#
    while let range = current.range(of: pattern, options: .regularExpression) {
        let candidate = current.replacingCharacters(in: range, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { break }
        current = candidate
    }

    return current
}

private func practicePreferredDisplayTitleCandidate(from candidates: [String]) -> String? {
    let normalized = candidates
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    guard !normalized.isEmpty else { return nil }

    let counts = Dictionary(grouping: normalized, by: {
        $0.folding(options: [.diacriticInsensitive], locale: .current).lowercased()
    })
    let ranked = counts.values.compactMap { group -> String? in
        group.min(by: practiceDisplayTitleOrder)
    }

    return ranked.max { lhs, rhs in
        let lhsCount = counts[lhs.folding(options: [.diacriticInsensitive], locale: .current).lowercased()]?.count ?? 0
        let rhsCount = counts[rhs.folding(options: [.diacriticInsensitive], locale: .current).lowercased()]?.count ?? 0
        if lhsCount != rhsCount { return lhsCount < rhsCount }
        return !practiceDisplayTitleOrder(lhs, rhs)
    }
}

private func practiceDisplayTitleOrder(_ lhs: String, _ rhs: String) -> Bool {
    let lhsTrimmed = lhs.trimmingCharacters(in: .whitespacesAndNewlines)
    let rhsTrimmed = rhs.trimmingCharacters(in: .whitespacesAndNewlines)
    if lhsTrimmed.count != rhsTrimmed.count {
        return lhsTrimmed.count < rhsTrimmed.count
    }
    return lhsTrimmed.localizedCaseInsensitiveCompare(rhsTrimmed) == .orderedAscending
}
