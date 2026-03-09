package com.pillyliu.pinprofandroid.league

import java.time.LocalDate

internal enum class TargetMetric(val label: String) {
    Second("2nd"),
    Fourth("4th"),
    Eighth("8th");

    fun value(row: TargetPreviewRow): Long = when (this) {
        Second -> row.second
        Fourth -> row.fourth
        Eighth -> row.eighth
    }
}

internal data class LeaguePreviewState(
    val nextBankTargets: List<TargetPreviewRow> = emptyList(),
    val nextBankLabel: String = "Next Bank",
    val standingsSeasonLabel: String = "Season",
    val standingsTopRows: List<StandingsPreviewRow> = emptyList(),
    val standingsAroundRows: List<StandingsPreviewRow> = emptyList(),
    val statsRecentRows: List<StatsPreviewRow> = emptyList(),
    val statsRecentBankLabel: String = "Most Recent Bank",
    val statsPlayerRawName: String = "",
)

internal data class TargetPreviewRow(
    val game: String,
    val second: Long,
    val fourth: Long,
    val eighth: Long,
    val bank: Int?,
    val order: Int,
)

internal data class StandingsPreviewRow(
    val rank: Int,
    val rawPlayer: String,
    val points: Double,
)

internal data class StatsPreviewRow(
    val machine: String,
    val score: Double,
    val points: Double,
)

internal data class StatsCsvRow(
    val season: Int,
    val bank: Int,
    val player: String,
    val machine: String,
    val score: Double,
    val points: Double,
    val eventDate: LocalDate?,
    val sourceOrder: Int,
)

internal data class StandingCsvRow(
    val season: Int,
    val player: String,
    val total: Double,
    val rank: Int?,
)

internal data class StatsPreviewPayload(
    val rows: List<StatsPreviewRow>,
    val bankLabel: String,
    val playerRawName: String,
)

internal data class StandingsPreviewPayload(
    val seasonLabel: String,
    val topRows: List<StandingsPreviewRow>,
    val aroundRows: List<StandingsPreviewRow>,
)
