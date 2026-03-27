import SwiftUI

struct PracticeInsightsContext {
    let games: [PinballGame]
    let librarySources: [PinballLibrarySource]
    let selectedLibrarySourceID: String?
    let onSelectLibrarySourceID: (String?) -> Void
    let selectedGameID: Binding<String>
    let scoreSummaryForGame: (String) -> ScoreSummary?
    let scoreTrendValuesForGame: (String) -> [Double]
    let playerName: String
    let opponentName: Binding<String>
    let opponentOptions: [String]
    let isLoadingHeadToHead: Bool
    let headToHead: HeadToHeadComparison?
    let onRefreshHeadToHead: () async -> Void
    let onRefreshOpponentOptions: () async -> Void
}
