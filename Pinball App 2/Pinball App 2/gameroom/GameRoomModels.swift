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

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension KeyedDecodingContainer {
    func decodeTrimmedStringIfPresent(forKey key: Key) -> String? {
        ((try? decodeIfPresent(String.self, forKey: key)) ?? nil)?.nilIfBlank
    }

    func decodeUUIDIfPresent(forKey key: Key) -> UUID? {
        guard let raw = decodeTrimmedStringIfPresent(forKey: key) else { return nil }
        return UUID(uuidString: raw)
    }

    func decodeUUID(forKey key: Key, default fallback: @autoclosure () -> UUID) -> UUID {
        decodeUUIDIfPresent(forKey: key) ?? fallback()
    }

    func decodeDateIfPresent(forKey key: Key) -> Date? {
        try? decodeIfPresent(Date.self, forKey: key)
    }

    func decodeEnum<T>(forKey key: Key, default fallback: T) -> T
    where T: RawRepresentable & CaseIterable, T.RawValue == String {
        guard let raw = decodeTrimmedStringIfPresent(forKey: key) else { return fallback }
        return T.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(raw) == .orderedSame }) ?? fallback
    }
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
