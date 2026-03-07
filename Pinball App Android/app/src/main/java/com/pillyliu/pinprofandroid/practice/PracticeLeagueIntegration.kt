package com.pillyliu.pinprofandroid.practice

internal class PracticeLeagueIntegration(
    private val gameNameForSlug: (String) -> String,
) {
    private var targetsByNormalizedMachine: Map<String, LeagueTargetScores> = emptyMap()

    suspend fun loadTargets() {
        targetsByNormalizedMachine = loadLeagueTargetsMap("/pinball/data/LPL_Targets.csv")
    }

    suspend fun availablePlayers(): List<String> = availableLeaguePlayersFromCsv()

    suspend fun importScores(
        selectedPlayer: String,
        games: List<com.pillyliu.pinprofandroid.library.PinballGame>,
        onAddScore: (slug: String, score: Double, timestampMs: Long) -> Unit,
    ): String {
        return importLeagueScoresFromCsvData(
            selectedPlayer = selectedPlayer,
            games = games,
            onAddScore = onAddScore,
        )
    }

    suspend fun comparePlayers(
        yourName: String,
        opponentName: String,
        games: List<com.pillyliu.pinprofandroid.library.PinballGame>,
    ): HeadToHeadComparison? {
        return comparePlayersFromCsv(
            yourName = yourName,
            opponentName = opponentName,
            games = games,
            gameNameForSlug = gameNameForSlug,
        )
    }

    fun targetScoresFor(
        gameSlug: String,
        games: List<com.pillyliu.pinprofandroid.library.PinballGame>,
    ): LeagueTargetScores? {
        return leagueTargetScoresForSlug(gameSlug, games) { gameName ->
            resolveLeagueTargetScores(gameName, targetsByNormalizedMachine)
        }
    }
}
