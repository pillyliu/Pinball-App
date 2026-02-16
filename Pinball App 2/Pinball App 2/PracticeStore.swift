import Foundation
import Combine

struct GameTaskSummaryRow: Identifiable {
    let task: StudyTaskKind
    let count: Int
    let lastTimestamp: Date?
    let latestProgress: Int?

    var id: String { task.id }
}

struct PracticeTimelineSummary {
    let scoreCount: Int
    let activeSessionCount: Int
    let longGapCount: Int
    let longestGapDays: Int
    let modeDescription: String
}

struct PracticeDashboardAlert: Identifiable {
    let id: UUID
    let message: String
    let severity: Severity

    enum Severity {
        case info
        case warning
        case caution
    }
}

struct GroupProgressSnapshot: Identifiable {
    let game: PinballGame
    let taskProgress: [StudyTaskKind: Int]

    var id: String { game.id }
}

struct GroupDashboardScore {
    let completionAverage: Int
    let staleGameCount: Int
    let weakerGameCount: Int
    let recommendedFirst: PinballGame?
}

struct HeadToHeadGameStats: Identifiable {
    let gameID: String
    let gameName: String
    let yourCount: Int
    let opponentCount: Int
    let yourMean: Double
    let opponentMean: Double
    let yourHigh: Double
    let opponentHigh: Double
    let yourLow: Double
    let opponentLow: Double

    var id: String { gameID }
    var meanDelta: Double { yourMean - opponentMean }
    var highDelta: Double { yourHigh - opponentHigh }
    var lowDelta: Double { yourLow - opponentLow }
}

struct HeadToHeadComparison {
    let yourPlayerName: String
    let opponentPlayerName: String
    let totalGamesCompared: Int
    let gamesYouLeadByMean: Int
    let gamesOpponentLeadsByMean: Int
    let averageMeanDelta: Double
    let games: [HeadToHeadGameStats]
}

struct MechanicsSkillLog: Identifiable {
    let id: UUID
    let skill: String
    let timestamp: Date
    let comfort: Int?
    let gameID: String
    let note: String
}

struct MechanicsSkillSummary {
    let skill: String
    let totalLogs: Int
    let latestComfort: Int?
    let averageComfort: Double?
    let trendDelta: Double?
    let latestTimestamp: Date?
}

struct LeagueImportResult {
    let imported: Int
    let duplicatesSkipped: Int
    let unmatchedRows: Int
    let selectedPlayer: String
    let sourcePath: String

    var summaryLine: String {
        "League import for \(redactPlayerNameForDisplay(selectedPlayer)): \(imported) imported, \(duplicatesSkipped) skipped, \(unmatchedRows) unmatched."
    }
}

struct LeagueTargetScores {
    let great: Double
    let main: Double
    let floor: Double
}

@MainActor
final class PracticeStore: ObservableObject {
    @Published var games: [PinballGame] = []
    @Published var isLoadingGames = false
    @Published var state = PracticePersistedState.empty
    @Published var lastErrorMessage: String?

    static let libraryPath = "/pinball/data/pinball_library.json"
    static let leagueStatsPath = "/pinball/data/LPL_Stats.csv"
    static let leagueTargetsPath = "/pinball/data/LPL_Targets.csv"
    static let storageKey = "practice-state-json"
    static let legacyStorageKey = "practice-upgrade-state-v1"

    var didLoad = false
    var leagueTargetsByNormalizedMachine: [String: LeagueTargetScores] = [:]

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true

        loadState()
        await loadGames()
        await loadLeagueTargets()
    }

    func leagueTargetScores(for gameID: String) -> LeagueTargetScores? {
        guard let game = games.first(where: { $0.id == gameID }) else { return nil }
        return leagueTargetScores(forGameName: game.name)
    }

    func gameName(for id: String) -> String {
        games.first(where: { $0.id == id })?.name ?? id
    }

    func actionType(for task: StudyTaskKind) -> JournalActionType {
        switch task {
        case .rulesheet:
            return .rulesheetRead
        case .playfield:
            return .playfieldViewed
        case .tutorialVideo:
            return .tutorialWatch
        case .gameplayVideo:
            return .gameplayWatch
        case .practice:
            return .practiceSession
        }
    }
}

typealias PracticeUpgradeStore = PracticeStore
