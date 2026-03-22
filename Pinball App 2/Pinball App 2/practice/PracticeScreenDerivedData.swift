import SwiftUI

extension PracticeScreen {
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
        let uiName = uiState.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = uiName.isEmpty
            ? store.state.practiceSettings.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
            : uiName
        guard !trimmed.isEmpty else { return nil }
        let redacted = redactPlayerNameForDisplay(trimmed)
        if redacted != trimmed {
            return redacted
        }
        let first = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        return first.isEmpty ? nil : first
    }

    var journalSections: [PracticeJournalDaySection] {
        store.journalSections(filter: journalFilter)
    }

    var journalFilter: JournalFilter {
        JournalFilter(rawValue: journalFilterRaw) ?? .all
    }
}
