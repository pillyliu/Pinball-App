import Foundation

struct CatalogSourceRecord: Decodable {
    let id: String
    let type: String
    let name: String
    let provider: String?
    let providerSourceID: String?
    let isBuiltin: Bool?
    let isEnabled: Bool?
    let isPinned: Bool?
    let pinRank: Int?
    let defaultSort: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case provider
        case providerSourceID = "provider_source_id"
        case isBuiltin = "is_builtin"
        case isEnabled = "is_enabled"
        case isPinned = "is_pinned"
        case pinRank = "pin_rank"
        case defaultSort = "default_sort"
    }
}

struct CatalogMembershipRecord: Decodable {
    let sourceID: String
    let practiceIdentity: String
    let sortName: String?
    let sortYear: Int?
    let area: String?
    let areaOrder: Int?
    let groupNumber: Int?
    let position: Int?
    let bank: Int?

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case practiceIdentity = "practice_identity"
        case sortName = "sort_name"
        case sortYear = "sort_year"
        case area
        case areaOrder = "area_order"
        case groupNumber = "group_number"
        case position
        case bank
    }
}

struct CatalogOverrideRecord: Decodable {
    let practiceIdentity: String
    let rulesheetLocalPath: String?
    let playfieldLocalPath: String?
    let playfieldSourceURL: String?
    let gameinfoLocalPath: String?
    let nameOverride: String?
    let variantOverride: String?
    let manufacturerOverride: String?
    let yearOverride: Int?

    enum CodingKeys: String, CodingKey {
        case practiceIdentity = "practice_identity"
        case rulesheetLocalPath = "rulesheet_local_path"
        case playfieldLocalPath = "playfield_local_path"
        case playfieldSourceURL = "playfield_source_url"
        case gameinfoLocalPath = "gameinfo_local_path"
        case nameOverride = "name_override"
        case variantOverride = "variant_override"
        case manufacturerOverride = "manufacturer_override"
        case yearOverride = "year_override"
    }
}

struct CatalogRulesheetLinkRecord: Decodable {
    let practiceIdentity: String
    let provider: String
    let label: String
    let localPath: String?
    let url: String?
    let priority: Int?

    enum CodingKeys: String, CodingKey {
        case practiceIdentity = "practice_identity"
        case provider
        case label
        case localPath = "local_path"
        case url
        case priority
    }
}

struct CatalogVideoLinkRecord: Decodable {
    let practiceIdentity: String
    let provider: String
    let kind: String
    let label: String
    let url: String
    let priority: Int?

    enum CodingKeys: String, CodingKey {
        case practiceIdentity = "practice_identity"
        case provider
        case kind
        case label
        case url
        case priority
    }
}
