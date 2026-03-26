package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.PinballPerformanceTrace
import com.pillyliu.pinprofandroid.library.hostedLeagueIfpaPlayersPath
import com.pillyliu.pinprofandroid.library.hostedLeagueMachineMappingsPath
import com.pillyliu.pinprofandroid.library.hostedLeagueStatsPath
import com.pillyliu.pinprofandroid.library.hostedLeagueTargetsPath
import com.pillyliu.pinprofandroid.library.hostedResolvedLeagueTargetsPath

internal class PracticeLeagueIntegration(
    private val gameNameForSlug: (String) -> String,
) {
    companion object {
        const val LEAGUE_SCORE_REPAIR_VERSION = 2
    }

    private var targetsByPracticeIdentity: Map<String, LeagueTargetScores> = emptyMap()
    private var targetsByNormalizedMachine: Map<String, LeagueTargetScores> = emptyMap()
    private var didLoadTargets = false
    private var isLoadingTargets = false
    private var cachedLeagueStatsUpdatedAtMs: Long? = null
    private var cachedLeagueStatsRows: List<LeagueCsvRow> = emptyList()
    private var cachedLeaguePlayers: List<String> = emptyList()
    private var cachedLeagueIfpaPlayersUpdatedAtMs: Long? = null
    private var cachedLeagueIfpaPlayers: List<LeagueIfpaPlayerRecord> = emptyList()
    private var cachedLeagueMachineMappingsUpdatedAtMs: Long? = null
    private var cachedLeagueMachineMappings: Map<String, LeagueMachineMappingRecord> = emptyMap()

    private data class LeagueStatsSnapshot(
        val rows: List<LeagueCsvRow>,
        val players: List<String>,
        val updatedAtMs: Long?,
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

    suspend fun availablePlayers(forceRefresh: Boolean = false): List<String> =
        loadLeagueStatsSnapshot(forceRefresh = forceRefresh).players

    suspend fun approvedLeagueIdentityMatch(
        inputName: String,
        forceRefresh: Boolean = false,
    ): LeagueIdentityMatch? {
        val trimmedInput = inputName.trim()
        if (trimmedInput.isBlank()) return null

        val approvedMatch = matchApprovedIfpaPlayer(
            records = loadLeagueIfpaPlayers(forceRefresh = forceRefresh),
            inputName = trimmedInput,
        )
        if (approvedMatch != null) {
            return LeagueIdentityMatch(
                player = approvedMatch.player,
                ifpaPlayerID = approvedMatch.ifpaPlayerID,
            )
        }

        val fallbackPlayer = loadLeagueStatsSnapshot(forceRefresh = forceRefresh)
            .players
            .firstOrNull { normalizeHumanName(it) == normalizeHumanName(trimmedInput) }
            ?: return null
        return LeagueIdentityMatch(player = fallbackPlayer, ifpaPlayerID = null)
    }

    suspend fun statsUpdatedAtMs(forceRefresh: Boolean = false): Long? =
        loadLeagueStatsSnapshot(forceRefresh = forceRefresh).updatedAtMs

    suspend fun leagueMachineMappings(forceRefresh: Boolean = false): Map<String, LeagueMachineMappingRecord> {
        val result = if (forceRefresh) {
            runCatching {
                com.pillyliu.pinprofandroid.data.PinballDataCache.forceRefreshText(hostedLeagueMachineMappingsPath, allowMissing = true)
            }.getOrElse {
                com.pillyliu.pinprofandroid.data.PinballDataCache.loadText(hostedLeagueMachineMappingsPath, allowMissing = true)
            }
        } else {
            com.pillyliu.pinprofandroid.data.PinballDataCache.loadText(hostedLeagueMachineMappingsPath, allowMissing = true)
        }

        val text = result.text ?: run {
            cachedLeagueMachineMappingsUpdatedAtMs = result.updatedAtMs
            cachedLeagueMachineMappings = emptyMap()
            return emptyMap()
        }

        if (cachedLeagueMachineMappings.isEmpty() || cachedLeagueMachineMappingsUpdatedAtMs != result.updatedAtMs) {
            cachedLeagueMachineMappings = parseLeagueMachineMappings(text)
            cachedLeagueMachineMappingsUpdatedAtMs = result.updatedAtMs
        }
        return cachedLeagueMachineMappings
    }

    suspend fun importScores(
        selectedPlayer: String,
        games: List<com.pillyliu.pinprofandroid.library.PinballGame>,
        existingScores: List<ScoreEntry>,
        forceRefresh: Boolean = false,
        machineMappings: Map<String, LeagueMachineMappingRecord>? = null,
        onAddScore: (slug: String, score: Double, timestampMs: Long) -> Unit,
        onRepairScore: (existingId: String, score: Double, slug: String, timestampMs: Long) -> Unit,
    ): LeagueImportResult {
        val resolvedMachineMappings = machineMappings ?: leagueMachineMappings(forceRefresh = forceRefresh)
        return importLeagueScoresFromRows(
            selectedPlayer = selectedPlayer,
            rows = loadLeagueStatsSnapshot(forceRefresh = forceRefresh).rows,
            games = games,
            existingScores = existingScores,
            machineMappings = resolvedMachineMappings,
            onAddScore = onAddScore,
            onRepairScore = onRepairScore,
        )
    }

    suspend fun comparePlayers(
        yourName: String,
        opponentName: String,
        games: List<com.pillyliu.pinprofandroid.library.PinballGame>,
    ): HeadToHeadComparison? {
        val machineMappings = leagueMachineMappings()
        return comparePlayersFromRows(
            yourName = yourName,
            opponentName = opponentName,
            rows = loadLeagueStatsSnapshot().rows,
            games = games,
            machineMappings = machineMappings,
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

    private suspend fun loadLeagueStatsSnapshot(forceRefresh: Boolean = false): LeagueStatsSnapshot {
        val result = if (forceRefresh) {
            runCatching {
                com.pillyliu.pinprofandroid.data.PinballDataCache.forceRefreshText(hostedLeagueStatsPath, allowMissing = false)
            }.getOrElse {
                com.pillyliu.pinprofandroid.data.PinballDataCache.loadText(hostedLeagueStatsPath, allowMissing = false)
            }
        } else {
            com.pillyliu.pinprofandroid.data.PinballDataCache.loadText(hostedLeagueStatsPath, allowMissing = false)
        }
        val text = result.text ?: run {
            cachedLeagueStatsUpdatedAtMs = result.updatedAtMs
            cachedLeagueStatsRows = emptyList()
            cachedLeaguePlayers = emptyList()
            return LeagueStatsSnapshot(rows = emptyList(), players = emptyList(), updatedAtMs = result.updatedAtMs)
        }

        if (cachedLeagueStatsRows.isEmpty() || cachedLeagueStatsUpdatedAtMs != result.updatedAtMs) {
            val snapshot = PinballPerformanceTrace.measure("PracticeLeagueStatsLoad") {
                val rows = parseLeagueRows(text)
                LeagueStatsSnapshot(
                    rows = rows,
                    players = availableLeaguePlayersFromRows(rows),
                    updatedAtMs = result.updatedAtMs,
                )
            }
            cachedLeagueStatsRows = snapshot.rows
            cachedLeaguePlayers = snapshot.players
            cachedLeagueStatsUpdatedAtMs = result.updatedAtMs
        }

        return LeagueStatsSnapshot(
            rows = cachedLeagueStatsRows,
            players = cachedLeaguePlayers,
            updatedAtMs = result.updatedAtMs,
        )
    }

    private suspend fun loadLeagueIfpaPlayers(forceRefresh: Boolean = false): List<LeagueIfpaPlayerRecord> {
        val result = if (forceRefresh) {
            runCatching {
                com.pillyliu.pinprofandroid.data.PinballDataCache.forceRefreshText(hostedLeagueIfpaPlayersPath, allowMissing = true)
            }.getOrElse {
                com.pillyliu.pinprofandroid.data.PinballDataCache.loadText(hostedLeagueIfpaPlayersPath, allowMissing = true)
            }
        } else {
            com.pillyliu.pinprofandroid.data.PinballDataCache.loadText(hostedLeagueIfpaPlayersPath, allowMissing = true)
        }

        val text = result.text ?: run {
            cachedLeagueIfpaPlayersUpdatedAtMs = result.updatedAtMs
            cachedLeagueIfpaPlayers = emptyList()
            return emptyList()
        }

        if (cachedLeagueIfpaPlayers.isEmpty() || cachedLeagueIfpaPlayersUpdatedAtMs != result.updatedAtMs) {
            cachedLeagueIfpaPlayers = parseLeagueIfpaPlayers(text)
            cachedLeagueIfpaPlayersUpdatedAtMs = result.updatedAtMs
        }

        return cachedLeagueIfpaPlayers
    }
}
