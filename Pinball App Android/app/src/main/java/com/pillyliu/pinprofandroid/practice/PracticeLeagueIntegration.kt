package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.PinballPerformanceTrace
import com.pillyliu.pinprofandroid.library.hostedLeagueStatsPath
import com.pillyliu.pinprofandroid.library.hostedLeagueTargetsPath
import com.pillyliu.pinprofandroid.library.hostedResolvedLeagueTargetsPath

internal class PracticeLeagueIntegration(
    private val gameNameForSlug: (String) -> String,
) {
    private var targetsByPracticeIdentity: Map<String, LeagueTargetScores> = emptyMap()
    private var targetsByNormalizedMachine: Map<String, LeagueTargetScores> = emptyMap()
    private var didLoadTargets = false
    private var isLoadingTargets = false
    private var cachedLeagueStatsUpdatedAtMs: Long? = null
    private var cachedLeagueStatsRows: List<LeagueCsvRow> = emptyList()
    private var cachedLeaguePlayers: List<String> = emptyList()

    private data class LeagueStatsSnapshot(
        val rows: List<LeagueCsvRow>,
        val players: List<String>,
    )

    suspend fun ensureTargetsLoaded() {
        if (didLoadTargets || isLoadingTargets) return
        isLoadingTargets = true
        try {
            PinballPerformanceTrace.measureSuspend("PracticeLeagueTargetsLoad") {
                loadTargets()
            }
            didLoadTargets = true
        } finally {
            isLoadingTargets = false
        }
    }

    private suspend fun loadTargets() {
        val resolved = loadResolvedLeagueTargets(hostedResolvedLeagueTargetsPath)
        if (resolved.isNotEmpty()) {
            targetsByPracticeIdentity = resolvedLeagueTargetScoresByPracticeIdentity(resolved)
            targetsByNormalizedMachine = emptyMap()
            return
        }
        targetsByPracticeIdentity = emptyMap()
        targetsByNormalizedMachine = loadLeagueTargetsMap(hostedLeagueTargetsPath)
    }

    suspend fun availablePlayers(): List<String> = loadLeagueStatsSnapshot().players

    suspend fun importScores(
        selectedPlayer: String,
        games: List<com.pillyliu.pinprofandroid.library.PinballGame>,
        onAddScore: (slug: String, score: Double, timestampMs: Long) -> Unit,
    ): String {
        return importLeagueScoresFromRows(
            selectedPlayer = selectedPlayer,
            rows = loadLeagueStatsSnapshot().rows,
            games = games,
            onAddScore = onAddScore,
        )
    }

    suspend fun comparePlayers(
        yourName: String,
        opponentName: String,
        games: List<com.pillyliu.pinprofandroid.library.PinballGame>,
    ): HeadToHeadComparison? {
        return comparePlayersFromRows(
            yourName = yourName,
            opponentName = opponentName,
            rows = loadLeagueStatsSnapshot().rows,
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

    private suspend fun loadLeagueStatsSnapshot(): LeagueStatsSnapshot {
        val result = com.pillyliu.pinprofandroid.data.PinballDataCache.loadText(hostedLeagueStatsPath, allowMissing = false)
        val text = result.text ?: run {
            cachedLeagueStatsUpdatedAtMs = result.updatedAtMs
            cachedLeagueStatsRows = emptyList()
            cachedLeaguePlayers = emptyList()
            return LeagueStatsSnapshot(rows = emptyList(), players = emptyList())
        }

        if (cachedLeagueStatsRows.isEmpty() || cachedLeagueStatsUpdatedAtMs != result.updatedAtMs) {
            val snapshot = PinballPerformanceTrace.measure("PracticeLeagueStatsLoad") {
                val rows = parseLeagueRows(text)
                LeagueStatsSnapshot(
                    rows = rows,
                    players = availableLeaguePlayersFromRows(rows),
                )
            }
            cachedLeagueStatsRows = snapshot.rows
            cachedLeaguePlayers = snapshot.players
            cachedLeagueStatsUpdatedAtMs = result.updatedAtMs
        }

        return LeagueStatsSnapshot(
            rows = cachedLeagueStatsRows,
            players = cachedLeaguePlayers,
        )
    }
}
