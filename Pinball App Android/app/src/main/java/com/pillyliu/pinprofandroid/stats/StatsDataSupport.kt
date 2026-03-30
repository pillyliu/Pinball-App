package com.pillyliu.pinprofandroid.stats

import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.data.parseCsv

internal const val STATS_CSV_URL = "https://pillyliu.com/pinball/data/LPL_Stats.csv"

internal suspend fun loadStatsRows(force: Boolean): StatsLoadResult {
    val cached = if (force) {
        PinballDataCache.forceRefreshText(STATS_CSV_URL)
    } else {
        PinballDataCache.passthroughOrCachedText(STATS_CSV_URL)
    }
    return StatsLoadResult(
        rows = parseScoreRows(cached.text.orEmpty()),
        updatedAtMs = cached.updatedAtMs,
    )
}

internal suspend fun hasRemoteStatsUpdate(): Boolean {
    return PinballDataCache.hasRemoteUpdate(STATS_CSV_URL)
}

internal fun compareStatsSeasons(left: String, right: String): Int {
    val leftNumber = left.toLongOrNull()
    val rightNumber = right.toLongOrNull()
    return when {
        leftNumber != null && rightNumber != null -> leftNumber.compareTo(rightNumber)
        else -> left.compareTo(right)
    }
}

private fun parseScoreRows(text: String): List<ScoreRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()
    val headers = table.first().map { it.trim() }

    fun idx(name: String): Int = headers.indexOfFirst { it.equals(name, ignoreCase = true) }

    val seasonIdx = idx("Season")
    val bankNumberIdx = idx("BankNumber")
    val playerIdx = idx("Player")
    val machineIdx = idx("Machine")
    val rawScoreIdx = idx("RawScore")
    val pointsIdx = idx("Points")

    if (listOf(seasonIdx, bankNumberIdx, playerIdx, machineIdx, rawScoreIdx, pointsIdx).any { it < 0 }) return emptyList()

    return table.drop(1).mapIndexedNotNull { offset, row ->
        if (row.size != headers.size) return@mapIndexedNotNull null
        ScoreRow(
            id = offset,
            season = normalizeStatsSeason(row[seasonIdx]),
            bankNumber = row[bankNumberIdx].trim().toIntOrNull() ?: 0,
            player = row[playerIdx].trim(),
            machine = row[machineIdx].trim(),
            rawScore = row[rawScoreIdx].trim().replace(",", "").toDoubleOrNull() ?: 0.0,
            points = row[pointsIdx].trim().replace(",", "").toDoubleOrNull() ?: 0.0,
        )
    }
}

private fun normalizeStatsSeason(raw: String): String {
    val trimmed = raw.trim()
    val digits = trimmed.filter { it.isDigit() }
    return if (digits.isNotEmpty()) digits else trimmed
}
