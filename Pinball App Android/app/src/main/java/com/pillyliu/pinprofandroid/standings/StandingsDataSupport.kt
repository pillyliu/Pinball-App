package com.pillyliu.pinprofandroid.standings

import com.pillyliu.pinprofandroid.data.parseCsv
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

internal const val STANDINGS_CSV_URL = "https://pillyliu.com/pinball/data/LPL_Standings.csv"

internal fun buildStandings(rows: List<StandingsCsvRow>, selectedSeason: Int?): List<Standing> {
    if (selectedSeason == null) return emptyList()
    val seasonRows = rows.filter { it.season == selectedSeason }
    if (seasonRows.isEmpty()) return emptyList()

    val mapped = seasonRows.map {
        Standing(
            rawPlayer = it.player,
            seasonTotal = it.total,
            eligible = it.eligible,
            nights = it.nights,
            banks = it.banks,
        )
    }

    val hasRankForAll = seasonRows.all { it.rank != null }
    if (hasRankForAll) {
        val rankMap = seasonRows.associate { it.player to (it.rank ?: Int.MAX_VALUE) }
        return mapped.sortedBy { rankMap[it.rawPlayer] ?: Int.MAX_VALUE }
    }

    return mapped.sortedByDescending { it.seasonTotal }
}

internal fun parseStandings(text: String): List<StandingsCsvRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()

    val headers = table[0].map { normalizeStandingsHeader(it) }
    val required = listOf(
        "season", "player", "total", "bank_1", "bank_2", "bank_3", "bank_4",
        "bank_5", "bank_6", "bank_7", "bank_8",
    )
    if (required.any { it !in headers }) {
        throw IllegalStateException("Standings CSV missing required columns")
    }

    return table.drop(1).mapNotNull { row ->
        if (row.size != headers.size) return@mapNotNull null
        val dict = headers.zip(row).toMap()

        val season = coerceStandingsSeason(dict["season"].orEmpty())
        val player = dict["player"].orEmpty().trim()
        if (season <= 0 || player.isBlank()) return@mapNotNull null

        StandingsCsvRow(
            season = season,
            player = player,
            total = dict["total"].orEmpty().toDoubleOrNull() ?: 0.0,
            rank = dict["rank"].orEmpty().trim().toIntOrNull(),
            eligible = dict["eligible"].orEmpty().trim(),
            nights = dict["nights"].orEmpty().trim(),
            banks = (1..8).map { i -> dict["bank_$i"].orEmpty().toDoubleOrNull() ?: 0.0 },
        )
    }
}

internal fun formatStandingsValue(value: Double): String = NumberFormat.getIntegerInstance().format(value.toLong())

internal fun formatStandingsUpdatedAt(epochMs: Long): String {
    return SimpleDateFormat("M/d/yy h:mm a", Locale.getDefault()).format(Date(epochMs))
}

private fun normalizeStandingsHeader(header: String): String {
    return header.replace("\uFEFF", "").trim().lowercase()
}

private fun coerceStandingsSeason(value: String): Int {
    val trimmed = value.trim()
    val digits = trimmed.filter { it.isDigit() }
    return digits.toIntOrNull() ?: trimmed.toIntOrNull() ?: 0
}
