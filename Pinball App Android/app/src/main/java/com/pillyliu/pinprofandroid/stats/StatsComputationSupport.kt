package com.pillyliu.pinprofandroid.stats

import com.pillyliu.pinprofandroid.data.formatLplPlayerNameForDisplay
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.pow
import kotlin.math.sqrt

internal fun computeStats(scope: List<ScoreRow>, isBankScope: Boolean): StatResult {
    val values = scope.map { it.rawScore }.filter { it.isFinite() && it > 0 }
    if (values.isEmpty()) return StatResult(0, null, null, null, null, null, null, null)

    val sorted = values.sorted()
    val count = values.size
    val low = sorted.first()
    val high = sorted.last()
    val mean = values.sum() / count
    val median = if (count % 2 == 0) (sorted[count / 2 - 1] + sorted[count / 2]) / 2 else sorted[(count - 1) / 2]
    val variance = values.sumOf { (it - mean).pow(2) } / count
    val std = sqrt(variance)

    val lowRow = scope.firstOrNull { it.rawScore == low }
    val highRow = scope.firstOrNull { it.rawScore == high }

    fun label(row: ScoreRow): StatPlayerLabel =
        StatPlayerLabel(
            rawPlayer = row.player,
            season = if (isBankScope) null else abbreviateStatsSeason(row.season),
        )

    return StatResult(
        count = count,
        low = low,
        lowPlayer = lowRow?.let(::label),
        high = high,
        highPlayer = highRow?.let(::label),
        mean = mean,
        median = median,
        std = std,
    )
}

internal fun formatStatsPlayerLabel(player: StatPlayerLabel?, showFullLplLastName: Boolean): String {
    player ?: return "-"
    val display = formatLplPlayerNameForDisplay(player.rawPlayer, showFullLplLastName)
    return player.season?.takeIf { it.isNotBlank() }?.let { "$display ($it)" } ?: display
}

internal fun selectedStatsBankLabel(season: String, bankNumber: Int?): String {
    val seasonLabel = if (season.isBlank()) "S?" else abbreviateStatsSeason(season)
    val bankLabel = bankNumber?.let { "B$it" } ?: "B?"
    return "$seasonLabel $bankLabel"
}

internal fun seasonDisplayText(season: String): String = if (season.isBlank()) "S: All" else abbreviateStatsSeason(season)
internal fun bankDisplayText(bankNumber: Int?): String = bankNumber?.let { "B$it" } ?: "B: All"
internal fun playerDisplayText(player: String, showFullLplLastName: Boolean): String =
    if (player.isBlank()) "Player: All" else formatLplPlayerNameForDisplay(player, showFullLplLastName)
internal fun machineDisplayText(machine: String): String = if (machine.isBlank()) "Machine: All" else machine

internal fun statsNavSummaryText(
    season: String,
    bankNumber: Int?,
    player: String,
    machine: String,
    showFullLplLastName: Boolean,
): String {
    val seasonToken = if (season.isBlank()) "S*" else abbreviateStatsSeason(season)
    val bankToken = bankNumber?.let { "B$it" } ?: "B*"
    return "$seasonToken$bankToken  ${playerDisplayText(player, showFullLplLastName)}  ${machineDisplayText(machine)}"
}

internal fun abbreviateStatsSeason(season: String): String {
    val digits = season.filter { it.isDigit() }
    return if (digits.isNotEmpty()) "S$digits" else season
}

internal fun formatStatsInt(value: Double?): String {
    if (value == null || !value.isFinite()) return "-"
    return NumberFormat.getIntegerInstance().format(value.toLong())
}

internal fun formatStatsUpdatedAt(epochMs: Long): String {
    return SimpleDateFormat("M/d/yy h:mm a", Locale.getDefault()).format(Date(epochMs))
}
