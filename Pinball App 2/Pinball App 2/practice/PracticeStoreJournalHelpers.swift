import Foundation

struct CachedPracticeJournalPayload {
    let libraryActivityRevision: UInt
    let sections: [PracticeJournalDaySection]
}

extension PracticeStore {
    func mostRecentTimelineGameID() -> String? {
        let raw = mostRecentPracticeTimelineGameID(
            journalEntries: state.journalEntries,
            libraryEvents: LibraryActivityLog.events()
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }

        let canonical = canonicalPracticeGameID(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return canonical.isEmpty ? raw : canonical
    }

    func journalSections(filter: JournalFilter) -> [PracticeJournalDaySection] {
        cachedJournalPayload(for: filter).sections
    }

    func scoreSummary(for gameID: String) -> ScoreSummary? {
        let gameID = canonicalPracticeGameID(gameID)
        if let cached = cachedScoreSummariesByGameID[gameID] {
            return cached
        }

        let values = cachedScoreEntries(for: gameID).map(\.score)

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

        let summary = ScoreSummary(
            average: average,
            median: median,
            floor: sorted.first ?? average,
            p25: values.pinballPercentile(0.25) ?? average,
            p75: values.pinballPercentile(0.75) ?? average
        )
        cachedScoreSummariesByGameID[gameID] = summary
        return summary
    }

    func gameJournalEntries(for gameID: String) -> [JournalEntry] {
        let gameID = canonicalPracticeGameID(gameID)
        if let cached = cachedGameJournalEntriesByGameID[gameID] {
            return cached
        }
        let entries = state.journalEntries
            .filter { $0.gameID == gameID }
            .sorted { $0.timestamp > $1.timestamp }
        cachedGameJournalEntriesByGameID[gameID] = entries
        return entries
    }

    func gameTaskSummary(for gameID: String) -> [GameTaskSummaryRow] {
        let gameID = canonicalPracticeGameID(gameID)
        if let cached = cachedGameTaskSummaryRowsByGameID[gameID] {
            return cached
        }

        let journalEntries = gameJournalEntries(for: gameID)
        let summaryRows = StudyTaskKind.allCases.map { task in
            let action = actionType(for: task)
            let taskLogs = journalEntries.filter { $0.action == action }
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
        cachedGameTaskSummaryRowsByGameID[gameID] = summaryRows
        return summaryRows
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
        return Array(cachedScoreEntries(for: gameID).prefix(limit))
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

    private func cachedJournalPayload(for filter: JournalFilter) -> CachedPracticeJournalPayload {
        let libraryActivityRevision = LibraryActivityLog.cacheRevision
        if let cached = cachedJournalPayloads[filter],
           cached.libraryActivityRevision == libraryActivityRevision {
            return cached
        }

        let journalEntries = state.journalEntries.sorted { $0.timestamp > $1.timestamp }
        let filteredJournalEntries = filterJournalEntries(journalEntries, filter: filter)
        let filteredLibraryEvents = filterLibraryActivities(LibraryActivityLog.events(), filter: filter)

        let appItems = filteredJournalEntries.map { entry in
            PracticeJournalItem(
                id: "app-\(entry.id.uuidString)",
                gameID: entry.gameID,
                summary: journalSummary(for: entry),
                icon: practiceJournalActionIcon(entry.action),
                timestamp: entry.timestamp,
                journalEntry: entry
            )
        }
        let libraryItems = filteredLibraryEvents.map { event in
            PracticeJournalItem(
                id: "library-\(event.id.uuidString)",
                gameID: event.gameID,
                summary: practiceLibraryActivitySummary(event),
                icon: practiceLibraryActivityIcon(event.kind),
                timestamp: event.timestamp,
                journalEntry: nil
            )
        }
        let items = (appItems + libraryItems).sorted(by: { $0.timestamp > $1.timestamp })
        let sections = groupedPracticeJournalSections(items)
        let payload = CachedPracticeJournalPayload(
            libraryActivityRevision: libraryActivityRevision,
            sections: sections
        )
        cachedJournalPayloads[filter] = payload
        return payload
    }

    private func cachedScoreEntries(for gameID: String) -> [ScoreLogEntry] {
        if let cached = cachedScoreEntriesByGameID[gameID] {
            return cached
        }

        let entries = state.scoreEntries
            .filter { $0.gameID == gameID }
            .sorted { $0.timestamp > $1.timestamp }
        cachedScoreEntriesByGameID[gameID] = entries
        return entries
    }
}

private func filterJournalEntries(_ entries: [JournalEntry], filter: JournalFilter) -> [JournalEntry] {
    switch filter {
    case .all:
        return entries
    case .study:
        return entries.filter { [.rulesheetRead, .tutorialWatch, .gameplayWatch, .playfieldViewed].contains($0.action) }
    case .practice:
        return entries.filter { $0.action == .practiceSession }
    case .score:
        return entries.filter { $0.action == .scoreLogged }
    case .notes:
        return entries.filter { $0.action == .noteAdded }
    case .league:
        return entries.filter { entry in
            entry.action == .scoreLogged && (entry.scoreContext == .league || (entry.note ?? "").localizedCaseInsensitiveContains("league import"))
        }
    }
}

private func filterLibraryActivities(_ events: [LibraryActivityEvent], filter: JournalFilter) -> [LibraryActivityEvent] {
    switch filter {
    case .all:
        return events
    case .study:
        return events.filter { [.openRulesheet, .openPlayfield, .tapVideo].contains($0.kind) }
    case .practice, .score, .notes, .league:
        return []
    }
}

func mostRecentPracticeTimelineGameID(
    journalEntries: [JournalEntry],
    libraryEvents: [LibraryActivityEvent]
) -> String? {
    let latestJournalEntry = journalEntries.max { $0.timestamp < $1.timestamp }
    let latestLibraryEvent = libraryEvents.max { $0.timestamp < $1.timestamp }

    switch (latestJournalEntry, latestLibraryEvent) {
    case let (journalEntry?, libraryEvent?):
        return journalEntry.timestamp >= libraryEvent.timestamp ? journalEntry.gameID : libraryEvent.gameID
    case let (journalEntry?, nil):
        return journalEntry.gameID
    case let (nil, libraryEvent?):
        return libraryEvent.gameID
    case (nil, nil):
        return nil
    }
}

private func practiceJournalActionIcon(_ action: JournalActionType) -> String {
    switch action {
    case .rulesheetRead: return "book"
    case .tutorialWatch: return "play.rectangle"
    case .gameplayWatch: return "video"
    case .playfieldViewed: return "photo"
    case .gameBrowse: return "gamecontroller"
    case .practiceSession: return "figure.run"
    case .scoreLogged: return "number.circle"
    case .noteAdded: return "note.text"
    }
}

private func practiceLibraryActivityIcon(_ kind: LibraryActivityKind) -> String {
    switch kind {
    case .browseGame:
        return "rectangle.grid.2x2"
    case .openRulesheet:
        return "book"
    case .openPlayfield:
        return "photo"
    case .tapVideo:
        return "play.rectangle"
    }
}

private func practiceLibraryActivitySummary(_ event: LibraryActivityEvent) -> String {
    switch event.kind {
    case .browseGame:
        return "Browsed \(event.gameName) in Library"
    case .openRulesheet:
        return "Opened \(event.gameName) rulesheet from Library"
    case .openPlayfield:
        return "Opened \(event.gameName) playfield image from Library"
    case .tapVideo:
        if let detail = event.detail, !detail.isEmpty {
            return "Opened \(detail) video for \(event.gameName) in Library"
        }
        return "Opened video for \(event.gameName) in Library"
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
