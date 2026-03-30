import Foundation

struct MachineIssue: Identifiable, Codable {
    let id: UUID
    var ownedMachineID: UUID
    var status: MachineIssueStatus
    var severity: MachineIssueSeverity
    var subsystem: MachineIssueSubsystem
    var symptom: String
    var reproSteps: String?
    var diagnosis: String?
    var resolution: String?
    var openedAt: Date
    var resolvedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownedMachineID: UUID,
        status: MachineIssueStatus = .open,
        severity: MachineIssueSeverity = .medium,
        subsystem: MachineIssueSubsystem = .other,
        symptom: String,
        reproSteps: String? = nil,
        diagnosis: String? = nil,
        resolution: String? = nil,
        openedAt: Date = Date(),
        resolvedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownedMachineID = ownedMachineID
        self.status = status
        self.severity = severity
        self.subsystem = subsystem
        self.symptom = symptom
        self.reproSteps = reproSteps
        self.diagnosis = diagnosis
        self.resolution = resolution
        self.openedAt = openedAt
        self.resolvedAt = resolvedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ownedMachineID
        case status
        case severity
        case subsystem
        case symptom
        case reproSteps
        case diagnosis
        case resolution
        case openedAt
        case resolvedAt
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        id = container.decodeUUID(forKey: .id, default: UUID())
        ownedMachineID = container.decodeUUID(forKey: .ownedMachineID, default: UUID())
        status = container.decodeEnum(forKey: .status, default: .open)
        severity = container.decodeEnum(forKey: .severity, default: .medium)
        subsystem = container.decodeEnum(forKey: .subsystem, default: .other)
        symptom = container.decodeTrimmedStringIfPresent(forKey: .symptom) ?? "Issue"
        reproSteps = container.decodeTrimmedStringIfPresent(forKey: .reproSteps)
        diagnosis = container.decodeTrimmedStringIfPresent(forKey: .diagnosis)
        resolution = container.decodeTrimmedStringIfPresent(forKey: .resolution)
        openedAt = container.decodeDateIfPresent(forKey: .openedAt) ?? now
        resolvedAt = container.decodeDateIfPresent(forKey: .resolvedAt)
        createdAt = container.decodeDateIfPresent(forKey: .createdAt) ?? now
        updatedAt = container.decodeDateIfPresent(forKey: .updatedAt) ?? createdAt
    }
}
