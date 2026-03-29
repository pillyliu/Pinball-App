import Foundation

extension PinballLibraryBrowsingState {
    var filteredGames: [PinballGame] {
        let effectiveBank = supportsBankFilter ? selectedBank : nil

        return sourceScopedGames.filter { game in
            let matchesQuery = matchesSearchQuery(
                query,
                fields: [
                    game.name,
                    game.normalizedVariant,
                    game.manufacturer,
                    game.year.map(String.init)
                ]
            )

            let matchesBank = effectiveBank == nil || game.bank == effectiveBank
            return matchesQuery && matchesBank
        }
    }

    var sortedFilteredGames: [PinballGame] {
        switch sortOption {
        case .area:
            return filteredGames.sorted {
                byOptionalAscending($0.areaOrder, $1.areaOrder)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? false
            }
        case .bank:
            return filteredGames.sorted {
                byOptionalAscending($0.bank, $1.bank)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? false
            }
        case .alphabetical:
            return filteredGames.sorted {
                byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? false
            }
        case .year:
            if yearSortDescending {
                return filteredGames.sorted {
                    byOptionalDescending($0.year, $1.year)
                        ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                        ?? false
                }
            } else {
                return filteredGames.sorted {
                    byOptionalAscending($0.year, $1.year)
                        ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                        ?? false
                }
            }
        }
    }

    var visibleSortedFilteredGames: [PinballGame] {
        Array(sortedFilteredGames.prefix(visibleGameLimit))
    }

    var hasMoreVisibleGames: Bool {
        visibleSortedFilteredGames.count < sortedFilteredGames.count
    }

    var showGroupedView: Bool {
        let effectiveBank = supportsBankFilter ? selectedBank : nil
        return effectiveBank == nil && (sortOption == .area || sortOption == .bank)
    }

    var sections: [PinballGroupSection] {
        var out: [PinballGroupSection] = []
        let groupingKey: (PinballGame) -> (String?, Int?) = {
            switch sortOption {
            case .area:
                return { (nil, $0.group) }
            case .bank:
                return { (nil, $0.bank) }
            case .alphabetical, .year:
                return { _ in (nil, nil) }
            }
        }()

        for game in visibleSortedFilteredGames {
            let (locationKey, groupKey) = groupingKey(game)
            if let last = out.last, last.locationKey == locationKey, last.groupKey == groupKey {
                var mutable = last
                mutable.games.append(game)
                out[out.count - 1] = mutable
            } else {
                out.append(PinballGroupSection(locationKey: locationKey, groupKey: groupKey, games: [game]))
            }
        }

        return out
    }
}

private func byOptionalAscending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
    switch (lhs, rhs) {
    case let (l?, r?):
        return byAscending(l, r)
    case (nil, nil):
        return nil
    case (nil, _?):
        return false
    case (_?, nil):
        return true
    }
}

private func byAscending<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool? {
    if lhs == rhs { return nil }
    return lhs < rhs
}

private func byOptionalDescending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
    switch (lhs, rhs) {
    case let (l?, r?):
        return byDescending(l, r)
    case (nil, nil):
        return nil
    case (nil, _?):
        return false
    case (_?, nil):
        return true
    }
}

private func byDescending<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool? {
    if lhs == rhs { return nil }
    return lhs > rhs
}
