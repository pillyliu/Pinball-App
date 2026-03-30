import Foundation

struct MachineImportRecord: Identifiable, Codable {
    let id: UUID
    var source: MachineImportSource
    var sourceUserOrURL: String
    var sourceItemKey: String?
    var rawTitle: String
    var rawVariant: String?
    var rawPurchaseDateText: String?
    var normalizedPurchaseDate: Date?
    var matchedCatalogGameID: String?
    var matchConfidence: MachineImportMatchConfidence
    var createdOwnedMachineID: UUID?
    var importedAt: Date
    var fingerprint: String?

    init(
        id: UUID = UUID(),
        source: MachineImportSource,
        sourceUserOrURL: String,
        sourceItemKey: String? = nil,
        rawTitle: String,
        rawVariant: String? = nil,
        rawPurchaseDateText: String? = nil,
        normalizedPurchaseDate: Date? = nil,
        matchedCatalogGameID: String? = nil,
        matchConfidence: MachineImportMatchConfidence,
        createdOwnedMachineID: UUID? = nil,
        importedAt: Date = Date(),
        fingerprint: String? = nil
    ) {
        self.id = id
        self.source = source
        self.sourceUserOrURL = sourceUserOrURL
        self.sourceItemKey = sourceItemKey
        self.rawTitle = rawTitle
        self.rawVariant = rawVariant
        self.rawPurchaseDateText = rawPurchaseDateText
        self.normalizedPurchaseDate = normalizedPurchaseDate
        self.matchedCatalogGameID = matchedCatalogGameID
        self.matchConfidence = matchConfidence
        self.createdOwnedMachineID = createdOwnedMachineID
        self.importedAt = importedAt
        self.fingerprint = fingerprint
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case sourceUserOrURL
        case sourceItemKey
        case rawTitle
        case rawVariant
        case rawPurchaseDateText
        case normalizedPurchaseDate
        case matchedCatalogGameID
        case matchConfidence
        case createdOwnedMachineID
        case importedAt
        case fingerprint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeUUID(forKey: .id, default: UUID())
        source = container.decodeEnum(forKey: .source, default: .pinside)
        sourceUserOrURL = container.decodeTrimmedStringIfPresent(forKey: .sourceUserOrURL) ?? "pinside"
        sourceItemKey = container.decodeTrimmedStringIfPresent(forKey: .sourceItemKey)
        rawTitle = container.decodeTrimmedStringIfPresent(forKey: .rawTitle) ?? "Imported Machine"
        rawVariant = container.decodeTrimmedStringIfPresent(forKey: .rawVariant)
        rawPurchaseDateText = container.decodeTrimmedStringIfPresent(forKey: .rawPurchaseDateText)
        normalizedPurchaseDate = container.decodeDateIfPresent(forKey: .normalizedPurchaseDate)
        matchedCatalogGameID = container.decodeTrimmedStringIfPresent(forKey: .matchedCatalogGameID)
        matchConfidence = container.decodeEnum(forKey: .matchConfidence, default: .manual)
        createdOwnedMachineID = container.decodeUUIDIfPresent(forKey: .createdOwnedMachineID)
        importedAt = container.decodeDateIfPresent(forKey: .importedAt) ?? Date()
        fingerprint = container.decodeTrimmedStringIfPresent(forKey: .fingerprint)
    }
}
