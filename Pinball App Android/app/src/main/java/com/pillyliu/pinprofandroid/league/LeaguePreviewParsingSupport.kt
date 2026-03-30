package com.pillyliu.pinprofandroid.league

import com.pillyliu.pinprofandroid.data.leaguePlayerNamesMatch
import java.time.LocalDate
import java.util.Locale

internal fun matchesLeaguePreferredPlayer(candidate: String, preferred: String): Boolean {
    return leaguePlayerNamesMatch(candidate, preferred)
}

internal fun resolveLeaguePlayerForStats(rows: List<StatsCsvRow>, preferredPlayer: String?): String {
    if (!preferredPlayer.isNullOrBlank() && rows.any { matchesLeaguePreferredPlayer(it.player, preferredPlayer) }) {
        return preferredPlayer
    }
    return rows.maxByOrNull(::latestLeagueSortValue)?.player ?: rows.first().player
}

internal fun latestLeagueSortValue(row: StatsCsvRow): Long {
    val datePart = row.eventDate?.toEpochDay() ?: 0L
    return (datePart * 1_000_000L) + (row.season * 100L + row.bank)
}

internal fun scopedLeagueStatsRows(rows: List<StatsCsvRow>, preferredPlayer: String?): List<StatsCsvRow> {
    if (preferredPlayer.isNullOrBlank()) return rows
    val selectedRows = rows.filter { matchesLeaguePreferredPlayer(it.player, preferredPlayer) }
    return if (selectedRows.isEmpty()) rows else selectedRows
}

internal fun normalizeLeagueHeader(value: String): String {
    return value.replace("\uFEFF", "").replace("\u0000", "").trim().lowercase(Locale.US)
}

internal fun coerceLeagueSeason(raw: String): Int {
    val trimmed = raw.trim()
    val digits = trimmed.filter { it.isDigit() }
    return digits.toIntOrNull() ?: trimmed.toIntOrNull() ?: 0
}

internal fun leagueAroundRowsWindow(
    rows: List<StandingsPreviewRow>,
    selectedIndex: Int,
    windowSize: Int = 5,
): List<StandingsPreviewRow> {
    if (rows.isEmpty()) return emptyList()
    val clampedIndex = selectedIndex.coerceIn(0, rows.lastIndex)
    val edge = windowSize / 2
    val start = when {
        clampedIndex <= edge -> 0
        clampedIndex >= rows.size - edge - 1 -> maxOf(0, rows.size - windowSize)
        else -> clampedIndex - edge
    }
    val end = minOf(rows.size, start + windowSize)
    return rows.subList(start, end)
}
