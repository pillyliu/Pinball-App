import Foundation

nonisolated struct PinballGame: Identifiable, Decodable {
    let sourceId: String
    let sourceName: String
    let sourceType: PinballLibrarySourceType
    let area: String?
    let areaOrder: Int?
    let group: Int?
    let pos: Int?
    let bank: Int?
    let name: String
    let variant: String?
    let manufacturer: String?
    let year: Int?
    let slug: String
    let libraryEntryID: String?
    let opdbID: String?
    let opdbMachineID: String?
    let practiceIdentity: String?
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
    let primaryImageUrl: String?
    let primaryImageLargeUrl: String?
    let playfieldImageUrl: String?
    let alternatePlayfieldImageUrl: String?
    let playfieldSourceLabel: String?
    let playfieldLocalOriginal: String?
    let playfieldLocal: String?
    let gameinfoLocal: String?
    let rulesheetLocal: String?
    let rulesheetUrl: String?
    let rulesheetLinks: [ReferenceLink]
    let videos: [Video]

    nonisolated init(record: ResolvedCatalogRecord) {
        sourceId = record.sourceID
        sourceName = record.sourceName
        sourceType = record.sourceType
        area = record.area
        areaOrder = record.areaOrder
        group = record.groupNumber
        pos = record.position
        bank = record.bank
        name = record.name
        variant = record.variant
        manufacturer = record.manufacturer
        year = record.year
        slug = record.slug
        libraryEntryID = "\(record.sourceID)--\(record.opdbID ?? record.practiceIdentity)"
        opdbID = record.opdbID
        opdbMachineID = record.opdbMachineID
        practiceIdentity = record.practiceIdentity
        opdbName = record.opdbName
        opdbCommonName = record.opdbCommonName
        opdbShortname = record.opdbShortname
        opdbDescription = record.opdbDescription
        opdbType = record.opdbType
        opdbDisplay = record.opdbDisplay
        opdbPlayerCount = record.opdbPlayerCount
        opdbManufactureDate = record.opdbManufactureDate
        opdbIpdbID = record.opdbIpdbID
        opdbGroupShortname = record.opdbGroupShortname
        opdbGroupDescription = record.opdbGroupDescription
        primaryImageUrl = record.primaryImageURL
        primaryImageLargeUrl = record.primaryImageLargeURL
        playfieldImageUrl = record.playfieldImageURL
        alternatePlayfieldImageUrl = record.alternatePlayfieldImageURL
        playfieldSourceLabel = record.playfieldSourceLabel
        let normalizedPlayfieldLocalPath = normalizeLibraryPlayfieldLocalPath(record.playfieldLocalPath)
        playfieldLocalOriginal = normalizedPlayfieldLocalPath
        playfieldLocal = normalizedPlayfieldLocalPath
        gameinfoLocal = record.gameinfoLocalPath
        rulesheetLocal = record.rulesheetLocalPath
        rulesheetUrl = record.rulesheetURL
        rulesheetLinks = record.rulesheetLinks
        videos = record.videos
    }

    var id: String { libraryEntryID ?? opdbID ?? practiceIdentity ?? "" }
    var practiceKey: String { practiceIdentity ?? opdbID ?? "" }
}
