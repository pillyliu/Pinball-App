import SwiftUI

struct PracticeSettingsContext {
    let playerName: Binding<String>
    let ifpaPlayerID: Binding<String>
    let prpaPlayerID: Binding<String>
    let leaguePlayerName: Binding<String>
    let leaguePlayerOptions: [String]
    let leagueImportStatus: String
    let importedLeagueScoreCount: Int
    let onSaveProfile: () -> Void
    let onSaveIFPAID: () -> Void
    let onSavePRPAID: () -> Void
    let onLeaguePlayerSelected: (String) -> Void
    let onImportLeagueCSV: () -> Void
    let onClearImportedLeagueScores: () -> Void
    let onResetPracticeLog: () -> Void
}
