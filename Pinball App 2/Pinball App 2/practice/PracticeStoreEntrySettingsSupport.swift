import Foundation

extension PracticeStore {
    func updatePracticeSettings(playerName: String? = nil, comparisonPlayerName: String? = nil, ifpaPlayerID: String? = nil) {
        if let playerName {
            state.practiceSettings.playerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let comparisonPlayerName {
            state.practiceSettings.comparisonPlayerName = comparisonPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let ifpaPlayerID {
            state.practiceSettings.ifpaPlayerID = ifpaPlayerID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        saveState()
        saveHomeBootstrapSnapshotIfNeeded()
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
        state.leagueSettings.lastRepairVersion = nil
        saveState()
        return before - state.scoreEntries.count
    }

    func clearImportedLeagueScoresAndBuildStatus() -> String {
        clearedImportedLeagueScoresStatusMessage(purgeImportedLeagueScores())
    }

    func updateAnalyticsSettings(gapMode: ChartGapMode, useMedian: Bool) {
        state.analyticsSettings.gapMode = gapMode
        state.analyticsSettings.useMedian = useMedian
        saveState()
    }

    func resetPracticeState() {
        state = .empty
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        saveState()
        saveHomeBootstrapSnapshotIfNeeded()
    }
}
