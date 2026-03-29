import Foundation

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
