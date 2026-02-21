import Foundation

func orderedGamesForDropdown(_ games: [PinballGame], limit: Int? = nil) -> [PinballGame] {
    let ordered = games.sorted { lhs, rhs in
        if lhs.sourceType != rhs.sourceType {
            return lhs.sourceType == .venue
        }
        if let cmp = compareOptionalIntAscending(lhs.areaOrder, rhs.areaOrder), cmp != .orderedSame {
            return cmp == .orderedAscending
        }
        if let cmp = compareOptionalIntAscending(lhs.group, rhs.group), cmp != .orderedSame {
            return cmp == .orderedAscending
        }
        if let cmp = compareOptionalIntAscending(lhs.pos, rhs.pos), cmp != .orderedSame {
            return cmp == .orderedAscending
        }
        if let cmp = compareOptionalIntAscending(lhs.year, rhs.year), cmp != .orderedSame {
            return cmp == .orderedAscending
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
    guard let limit else { return ordered }
    return Array(ordered.prefix(limit))
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
