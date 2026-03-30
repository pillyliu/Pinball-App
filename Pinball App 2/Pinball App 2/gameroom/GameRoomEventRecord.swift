import Foundation

struct MachineEvent: Identifiable, Codable {
    let id: UUID
    var ownedMachineID: UUID
    var type: MachineEventType
    var category: MachineEventCategory
    var occurredAt: Date
    var playCountAtEvent: Int?
    var summary: String
    var notes: String?
    var performedBy: String?
    var cost: Double?
    var partsUsed: String?
    var consumablesUsed: String?
    var pitchValue: Double?
    var pitchMeasurementPoint: String?
    var linkedIssueID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownedMachineID: UUID,
        type: MachineEventType,
        category: MachineEventCategory,
        occurredAt: Date = Date(),
        playCountAtEvent: Int? = nil,
        summary: String,
        notes: String? = nil,
        performedBy: String? = nil,
        cost: Double? = nil,
        partsUsed: String? = nil,
        consumablesUsed: String? = nil,
        pitchValue: Double? = nil,
        pitchMeasurementPoint: String? = nil,
        linkedIssueID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownedMachineID = ownedMachineID
        self.type = type
        self.category = category
        self.occurredAt = occurredAt
        self.playCountAtEvent = playCountAtEvent
        self.summary = summary
        self.notes = notes
        self.performedBy = performedBy
        self.cost = cost
        self.partsUsed = partsUsed
        self.consumablesUsed = consumablesUsed
        self.pitchValue = pitchValue
        self.pitchMeasurementPoint = pitchMeasurementPoint
        self.linkedIssueID = linkedIssueID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var contributesToPlayCount: Bool {
        type == .custom && category == .custom
    }

    var loggedPlayCountTotal: Int? {
        guard contributesToPlayCount,
              let playCountAtEvent,
              playCountAtEvent >= 0 else {
            return nil
        }
        return playCountAtEvent
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownedMachineID
        case type
        case category
        case occurredAt
        case playCountAtEvent
        case summary
        case notes
        case performedBy
        case cost
        case partsUsed
        case consumablesUsed
        case pitchValue
        case pitchMeasurementPoint
        case linkedIssueID
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        id = container.decodeUUID(forKey: .id, default: UUID())
        ownedMachineID = container.decodeUUID(forKey: .ownedMachineID, default: UUID())
        type = container.decodeEnum(forKey: .type, default: .custom)
        category = container.decodeEnum(forKey: .category, default: .custom)
        occurredAt = container.decodeDateIfPresent(forKey: .occurredAt) ?? now
        playCountAtEvent = try? container.decodeIfPresent(Int.self, forKey: .playCountAtEvent)
        summary = container.decodeTrimmedStringIfPresent(forKey: .summary) ?? "Event"
        notes = container.decodeTrimmedStringIfPresent(forKey: .notes)
        performedBy = container.decodeTrimmedStringIfPresent(forKey: .performedBy)
        cost = try? container.decodeIfPresent(Double.self, forKey: .cost)
        partsUsed = container.decodeTrimmedStringIfPresent(forKey: .partsUsed)
        consumablesUsed = container.decodeTrimmedStringIfPresent(forKey: .consumablesUsed)
        pitchValue = try? container.decodeIfPresent(Double.self, forKey: .pitchValue)
        pitchMeasurementPoint = container.decodeTrimmedStringIfPresent(forKey: .pitchMeasurementPoint)
        linkedIssueID = container.decodeUUIDIfPresent(forKey: .linkedIssueID)
        createdAt = container.decodeDateIfPresent(forKey: .createdAt) ?? now
        updatedAt = container.decodeDateIfPresent(forKey: .updatedAt) ?? createdAt
    }
}
