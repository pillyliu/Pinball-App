package com.pillyliu.pinprofandroid.league

import com.pillyliu.pinprofandroid.data.parseCsv
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlin.math.abs

internal fun buildStatsPreview(rows: List<StatsCsvRow>, preferredPlayer: String?): StatsPreviewPayload {
    if (rows.isEmpty()) return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")

    val selectedPlayer = resolveLeaguePlayerForStats(rows, preferredPlayer)
    val selected = rows.filter { matchesLeaguePreferredPlayer(it.player, selectedPlayer) }
    if (selected.isEmpty()) return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")

    val grouped = selected.groupBy { "${it.season}-${it.bank}" }
    val recentKey = grouped.keys.maxByOrNull { key ->
        grouped[key]?.maxOfOrNull(::latestLeagueSortValue) ?: 0L
    } ?: return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")
    val sample = grouped[recentKey]?.firstOrNull() ?: return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")

    val sortedMostRecentRows = grouped[recentKey].orEmpty().sortedBy { it.sourceOrder }
    val rowsForPreview = if (sortedMostRecentRows.size > 5) {
        val nonZeroScoreRows = sortedMostRecentRows.filter { abs(it.score) > 0.000001 }
        if (nonZeroScoreRows.size >= 5) nonZeroScoreRows else sortedMostRecentRows
    } else {
        sortedMostRecentRows
    }

    return StatsPreviewPayload(
        rows = rowsForPreview.take(5).map {
            StatsPreviewRow(machine = it.machine, score = it.score, points = it.points)
        },
        bankLabel = "Most Recent • S${sample.season} B${sample.bank}",
        playerRawName = sample.player,
    )
}

internal fun parseStatsRows(text: String): List<StatsCsvRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()
    val header = table.first().map(::normalizeLeagueHeader)
    val seasonIndex = header.indexOf("season")
    val bankIndex = header.indexOf("banknumber")
    val playerIndex = header.indexOf("player")
    val machineIndex = header.indexOf("machine")
    val scoreIndex = header.indexOf("rawscore")
    val pointsIndex = header.indexOf("points")
    val eventDateIndex = header.indexOf("eventdate")

    if (listOf(seasonIndex, bankIndex, playerIndex, machineIndex, scoreIndex, pointsIndex).any { it < 0 }) {
        return emptyList()
    }

    return table.drop(1).mapIndexedNotNull { idx, row ->
        if (listOf(seasonIndex, bankIndex, playerIndex, machineIndex, scoreIndex, pointsIndex).any { it !in row.indices }) {
            return@mapIndexedNotNull null
        }
        val season = coerceLeagueSeason(row[seasonIndex])
        val bank = row[bankIndex].trim().toIntOrNull() ?: 0
        val player = row[playerIndex].trim()
        val machine = row[machineIndex].trim()
        val score = row[scoreIndex].trim().replace(",", "").toDoubleOrNull() ?: 0.0
        val points = row[pointsIndex].trim().replace(",", "").toDoubleOrNull() ?: 0.0
        val eventDate = if (eventDateIndex in row.indices) {
            runCatching { LocalDate.parse(row[eventDateIndex].trim(), DateTimeFormatter.ISO_LOCAL_DATE) }.getOrNull()
        } else {
            null
        }

        if (season <= 0 || bank <= 0 || player.isBlank() || machine.isBlank()) return@mapIndexedNotNull null
        if (score <= 0.0 && points <= 0.0) return@mapIndexedNotNull null

        StatsCsvRow(season, bank, player, machine, score, points, eventDate, idx)
    }
}
