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
            let value = entry.progressPercent.map { "Progress: \($0)%" } ?? "Read rulesheet"
            return structuredStudySummary(title: "Rulesheet", value: value, note: entry.note, gameName: name)
        case .tutorialWatch:
            let valueLine: String
            if let value = entry.videoValue {
                valueLine = "Progress: \(value)"
            } else if let progress = entry.progressPercent {
                valueLine = "Progress: \(progress)%"
            } else {
                valueLine = "Updated progress"
            }
            return structuredStudySummary(title: "Tutorial Video", value: valueLine, note: entry.note, gameName: name)
        case .gameplayWatch:
            let valueLine: String
            if let value = entry.videoValue {
                valueLine = "Progress: \(value)"
            } else if let progress = entry.progressPercent {
                valueLine = "Progress: \(progress)%"
            } else {
                valueLine = "Updated progress"
            }
            return structuredStudySummary(title: "Gameplay Video", value: valueLine, note: entry.note, gameName: name)
        case .playfieldViewed:
            return structuredStudySummary(title: "Playfield", value: "Viewed playfield", note: entry.note, gameName: name)
        case .gameBrowse:
            return "Browsed \(name)"
        case .practiceSession:
            if let progress = entry.progressPercent {
                return "Practice progress \(progress)% on \(name)"
            }
            let practiceParts = parsedPracticeSessionParts(from: entry.note)
            var lines = ["Practice:", practiceParts.value]
            if let note = practiceParts.note, !note.isEmpty {
                lines.append(note)
            }
            lines.append("• \(name)")
            return lines.joined(separator: "\n")
        case .scoreLogged:
            if let score = entry.score, let context = entry.scoreContext {
                if context == .tournament, let tournament = entry.tournamentName, !tournament.isEmpty {
                    return "Score: \(formatScore(score)) • \(name) (\(context.label): \(tournament))"
                }
                return "Score: \(formatScore(score)) • \(name) (\(context.label))"
            }
            return entry.note ?? "Logged score for \(name)"
        case .noteAdded:
            if let category = entry.noteCategory {
                if category == .general,
                   let detail = entry.noteDetail,
                   detail.caseInsensitiveCompare("Game Note") == .orderedSame {
                    let noteText = (entry.note ?? "").isEmpty ? "Added game note" : (entry.note ?? "")
                    return "Game Note:\n\(noteText)\n• \(name)"
                }
                let categoryLabel = category.label
                let detailSuffix: String
                if let detail = entry.noteDetail, !detail.isEmpty {
                    detailSuffix = " (\(detail))"
                } else {
                    detailSuffix = ""
                }
                let noteText = (entry.note ?? "").isEmpty ? "Added \(categoryLabel.lowercased()) note" : (entry.note ?? "")
                return "\(categoryLabel) note\(detailSuffix): \(noteText)\n• \(name)"
            }
            if let note = entry.note, !note.isEmpty {
                return "Note: \(note)\n• \(name)"
            }
            return "Added note\n• \(name)"
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

private func structuredStudySummary(title: String, value: String, note: String?, gameName: String) -> String {
    var lines = [title + ":", value]
    if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        lines.append(note)
    }
    lines.append("• \(gameName)")
    return lines.joined(separator: "\n")
}

private func parsedPracticeSessionParts(from raw: String?) -> (value: String, note: String?) {
    let normalized = raw?
        .replacingOccurrences(of: "\r\n", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard !normalized.isEmpty else {
        return ("Practice session", nil)
    }

    if normalized.hasPrefix("Practice session") {
        if let newline = normalized.firstIndex(of: "\n") {
            let value = String(normalized[..<newline]).trimmingCharacters(in: .whitespacesAndNewlines)
            let note = String(normalized[normalized.index(after: newline)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (value.isEmpty ? "Practice session" : value, note.isEmpty ? nil : note)
        }
        if let dotRange = normalized.range(of: ". ") {
            let value = String(normalized[..<dotRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let note = String(normalized[dotRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                return (value, note.isEmpty ? nil : note)
            }
        }
        return (normalized, nil)
    }

    return ("Practice session", normalized)
}
