package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.LibraryGameLookup
import com.pillyliu.pinprofandroid.library.PinballGame
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId
import java.util.Locale
import kotlin.math.abs

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
    existingScores: List<ScoreEntry>,
    machineMappings: Map<String, LeagueMachineMappingRecord>,
    onAddScore: (slug: String, score: Double, timestampMs: Long) -> Unit,
    onRepairScore: (existingId: String, score: Double, slug: String, timestampMs: Long) -> Unit,
): LeagueImportResult = withContext(Dispatchers.IO) {
    if (selectedPlayer.isEmpty()) {
        return@withContext LeagueImportResult(
            imported = 0,
            duplicatesSkipped = 0,
            unmatchedRows = 0,
            selectedPlayer = selectedPlayer,
            errorMessage = "Select league player first.",
        )
    }

    try {
        if (rows.isEmpty()) {
            return@withContext LeagueImportResult(
                imported = 0,
                duplicatesSkipped = 0,
                unmatchedRows = 0,
                selectedPlayer = selectedPlayer,
                errorMessage = "No league rows found.",
            )
        }

        var imported = 0
        var repaired = 0
        var duplicates = 0
        var unmatched = 0
        val normalizedSelectedPlayer = normalizeHumanName(selectedPlayer)
        val knownScores = existingScores.toMutableList()

        rows.forEach { row ->
            if (normalizeHumanName(row.player) != normalizedSelectedPlayer) return@forEach

            val slug = resolveLeagueGameSlug(row, games, machineMappings)
            if (slug == null) {
                unmatched++
                return@forEach
            }

            val eventDateMs = row.eventDateMs
            if (eventDateMs == null) {
                unmatched++
                return@forEach
            }

            if (isDuplicateLeagueScore(slug, row.rawScore, eventDateMs, knownScores)) {
                duplicates++
                return@forEach
            }

            val repairCandidate = repairCandidateLeagueScore(row.rawScore, eventDateMs, knownScores)
            if (repairCandidate != null) {
                onRepairScore(repairCandidate.id, row.rawScore, slug, eventDateMs)
                knownScores.replaceAll { existing ->
                    if (existing.id == repairCandidate.id) {
                        existing.copy(gameSlug = slug, timestampMs = eventDateMs)
                    } else {
                        existing
                    }
                }
                repaired++
                return@forEach
            }

            onAddScore(slug, row.rawScore, eventDateMs)
            knownScores += ScoreEntry(
                id = "league-import-$imported",
                gameSlug = slug,
                score = row.rawScore,
                context = "league",
                timestampMs = eventDateMs,
                leagueImported = true,
            )
            imported++
        }

        LeagueImportResult(
            imported = imported,
            duplicatesSkipped = duplicates,
            unmatchedRows = unmatched,
            selectedPlayer = selectedPlayer,
            repaired = repaired,
        )
    } catch (t: Throwable) {
        LeagueImportResult(
            imported = 0,
            duplicatesSkipped = 0,
            unmatchedRows = 0,
            selectedPlayer = selectedPlayer,
            errorMessage = "League CSV import failed: ${t.message ?: "unknown error"}",
        )
    }
}

internal suspend fun comparePlayersFromRows(
    yourName: String,
    opponentName: String,
    rows: List<LeagueCsvRow>,
    games: List<PinballGame>,
    machineMappings: Map<String, LeagueMachineMappingRecord>,
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
                val slug = resolveLeagueGameSlug(row, games, machineMappings) ?: return@mapNotNull null
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

private fun resolveLeagueGameSlug(
    row: LeagueCsvRow,
    games: List<PinballGame>,
    machineMappings: Map<String, LeagueMachineMappingRecord>,
): String? {
    resolveLeagueGameSlug(row.practiceIdentity, row.opdbId, games)?.let { return it }

    val normalizedMachine = LibraryGameLookup.normalizeMachineName(row.machine)
    machineMappings[normalizedMachine]?.let { mapping ->
        resolveLeagueGameSlug(mapping.practiceIdentity, mapping.opdbId, games)?.let { return it }
    }

    return matchGameSlug(row.machine, games)
}

private fun resolveLeagueGameSlug(
    practiceIdentity: String?,
    opdbId: String?,
    games: List<PinballGame>,
): String? {
    val candidates = listOfNotNull(
        practiceIdentity?.trim()?.takeIf { it.isNotBlank() },
        opdbId?.let(::extractLikelyOpdbGroupId),
        opdbId?.trim()?.takeIf { it.isNotBlank() },
    )
    candidates.forEach { candidate ->
        val canonical = canonicalPracticeKey(candidate, games)
        if (canonical.isNotBlank() &&
            (findGameByPracticeLookupKey(games, canonical) != null || findGameByPracticeLookupKey(games, candidate) != null)
        ) {
            return canonical
        }
    }
    return null
}

private fun matchGameSlug(machine: String, games: List<PinballGame>): String? {
    val machineKeys = LibraryGameLookup.equivalentKeys(machine)
    if (machineKeys.isEmpty()) return null

    val matches = distinctGamesByPracticeIdentity(games).mapNotNull { game ->
        val gameKeys = LibraryGameLookup.equivalentKeys(game.name)
        canonicalPracticeKey(game.practiceKey, games).takeIf { gameKeys.any(machineKeys::contains) }
    }.distinct()

    return matches.singleOrNull()
}

private fun extractLikelyOpdbGroupId(raw: String): String? {
    return Regex("\\bG[0-9A-Za-z]{4,}\\b", RegexOption.IGNORE_CASE).find(raw)?.value
}

private fun isDuplicateLeagueScore(
    gameSlug: String,
    score: Double,
    eventDateMs: Long,
    existingScores: List<ScoreEntry>,
): Boolean {
    val eventDate = Instant.ofEpochMilli(eventDateMs).atZone(ZoneId.systemDefault()).toLocalDate()
    return existingScores.any { existing ->
        existing.gameSlug == gameSlug &&
            existing.context == "league" &&
            abs(existing.score - score) < 0.5 &&
            Instant.ofEpochMilli(existing.timestampMs).atZone(ZoneId.systemDefault()).toLocalDate() == eventDate
    }
}

private fun repairCandidateLeagueScore(
    score: Double,
    eventDateMs: Long,
    existingScores: List<ScoreEntry>,
): ScoreEntry? {
    val eventDate = Instant.ofEpochMilli(eventDateMs).atZone(ZoneId.systemDefault()).toLocalDate()
    val matches = existingScores.filter { existing ->
        existing.leagueImported &&
            existing.context == "league" &&
            abs(existing.score - score) < 0.5 &&
            Instant.ofEpochMilli(existing.timestampMs).atZone(ZoneId.systemDefault()).toLocalDate() == eventDate
    }
    return matches.singleOrNull()
}
