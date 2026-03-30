import Foundation

struct OwnedMachineSnapshot: Identifiable, Codable {
    let ownedMachineID: UUID
    var currentPlayCount: Int
    var lastGlassCleanedAt: Date?
    var lastPlayfieldCleanedAt: Date?
    var lastPlayfieldCleanerUsed: String?
    var lastBallsServicedAt: Date?
    var lastBallsReplacedAt: Date?
    var currentBallSetNotes: String?
    var lastPitchCheckedAt: Date?
    var currentPitchValue: Double?
    var currentPitchMeasurementPoint: String?
    var lastLeveledAt: Date?
    var lastRubberServiceAt: Date?
    var lastFlipperServiceAt: Date?
    var lastGeneralInspectionAt: Date?
    var lastServiceAt: Date?
    var openIssueCount: Int
    var dueTaskCount: Int
    var attentionState: GameRoomAttentionState
    var updatedAt: Date

    var id: UUID { ownedMachineID }
}
