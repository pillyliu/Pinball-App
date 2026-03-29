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

struct NormalizedLibraryRoot: Decodable {
    let schemaVersion: Int?
    let generatedAt: String?
    let manufacturers: [CatalogManufacturerRecord]?
    let machines: [CatalogMachineRecord]?
    let sources: [CatalogSourceRecord]?
    let sourceMemberships: [CatalogMembershipRecord]?
    let memberships: [CatalogMembershipRecord]?
    let overrides: [CatalogOverrideRecord]?
    let rulesheetLinks: [CatalogRulesheetLinkRecord]?
    let videoLinks: [CatalogVideoLinkRecord]?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case manufacturers
        case machines
        case sources
        case sourceMemberships = "source_memberships"
        case memberships
        case overrides
        case rulesheetLinks = "rulesheet_links"
        case videoLinks = "video_links"
    }
}

struct RawOPDBExportMachineRecord: Decodable {
    struct ManufacturerRecord: Decodable {
        let manufacturerID: Int?
        let name: String?

        enum CodingKeys: String, CodingKey {
            case manufacturerID = "manufacturer_id"
            case name
        }
    }

    struct ImageRecord: Decodable {
        struct URLs: Decodable {
            let medium: String?
            let large: String?
        }

        let primary: Bool?
        let type: String?
        let urls: URLs?
    }

    let opdbID: String
    let isMachine: Bool?
    let name: String
    let commonName: String?
    let shortname: String?
    let manufactureDate: String?
    let manufacturer: ManufacturerRecord?
    let type: String?
    let display: String?
    let playerCount: Int?
    let description: String?
    let ipdbID: Int?
    let images: [ImageRecord]?

    enum CodingKeys: String, CodingKey {
        case opdbID = "opdb_id"
        case isMachine = "is_machine"
        case name
        case commonName = "common_name"
        case shortname
        case manufactureDate = "manufacture_date"
        case manufacturer
        case type
        case display
        case playerCount = "player_count"
        case description
        case ipdbID = "ipdb_id"
        case images
    }
}

struct CatalogManufacturerRecord: Decodable {
    let id: String
    let name: String
    let isModern: Bool?
    let featuredRank: Int?
    let gameCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isModern = "is_modern"
        case featuredRank = "featured_rank"
        case gameCount = "game_count"
    }
}

struct CatalogMachineRecord: Decodable {
    struct RemoteImageSet: Decodable {
        let mediumURL: String?
        let largeURL: String?

        enum CodingKeys: String, CodingKey {
            case mediumURL = "medium_url"
            case largeURL = "large_url"
        }
    }

    let practiceIdentity: String
    let opdbMachineID: String?
    let opdbGroupID: String?
    let slug: String
    let name: String
    let variant: String?
    let manufacturerID: String?
    let manufacturerName: String?
    let year: Int?
    let opdbName: String?
    let opdbCommonName: String?
    let opdbShortname: String?
    let opdbDescription: String?
    let opdbType: String?
    let opdbDisplay: String?
    let opdbPlayerCount: Int?
    let opdbManufactureDate: String?
    let opdbIpdbID: Int?
    let opdbGroupShortname: String?
    let opdbGroupDescription: String?
    let primaryImage: RemoteImageSet?
    let playfieldImage: RemoteImageSet?

    enum CodingKeys: String, CodingKey {
        case practiceIdentity = "practice_identity"
        case opdbMachineID = "opdb_machine_id"
        case opdbGroupID = "opdb_group_id"
        case slug
        case name
        case variant
        case manufacturerID = "manufacturer_id"
        case manufacturerName = "manufacturer_name"
        case year
        case opdbName = "opdb_name"
        case opdbCommonName = "opdb_common_name"
        case opdbShortname = "opdb_shortname"
        case opdbDescription = "opdb_description"
        case opdbType = "opdb_type"
        case opdbDisplay = "opdb_display"
        case opdbPlayerCount = "opdb_player_count"
        case opdbManufactureDate = "opdb_manufacture_date"
        case opdbIpdbID = "opdb_ipdb_id"
        case opdbGroupShortname = "opdb_group_shortname"
        case opdbGroupDescription = "opdb_group_description"
        case primaryImage = "primary_image"
        case playfieldImage = "playfield_image"
    }
}

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

