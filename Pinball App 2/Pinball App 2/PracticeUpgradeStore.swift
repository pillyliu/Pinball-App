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
        "League import for \(selectedPlayer): \(imported) imported, \(duplicatesSkipped) skipped, \(unmatchedRows) unmatched."
    }
}

@MainActor
final class PracticeUpgradeStore: ObservableObject {
    @Published private(set) var games: [PinballGame] = []
    @Published private(set) var isLoadingGames = false
    @Published private(set) var state = PracticeUpgradeState.empty
    @Published private(set) var lastErrorMessage: String?

    private static let libraryPath = "/pinball/data/pinball_library.json"
    private static let leagueStatsPath = "/pinball/data/LPL_Stats.csv"
    private static let storageKey = "practice-upgrade-state-v1"

    private var didLoad = false

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true

        loadState()
        await loadGames()
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
                task: task,
                progressPercent: progressPercent,
                note: note
            )
        )

        saveState()
    }

    func addManualVideoProgress(gameID: String, action: JournalActionType, kind: VideoProgressInputKind, value: String, note: String? = nil) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = VideoProgressEntry(gameID: gameID, kind: kind, value: trimmedValue)
        state.videoProgressEntries.append(entry)
        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: action,
                task: action == .gameplayWatch ? .gameplayVideo : .tutorialVideo,
                videoKind: kind,
                videoValue: trimmedValue,
                note: (trimmedNote?.isEmpty == true) ? nil : trimmedNote
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
                score: score,
                scoreContext: context,
                tournamentName: entry.tournamentName
            )
        )
        saveState()
    }

    func addNote(gameID: String, category: PracticeCategory, detail: String?, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let trimmedDetail = detail?.trimmingCharacters(in: .whitespacesAndNewlines)

        let detected = detectedMechanicsTags(in: [trimmedDetail, trimmed].compactMap { $0 }.joined(separator: " "))
        let autoTagStrings = detected.map { "#\($0.replacingOccurrences(of: " ", with: "").lowercased())" }
        var autoTaggedNote = trimmed
        for tag in autoTagStrings where !autoTaggedNote.localizedCaseInsensitiveContains(tag) {
            autoTaggedNote += " \(tag)"
        }

        let entry = PracticeNoteEntry(
            gameID: gameID,
            category: category,
            detail: trimmedDetail,
            note: autoTaggedNote
        )

        state.noteEntries.append(entry)
        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: .noteAdded,
                noteCategory: category,
                noteDetail: entry.detail,
                note: autoTaggedNote
            )
        )
        saveState()
    }

    func markGameBrowsed(gameID: String) {
        guard !gameID.isEmpty else { return }

        if let latest = state.journalEntries
            .filter({ $0.gameID == gameID && $0.action == .gameBrowse })
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first,
           Date().timeIntervalSince(latest.timestamp) < 45 {
            return
        }

        state.journalEntries.append(
            JournalEntry(
                gameID: gameID,
                action: .gameBrowse
            )
        )
        saveState()
    }

    @discardableResult
    func createGroup(
        name: String,
        gameIDs: [String],
        type: GroupType = .custom,
        isActive: Bool = true,
        isPriority: Bool = false,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let group = CustomGameGroup(
            name: trimmed,
            gameIDs: uniqueGameIDsPreservingOrder(gameIDs),
            type: type,
            isActive: isActive,
            isPriority: isPriority,
            startDate: startDate,
            endDate: endDate
        )

        if isPriority {
            for idx in state.customGroups.indices {
                state.customGroups[idx].isPriority = false
            }
        }
        state.customGroups.append(group)
        if state.practiceSettings.selectedGroupID == nil {
            state.practiceSettings.selectedGroupID = group.id
        }
        saveState()
        return group.id
    }

    func applyBankTemplate(bank: Int, into groupName: String) {
        let gameIDs = games.filter { $0.bank == bank }.map(\.id)
        createGroup(
            name: groupName.isEmpty ? "Bank \(bank) Focus" : groupName,
            gameIDs: gameIDs,
            type: .bank
        )
    }

    func setSelectedGroup(id: UUID?) {
        state.practiceSettings.selectedGroupID = id
        saveState()
    }

    func selectedGroup() -> CustomGameGroup? {
        if let selected = state.practiceSettings.selectedGroupID,
           let exact = state.customGroups.first(where: { $0.id == selected }) {
            return exact
        }

        if let priority = state.customGroups.first(where: { $0.isActive && $0.isPriority }) {
            return priority
        }

        if let active = state.customGroups.first(where: { $0.isActive }) {
            return active
        }

        return state.customGroups.first
    }

    func updateGroup(
        id: UUID,
        name: String? = nil,
        gameIDs: [String]? = nil,
        type: GroupType? = nil,
        isActive: Bool? = nil,
        isPriority: Bool? = nil,
        replaceStartDate: Bool = false,
        startDate: Date? = nil,
        replaceEndDate: Bool = false,
        endDate: Date? = nil
    ) {
        guard let index = state.customGroups.firstIndex(where: { $0.id == id }) else { return }
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                state.customGroups[index].name = trimmed
            }
        }
        if let gameIDs {
            state.customGroups[index].gameIDs = uniqueGameIDsPreservingOrder(gameIDs)
        }
        if let type {
            state.customGroups[index].type = type
        }
        if let isActive {
            state.customGroups[index].isActive = isActive
        }
        if let isPriority {
            if isPriority {
                for idx in state.customGroups.indices {
                    state.customGroups[idx].isPriority = (state.customGroups[idx].id == id)
                }
            } else {
                state.customGroups[index].isPriority = false
            }
        }
        if replaceStartDate {
            state.customGroups[index].startDate = startDate
        }
        if replaceEndDate {
            state.customGroups[index].endDate = endDate
        }
        saveState()
    }

    func deleteGroup(id: UUID) {
        state.customGroups.removeAll { $0.id == id }
        if state.practiceSettings.selectedGroupID == id {
            state.practiceSettings.selectedGroupID = state.customGroups.first?.id
        }
        saveState()
    }

    func reorderGroups(fromOffsets: IndexSet, toOffset: Int) {
        var reordered = state.customGroups
        let sortedOffsets = fromOffsets.sorted()
        let moving = sortedOffsets.map { reordered[$0] }
        for index in sortedOffsets.reversed() {
            reordered.remove(at: index)
        }

        let removedBeforeDestination = sortedOffsets.filter { $0 < toOffset }.count
        let adjustedDestination = toOffset - removedBeforeDestination
        let destination = max(0, min(adjustedDestination, reordered.count))
        reordered.insert(contentsOf: moving, at: destination)
        state.customGroups = reordered
        saveState()
    }

    func removeGame(_ gameID: String, fromGroup groupID: UUID) {
        guard let index = state.customGroups.firstIndex(where: { $0.id == groupID }) else { return }
        state.customGroups[index].gameIDs.removeAll { $0 == gameID }
        saveState()
    }

    func groupGames(for group: CustomGameGroup) -> [PinballGame] {
        let byID = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
        return group.gameIDs.compactMap { byID[$0] }
    }

    func groupProgress(for group: CustomGameGroup) -> [GroupProgressSnapshot] {
        groupGames(for: group).map { game in
            let progress = Dictionary(
                uniqueKeysWithValues: StudyTaskKind.allCases.map { task in
                    (task, latestTaskProgress(gameID: game.id, task: task))
                }
            )
            return GroupProgressSnapshot(game: game, taskProgress: progress)
        }
    }

    func recommendedGame(in group: CustomGameGroup) -> PinballGame? {
        let groupIDs = Set(group.gameIDs)
        return games
            .filter { groupIDs.contains($0.id) }
            .sorted { focusPriority(for: $0.id) > focusPriority(for: $1.id) }
            .first
    }

    func groupDashboardScore(for group: CustomGameGroup) -> GroupDashboardScore {
        let groupGames = groupGames(for: group)
        guard !groupGames.isEmpty else {
            return GroupDashboardScore(
                completionAverage: 0,
                staleGameCount: 0,
                weakerGameCount: 0,
                recommendedFirst: nil
            )
        }

        let completionValues = groupGames.map { studyCompletionPercent(for: $0.id) }
        let completionAverage = Int((Double(completionValues.reduce(0, +)) / Double(completionValues.count)).rounded())

        let staleGameCount = groupGames.filter { game in
            guard let ts = taskLastTimestamp(gameID: game.id, task: .practice) else { return true }
            let days = Calendar.current.dateComponents([.day], from: ts, to: Date()).day ?? 0
            return days >= 14
        }.count

        let weakerGameCount = groupGames.filter { game in
            guard let summary = scoreSummary(for: game.id), summary.median > 0 else { return true }
            let spread = (summary.p75 - summary.floor) / summary.median
            return spread >= 0.6
        }.count

        return GroupDashboardScore(
            completionAverage: completionAverage,
            staleGameCount: staleGameCount,
            weakerGameCount: weakerGameCount,
            recommendedFirst: recommendedGame(in: group)
        )
    }

    func updatePracticeSettings(playerName: String, comparisonPlayerName: String? = nil) {
        state.practiceSettings.playerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let comparisonPlayerName {
            state.practiceSettings.comparisonPlayerName = comparisonPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        saveState()
    }

    @discardableResult
    func purgeImportedLeagueScores() -> Int {
        let before = state.scoreEntries.count
        state.scoreEntries.removeAll(where: { $0.leagueImported })
        state.journalEntries.removeAll(where: { entry in
            if entry.action != .scoreLogged { return false }
            if entry.scoreContext == .league { return true }
            return (entry.note ?? "").localizedCaseInsensitiveContains("Imported from LPL stats CSV")
        })
        state.leagueSettings.lastImportAt = nil
        saveState()
        return before - state.scoreEntries.count
    }

    var mechanicsSkills: [String] {
        [
            "Dead Bounce",
            "Post Pass",
            "Post Catch",
            "Flick Pass",
            "Nudge Pass",
            "Drop Catch",
            "Live Catch",
            "Shatz",
            "Back Flip",
            "Loop Pass",
            "Slap Save (Single)",
            "Slap Save (Double)",
            "Air Defense",
            "Cradle Separation",
            "Over Under",
            "Tap Pass"
        ]
    }

    func detectedMechanicsTags(in text: String) -> [String] {
        let normalized = text.lowercased()
        return mechanicsSkills.filter { skill in
            mechanicsAliases(for: skill).contains { alias in
                normalized.contains(alias)
            }
        }
    }

    func mechanicsLogs(for skill: String) -> [MechanicsSkillLog] {
        let trimmedSkill = skill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSkill.isEmpty else { return [] }

        return state.noteEntries
            .filter { entry in
                let detailMatch = detectedMechanicsTags(in: entry.detail ?? "").contains(trimmedSkill)
                let tagMatch = entry.note.localizedCaseInsensitiveContains("#\(trimmedSkill.replacingOccurrences(of: " ", with: "").lowercased())")
                let termMatch = detectedMechanicsTags(in: entry.note).contains(trimmedSkill)
                return detailMatch || tagMatch || termMatch
            }
            .sorted { $0.timestamp < $1.timestamp }
            .map { entry in
                MechanicsSkillLog(
                    id: entry.id,
                    skill: trimmedSkill,
                    timestamp: entry.timestamp,
                    comfort: parseComfortValue(from: entry.note),
                    gameID: entry.gameID,
                    note: entry.note
                )
            }
    }

    func mechanicsSummary(for skill: String) -> MechanicsSkillSummary {
        let logs = mechanicsLogs(for: skill)
        let comforts = logs.compactMap(\.comfort)

        let latestComfort = comforts.last
        let averageComfort = comforts.isEmpty ? nil : (Double(comforts.reduce(0, +)) / Double(comforts.count))
        let trendDelta: Double? = {
            guard comforts.count >= 2 else { return nil }
            let split = max(1, comforts.count / 2)
            let firstAvg = Double(comforts.prefix(split).reduce(0, +)) / Double(split)
            let secondSlice = comforts.suffix(comforts.count - split)
            guard !secondSlice.isEmpty else { return nil }
            let secondAvg = Double(secondSlice.reduce(0, +)) / Double(secondSlice.count)
            return secondAvg - firstAvg
        }()

        return MechanicsSkillSummary(
            skill: skill,
            totalLogs: logs.count,
            latestComfort: latestComfort,
            averageComfort: averageComfort,
            trendDelta: trendDelta,
            latestTimestamp: logs.last?.timestamp
        )
    }

    func allTrackedMechanicsSkills() -> [String] {
        var tracked = Set(mechanicsSkills)
        for note in state.noteEntries {
            if let detail = note.detail, !detail.isEmpty {
                for matched in detectedMechanicsTags(in: detail) {
                    tracked.insert(matched)
                }
            }
            for skill in detectedMechanicsTags(in: note.note) {
                tracked.insert(skill)
            }
        }
        return mechanicsSkills.filter { tracked.contains($0) }
    }

    private func uniqueGameIDsPreservingOrder(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for id in ids {
            guard !id.isEmpty, !seen.contains(id) else { continue }
            seen.insert(id)
            ordered.append(id)
        }
        return ordered
    }

    func comparePlayers(yourName: String, opponentName: String) async -> HeadToHeadComparison? {
        let yourNormalized = normalizeHumanName(yourName)
        let opponentNormalized = normalizeHumanName(opponentName)
        guard !yourNormalized.isEmpty, !opponentNormalized.isEmpty else { return nil }

        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.leagueStatsPath)
            guard let text = cached.text else { return nil }
            let rows = parseLeagueRows(text: text)

            let yourRows = rows.filter { normalizeHumanName($0.player) == yourNormalized }
            let opponentRows = rows.filter { normalizeHumanName($0.player) == opponentNormalized }
            guard !yourRows.isEmpty, !opponentRows.isEmpty else { return nil }

            struct PerGameAggregate {
                let gameID: String
                let values: [Double]
            }

            func aggregate(_ rows: [LeagueCSVRow]) -> [String: PerGameAggregate] {
                Dictionary(grouping: rows.compactMap { row -> (String, Double)? in
                    guard let gameID = matchGameID(fromMachine: row.machine) else { return nil }
                    return (gameID, row.rawScore)
                }, by: { $0.0 })
                .mapValues { pairs in
                    PerGameAggregate(gameID: pairs[0].0, values: pairs.map(\.1))
                }
            }

            let yourAgg = aggregate(yourRows)
            let opponentAgg = aggregate(opponentRows)
            let sharedIDs = Set(yourAgg.keys).intersection(opponentAgg.keys)
            guard !sharedIDs.isEmpty else { return nil }

            let games: [HeadToHeadGameStats] = sharedIDs.compactMap { gameID in
                guard let left = yourAgg[gameID], let right = opponentAgg[gameID],
                      !left.values.isEmpty, !right.values.isEmpty else { return nil }
                return HeadToHeadGameStats(
                    gameID: gameID,
                    gameName: gameName(for: gameID),
                    yourCount: left.values.count,
                    opponentCount: right.values.count,
                    yourMean: left.values.reduce(0, +) / Double(left.values.count),
                    opponentMean: right.values.reduce(0, +) / Double(right.values.count),
                    yourHigh: left.values.max() ?? 0,
                    opponentHigh: right.values.max() ?? 0,
                    yourLow: left.values.min() ?? 0,
                    opponentLow: right.values.min() ?? 0
                )
            }
            .sorted { abs($0.meanDelta) > abs($1.meanDelta) }

            let leadCount = games.filter { $0.meanDelta > 0 }.count
            let oppLeadCount = games.filter { $0.meanDelta < 0 }.count
            let avgDelta = games.isEmpty ? 0 : games.map(\.meanDelta).reduce(0, +) / Double(games.count)

            return HeadToHeadComparison(
                yourPlayerName: yourName,
                opponentPlayerName: opponentName,
                totalGamesCompared: games.count,
                gamesYouLeadByMean: leadCount,
                gamesOpponentLeadsByMean: oppLeadCount,
                averageMeanDelta: avgDelta,
                games: games
            )
        } catch {
            lastErrorMessage = "Head-to-head load failed: \(error.localizedDescription)"
            return nil
        }
    }

    func availableLeaguePlayers() async -> [String] {
        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.leagueStatsPath)
            guard let text = cached.text else { return [] }
            let rows = parseLeagueRows(text: text)

            var dedupedByNormalized: [String: String] = [:]
            for row in rows {
                let normalized = normalizeHumanName(row.player)
                guard !normalized.isEmpty else { continue }
                if dedupedByNormalized[normalized] == nil {
                    dedupedByNormalized[normalized] = row.player.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            return dedupedByNormalized.values
                .filter { !$0.isEmpty }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        } catch {
            lastErrorMessage = "Could not load player list: \(error.localizedDescription)"
            return []
        }
    }

    func updateLeagueSettings(playerName: String, csvAutoFillEnabled: Bool) {
        state.leagueSettings.playerName = playerName
        state.leagueSettings.csvAutoFillEnabled = csvAutoFillEnabled
        saveState()
    }

    func rulesheetResumeOffset(for gameID: String) -> Double {
        state.rulesheetResumeOffsets[gameID] ?? 0
    }

    func updateRulesheetResumeOffset(gameID: String, offset: Double) {
        guard !gameID.isEmpty else { return }
        state.rulesheetResumeOffsets[gameID] = max(0, offset)
        saveState()
    }

    func videoResumeHint(for gameID: String) -> String? {
        state.videoResumeHints[gameID]
    }

    func updateVideoResumeHint(gameID: String, hint: String) {
        guard !gameID.isEmpty else { return }
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.videoResumeHints[gameID] = trimmed
        saveState()
    }

    func importLeagueScoresFromCSV() async -> LeagueImportResult {
        let playerName = state.leagueSettings.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !playerName.isEmpty else {
            return LeagueImportResult(
                imported: 0,
                duplicatesSkipped: 0,
                unmatchedRows: 0,
                selectedPlayer: "(none)",
                sourcePath: Self.leagueStatsPath
            )
        }

        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.leagueStatsPath)
            guard let text = cached.text else {
                throw URLError(.cannotDecodeRawData)
            }

            let rows = parseLeagueRows(text: text)
            let normalizedSelectedPlayer = normalizeHumanName(playerName)
            let matchedRows = rows.filter { normalizeHumanName($0.player) == normalizedSelectedPlayer }

            var imported = 0
            var duplicates = 0
            var unmatched = 0
            var importedEventDates: [Date] = []

            for row in matchedRows {
                guard let gameID = matchGameID(fromMachine: row.machine) else {
                    unmatched += 1
                    continue
                }

                guard let eventDate = row.eventDate else {
                    unmatched += 1
                    continue
                }

                if isDuplicateLeagueScore(gameID: gameID, score: row.rawScore, eventDate: eventDate) {
                    duplicates += 1
                    continue
                }

                let entry = ScoreLogEntry(
                    gameID: gameID,
                    score: row.rawScore,
                    context: .league,
                    tournamentName: nil,
                    timestamp: eventDate,
                    leagueImported: true
                )
                state.scoreEntries.append(entry)
                state.journalEntries.append(
                    JournalEntry(
                        gameID: gameID,
                        action: .scoreLogged,
                        score: row.rawScore,
                        scoreContext: .league,
                        note: "Imported from LPL stats CSV",
                        timestamp: eventDate
                    )
                )
                importedEventDates.append(eventDate)
                imported += 1
            }

            state.leagueSettings.lastImportAt = Date()
            let result = LeagueImportResult(
                imported: imported,
                duplicatesSkipped: duplicates,
                unmatchedRows: unmatched,
                selectedPlayer: playerName,
                sourcePath: Self.leagueStatsPath
            )
            state.journalEntries.append(
                JournalEntry(
                    gameID: games.first?.id ?? "library",
                    action: .scoreLogged,
                    scoreContext: .league,
                    note: result.summaryLine,
                    timestamp: importedEventDates.max() ?? Date()
                )
            )
            saveState()
            return result
        } catch {
            lastErrorMessage = "League CSV import failed: \(error.localizedDescription)"
            return LeagueImportResult(
                imported: 0,
                duplicatesSkipped: 0,
                unmatchedRows: 0,
                selectedPlayer: playerName,
                sourcePath: Self.leagueStatsPath
            )
        }
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

    func allJournalEntries() -> [JournalEntry] {
        state.journalEntries.sorted { $0.timestamp > $1.timestamp }
    }

    func clearJournalLog() {
        state.journalEntries.removeAll()
        saveState()
    }

    func resetPracticeState() {
        state = .empty
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        saveState()
    }

    func gameJournalEntries(for gameID: String) -> [JournalEntry] {
        state.journalEntries
            .filter { $0.gameID == gameID }
            .sorted { $0.timestamp > $1.timestamp }
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
            return entry.note ?? "Read \(name) rulesheet"
        case .tutorialWatch:
            if let value = entry.videoValue, let kind = entry.videoKind {
                let suffix = kind == .clock ? "watched" : "complete"
                return "Tutorial for \(name): \(value) \(suffix)"
            }
            if let progress = entry.progressPercent {
                return "Tutorial for \(name): \(progress)% complete"
            }
            return entry.note ?? "Updated tutorial progress for \(name)"
        case .gameplayWatch:
            if let value = entry.videoValue, let kind = entry.videoKind {
                let suffix = kind == .clock ? "watched" : "complete"
                return "Gameplay for \(name): \(value) \(suffix)"
            }
            if let progress = entry.progressPercent {
                return "Gameplay for \(name): \(progress)% complete"
            }
            return entry.note ?? "Updated gameplay progress for \(name)"
        case .playfieldViewed:
            return entry.note ?? "Viewed \(name) playfield"
        case .gameBrowse:
            return "Browsed \(name)"
        case .practiceSession:
            if let progress = entry.progressPercent {
                return "Practice progress \(progress)% on \(name)"
            }
            return entry.note ?? "Logged practice for \(name)"
        case .scoreLogged:
            if let score = entry.score, let context = entry.scoreContext {
                if context == .tournament, let tournament = entry.tournamentName, !tournament.isEmpty {
                    return "Logged \(formatScore(score)) on \(name) (\(context.label): \(tournament))"
                }
                return "Logged \(formatScore(score)) on \(name) (\(context.label))"
            }
            return entry.note ?? "Logged score for \(name)"
        case .noteAdded:
            if let category = entry.noteCategory {
                if let detail = entry.noteDetail, !detail.isEmpty {
                    return "\(category.label) note for \(name) (\(detail)): \(entry.note ?? "")"
                }
                return "\(category.label) note for \(name): \(entry.note ?? "")"
            }
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

    func recommendedFocusGames(limit: Int = 3) -> [PinballGame] {
        games.sorted { lhs, rhs in
            focusPriority(for: lhs.id) > focusPriority(for: rhs.id)
        }
        .prefix(limit)
        .map { $0 }
    }

    func dashboardAlerts(for gameID: String) -> [PracticeDashboardAlert] {
        var alerts: [PracticeDashboardAlert] = []
        let now = Date()

        if let rulesheetLast = taskLastTimestamp(gameID: gameID, task: .rulesheet) {
            let days = Calendar.current.dateComponents([.day], from: rulesheetLast, to: now).day ?? 0
            if days >= 90 {
                alerts.append(PracticeDashboardAlert(id: UUID(), message: "Rulesheet last read \(days) days ago.", severity: .warning))
            }
        } else {
            alerts.append(PracticeDashboardAlert(id: UUID(), message: "No rulesheet reading logged yet.", severity: .info))
        }

        if let practiceLast = taskLastTimestamp(gameID: gameID, task: .practice) {
            let days = Calendar.current.dateComponents([.day], from: practiceLast, to: now).day ?? 0
            if days >= 14 {
                alerts.append(PracticeDashboardAlert(id: UUID(), message: "No practice logged in the last \(days) days.", severity: .warning))
            }
        } else {
            alerts.append(PracticeDashboardAlert(id: UUID(), message: "No practice sessions logged yet.", severity: .info))
        }

        if let summary = scoreSummary(for: gameID), summary.median > 0 {
            let spreadRatio = (summary.p75 - summary.floor) / summary.median
            if spreadRatio >= 0.6 {
                alerts.append(
                    PracticeDashboardAlert(
                        id: UUID(),
                        message: "Score variance is high (wide floor-to-upper spread).",
                        severity: .caution
                    )
                )
            }
        }

        if alerts.isEmpty {
            alerts.append(PracticeDashboardAlert(id: UUID(), message: "No immediate alerts for this game.", severity: .info))
        }
        return alerts
    }

    func timelineSummary(for gameID: String, gapMode: ChartGapMode) -> PracticeTimelineSummary {
        let scores = state.scoreEntries
            .filter { $0.gameID == gameID }
            .sorted { $0.timestamp < $1.timestamp }
        let timestamps = scores.map(\.timestamp)
        let gaps = timestamps.adjacentDayGaps()
        let longGaps = gaps.filter { $0 >= 14 }
        let longestGap = gaps.max() ?? 0

        let activeSessionCount: Int = switch gapMode {
        case .realTimeline:
            max(1, timestamps.count)
        case .compressInactive:
            max(1, timestamps.count - longGaps.count)
        case .activeSessionsOnly:
            max(1, timestamps.count - longGaps.count)
        case .brokenAxis:
            max(1, timestamps.count)
        }

        let modeDescription: String = switch gapMode {
        case .realTimeline:
            "Shows raw calendar spacing between score entries."
        case .compressInactive:
            "Compresses long inactive gaps to emphasize active periods."
        case .activeSessionsOnly:
            "Focuses only on contiguous active sessions."
        case .brokenAxis:
            "Preserves chronology with visual breaks for long inactivity."
        }

        return PracticeTimelineSummary(
            scoreCount: scores.count,
            activeSessionCount: activeSessionCount,
            longGapCount: longGaps.count,
            longestGapDays: longestGap,
            modeDescription: modeDescription
        )
    }

    func studyCompletionPercent(for gameID: String) -> Int {
        let values = StudyTaskKind.allCases.map { latestTaskProgress(gameID: gameID, task: $0) }
        let total = values.reduce(0, +)
        return Int((Double(total) / Double(max(values.count, 1))).rounded())
    }

    private func scoreGapSeverity(for gameID: String) -> Double {
        guard let summary = scoreSummary(for: gameID) else { return 999_999 }
        return max(0, summary.median - summary.floor)
    }

    private func focusPriority(for gameID: String) -> Double {
        let varianceWeight: Double
        if let summary = scoreSummary(for: gameID), summary.median > 0 {
            varianceWeight = (summary.p75 - summary.floor) / summary.median
        } else {
            varianceWeight = 1.0
        }

        let practiceGapDays: Double = {
            guard let last = taskLastTimestamp(gameID: gameID, task: .practice) else { return 30 }
            return Double(Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0)
        }()

        let completionGap = Double(100 - studyCompletionPercent(for: gameID)) / 100.0
        return (varianceWeight * 0.45) + (min(practiceGapDays, 30) / 30.0 * 0.4) + (completionGap * 0.15)
    }

    private func taskLastTimestamp(gameID: String, task: StudyTaskKind) -> Date? {
        let action = actionType(for: task)
        return state.journalEntries
            .filter { $0.gameID == gameID && $0.action == action }
            .sorted { $0.timestamp > $1.timestamp }
            .first?
            .timestamp
    }

    private func latestTaskProgress(gameID: String, task: StudyTaskKind) -> Int {
        let explicit = state.studyEvents
            .filter { $0.gameID == gameID && $0.task == task }
            .sorted { $0.timestamp > $1.timestamp }
            .first?
            .progressPercent

        if let explicit {
            return explicit
        }

        if task == .playfield {
            let hasViewed = state.journalEntries.contains { $0.gameID == gameID && $0.action == .playfieldViewed }
            return hasViewed ? 100 : 0
        }
        return 0
    }

    private struct LeagueCSVRow {
        let player: String
        let machine: String
        let rawScore: Double
        let eventDate: Date?
    }

    private func parseLeagueRows(text: String) -> [LeagueCSVRow] {
        let table = parseCSVRows(text)
        guard let header = table.first else { return [] }
        let headers = header.map(normalizeCSVHeader)

        func idx(_ name: String) -> Int {
            headers.firstIndex(of: normalizeCSVHeader(name)) ?? -1
        }

        func firstIndex(_ names: [String]) -> Int {
            names.map(idx).first(where: { $0 >= 0 }) ?? -1
        }

        let playerIndex = firstIndex(["Player"])
        let machineIndex = firstIndex(["Machine", "Game"])
        let rawScoreIndex = firstIndex(["RawScore", "Score"])
        let eventDateIndex = firstIndex(["EventDate", "Event Date", "Date"])

        guard [playerIndex, machineIndex, rawScoreIndex].allSatisfy({ $0 >= 0 }) else { return [] }

        return table.dropFirst().compactMap { columns in
            let maxRequired = max(playerIndex, machineIndex, rawScoreIndex)
            guard columns.indices.contains(maxRequired) else { return nil }
            let player = columns[playerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let machine = columns[machineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawScore = Double(columns[rawScoreIndex].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            guard !player.isEmpty, !machine.isEmpty, rawScore > 0 else { return nil }
            let eventDate: Date? = {
                guard eventDateIndex >= 0, columns.indices.contains(eventDateIndex) else { return nil }
                let value = columns[eventDateIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return nil }
                return Self.eventDateFormatter.date(from: value)
            }()

            return LeagueCSVRow(player: player, machine: machine, rawScore: rawScore, eventDate: eventDate)
        }
    }

    private func matchGameID(fromMachine machine: String) -> String? {
        let normalizedMachine = normalizeMachineName(machine)
        if let exact = games.first(where: { normalizeMachineName($0.name) == normalizedMachine }) {
            return exact.id
        }

        if let fuzzy = games.first(where: {
            let candidate = normalizeMachineName($0.name)
            return candidate.contains(normalizedMachine) || normalizedMachine.contains(candidate)
        }) {
            return fuzzy.id
        }
        return nil
    }

    private func isDuplicateLeagueScore(gameID: String, score: Double, eventDate: Date) -> Bool {
        state.scoreEntries.contains { existing in
            guard existing.gameID == gameID, existing.context == .league else { return false }
            guard abs(existing.score - score) < 0.5 else { return false }
            return Calendar.current.isDate(existing.timestamp, inSameDayAs: eventDate)
        }
    }

    private func normalizeHumanName(_ raw: String) -> String {
        raw
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func normalizeMachineName(_ raw: String) -> String {
        raw.lowercased()
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private func parseComfortValue(from note: String) -> Int? {
        let pattern = #"comfort\s+([1-5])(?:\s*/\s*5)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(location: 0, length: note.utf16.count)
        guard let match = regex.firstMatch(in: note, options: [], range: range),
              match.numberOfRanges >= 2,
              let comfortRange = Range(match.range(at: 1), in: note) else {
            return nil
        }
        return Int(note[comfortRange])
    }

    private func mechanicsAliases(for skill: String) -> [String] {
        switch skill {
        case "Dead Bounce": return ["dead bounce", "deadbounce", "dead flip", "deadflip"]
        case "Post Pass": return ["post pass", "postpass"]
        case "Post Catch": return ["post catch", "postcatch"]
        case "Flick Pass": return ["flick pass", "flickpass"]
        case "Nudge Pass": return ["nudge pass", "nudgepass", "nudge control", "nudgecontrol"]
        case "Drop Catch": return ["drop catch", "dropcatch"]
        case "Live Catch": return ["live catch", "livecatch"]
        case "Shatz": return ["shatz", "shatzing", "alley pass", "alleypass"]
        case "Back Flip": return ["back flip", "backflip", "bang back", "bangback"]
        case "Loop Pass": return ["loop pass", "looppass"]
        case "Slap Save (Single)": return ["slap save", "slap save single", "single slap save"]
        case "Slap Save (Double)": return ["slap save double", "double slap save"]
        case "Air Defense": return ["air defense", "airdefense"]
        case "Cradle Separation": return ["cradle separation", "cradleseparation"]
        case "Over Under": return ["over under", "overunder"]
        case "Tap Pass": return ["tap pass", "tappass"]
        default: return [skill.lowercased()]
        }
    }

    private static let eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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

private extension Array where Element == Date {
    func adjacentDayGaps() -> [Int] {
        guard count > 1 else { return [] }
        let ordered = self.sorted()
        return zip(ordered, ordered.dropFirst()).map { start, end in
            Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        }
    }
}
