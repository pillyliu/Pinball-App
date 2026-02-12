import Foundation
import Combine

struct GameTaskSummaryRow: Identifiable {
    let task: StudyTaskKind
    let count: Int
    let lastTimestamp: Date?
    let latestProgress: Int?

    var id: String { task.id }
}

@MainActor
final class PracticeUpgradeStore: ObservableObject {
    @Published private(set) var games: [PinballGame] = []
    @Published private(set) var isLoadingGames = false
    @Published private(set) var state = PracticeUpgradeState.empty
    @Published private(set) var lastErrorMessage: String?

    private static let libraryPath = "/pinball/data/pinball_library.json"
    private static let storageKey = "practice-upgrade-state-v1"

    private var didLoad = false

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true

        loadState()
        await loadGames()

        if state.journalEntries.isEmpty {
            seedSamplePlaceholders()
        }
    }

    func gameName(for id: String) -> String {
        games.first(where: { $0.id == id })?.name ?? id
    }

    func studyProgress(gameID: String, task: StudyTaskKind) -> Int {
        state.studyEvents
            .filter { $0.gameID == gameID && $0.task == task }
            .sorted { $0.timestamp < $1.timestamp }
            .last?
            .progressPercent ?? 0
    }

    func studyHistory(gameID: String, task: StudyTaskKind) -> [StudyProgressEvent] {
        state.studyEvents
            .filter { $0.gameID == gameID && $0.task == task }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func updateStudyProgress(gameID: String, task: StudyTaskKind, progressPercent: Int) {
        addGameTaskEntry(
            gameID: gameID,
            task: task,
            progressPercent: progressPercent,
            note: "Updated \(task.label.lowercased())"
        )
    }

    func addGameTaskEntry(gameID: String, task: StudyTaskKind, progressPercent: Int?, note: String?) {
        if let progressPercent {
            let event = StudyProgressEvent(gameID: gameID, task: task, progressPercent: progressPercent)
            state.studyEvents.append(event)
        }

        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: actionType(for: task),
                progressPercent: progressPercent,
                note: note
            )
        )

        saveState()
    }

    func addManualVideoProgress(gameID: String, kind: VideoProgressInputKind, value: String) {
        let entry = VideoProgressEntry(gameID: gameID, kind: kind, value: value)
        state.videoProgressEntries.append(entry)
        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: .tutorialWatch,
                note: "Manual video progress: \(value) \(kind.label)"
            )
        )
        saveState()
    }

    func addScore(gameID: String, score: Double, context: ScoreContext, tournamentName: String?) {
        let entry = ScoreLogEntry(
            gameID: gameID,
            score: score,
            context: context,
            tournamentName: context == .tournament ? tournamentName?.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            leagueImported: false
        )

        state.scoreEntries.append(entry)
        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: .scoreLogged,
                note: "Logged \(formatScore(score)) as \(context.label)"
            )
        )
        saveState()
    }

    func addNote(gameID: String, category: PracticeCategory, detail: String?, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = PracticeNoteEntry(
            gameID: gameID,
            category: category,
            detail: detail?.trimmingCharacters(in: .whitespacesAndNewlines),
            note: trimmed
        )

        state.noteEntries.append(entry)
        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: .noteAdded,
                note: "\(category.label): \(trimmed)"
            )
        )
        saveState()
    }

    func createGroup(name: String, gameIDs: [String]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let group = CustomGameGroup(name: trimmed, gameIDs: Array(Set(gameIDs)).sorted())
        state.customGroups.append(group)
        saveState()
    }

    func applyBankTemplate(bank: Int, into groupName: String) {
        let gameIDs = games.filter { $0.bank == bank }.map(\.id)
        createGroup(name: groupName.isEmpty ? "Bank \(bank) Focus" : groupName, gameIDs: gameIDs)
    }

    func updateLeagueSettings(playerName: String, csvAutoFillEnabled: Bool) {
        state.leagueSettings.playerName = playerName
        state.leagueSettings.csvAutoFillEnabled = csvAutoFillEnabled
        saveState()
    }

    func markLeagueImportAttempt() {
        state.leagueSettings.lastImportAt = Date()
        state.journalEntries.append(
            JournalEntry(
                gameID: games.first?.id ?? "library",
                action: .scoreLogged,
                note: "Placeholder: attempted LPL stats CSV auto-fill"
            )
        )
        saveState()
    }

    func updateSyncSettings(cloudSyncEnabled: Bool) {
        state.syncSettings.cloudSyncEnabled = cloudSyncEnabled
        state.syncSettings.phaseLabel = cloudSyncEnabled ? "Phase 2: Optional cloud sync" : "Phase 1: On-device"
        saveState()
    }

    func updateAnalyticsSettings(gapMode: ChartGapMode, useMedian: Bool) {
        state.analyticsSettings.gapMode = gapMode
        state.analyticsSettings.useMedian = useMedian
        saveState()
    }

    func scoreSummary(for gameID: String) -> ScoreSummary? {
        let values = state.scoreEntries
            .filter { $0.gameID == gameID }
            .map(\.score)

        guard !values.isEmpty else { return nil }

        let average = values.reduce(0, +) / Double(values.count)
        let sorted = values.sorted()
        let median: Double
        if sorted.count % 2 == 0 {
            let upper = sorted.count / 2
            median = (sorted[upper - 1] + sorted[upper]) / 2
        } else {
            median = sorted[sorted.count / 2]
        }

        return ScoreSummary(
            average: average,
            median: median,
            floor: sorted.first ?? average,
            p25: values.pinballPercentile(0.25) ?? average,
            p75: values.pinballPercentile(0.75) ?? average
        )
    }

    func recentJournalEntries(limit: Int = 60) -> [JournalEntry] {
        Array(state.journalEntries.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }

    func gameJournalEntries(for gameID: String, limit: Int = 120) -> [JournalEntry] {
        Array(
            state.journalEntries
                .filter { $0.gameID == gameID }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(limit)
        )
    }

    func gameTaskSummary(for gameID: String) -> [GameTaskSummaryRow] {
        StudyTaskKind.allCases.map { task in
            let action = actionType(for: task)
            let taskLogs = state.journalEntries
                .filter { $0.gameID == gameID && $0.action == action }
                .sorted { $0.timestamp > $1.timestamp }
            let latestProgress = state.studyEvents
                .filter { $0.gameID == gameID && $0.task == task }
                .sorted { $0.timestamp > $1.timestamp }
                .first?
                .progressPercent

            return GameTaskSummaryRow(
                task: task,
                count: taskLogs.count,
                lastTimestamp: taskLogs.first?.timestamp,
                latestProgress: latestProgress
            )
        }
    }

    func journalSummary(for entry: JournalEntry) -> String {
        let name = gameName(for: entry.gameID)

        switch entry.action {
        case .rulesheetRead:
            if let progress = entry.progressPercent {
                return "Read \(progress)% of \(name) rulesheet"
            }
            return "Read \(name) rulesheet"
        case .tutorialWatch:
            return "Updated tutorial progress for \(name)"
        case .gameplayWatch:
            return "Updated gameplay progress for \(name)"
        case .playfieldViewed:
            return "Viewed \(name) playfield"
        case .gameBrowse:
            return "Browsed \(name)"
        case .practiceSession:
            if let progress = entry.progressPercent {
                return "Practice progress \(progress)% on \(name)"
            }
            return "Logged practice for \(name)"
        case .scoreLogged:
            return entry.note ?? "Logged score for \(name)"
        case .noteAdded:
            return entry.note ?? "Added note for \(name)"
        }
    }

    func recentScores(for gameID: String, limit: Int = 10) -> [ScoreLogEntry] {
        Array(
            state.scoreEntries
                .filter { $0.gameID == gameID }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(limit)
        )
    }

    func recentNotes(for gameID: String, limit: Int = 15) -> [PracticeNoteEntry] {
        Array(
            state.noteEntries
                .filter { $0.gameID == gameID }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(limit)
        )
    }

    func groupPriorityCandidates(group: CustomGameGroup) -> [PinballGame] {
        let groupGames = games.filter { group.gameIDs.contains($0.id) }
        return groupGames.sorted { lhs, rhs in
            scoreGapSeverity(for: lhs.id) > scoreGapSeverity(for: rhs.id)
        }
    }

    private func scoreGapSeverity(for gameID: String) -> Double {
        guard let summary = scoreSummary(for: gameID) else { return 999_999 }
        return max(0, summary.median - summary.floor)
    }

    private func loadState() {
        guard let raw = UserDefaults.standard.data(forKey: Self.storageKey) else {
            state = .empty
            return
        }

        do {
            state = try JSONDecoder().decode(PracticeUpgradeState.self, from: raw)
        } catch {
            lastErrorMessage = "Failed to load saved practice data: \(error.localizedDescription)"
            state = .empty
        }
    }

    private func saveState() {
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            lastErrorMessage = "Failed to save practice data: \(error.localizedDescription)"
        }
    }

    private func loadGames() async {
        isLoadingGames = true
        defer { isLoadingGames = false }

        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.libraryPath)
            guard let text = cached.text,
                  let data = text.data(using: .utf8) else {
                throw URLError(.cannotDecodeRawData)
            }
            let loaded = try JSONDecoder().decode([PinballGame].self, from: data)
            games = loaded
        } catch {
            games = []
            lastErrorMessage = "Failed to load library for practice upgrade: \(error.localizedDescription)"
        }
    }

    private func seedSamplePlaceholders() {
        guard let first = games.first else { return }

        state.journalEntries.append(
            JournalEntry(
                gameID: first.id,
                action: .gameBrowse,
                note: "Scaffold initialized for next big upgrade"
            )
        )

        state.studyEvents.append(StudyProgressEvent(gameID: first.id, task: .rulesheet, progressPercent: 35))
        state.scoreEntries.append(ScoreLogEntry(gameID: first.id, score: 325_000_000, context: .practice))
        state.noteEntries.append(
            PracticeNoteEntry(
                gameID: first.id,
                category: .strategy,
                detail: "Opener",
                note: "Placeholder note: stabilize early game before deep mode stack"
            )
        )
        saveState()
    }

    private func formatScore(_ score: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: score)) ?? String(Int(score))
    }

    private func actionType(for task: StudyTaskKind) -> JournalActionType {
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