nonisolated struct ResolvedCatalogRecord {
    let sourceID: String
    let sourceName: String
    let sourceType: PinballLibrarySourceType
    let area: String?
    let areaOrder: Int?
    let groupNumber: Int?
    let position: Int?
    let bank: Int?
    let name: String
    let variant: String?
    let manufacturer: String?
    let year: Int?
    let slug: String
    let opdbID: String?
    let opdbMachineID: String?
    let practiceIdentity: String
    let opdbName: String?
    let opdbCommonName: String?
    let opdbShortname: String?
    let opdbDescription: String?
    let opdbType: String?
    let opdbDisplay: String?
    let opdbPlayerCount: Int?
    let opdbManufactureDate: String?
    let opdbIpdbID: Int?
    let opdbGroupShortname: String?
    let opdbGroupDescription: String?
    let primaryImageURL: String?
    let primaryImageLargeURL: String?
    let playfieldImageURL: String?
    let alternatePlayfieldImageURL: String?
    let playfieldLocalPath: String?
    let playfieldSourceLabel: String?
    let gameinfoLocalPath: String?
    let rulesheetLocalPath: String?
    let rulesheetURL: String?
    let rulesheetLinks: [PinballGame.ReferenceLink]
    let videos: [PinballGame.Video]

    init(
        sourceID: String,
        sourceName: String,
        sourceType: PinballLibrarySourceType,
        area: String?,
        areaOrder: Int?,
        groupNumber: Int?,
        position: Int?,
        bank: Int?,
        name: String,
        variant: String?,
        manufacturer: String?,
        year: Int?,
        slug: String,
        opdbID: String?,
        opdbMachineID: String? = nil,
        practiceIdentity: String,
        opdbName: String? = nil,
        opdbCommonName: String? = nil,
        opdbShortname: String? = nil,
        opdbDescription: String? = nil,
        opdbType: String? = nil,
        opdbDisplay: String? = nil,
        opdbPlayerCount: Int? = nil,
        opdbManufactureDate: String? = nil,
        opdbIpdbID: Int? = nil,
        opdbGroupShortname: String? = nil,
        opdbGroupDescription: String? = nil,
        primaryImageURL: String?,
        primaryImageLargeURL: String?,
        playfieldImageURL: String?,
        alternatePlayfieldImageURL: String?,
        playfieldLocalPath: String?,
        playfieldSourceLabel: String?,
        gameinfoLocalPath: String?,
        rulesheetLocalPath: String?,
        rulesheetURL: String?,
        rulesheetLinks: [PinballGame.ReferenceLink],
        videos: [PinballGame.Video]
    ) {
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.sourceType = sourceType
        self.area = area
        self.areaOrder = areaOrder
        self.groupNumber = groupNumber
        self.position = position
        self.bank = bank
        self.name = name
        self.variant = variant
        self.manufacturer = manufacturer
        self.year = year
        self.slug = slug
        self.opdbID = opdbID
        self.opdbMachineID = opdbMachineID
        self.practiceIdentity = practiceIdentity
        self.opdbName = opdbName
        self.opdbCommonName = opdbCommonName
        self.opdbShortname = opdbShortname
        self.opdbDescription = opdbDescription
        self.opdbType = opdbType
        self.opdbDisplay = opdbDisplay
        self.opdbPlayerCount = opdbPlayerCount
        self.opdbManufactureDate = opdbManufactureDate
        self.opdbIpdbID = opdbIpdbID
        self.opdbGroupShortname = opdbGroupShortname
        self.opdbGroupDescription = opdbGroupDescription
        self.primaryImageURL = primaryImageURL
        self.primaryImageLargeURL = primaryImageLargeURL
        self.playfieldImageURL = playfieldImageURL
        self.alternatePlayfieldImageURL = alternatePlayfieldImageURL
        self.playfieldLocalPath = playfieldLocalPath
        self.playfieldSourceLabel = playfieldSourceLabel
        self.gameinfoLocalPath = gameinfoLocalPath
        self.rulesheetLocalPath = rulesheetLocalPath
        self.rulesheetURL = rulesheetURL
        self.rulesheetLinks = rulesheetLinks
        self.videos = videos
    }
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

struct LibraryExtraction {
    let payload: PinballLibraryPayload
    let state: PinballLibrarySourceState
}

struct LegacyCuratedOverride {
    let practiceIdentity: String
    var nameOverride: String?
    var variantOverride: String?
    var manufacturerOverride: String?
    var yearOverride: Int?
    var playfieldLocalPath: String?
    var playfieldSourceURL: String?
    var gameinfoLocalPath: String?
    var rulesheetLocalPath: String?
    var rulesheetLinks: [PinballGame.ReferenceLink]
    var videos: [PinballGame.Video]
}

nonisolated func catalogNormalizedOptionalString(_ value: String?) -> String? {
    libraryNormalizedOptionalString(value)
}
