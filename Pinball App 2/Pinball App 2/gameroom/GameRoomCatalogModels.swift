import Foundation

struct GameRoomCatalogGame: Identifiable, Hashable {
    let id: String
    let catalogGameID: String
    let opdbID: String
    let canonicalPracticeIdentity: String
    let displayTitle: String
    let displayVariant: String?
    let manufacturerID: String?
    let manufacturer: String?
    let year: Int?
    let primaryImageURL: String?
    let opdbType: String?
    let opdbDisplay: String?
    let opdbShortname: String?
    let opdbCommonName: String?
}

struct GameRoomCatalogSlugMatch: Hashable {
    let catalogGameID: String
    let canonicalPracticeIdentity: String
    let variant: String?
}
