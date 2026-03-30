import Foundation

struct MachineAttachment: Identifiable, Codable {
    let id: UUID
    var ownedMachineID: UUID
    var ownerType: MachineAttachmentOwnerType
    var ownerID: UUID
    var kind: MachineAttachmentKind
    var uri: String
    var thumbnailURI: String?
    var caption: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        ownedMachineID: UUID,
        ownerType: MachineAttachmentOwnerType,
        ownerID: UUID,
        kind: MachineAttachmentKind,
        uri: String,
        thumbnailURI: String? = nil,
        caption: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ownedMachineID = ownedMachineID
        self.ownerType = ownerType
        self.ownerID = ownerID
        self.kind = kind
        self.uri = uri
        self.thumbnailURI = thumbnailURI
        self.caption = caption
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownedMachineID
        case ownerType
        case ownerID
        case kind
        case uri
        case thumbnailURI
        case caption
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeUUID(forKey: .id, default: UUID())
        ownedMachineID = container.decodeUUID(forKey: .ownedMachineID, default: UUID())
        ownerType = container.decodeEnum(forKey: .ownerType, default: .event)
        ownerID = container.decodeUUID(forKey: .ownerID, default: UUID())
        kind = container.decodeEnum(forKey: .kind, default: .photo)
        uri = container.decodeTrimmedStringIfPresent(forKey: .uri) ?? ""
        thumbnailURI = container.decodeTrimmedStringIfPresent(forKey: .thumbnailURI)
        caption = container.decodeTrimmedStringIfPresent(forKey: .caption)
        createdAt = container.decodeDateIfPresent(forKey: .createdAt) ?? Date()
    }
}
