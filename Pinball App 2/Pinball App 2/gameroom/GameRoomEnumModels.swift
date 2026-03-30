import Foundation

enum OwnedMachineStatus: String, CaseIterable, Codable, Identifiable {
    case active
    case loaned
    case archived
    case sold
    case traded

    var id: String { rawValue }

    var countsAsActiveInventory: Bool {
        self == .active || self == .loaned
    }
}

enum GameRoomAttentionState: String, CaseIterable, Codable, Identifiable {
    case red
    case yellow
    case green
    case gray

    var id: String { rawValue }
}

enum MachineEventCategory: String, CaseIterable, Codable, Identifiable {
    case service
    case ownership
    case mod
    case media
    case inspection
    case issue
    case custom

    var id: String { rawValue }
}

enum MachineEventType: String, CaseIterable, Codable, Identifiable {
    case glassCleaned
    case playfieldCleaned
    case ballsCleaned
    case ballsReplaced
    case pitchChecked
    case machineLeveled
    case rubbersReplaced
    case flipperServiced
    case generalInspection
    case partReplaced
    case modInstalled
    case modRemoved
    case purchased
    case moved
    case loanedOut
    case returned
    case listedForSale
    case sold
    case traded
    case reacquired
    case issueOpened
    case issueResolved
    case photoAdded
    case videoAdded
    case custom

    var id: String { rawValue }
}

enum MachineIssueStatus: String, CaseIterable, Codable, Identifiable {
    case open
    case monitoring
    case resolved
    case deferred

    var id: String { rawValue }
}

enum MachineIssueSeverity: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high
    case critical

    var id: String { rawValue }
}

enum MachineIssueSubsystem: String, CaseIterable, Codable, Identifiable {
    case flipper
    case slingshot
    case popBumper
    case trough
    case shooterLane
    case switchMatrix
    case opto
    case coil
    case magnet
    case diverter
    case ramp
    case toyMech
    case lighting
    case sound
    case display
    case cabinet
    case software
    case network
    case other

    var id: String { rawValue }
}

enum MachineAttachmentOwnerType: String, CaseIterable, Codable, Identifiable {
    case event
    case issue

    var id: String { rawValue }
}

enum MachineAttachmentKind: String, CaseIterable, Codable, Identifiable {
    case photo
    case video

    var id: String { rawValue }
}

enum MachineReminderTaskType: String, CaseIterable, Codable, Identifiable {
    case glassCleaned
    case playfieldCleaned
    case ballsReplaced
    case pitchChecked
    case machineLeveled
    case rubbersReplaced
    case flipperServiced
    case generalInspection

    var id: String { rawValue }

    var matchingEventTypes: [MachineEventType] {
        switch self {
        case .glassCleaned:
            return [.glassCleaned]
        case .playfieldCleaned:
            return [.playfieldCleaned]
        case .ballsReplaced:
            return [.ballsReplaced]
        case .pitchChecked:
            return [.pitchChecked]
        case .machineLeveled:
            return [.machineLeveled]
        case .rubbersReplaced:
            return [.rubbersReplaced]
        case .flipperServiced:
            return [.flipperServiced]
        case .generalInspection:
            return [.generalInspection]
        }
    }
}

enum MachineReminderMode: String, CaseIterable, Codable, Identifiable {
    case dateBased
    case playBased
    case manualOnly

    var id: String { rawValue }
}

enum MachineImportSource: String, CaseIterable, Codable, Identifiable {
    case pinside

    var id: String { rawValue }
}

enum MachineImportMatchConfidence: String, CaseIterable, Codable, Identifiable {
    case high
    case medium
    case low
    case manual

    var id: String { rawValue }
}
