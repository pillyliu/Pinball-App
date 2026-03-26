import SwiftUI
import Combine

extension Notification.Name {
    static let pinballLeaguePreviewNeedsRefresh = Notification.Name("pinballLeaguePreviewNeedsRefresh")
}

func notifyLeaguePreviewNeedsRefresh() {
    NotificationCenter.default.post(name: .pinballLeaguePreviewNeedsRefresh, object: nil)
}

@MainActor
final class LeaguePreviewModel: ObservableObject {
    @Published private(set) var nextBankTargets: [LeagueTargetPreviewRow] = []
    @Published private(set) var nextBankLabel: String = "Next Bank"

    @Published private(set) var standingsSeasonLabel: String = "Season"
    @Published private(set) var standingsTopRows: [LeagueStandingsPreviewRow] = []
    @Published private(set) var standingsAroundRows: [LeagueStandingsPreviewRow] = []
    @Published private(set) var currentPlayerStanding: LeagueStandingsPreviewRow?
    @Published private(set) var statsRecentRows: [LeagueStatsPreviewRow] = []
    @Published private(set) var statsRecentBankLabel: String = "Most Recent Bank"
    @Published private(set) var statsPlayerRawName: String = ""

    var hasAroundYouStandings: Bool { !standingsAroundRows.isEmpty }

    private var didLoad = false

    func loadIfNeeded() async {
        guard !didLoad else { return }
        await reload()
    }

    func reload() async {
        didLoad = true
        apply(snapshot: await loadLeaguePreviewSnapshot())
    }

    private func apply(snapshot: LeaguePreviewSnapshot) {
        nextBankTargets = snapshot.nextBankTargets
        nextBankLabel = snapshot.nextBankLabel
        standingsSeasonLabel = snapshot.standingsSeasonLabel
        standingsTopRows = snapshot.standingsTopRows
        standingsAroundRows = snapshot.standingsAroundRows
        currentPlayerStanding = snapshot.currentPlayerStanding
        statsRecentRows = snapshot.statsRecentRows
        statsRecentBankLabel = snapshot.statsRecentBankLabel
        statsPlayerRawName = snapshot.statsPlayerRawName
    }
}
