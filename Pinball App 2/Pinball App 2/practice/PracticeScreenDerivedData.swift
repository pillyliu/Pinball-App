import SwiftUI

extension PracticeScreen {
    struct TimelineItem: Identifiable {
        let id: String
        let gameID: String
        let summary: String
        let icon: String
        let timestamp: Date
        let journalEntry: JournalEntry?
    }

    var resumeGame: PinballGame? {
        let libraryID = appNavigation.lastViewedLibraryGameID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let practiceID = practiceLastViewedGameID.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateID: String
        if libraryLastViewedGameTS >= practiceLastViewedGameTS {
            candidateID = libraryID.isEmpty ? practiceID : libraryID
        } else {
            candidateID = practiceID.isEmpty ? libraryID : practiceID
        }
        if !candidateID.isEmpty,
           let match = store.gameForAnyID(candidateID) {
            return match
        }
        return defaultPracticeGame
    }

    var defaultPracticeGame: PinballGame? {
        orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true).first
    }

    var selectedGroup: CustomGameGroup? {
        store.selectedGroup()
    }

    var greetingName: String? {
        let trimmed = uiState.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let redacted = redactPlayerNameForDisplay(trimmed)
        if redacted != trimmed {
            return redacted
        }
        let first = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        return first.isEmpty ? nil : first
    }

    var filteredJournalEntries: [JournalEntry] {
        let all = store.allJournalEntries()
        switch journalFilter {
        case .all:
            return all
        case .study:
            return all.filter { [.rulesheetRead, .tutorialWatch, .gameplayWatch, .playfieldViewed].contains($0.action) }
        case .practice:
            return all.filter { $0.action == .practiceSession }
        case .score:
            return all.filter { $0.action == .scoreLogged }
        case .notes:
            return all.filter { $0.action == .noteAdded }
        case .league:
            return all.filter { entry in
                entry.action == .scoreLogged && (entry.scoreContext == .league || (entry.note ?? "").localizedCaseInsensitiveContains("league import"))
            }
        }
    }

    var filteredLibraryActivities: [LibraryActivityEvent] {
        let all = LibraryActivityLog.events()
        switch journalFilter {
        case .all:
            return all
        case .study:
            return all.filter { [.openRulesheet, .openPlayfield, .tapVideo].contains($0.kind) }
        case .practice, .score, .notes, .league:
            return []
        }
    }

    var timelineItems: [TimelineItem] {
        let appItems = filteredJournalEntries.map { entry in
            TimelineItem(
                id: "app-\(entry.id.uuidString)",
                gameID: entry.gameID,
                summary: store.journalSummary(for: entry),
                icon: actionIcon(entry.action),
                timestamp: entry.timestamp,
                journalEntry: entry
            )
        }
        let libraryItems = filteredLibraryActivities.map { event in
            TimelineItem(
                id: "library-\(event.id.uuidString)",
                gameID: event.gameID,
                summary: libraryActivitySummary(event),
                icon: libraryActivityIcon(event.kind),
                timestamp: event.timestamp,
                journalEntry: nil
            )
        }
        return (appItems + libraryItems).sorted { $0.timestamp > $1.timestamp }
    }

    var journalSectionItems: [PracticeJournalItem] {
        timelineItems.map { item in
            PracticeJournalItem(
                id: item.id,
                gameID: item.gameID,
                summary: item.summary,
                icon: item.icon,
                timestamp: item.timestamp,
                journalEntry: item.journalEntry
            )
        }
    }

    var journalFilter: JournalFilter {
        JournalFilter(rawValue: journalFilterRaw) ?? .all
    }
}
