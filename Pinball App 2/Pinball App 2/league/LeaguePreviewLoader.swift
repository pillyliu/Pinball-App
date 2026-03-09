import Foundation

struct LeaguePreviewSnapshot {
    var nextBankTargets: [LeagueTargetPreviewRow] = []
    var nextBankLabel: String = "Next Bank"
    var standingsSeasonLabel: String = "Season"
    var standingsTopRows: [LeagueStandingsPreviewRow] = []
    var standingsAroundRows: [LeagueStandingsPreviewRow] = []
    var currentPlayerStanding: LeagueStandingsPreviewRow?
    var statsRecentRows: [LeagueStatsPreviewRow] = []
    var statsRecentBankLabel: String = "Most Recent Bank"
    var statsPlayerRawName: String = ""
}

func loadLeaguePreviewSnapshot() async -> LeaguePreviewSnapshot {
    do {
        async let targetsResult = PinballDataCache.shared.loadText(path: LeaguePreviewPaths.targetsPath)
        async let standingsResult = PinballDataCache.shared.loadText(path: LeaguePreviewPaths.standingsPath, allowMissing: true)
        async let statsResult = PinballDataCache.shared.loadText(path: LeaguePreviewPaths.statsPath, allowMissing: true)
        async let libraryExtraction = loadLibraryExtraction()

        let (targetsTextResult, standingsTextResult, statsTextResult, extraction) = try await (
            targetsResult,
            standingsResult,
            statsResult,
            libraryExtraction
        )

        let selectedPlayer = PracticeStore.loadPreferredLeaguePlayerNameFromDefaults()
        let libraryEntries = LibraryGameLookup.buildEntries(games: extraction.payload.games)

        let mergedTargets = targetsTextResult.text.map {
            mergeLeagueTargetsWithLibrary(
                targetRows: parseLeagueTargetRows($0),
                libraryEntries: libraryEntries
            )
        } ?? []
        let availableBanks = Set(mergedTargets.compactMap(\.bank))
        let nextBank = resolveLeagueNextBank(
            statsCSV: statsTextResult.text,
            availableBanks: availableBanks,
            preferredPlayer: selectedPlayer
        )
        let nextBankTargets: [LeagueTargetPreviewRow]
        let nextBankLabel: String
        if let nextBank {
            nextBankTargets = Array(
                mergedTargets
                    .filter { $0.bank == nextBank }
                    .sorted { lhs, rhs in
                        if lhs.order == rhs.order {
                            return lhs.game.localizedCaseInsensitiveCompare(rhs.game) == .orderedAscending
                        }
                        return lhs.order < rhs.order
                    }
                    .prefix(5)
            )
            nextBankLabel = "Next Bank • B\(nextBank)"
        } else {
            nextBankTargets = []
            nextBankLabel = "Next Bank"
        }

        let standingsPreview = standingsTextResult.text.map {
            buildLeagueStandingsPreview(standingsCSV: $0, selectedPlayer: selectedPlayer)
        } ?? LeagueStandingsPreviewPayload()
        let statsPreview = statsTextResult.text.map {
            buildLeagueStatsPreview(statsCSV: $0, preferredPlayer: selectedPlayer)
        } ?? LeagueStatsPreviewPayload()

        return LeaguePreviewSnapshot(
            nextBankTargets: nextBankTargets,
            nextBankLabel: nextBankLabel,
            standingsSeasonLabel: standingsPreview.seasonLabel,
            standingsTopRows: standingsPreview.topRows,
            standingsAroundRows: standingsPreview.aroundRows,
            currentPlayerStanding: standingsPreview.currentPlayerStanding,
            statsRecentRows: statsPreview.rows,
            statsRecentBankLabel: statsPreview.bankLabel,
            statsPlayerRawName: statsPreview.playerRawName
        )
    } catch {
        return LeaguePreviewSnapshot()
    }
}

private enum LeaguePreviewPaths {
    static let targetsPath = "/pinball/data/LPL_Targets.csv"
    static let standingsPath = "/pinball/data/LPL_Standings.csv"
    static let statsPath = "/pinball/data/LPL_Stats.csv"
}
