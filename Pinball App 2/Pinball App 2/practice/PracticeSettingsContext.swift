import SwiftUI

struct PracticeSettingsContext {
    let store: PracticeStore
    let playerName: Binding<String>
    let ifpaPlayerID: Binding<String>
    let leaguePlayerName: Binding<String>
    let leaguePlayerOptions: [String]
    let leagueImportStatus: String
    let cloudSyncEnabled: Binding<Bool>
    let redactName: (String) -> String
    let onImportLeagueCSV: () -> Void
    let onResetPracticeLog: () -> Void
}
