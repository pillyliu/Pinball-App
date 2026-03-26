import SwiftUI

struct PracticeSettingsContext {
    let store: PracticeStore
    let playerName: Binding<String>
    let ifpaPlayerID: Binding<String>
    let leaguePlayerName: Binding<String>
    let leaguePlayerOptions: [String]
    let leagueImportStatus: String
    let importedLeagueScoreCount: Int
    let cloudSyncEnabled: Binding<Bool>
    let redactName: (String) -> String
    let onLeaguePlayerSelected: (String) -> Void
    let onImportLeagueCSV: () -> Void
    let onClearImportedLeagueScores: () -> Void
    let onResetPracticeLog: () -> Void
}
