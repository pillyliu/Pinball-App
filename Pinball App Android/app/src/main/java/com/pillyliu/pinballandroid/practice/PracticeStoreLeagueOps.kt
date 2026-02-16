package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.data.parseCsv
import com.pillyliu.pinballandroid.data.redactPlayerNameForDisplay
import com.pillyliu.pinballandroid.library.PinballGame
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Locale

private const val LEAGUE_STATS_PATH = "/pinball/data/LPL_Stats.csv"

internal suspend fun availableLeaguePlayersFromCsv(): List<String> = withContext(Dispatchers.IO) {
    try {
        val result = PinballDataCache.loadText(LEAGUE_STATS_PATH, allowMissing = false)
        val text = result.text ?: return@withContext emptyList()
        val rows = parseCsv(text)
        if (rows.isEmpty()) return@withContext emptyList()
        val headers = rows.first().map { normalizeHeader(it) }
        val idx = headers.indexOf("player")
        if (idx < 0) return@withContext emptyList()
        rows.drop(1)
            .mapNotNull { row -> row.getOrNull(idx)?.trim()?.takeIf { it.isNotEmpty() } }
            .distinct()
            .sortedBy { it.lowercase(Locale.US) }
    } catch (_: Throwable) {
        emptyList()
    }
}

internal suspend fun importLeagueScoresFromCsvData(
    selectedPlayer: String,
    games: List<PinballGame>,
    onAddScore: (slug: String, score: Double, timestampMs: Long) -> Unit,
): String = withContext(Dispatchers.IO) {
    if (selectedPlayer.isEmpty()) {
        return@withContext "Select league player first."
    }
    try {
        val result = PinballDataCache.loadText(LEAGUE_STATS_PATH, allowMissing = false)
        val text = result.text ?: return@withContext "LPL CSV missing."
        val rows = parseCsv(text)
        if (rows.isEmpty()) return@withContext "No league rows found."

        val headers = rows.first().map { normalizeHeader(it) }
        val playerIdx = headers.indexOf("player")
        val machineIdx = headers.indexOf("machine").takeIf { it >= 0 } ?: headers.indexOf("game")
        val scoreIdx = headers.indexOf("rawscore").takeIf { it >= 0 } ?: headers.indexOf("score")
        val dateIdx = headers.indexOf("eventdate").takeIf { it >= 0 } ?: headers.indexOf("date")
        if (playerIdx < 0 || machineIdx < 0 || scoreIdx < 0) {
            return@withContext "CSV header mismatch."
        }

        var imported = 0
        var unmatched = 0

        rows.drop(1).forEach { row ->
            val player = row.getOrNull(playerIdx)?.trim().orEmpty()
            if (!player.equals(selectedPlayer, ignoreCase = true)) return@forEach
            val machine = row.getOrNull(machineIdx)?.trim().orEmpty()
            val score = row.getOrNull(scoreIdx)?.trim()?.toDoubleOrNull() ?: return@forEach
            if (machine.isBlank() || score <= 0) return@forEach
            val slug = matchGameSlug(machine, games)
            if (slug == null) {
                unmatched++
                return@forEach
            }
            val timestamp = row.getOrNull(dateIdx)
                ?.trim()
                ?.takeIf { it.isNotBlank() }
                ?.let { parseEventDateMillis(it) }
                ?: System.currentTimeMillis()
            onAddScore(slug, score, timestamp)
            imported++
        }
        "League import for ${redactPlayerNameForDisplay(selectedPlayer)}: $imported imported, $unmatched unmatched."
    } catch (t: Throwable) {
        "League CSV import failed: ${t.message ?: "unknown error"}"
    }
}

internal suspend fun comparePlayersFromCsv(
    yourName: String,
    opponentName: String,
    games: List<PinballGame>,
    gameNameForSlug: (String) -> String,
): HeadToHeadComparison? = withContext(Dispatchers.IO) {
    val yourNormalized = normalizeHumanName(yourName)
    val opponentNormalized = normalizeHumanName(opponentName)
    if (yourNormalized.isEmpty() || opponentNormalized.isEmpty()) return@withContext null

    try {
        val result = PinballDataCache.loadText(LEAGUE_STATS_PATH, allowMissing = false)
        val text = result.text ?: return@withContext null
        val rows = parseLeagueRows(text)
        val yourRows = rows.filter { normalizeHumanName(it.player) == yourNormalized }
        val opponentRows = rows.filter { normalizeHumanName(it.player) == opponentNormalized }
        if (yourRows.isEmpty() || opponentRows.isEmpty()) return@withContext null

        data class PerGameAggregate(val gameSlug: String, val values: List<Double>)
        fun aggregate(sourceRows: List<LeagueCsvRow>): Map<String, PerGameAggregate> {
            val grouped = sourceRows.mapNotNull { row ->
                val slug = matchGameSlug(row.machine, games) ?: return@mapNotNull null
                slug to row.rawScore
            }.groupBy({ it.first }, { it.second })

            return grouped.mapValues { (slug, values) ->
                PerGameAggregate(gameSlug = slug, values = values)
            }
        }

        val yourAgg = aggregate(yourRows)
        val opponentAgg = aggregate(opponentRows)
        val shared = yourAgg.keys.intersect(opponentAgg.keys)
        if (shared.isEmpty()) return@withContext null

        val gameRows = shared.mapNotNull { slug ->
            val left = yourAgg[slug] ?: return@mapNotNull null
            val right = opponentAgg[slug] ?: return@mapNotNull null
            if (left.values.isEmpty() || right.values.isEmpty()) return@mapNotNull null
            HeadToHeadGameStats(
                gameSlug = slug,
                gameName = gameNameForSlug(slug),
                yourCount = left.values.size,
                opponentCount = right.values.size,
                yourMean = left.values.average(),
                opponentMean = right.values.average(),
                yourHigh = left.values.maxOrNull() ?: 0.0,
                opponentHigh = right.values.maxOrNull() ?: 0.0,
                yourLow = left.values.minOrNull() ?: 0.0,
                opponentLow = right.values.minOrNull() ?: 0.0,
            )
        }.sortedByDescending { kotlin.math.abs(it.meanDelta) }

        if (gameRows.isEmpty()) return@withContext null
        val leadCount = gameRows.count { it.meanDelta > 0 }
        val oppLeadCount = gameRows.count { it.meanDelta < 0 }
        val avgDelta = gameRows.map { it.meanDelta }.average()

        HeadToHeadComparison(
            yourPlayerName = yourName,
            opponentPlayerName = opponentName,
            totalGamesCompared = gameRows.size,
            gamesYouLeadByMean = leadCount,
            gamesOpponentLeadsByMean = oppLeadCount,
            averageMeanDelta = avgDelta,
            games = gameRows,
        )
    } catch (_: Throwable) {
        null
    }
}

private fun matchGameSlug(machine: String, games: List<PinballGame>): String? {
    val normalized = normalizeMachine(machine)
    val byNormalized = games.associateBy { normalizeMachine(it.name) }
    byNormalized[normalized]?.let { return it.slug }
    return byNormalized.entries.firstOrNull { (key, _) ->
        key.contains(normalized) || normalized.contains(key)
    }?.value?.slug
}
