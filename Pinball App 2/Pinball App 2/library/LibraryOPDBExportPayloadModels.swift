import Foundation

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
