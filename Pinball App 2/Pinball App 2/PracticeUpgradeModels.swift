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
    case shots
    case modes
    case multiball
    case strategy
    case general

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
    let progressPercent: Int?
    let note: String?
    let timestamp: Date

    init(
        id: UUID = UUID(),
        gameID: String,
        action: JournalActionType,
        progressPercent: Int? = nil,
        note: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.gameID = gameID
        self.action = action
        self.progressPercent = progressPercent
        self.note = note
        self.timestamp = timestamp
    }
}

struct GameGroupTemplate: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let gameIDs: [String]
}

struct CustomGameGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var gameIDs: [String]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, gameIDs: [String], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.gameIDs = gameIDs
        self.createdAt = createdAt
    }
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

    static let empty = PracticeUpgradeState(
        studyEvents: [],
        videoProgressEntries: [],
        scoreEntries: [],
        noteEntries: [],
        journalEntries: [],
        customGroups: [],
        leagueSettings: .empty,
        syncSettings: .defaults,
        analyticsSettings: .defaults
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
