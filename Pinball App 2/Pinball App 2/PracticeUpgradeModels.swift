import Foundation

enum StudyTaskKind: String, CaseIterable, Codable, Identifiable {
    case playfield
    case rulesheet
    case tutorialVideo
    case gameplayVideo
    case practice

    var id: String { rawValue }

    var label: String {
        switch self {
        case .playfield: return "View playfield image"
        case .rulesheet: return "Read rulesheet"
        case .tutorialVideo: return "Watch tutorial video(s)"
        case .gameplayVideo: return "Watch gameplay video(s)"
        case .practice: return "Practice the game"
        }
    }
}

enum JournalActionType: String, CaseIterable, Codable, Identifiable {
    case rulesheetRead
    case tutorialWatch
    case gameplayWatch
    case playfieldViewed
    case gameBrowse
    case practiceSession
    case scoreLogged
    case noteAdded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rulesheetRead: return "Rulesheet"
        case .tutorialWatch: return "Tutorial"
        case .gameplayWatch: return "Gameplay"
        case .playfieldViewed: return "Playfield"
        case .gameBrowse: return "Game page"
        case .practiceSession: return "Practice"
        case .scoreLogged: return "Score"
        case .noteAdded: return "Note"
        }
    }
}

enum ScoreContext: String, CaseIterable, Codable, Identifiable {
    case practice
    case league
    case tournament

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}

enum PracticeCategory: String, CaseIterable, Codable, Identifiable {
    case general
    case shots
    case modes
    case multiball
    case strategy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shots: return "Shots"
        case .modes: return "Modes"
        case .multiball: return "Multiball"
        case .strategy: return "Scoring strategy"
        case .general: return "General practice"
        }
    }
}

enum VideoProgressInputKind: String, CaseIterable, Codable, Identifiable {
    case clock
    case percent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clock: return "mm:ss"
        case .percent: return "%"
        }
    }
}

enum ChartGapMode: String, CaseIterable, Codable, Identifiable {
    case realTimeline
    case compressInactive
    case activeSessionsOnly
    case brokenAxis

    var id: String { rawValue }

    var label: String {
        switch self {
        case .realTimeline: return "Real timeline"
        case .compressInactive: return "Compressed inactive periods"
        case .activeSessionsOnly: return "Active sessions only"
        case .brokenAxis: return "Broken axis"
        }
    }
}

struct StudyProgressEvent: Identifiable, Codable {
    let id: UUID
    let gameID: String
    let task: StudyTaskKind
    let progressPercent: Int
    let timestamp: Date

    init(id: UUID = UUID(), gameID: String, task: StudyTaskKind, progressPercent: Int, timestamp: Date = Date()) {
        self.id = id
        self.gameID = gameID
        self.task = task
        self.progressPercent = min(max(progressPercent, 0), 100)
        self.timestamp = timestamp
    }
}

struct VideoProgressEntry: Identifiable, Codable {
    let id: UUID
    let gameID: String
    let kind: VideoProgressInputKind
    let value: String
    let timestamp: Date

    init(id: UUID = UUID(), gameID: String, kind: VideoProgressInputKind, value: String, timestamp: Date = Date()) {
        self.id = id
        self.gameID = gameID
        self.kind = kind
        self.value = value
        self.timestamp = timestamp
    }
}

struct ScoreLogEntry: Identifiable, Codable {
    let id: UUID
    let gameID: String
    let score: Double
    let context: ScoreContext
    let tournamentName: String?
    let timestamp: Date
    let leagueImported: Bool

    init(
        id: UUID = UUID(),
        gameID: String,
        score: Double,
        context: ScoreContext,
        tournamentName: String? = nil,
        timestamp: Date = Date(),
        leagueImported: Bool = false
    ) {
        self.id = id
        self.gameID = gameID
        self.score = score
        self.context = context
        self.tournamentName = tournamentName
        self.timestamp = timestamp
        self.leagueImported = leagueImported
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case gameID
        case score
        case context
        case tournamentName
        case timestamp
        case leagueImported
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        gameID = try container.decodeIfPresent(String.self, forKey: .gameID) ?? ""
        score = try container.decodeIfPresent(Double.self, forKey: .score) ?? 0
        context = try container.decodeIfPresent(ScoreContext.self, forKey: .context) ?? .practice
        tournamentName = try container.decodeIfPresent(String.self, forKey: .tournamentName)
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        leagueImported = try container.decodeIfPresent(Bool.self, forKey: .leagueImported) ?? false
    }
}

