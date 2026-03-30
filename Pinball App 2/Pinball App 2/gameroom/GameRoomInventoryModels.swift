import Foundation

struct GameRoomArea: Identifiable, Codable {
    let id: UUID
    var name: String
    var areaOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        areaOrder: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.areaOrder = areaOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case areaOrder
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeUUID(forKey: .id, default: UUID())
        name = container.decodeTrimmedStringIfPresent(forKey: .name) ?? "Area"
        areaOrder = (try? container.decodeIfPresent(Int.self, forKey: .areaOrder)) ?? 0
        createdAt = container.decodeDateIfPresent(forKey: .createdAt) ?? Date()
        updatedAt = container.decodeDateIfPresent(forKey: .updatedAt) ?? createdAt
    }
}

struct OwnedMachine: Identifiable, Codable {
    let id: UUID
    var catalogGameID: String
    var opdbID: String?
    var canonicalPracticeIdentity: String
    var displayTitle: String
    var displayVariant: String?
    var importedSourceTitle: String?
    var manufacturer: String?
    var year: Int?
    var status: OwnedMachineStatus
    var gameRoomAreaID: UUID?
    var groupNumber: Int?
    var position: Int?
    var purchaseDate: Date?
    var purchaseDateRawText: String?
    var purchaseSource: String?
    var purchasePrice: Double?
    var serialNumber: String?
    var manufactureDate: Date?
    var soldOrTradedDate: Date?
    var ownershipNotes: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        catalogGameID: String,
        opdbID: String? = nil,
        canonicalPracticeIdentity: String,
        displayTitle: String,
        displayVariant: String? = nil,
        importedSourceTitle: String? = nil,
        manufacturer: String? = nil,
        year: Int? = nil,
        status: OwnedMachineStatus = .active,
        gameRoomAreaID: UUID? = nil,
        groupNumber: Int? = nil,
        position: Int? = nil,
        purchaseDate: Date? = nil,
        purchaseDateRawText: String? = nil,
        purchaseSource: String? = nil,
        purchasePrice: Double? = nil,
        serialNumber: String? = nil,
        manufactureDate: Date? = nil,
        soldOrTradedDate: Date? = nil,
        ownershipNotes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.catalogGameID = catalogGameID
        self.opdbID = opdbID
        self.canonicalPracticeIdentity = canonicalPracticeIdentity
        self.displayTitle = displayTitle
        self.displayVariant = displayVariant
        self.importedSourceTitle = importedSourceTitle
        self.manufacturer = manufacturer
        self.year = year
        self.status = status
        self.gameRoomAreaID = gameRoomAreaID
        self.groupNumber = groupNumber
        self.position = position
        self.purchaseDate = purchaseDate
        self.purchaseDateRawText = purchaseDateRawText
        self.purchaseSource = purchaseSource
        self.purchasePrice = purchasePrice
        self.serialNumber = serialNumber
        self.manufactureDate = manufactureDate
        self.soldOrTradedDate = soldOrTradedDate
        self.ownershipNotes = ownershipNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case catalogGameID
        case opdbID = "opdb_id"
        case canonicalPracticeIdentity
        case displayTitle
        case displayVariant
        case importedSourceTitle
        case manufacturer
        case year
        case status
        case gameRoomAreaID
        case groupNumber
        case position
        case purchaseDate
        case purchaseDateRawText
        case purchaseSource
        case purchasePrice
        case serialNumber
        case manufactureDate
        case soldOrTradedDate
        case ownershipNotes
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeUUID(forKey: .id, default: UUID())
        catalogGameID = container.decodeTrimmedStringIfPresent(forKey: .catalogGameID) ?? ""
        opdbID = container.decodeTrimmedStringIfPresent(forKey: .opdbID)
        canonicalPracticeIdentity = container.decodeTrimmedStringIfPresent(forKey: .canonicalPracticeIdentity) ?? ""
        displayTitle = container.decodeTrimmedStringIfPresent(forKey: .displayTitle) ?? "Machine"
        displayVariant = container.decodeTrimmedStringIfPresent(forKey: .displayVariant)
        importedSourceTitle = container.decodeTrimmedStringIfPresent(forKey: .importedSourceTitle)
        manufacturer = container.decodeTrimmedStringIfPresent(forKey: .manufacturer)
        year = try? container.decodeIfPresent(Int.self, forKey: .year)
        status = container.decodeEnum(forKey: .status, default: .active)
        gameRoomAreaID = container.decodeUUIDIfPresent(forKey: .gameRoomAreaID)
        groupNumber = try? container.decodeIfPresent(Int.self, forKey: .groupNumber)
        position = try? container.decodeIfPresent(Int.self, forKey: .position)
        purchaseDate = container.decodeDateIfPresent(forKey: .purchaseDate)
        purchaseDateRawText = container.decodeTrimmedStringIfPresent(forKey: .purchaseDateRawText)
        purchaseSource = container.decodeTrimmedStringIfPresent(forKey: .purchaseSource)
        purchasePrice = try? container.decodeIfPresent(Double.self, forKey: .purchasePrice)
        serialNumber = container.decodeTrimmedStringIfPresent(forKey: .serialNumber)
        manufactureDate = container.decodeDateIfPresent(forKey: .manufactureDate)
        soldOrTradedDate = container.decodeDateIfPresent(forKey: .soldOrTradedDate)
        ownershipNotes = container.decodeTrimmedStringIfPresent(forKey: .ownershipNotes)
        createdAt = container.decodeDateIfPresent(forKey: .createdAt) ?? Date()
        updatedAt = container.decodeDateIfPresent(forKey: .updatedAt) ?? createdAt
    }
}
