import Foundation

func orderedGamesForDropdown(_ games: [PinballGame], collapseByPracticeIdentity: Bool = false, limit: Int? = nil) -> [PinballGame] {
    let source = collapseByPracticeIdentity ? dedupePracticeGames(games) : games
    let ordered = source.sorted { lhs, rhs in
        let nameCompare = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameCompare != .orderedSame {
            return nameCompare == .orderedAscending
        }
        if let cmp = compareOptionalIntAscending(lhs.year, rhs.year), cmp != .orderedSame {
            return cmp == .orderedAscending
        }
        return lhs.canonicalPracticeKey.localizedCaseInsensitiveCompare(rhs.canonicalPracticeKey) == .orderedAscending
    }
    guard let limit else { return ordered }
    return Array(ordered.prefix(limit))
}

private func dedupePracticeGames(_ games: [PinballGame]) -> [PinballGame] {
    var seen = Set<String>()
    var out: [PinballGame] = []
    for game in games {
        let key = game.canonicalPracticeKey
        if seen.insert(key).inserted {
            out.append(game)
        }
    }
    return out
}

private func compareOptionalIntAscending(_ lhs: Int?, _ rhs: Int?) -> ComparisonResult? {
    switch (lhs, rhs) {
    case let (l?, r?):
        if l == r { return .orderedSame }
        return l < r ? .orderedAscending : .orderedDescending
    case (.some, .none):
        return .orderedAscending
    case (.none, .some):
        return .orderedDescending
    case (.none, .none):
        return .orderedSame
    }
}