struct PracticeNoteEntry: Identifiable, Codable {
    let id: UUID
    let gameID: String
    let category: PracticeCategory
    let detail: String?
    let note: String
    let timestamp: Date

    init(id: UUID = UUID(), gameID: String, category: PracticeCategory, detail: String? = nil, note: String, timestamp: Date = Date()) {
        self.id = id
        self.gameID = gameID
        self.category = category
        self.detail = detail
        self.note = note
        self.timestamp = timestamp
    }
}

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let gameID: String
    let action: JournalActionType
    let task: StudyTaskKind?
    let progressPercent: Int?
    let videoKind: VideoProgressInputKind?
    let videoValue: String?
    let score: Double?
    let scoreContext: ScoreContext?
    let tournamentName: String?
    let noteCategory: PracticeCategory?
    let noteDetail: String?
    let note: String?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        gameID: String,
        action: JournalActionType,
        task: StudyTaskKind? = nil,
        progressPercent: Int? = nil,
        videoKind: VideoProgressInputKind? = nil,
        videoValue: String? = nil,
        score: Double? = nil,
        scoreContext: ScoreContext? = nil,
        tournamentName: String? = nil,
        noteCategory: PracticeCategory? = nil,
        noteDetail: String? = nil,
        note: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.gameID = gameID
        self.action = action
        self.task = task
        self.progressPercent = progressPercent
        self.videoKind = videoKind
        self.videoValue = videoValue
        self.score = score
        self.scoreContext = scoreContext
        self.tournamentName = tournamentName
        self.noteCategory = noteCategory
        self.noteDetail = noteDetail
        self.note = note
        self.timestamp = timestamp
    }
}

struct GameGroupTemplate: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let gameIDs: [String]
}

enum GroupType: String, CaseIterable, Codable, Identifiable {
    case bank
    case location
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bank: return "Bank"
        case .location: return "Location"
        case .custom: return "Custom"
        }
    }
}

struct CustomGameGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var gameIDs: [String]
    var type: GroupType
    var isActive: Bool
    var isPriority: Bool
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case gameIDs
        case type
        case isActive
        case isPriority
        case startDate
        case endDate
        case createdAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        gameIDs: [String],
        type: GroupType = .custom,
        isActive: Bool = true,
        isPriority: Bool = false,
        startDate: Date? = nil,
        endDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.gameIDs = gameIDs
        self.type = type
        self.isActive = isActive
        self.isPriority = isPriority
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Group"
        gameIDs = try container.decodeIfPresent([String].self, forKey: .gameIDs) ?? []
        type = try container.decodeIfPresent(GroupType.self, forKey: .type) ?? .custom
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        isPriority = try container.decodeIfPresent(Bool.self, forKey: .isPriority) ?? false
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

struct PracticeSettings: Codable {
    var playerName: String
    var comparisonPlayerName: String
    var selectedGroupID: UUID?

    private enum CodingKeys: String, CodingKey {
        case playerName
        case comparisonPlayerName
        case selectedGroupID
    }

    init(
        playerName: String,
        comparisonPlayerName: String,
        selectedGroupID: UUID?
    ) {
        self.playerName = playerName
        self.comparisonPlayerName = comparisonPlayerName
        self.selectedGroupID = selectedGroupID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playerName = try container.decodeIfPresent(String.self, forKey: .playerName) ?? ""
        comparisonPlayerName = try container.decodeIfPresent(String.self, forKey: .comparisonPlayerName) ?? ""
        selectedGroupID = try container.decodeIfPresent(UUID.self, forKey: .selectedGroupID)
    }

    static let defaults = PracticeSettings(
        playerName: "",
        comparisonPlayerName: "",
        selectedGroupID: nil
    )
}

struct LeagueLinkSettings: Codable {
    var playerName: String
    var csvAutoFillEnabled: Bool
    var lastImportAt: Date?

    static let empty = LeagueLinkSettings(playerName: "", csvAutoFillEnabled: false, lastImportAt: nil)
}

struct SyncSettings: Codable {
    var cloudSyncEnabled: Bool
    var endpoint: String
    var phaseLabel: String

    static let defaults = SyncSettings(cloudSyncEnabled: false, endpoint: "pillyliu.com", phaseLabel: "Phase 1: On-device")
}

struct AnalyticsSettings: Codable {
    var gapMode: ChartGapMode
    var useMedian: Bool

    static let defaults = AnalyticsSettings(gapMode: .compressInactive, useMedian: true)
}

