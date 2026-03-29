import Foundation

struct PinballLibraryPayload {
    let games: [PinballGame]
    let sources: [PinballLibrarySource]
}

struct PinballGroupSection {
    let locationKey: String?
    let groupKey: Int?
    var games: [PinballGame]
}

struct PinballLibraryBrowsingState {
    let games: [PinballGame]
    let sources: [PinballLibrarySource]
    let selectedSourceID: String
    let query: String
    let sortOption: PinballLibrarySortOption
    let yearSortDescending: Bool
    let selectedBank: Int?
    let visibleGameLimit: Int
    let pinnedSourceIDs: [String]
}
