package com.pillyliu.pinprofandroid.practice

internal class PracticeLeagueIntegration(
    private val gameNameForSlug: (String) -> String,
) {
    private var targetsByPracticeIdentity: Map<String, LeagueTargetScores> = emptyMap()
    private var targetsByNormalizedMachine: Map<String, LeagueTargetScores> = emptyMap()

    suspend fun loadTargets() {
        val resolved = loadResolvedLeagueTargets("/pinball/data/lpl_targets_resolved_v1.json")
        if (resolved.isNotEmpty()) {
            targetsByPracticeIdentity = resolvedLeagueTargetScoresByPracticeIdentity(resolved)
            targetsByNormalizedMachine = emptyMap()
            return
        }
        targetsByPracticeIdentity = emptyMap()
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
        targetsByPracticeIdentity[gameSlug]?.let { return it }
        return leagueTargetScoresForSlug(gameSlug, games) { gameName ->
            resolveLeagueTargetScores(gameName, targetsByNormalizedMachine)
        }
    }
}