struct PracticeUpgradeState: Codable {
    var studyEvents: [StudyProgressEvent]
    var videoProgressEntries: [VideoProgressEntry]
    var scoreEntries: [ScoreLogEntry]
    var noteEntries: [PracticeNoteEntry]
    var journalEntries: [JournalEntry]
    var customGroups: [CustomGameGroup]
    var leagueSettings: LeagueLinkSettings
    var syncSettings: SyncSettings
    var analyticsSettings: AnalyticsSettings
    var rulesheetResumeOffsets: [String: Double]
    var videoResumeHints: [String: String]
    var practiceSettings: PracticeSettings

    private enum CodingKeys: String, CodingKey {
        case studyEvents
        case videoProgressEntries
        case scoreEntries
        case noteEntries
        case journalEntries
        case customGroups
        case leagueSettings
        case syncSettings
        case analyticsSettings
        case rulesheetResumeOffsets
        case videoResumeHints
        case practiceSettings
    }

    init(
        studyEvents: [StudyProgressEvent],
        videoProgressEntries: [VideoProgressEntry],
        scoreEntries: [ScoreLogEntry],
        noteEntries: [PracticeNoteEntry],
        journalEntries: [JournalEntry],
        customGroups: [CustomGameGroup],
        leagueSettings: LeagueLinkSettings,
        syncSettings: SyncSettings,
        analyticsSettings: AnalyticsSettings,
        rulesheetResumeOffsets: [String: Double],
        videoResumeHints: [String: String],
        practiceSettings: PracticeSettings
    ) {
        self.studyEvents = studyEvents
        self.videoProgressEntries = videoProgressEntries
        self.scoreEntries = scoreEntries
        self.noteEntries = noteEntries
        self.journalEntries = journalEntries
        self.customGroups = customGroups
        self.leagueSettings = leagueSettings
        self.syncSettings = syncSettings
        self.analyticsSettings = analyticsSettings
        self.rulesheetResumeOffsets = rulesheetResumeOffsets
        self.videoResumeHints = videoResumeHints
        self.practiceSettings = practiceSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        studyEvents = try container.decodeIfPresent([StudyProgressEvent].self, forKey: .studyEvents) ?? []
        videoProgressEntries = try container.decodeIfPresent([VideoProgressEntry].self, forKey: .videoProgressEntries) ?? []
        scoreEntries = try container.decodeIfPresent([ScoreLogEntry].self, forKey: .scoreEntries) ?? []
        noteEntries = try container.decodeIfPresent([PracticeNoteEntry].self, forKey: .noteEntries) ?? []
        journalEntries = try container.decodeIfPresent([JournalEntry].self, forKey: .journalEntries) ?? []
        customGroups = try container.decodeIfPresent([CustomGameGroup].self, forKey: .customGroups) ?? []
        leagueSettings = try container.decodeIfPresent(LeagueLinkSettings.self, forKey: .leagueSettings) ?? .empty
        syncSettings = try container.decodeIfPresent(SyncSettings.self, forKey: .syncSettings) ?? .defaults
        analyticsSettings = try container.decodeIfPresent(AnalyticsSettings.self, forKey: .analyticsSettings) ?? .defaults
        rulesheetResumeOffsets = try container.decodeIfPresent([String: Double].self, forKey: .rulesheetResumeOffsets) ?? [:]
        videoResumeHints = try container.decodeIfPresent([String: String].self, forKey: .videoResumeHints) ?? [:]
        practiceSettings = try container.decodeIfPresent(PracticeSettings.self, forKey: .practiceSettings) ?? .defaults
    }

    static let empty = PracticeUpgradeState(
        studyEvents: [],
        videoProgressEntries: [],
        scoreEntries: [],
        noteEntries: [],
        journalEntries: [],
        customGroups: [],
        leagueSettings: .empty,
        syncSettings: .defaults,
        analyticsSettings: .defaults,
        rulesheetResumeOffsets: [:],
        videoResumeHints: [:],
        practiceSettings: .defaults
    )
}

struct ScoreSummary {
    let average: Double
    let median: Double
    let floor: Double
    let p25: Double
    let p75: Double
}

extension Array where Element == Double {
    func pinballPercentile(_ percentile: Double) -> Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        let clamped = Swift.min(Swift.max(percentile, 0), 1)
        if sorted.count == 1 { return sorted[0] }
        let index = clamped * Double(sorted.count - 1)
        let lower = Int(index.rounded(FloatingPointRoundingRule.down))
        let upper = Int(index.rounded(FloatingPointRoundingRule.up))
        if lower == upper { return sorted[lower] }
        let weight = index - Double(lower)
        return sorted[lower] + ((sorted[upper] - sorted[lower]) * weight)
    }
}
