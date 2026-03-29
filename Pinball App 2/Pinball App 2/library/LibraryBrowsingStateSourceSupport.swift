import Foundation

extension PinballLibraryBrowsingState {
    var selectedSource: PinballLibrarySource? {
        sources.first(where: { $0.id == selectedSourceID }) ?? sources.first
    }

    var visibleSources: [PinballLibrarySource] {
        let pinned = pinnedSourceIDs.compactMap { id in
            sources.first(where: { $0.id == id })
        }
        var visible = pinned
        if let selectedSource, !visible.contains(where: { $0.id == selectedSource.id }) {
            visible.append(selectedSource)
        }
        if let gameRoomSource = sources.first(where: { $0.id == gameRoomLibrarySourceID }),
           !visible.contains(where: { $0.id == gameRoomSource.id }) {
            visible.append(gameRoomSource)
        }
        return visible.isEmpty ? sources : visible
    }

    var sourceScopedGames: [PinballGame] {
        guard let selectedSource else { return games }
        return games.filter { $0.sourceId == selectedSource.id }
    }

    var sortOptions: [PinballLibrarySortOption] {
        guard let selectedSource else {
            return [.area, .alphabetical]
        }
        return librarySortOptions(for: selectedSource, games: sourceScopedGames)
    }

    var supportsBankFilter: Bool {
        guard let selectedSource else { return false }
        return selectedSource.type == .venue && sourceScopedGames.contains { ($0.bank ?? 0) > 0 }
    }

    var bankOptions: [Int] {
        guard supportsBankFilter else { return [] }
        return Array(Set(sourceScopedGames.compactMap(\.bank).filter { $0 > 0 })).sorted()
    }

    var selectedBankLabel: String {
        if let selectedBank {
            return "Bank \(selectedBank)"
        }
        return "All banks"
    }

    var selectedSortLabel: String {
        menuLabel(for: sortOption)
    }

    func menuLabel(for option: PinballLibrarySortOption) -> String {
        if option == .year {
            return yearSortDescending ? "Sort: Year (New-Old)" : "Sort: Year (Old-New)"
        }
        return option.menuLabel
    }
}
