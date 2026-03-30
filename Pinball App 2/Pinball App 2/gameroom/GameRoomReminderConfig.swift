import Foundation

struct MachineReminderConfig: Identifiable, Codable {
    let id: UUID
    var ownedMachineID: UUID
    var taskType: MachineReminderTaskType
    var mode: MachineReminderMode
    var intervalDays: Int?
    var intervalPlays: Int?
    var enabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownedMachineID: UUID,
        taskType: MachineReminderTaskType,
        mode: MachineReminderMode,
        intervalDays: Int? = nil,
        intervalPlays: Int? = nil,
        enabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownedMachineID = ownedMachineID
        self.taskType = taskType
        self.mode = mode
        self.intervalDays = intervalDays
        self.intervalPlays = intervalPlays
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func defaultConfigs(for machineID: UUID, now: Date = Date()) -> [MachineReminderConfig] {
        [
            MachineReminderConfig(
                ownedMachineID: machineID,
                taskType: .glassCleaned,
                mode: .dateBased,
                intervalDays: 30,
                createdAt: now,
                updatedAt: now
            ),
            MachineReminderConfig(
                ownedMachineID: machineID,
                taskType: .playfieldCleaned,
                mode: .dateBased,
                intervalDays: 90,
                createdAt: now,
                updatedAt: now
            ),
            MachineReminderConfig(
                ownedMachineID: machineID,
                taskType: .ballsReplaced,
                mode: .playBased,
                intervalPlays: 5000,
                createdAt: now,
                updatedAt: now
            ),
            MachineReminderConfig(
                ownedMachineID: machineID,
                taskType: .generalInspection,
                mode: .dateBased,
                intervalDays: 45,
                createdAt: now,
                updatedAt: now
            )
        ]
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownedMachineID
        case taskType
        case mode
        case intervalDays
        case intervalPlays
        case enabled
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        id = container.decodeUUID(forKey: .id, default: UUID())
        ownedMachineID = container.decodeUUID(forKey: .ownedMachineID, default: UUID())
        taskType = container.decodeEnum(forKey: .taskType, default: .glassCleaned)
        mode = container.decodeEnum(forKey: .mode, default: .dateBased)
        intervalDays = try? container.decodeIfPresent(Int.self, forKey: .intervalDays)
        intervalPlays = try? container.decodeIfPresent(Int.self, forKey: .intervalPlays)
        enabled = (try? container.decodeIfPresent(Bool.self, forKey: .enabled)) ?? true
        createdAt = container.decodeDateIfPresent(forKey: .createdAt) ?? now
        updatedAt = container.decodeDateIfPresent(forKey: .updatedAt) ?? createdAt
    }
}
