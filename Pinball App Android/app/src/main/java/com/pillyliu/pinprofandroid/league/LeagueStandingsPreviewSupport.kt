package com.pillyliu.pinprofandroid.league

import com.pillyliu.pinprofandroid.data.parseCsv

internal fun buildStandingsPreview(rows: List<StandingCsvRow>, selectedPlayer: String?): StandingsPreviewPayload {
    if (rows.isEmpty()) return StandingsPreviewPayload("Season", emptyList(), emptyList(), null)
    val latestSeason = rows.maxOfOrNull { it.season } ?: return StandingsPreviewPayload("Season", emptyList(), emptyList(), null)
    val seasonRows = rows.filter { it.season == latestSeason }
    if (seasonRows.isEmpty()) return StandingsPreviewPayload("Season $latestSeason", emptyList(), emptyList(), null)

    val sorted = if (seasonRows.all { it.rank != null }) {
        seasonRows.sortedBy { it.rank ?: Int.MAX_VALUE }
    } else {
        seasonRows.sortedByDescending { it.total }
    }
    val previewRows = sorted.mapIndexed { index, row ->
        StandingsPreviewRow(rank = row.rank ?: (index + 1), rawPlayer = row.player, points = row.total)
    }
    val topRows = previewRows.take(5)

    if (!selectedPlayer.isNullOrBlank()) {
        val selectedIndex = previewRows.indexOfFirst { matchesLeaguePreferredPlayer(it.rawPlayer, selectedPlayer) }
        if (selectedIndex >= 0) {
            val currentPlayerStanding = previewRows[selectedIndex]
            val aroundWindowSize = if (currentPlayerStanding.rank > 5) 6 else 5
            return StandingsPreviewPayload(
                seasonLabel = "Season $latestSeason",
                topRows = topRows,
                aroundRows = leagueAroundRowsWindow(previewRows, selectedIndex, aroundWindowSize),
                currentPlayerStanding = currentPlayerStanding,
            )
        }
    }

    return StandingsPreviewPayload("Season $latestSeason", topRows, emptyList(), null)
}

internal fun parseStandingsRows(text: String): List<StandingCsvRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()
    val header = table.first().map(::normalizeLeagueHeader)
    val seasonIndex = header.indexOf("season")
    val playerIndex = header.indexOf("player")
    val totalIndex = header.indexOf("total")
    val rankIndex = header.indexOf("rank")
    if (listOf(seasonIndex, playerIndex, totalIndex).any { it < 0 }) return emptyList()

    return table.drop(1).mapNotNull { row ->
        if (listOf(seasonIndex, playerIndex, totalIndex).any { it !in row.indices }) return@mapNotNull null
        val season = coerceLeagueSeason(row[seasonIndex])
        val player = row[playerIndex].trim()
        val total = row[totalIndex].trim().replace(",", "").toDoubleOrNull() ?: 0.0
        val rank = if (rankIndex in row.indices) row[rankIndex].trim().toIntOrNull() else null
        if (season <= 0 || player.isBlank()) return@mapNotNull null
        StandingCsvRow(season, player, total, rank)
    }
}
