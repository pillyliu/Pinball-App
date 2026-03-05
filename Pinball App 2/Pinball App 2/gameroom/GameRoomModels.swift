import Foundation

enum OwnedMachineStatus: String, CaseIterable, Codable, Identifiable {
    case active
    case loaned
    case archived
    case sold
    case traded

    var id: String { rawValue }
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
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Area"
        areaOrder = try container.decodeIfPresent(Int.self, forKey: .areaOrder) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

struct OwnedMachine: Identifiable, Codable {
    let id: UUID
    var catalogGameID: String
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
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        catalogGameID = try container.decodeIfPresent(String.self, forKey: .catalogGameID) ?? ""
        canonicalPracticeIdentity = try container.decodeIfPresent(String.self, forKey: .canonicalPracticeIdentity) ?? ""
        displayTitle = try container.decodeIfPresent(String.self, forKey: .displayTitle) ?? "Machine"
        displayVariant = try container.decodeIfPresent(String.self, forKey: .displayVariant)
        importedSourceTitle = try container.decodeIfPresent(String.self, forKey: .importedSourceTitle)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        status = try container.decodeIfPresent(OwnedMachineStatus.self, forKey: .status) ?? .active
        gameRoomAreaID = try container.decodeIfPresent(UUID.self, forKey: .gameRoomAreaID)
        groupNumber = try container.decodeIfPresent(Int.self, forKey: .groupNumber)
        position = try container.decodeIfPresent(Int.self, forKey: .position)
        purchaseDate = try container.decodeIfPresent(Date.self, forKey: .purchaseDate)
        purchaseDateRawText = try container.decodeIfPresent(String.self, forKey: .purchaseDateRawText)
        purchaseSource = try container.decodeIfPresent(String.self, forKey: .purchaseSource)
        purchasePrice = try container.decodeIfPresent(Double.self, forKey: .purchasePrice)
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        manufactureDate = try container.decodeIfPresent(Date.self, forKey: .manufactureDate)
        soldOrTradedDate = try container.decodeIfPresent(Date.self, forKey: .soldOrTradedDate)
        ownershipNotes = try container.decodeIfPresent(String.self, forKey: .ownershipNotes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

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
}

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
}

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
}

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
}

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
}

struct GameRoomPersistedState: Codable {
    static let currentSchemaVersion = 1
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
