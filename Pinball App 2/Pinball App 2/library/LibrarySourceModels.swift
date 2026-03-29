import Foundation

nonisolated enum PinballLibrarySourceType: String, CaseIterable, Codable {
    case venue
    case category
    case manufacturer
    case tournament
}

nonisolated struct PinballLibrarySource: Identifiable {
    let id: String
    let name: String
    let type: PinballLibrarySourceType

    var defaultSortOption: PinballLibrarySortOption {
        switch type {
        case .venue:
            return .area
        case .category:
            return .alphabetical
        case .manufacturer:
            return .year
        case .tournament:
            return .alphabetical
        }
    }
}

nonisolated enum PinballLibrarySortOption: String, CaseIterable, Identifiable {
    case area
    case bank
    case alphabetical
    case year

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .area:
            return "Sort: Area"
        case .bank:
            return "Sort: Bank"
        case .alphabetical:
            return "Sort: A-Z"
        case .year:
            return "Sort: Year"
        }
    }
}
