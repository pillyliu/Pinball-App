package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.data.formatLplPlayerNameForDisplay
import com.pillyliu.pinprofandroid.data.parseCsv
import com.pillyliu.pinprofandroid.library.LibraryGameLookup
import com.pillyliu.pinprofandroid.library.PinballGame
import com.pillyliu.pinprofandroid.library.hostedLeagueStatsPath
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Locale

internal fun availableLeaguePlayersFromRows(rows: List<LeagueCsvRow>): List<String> {
    return rows
        .mapNotNull { row -> row.player.trim().takeIf { it.isNotEmpty() } }
        .distinctBy { normalizeHumanName(it) }
        .sortedBy { it.lowercase(Locale.US) }
}

internal suspend fun importLeagueScoresFromRows(
    selectedPlayer: String,
    rows: List<LeagueCsvRow>,
    games: List<PinballGame>,
    onAddScore: (slug: String, score: Double, timestampMs: Long) -> Unit,
): String = withContext(Dispatchers.IO) {
    if (selectedPlayer.isEmpty()) {
        return@withContext "Select league player first."
    }
    try {
        if (rows.isEmpty()) return@withContext "No league rows found."

        var imported = 0
        var unmatched = 0

        rows.forEach { row ->
            if (!row.player.equals(selectedPlayer, ignoreCase = true)) return@forEach
            val slug = matchGameSlug(row.machine, games)
            if (slug == null) {
                unmatched++
                return@forEach
            }
            onAddScore(
                slug,
                row.rawScore,
                row.eventDateMs ?: System.currentTimeMillis(),
            )
            imported++
        }
        "League import for ${formatLplPlayerNameForDisplay(selectedPlayer, false)}: $imported imported, $unmatched unmatched."
    } catch (t: Throwable) {
        "League CSV import failed: ${t.message ?: "unknown error"}"
    }
}

internal suspend fun comparePlayersFromRows(
    yourName: String,
    opponentName: String,
    rows: List<LeagueCsvRow>,
    games: List<PinballGame>,
    gameNameForSlug: (String) -> String,
): HeadToHeadComparison? = withContext(Dispatchers.IO) {
    val yourNormalized = normalizeHumanName(yourName)
    val opponentNormalized = normalizeHumanName(opponentName)
    if (yourNormalized.isEmpty() || opponentNormalized.isEmpty()) return@withContext null

    try {
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
    return LibraryGameLookup.bestMatch(machine, games)?.slug
}
