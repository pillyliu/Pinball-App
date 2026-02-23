import Foundation

extension PracticeStore {
    func scoreSummary(for gameID: String) -> ScoreSummary? {
        let gameID = canonicalPracticeGameID(gameID)
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

    func gameJournalEntries(for gameID: String) -> [JournalEntry] {
        let gameID = canonicalPracticeGameID(gameID)
        return state.journalEntries
            .filter { $0.gameID == gameID }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func gameTaskSummary(for gameID: String) -> [GameTaskSummaryRow] {
        let gameID = canonicalPracticeGameID(gameID)
        return StudyTaskKind.allCases.map { task in
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
            if let value = entry.videoValue {
                return "Tutorial for \(name): \(value)"
            }
            if let progress = entry.progressPercent {
                return "Tutorial for \(name): \(progress)% complete"
            }
            return entry.note ?? "Updated tutorial progress for \(name)"
        case .gameplayWatch:
            if let value = entry.videoValue {
                return "Gameplay for \(name): \(value)"
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
        let gameID = canonicalPracticeGameID(gameID)
        return Array(
            state.scoreEntries
                .filter { $0.gameID == gameID }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(limit)
        )
    }

    func recentNotes(for gameID: String, limit: Int = 15) -> [PracticeNoteEntry] {
        let gameID = canonicalPracticeGameID(gameID)
        return Array(
            state.noteEntries
                .filter { $0.gameID == gameID }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(limit)
        )
    }

    func formatScore(_ score: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: score)) ?? String(Int(score))
    }
}
