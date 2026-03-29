import Foundation

struct VenueLayoutAreaOverlayRecord: Decodable {
    let sourceID: String
    let area: String
    let areaOrder: Int

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case area
        case areaOrder = "area_order"
    }
}

struct VenueMachineLayoutOverlayRecord: Decodable {
    let sourceID: String
    let opdbID: String
    let area: String?
    let groupNumber: Int?
    let position: Int?

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case opdbID = "opdb_id"
        case area
        case groupNumber = "group_number"
        case position
    }
}

struct VenueMachineBankOverlayRecord: Decodable {
    let sourceID: String
    let opdbID: String
    let bank: Int

    enum CodingKeys: String, CodingKey {
        case sourceID = "source_id"
        case opdbID = "opdb_id"
        case bank
    }
}

struct VenueMetadataOverlayIndex {
    let areaOrderByKey: [String: Int]
    let machineLayoutByKey: [String: VenueMachineLayoutOverlayRecord]
    let machineBankByKey: [String: VenueMachineBankOverlayRecord]
}

let emptyVenueMetadataOverlayIndex = VenueMetadataOverlayIndex(
    areaOrderByKey: [:],
    machineLayoutByKey: [:],
    machineBankByKey: [:]
)

struct ResolvedImportedVenueMetadata {
    let area: String?
    let areaOrder: Int?
    let groupNumber: Int?
    let position: Int?
    let bank: Int?
}
