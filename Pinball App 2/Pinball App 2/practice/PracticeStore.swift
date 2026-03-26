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
    let selectionGameID: String
    let game: PinballGame
    let taskProgress: [StudyTaskKind: Int]

    var id: String { selectionGameID }
}

struct GroupDashboardScore {
    let completionAverage: Int
    let staleGameCount: Int
    let weakerGameCount: Int
}

struct GroupDashboardDetail {
    let score: GroupDashboardScore
    let snapshots: [GroupProgressSnapshot]
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
    let repaired: Int

    init(
        imported: Int,
        duplicatesSkipped: Int,
        unmatchedRows: Int,
        selectedPlayer: String,
        sourcePath: String,
        repaired: Int = 0
    ) {
        self.imported = imported
        self.duplicatesSkipped = duplicatesSkipped
        self.unmatchedRows = unmatchedRows
        self.selectedPlayer = selectedPlayer
        self.sourcePath = sourcePath
        self.repaired = repaired
    }

    var hasNewScores: Bool { imported > 0 }
    var hasChanges: Bool { imported > 0 || repaired > 0 }

    var summaryLine: String {
        let repairedSegment = repaired > 0 ? ", \(repaired) repaired" : ""
        return "League import for \(formatLPLPlayerNameForDisplay(selectedPlayer)): \(imported) imported\(repairedSegment), \(duplicatesSkipped) skipped, \(unmatchedRows) unmatched."
    }
}

struct LeagueTargetScores {
    let great: Double
    let main: Double
    let floor: Double
}

@MainActor
final class PracticeStore: ObservableObject {
    @Published var games: [PinballGame] = [] {
        didSet { invalidatePracticeLookupCaches() }
    }
    @Published var allLibraryGames: [PinballGame] = [] {
        didSet { invalidatePracticeLookupCaches() }
    }
    @Published var searchCatalogGames: [PinballGame] = [] {
        didSet { invalidatePracticeLookupCaches() }
    }
    @Published var bankTemplateGames: [PinballGame] = [] {
        didSet { invalidatePracticeLookupCaches() }
    }
    @Published var librarySources: [PinballLibrarySource] = []
    @Published var defaultPracticeSourceID: String?
    @Published var isLoadingGames = false
    @Published var isLoadingSearchCatalog = false
    @Published var isLoadingAllLibraryGames = false
    @Published var isLoadingLeagueTargets = false
    @Published var didLoadLeagueTargets = false
    @Published var isBootstrapping = true
    @Published var state = PracticePersistedState.empty {
        didSet { invalidateDerivedCaches() }
    }
    @Published var lastErrorMessage: String?

    static let leagueStatsPath = hostedLeagueStatsPath
    static let leagueTargetsPath = hostedLeagueTargetsPath
    static let leagueIFPAPlayersPath = hostedLeagueIFPAPlayersPath
    static let resolvedLeagueTargetsPath = hostedResolvedLeagueTargetsPath
    static let leagueMachineMappingsPath = hostedLeagueMachineMappingsPath
    static let storageKey = "practice-state-json"
    static let legacyStorageKey = "practice-upgrade-state-v1"
    static let leagueScoreRepairVersion = 2

