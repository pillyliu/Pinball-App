import Foundation

struct GameRoomPersistedState: Codable {
    static let currentSchemaVersion = 2
    static let defaultVenueName = "GameRoom"

    var schemaVersion: Int
    var venueName: String
    var areas: [GameRoomArea]
    var ownedMachines: [OwnedMachine]
    var events: [MachineEvent]
    var issues: [MachineIssue]
    var attachments: [MachineAttachment]
    var reminderConfigs: [MachineReminderConfig]
    var importRecords: [MachineImportRecord]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case venueName
        case areas
        case ownedMachines
        case events
        case issues
        case attachments
        case reminderConfigs
        case importRecords
    }

    init(
        schemaVersion: Int = GameRoomPersistedState.currentSchemaVersion,
        venueName: String = GameRoomPersistedState.defaultVenueName,
        areas: [GameRoomArea],
        ownedMachines: [OwnedMachine],
        events: [MachineEvent],
        issues: [MachineIssue],
        attachments: [MachineAttachment],
        reminderConfigs: [MachineReminderConfig],
        importRecords: [MachineImportRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.venueName = venueName
        self.areas = areas
        self.ownedMachines = ownedMachines
        self.events = events
        self.issues = issues
        self.attachments = attachments
        self.reminderConfigs = reminderConfigs
        self.importRecords = importRecords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? GameRoomPersistedState.currentSchemaVersion
        venueName = try container.decodeIfPresent(String.self, forKey: .venueName) ?? GameRoomPersistedState.defaultVenueName
        areas = try container.decodeIfPresent([GameRoomArea].self, forKey: .areas) ?? []
        ownedMachines = try container.decodeIfPresent([OwnedMachine].self, forKey: .ownedMachines) ?? []
        events = try container.decodeIfPresent([MachineEvent].self, forKey: .events) ?? []
        issues = try container.decodeIfPresent([MachineIssue].self, forKey: .issues) ?? []
        attachments = try container.decodeIfPresent([MachineAttachment].self, forKey: .attachments) ?? []
        reminderConfigs = try container.decodeIfPresent([MachineReminderConfig].self, forKey: .reminderConfigs) ?? []
        importRecords = try container.decodeIfPresent([MachineImportRecord].self, forKey: .importRecords) ?? []
    }

    static let empty = GameRoomPersistedState(
        schemaVersion: GameRoomPersistedState.currentSchemaVersion,
        venueName: GameRoomPersistedState.defaultVenueName,
        areas: [],
        ownedMachines: [],
        events: [],
        issues: [],
        attachments: [],
        reminderConfigs: [],
        importRecords: []
    )
}
