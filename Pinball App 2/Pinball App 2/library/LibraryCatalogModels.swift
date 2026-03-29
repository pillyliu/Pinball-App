import Foundation

struct PinballCatalogManufacturerOption: Identifiable, Hashable {
    let id: String
    let name: String
    let gameCount: Int
    let isModern: Bool
    let featuredRank: Int?
    let sortBucket: Int
}

let curatedModernManufacturerNames = [
    "stern",
    "stern pinball",
    "jersey jack pinball",
    "chicago gaming",
    "american pinball",
    "spooky pinball",
    "multimorphic",
    "barrels of fun",
    "dutch pinball",
    "pinball brothers",
    "turner pinball",
    "pinprof labs",
]

struct PinballLibraryVenueSearchResult: Identifiable, Hashable {
    let id: String
    let name: String
    let city: String?
    let state: String?
    let zip: String?
    let distanceMiles: Double?
    let machineCount: Int
}

enum CatalogRulesheetProvider: String {
    case local
    case prof
    case tf
    case pp
    case bob
    case papa
    case opdb
}

enum CatalogVideoProvider: String {
    case local
    case matchplay
}

nonisolated func catalogNormalizedOptionalString(_ value: String?) -> String? {
    libraryNormalizedOptionalString(value)
}