    var didLoad = false
    var didLoadAllLibraryGames = false
    var isLoadingLeagueCatalogGames = false
    var leagueCatalogGames: [PinballGame] = [] {
        didSet { invalidatePracticeLookupCaches() }
    }
    var leagueTargetsByPracticeIdentity: [String: LeagueTargetScores] = [:]
    var leagueTargetsByNormalizedMachine: [String: LeagueTargetScores] = [:]
    var cachedLeagueStatsUpdatedAt: Date?
    var cachedLeagueStatsRows: [LeagueCSVRow] = []
    var cachedLeaguePlayers: [String] = []
    var cachedLeagueIFPAPlayersUpdatedAt: Date?
    var cachedLeagueIFPAPlayers: [LeagueIFPAPlayerRecord] = []
    var cachedLeagueMachineMappingsUpdatedAt: Date?
    var cachedLeagueMachineMappings: [String: LeagueMachineMappingRecord] = [:]
    var lastLeagueAutoImportAttemptAt: Date?
    var isAutoImportingLeagueScores = false
    var cachedScoreEntriesByGameID: [String: [ScoreLogEntry]] = [:]
    var cachedScoreSummariesByGameID: [String: ScoreSummary] = [:]
    var cachedGameJournalEntriesByGameID: [String: [JournalEntry]] = [:]
    var cachedGameTaskSummaryRowsByGameID: [String: [GameTaskSummaryRow]] = [:]
    var cachedPracticeGameNames: [String: String] = [:]
    var cachedJournalPayloads: [JournalFilter: CachedPracticeJournalPayload] = [:]
    var cachedGroupDashboardDetails: [UUID: GroupDashboardDetail] = [:]
    var isLoadingBankTemplateGames = false
    var hasRestoredHomeBootstrapSnapshot = false
    let leagueAutoImportCooldown: TimeInterval = 60

    init() {
        restoreHomeBootstrapSnapshotIfAvailableAsync()
    }

    func loadIfNeeded() async {
        guard !didLoad else {
            isBootstrapping = false
            return
        }
        didLoad = true
        defer { isBootstrapping = false }

        await PinballPerformanceTrace.measure("PracticeBootstrap") {
            async let loadedStateTask = Self.loadPersistedStateResult()
            async let initialLibraryStateTask = loadInitialLibraryState()

            let loadedState = await loadedStateTask
            let initialLibraryState = await initialLibraryStateTask
            applyLoadedState(loadedState)
            applyLibraryState(initialLibraryState)
            await ensureBankTemplateGamesLoadedForStoredReferencesIfNeeded()
            await ensureAllLibraryGamesLoadedForStoredReferencesIfNeeded()
            await ensureSearchCatalogGamesLoadedForStoredReferencesIfNeeded()
            let migratedState = migratePracticeStateKeysToCanonicalIfNeeded()
            if let loadedState,
               loadedState.requiresCanonicalSave && !migratedState {
                saveState()
            }
            saveHomeBootstrapSnapshotIfNeeded()
        }
    }

    func leagueTargetScores(for gameID: String) -> LeagueTargetScores? {
        let canonical = canonicalPracticeGameID(gameID)
        if let direct = leagueTargetsByPracticeIdentity[canonical] {
            return direct
        }
        guard let game = gameForAnyID(canonical) else { return nil }
        return leagueTargetScores(forGameName: game.name)
    }

    func gameName(for id: String) -> String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "None" }
        if let cached = cachedPracticeGameNames[trimmed] {
            return cached
        }
        let canonical = canonicalPracticeGameID(trimmed)
        if let cached = cachedPracticeGameNames[canonical] {
            cachedPracticeGameNames[trimmed] = cached
            return cached
        }
        let lookupGames: [PinballGame]
        if !searchCatalogGames.isEmpty && !allLibraryGames.isEmpty {
            lookupGames = allLibraryGames + searchCatalogGames
        } else if !searchCatalogGames.isEmpty {
            lookupGames = games + searchCatalogGames
        } else if !allLibraryGames.isEmpty {
            lookupGames = allLibraryGames
        } else {
            lookupGames = games
        }
        let resolved = practiceDisplayTitle(for: canonical, in: lookupGames)
            ?? gameForAnyID(trimmed)?.name
            ?? trimmed
        cachedPracticeGameNames[trimmed] = resolved
        cachedPracticeGameNames[canonical] = resolved
        return resolved
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

    func invalidatePracticeLookupCaches() {
        cachedPracticeGameNames.removeAll()
        invalidateDerivedCaches()
    }

    func invalidateDerivedCaches() {
        cachedScoreEntriesByGameID.removeAll()
        cachedScoreSummariesByGameID.removeAll()
        cachedGameJournalEntriesByGameID.removeAll()
        cachedGameTaskSummaryRowsByGameID.removeAll()
        cachedJournalPayloads.removeAll()
        cachedGroupDashboardDetails.removeAll()
    }

    func invalidateJournalCaches() {
        invalidateDerivedCaches()
    }
}
