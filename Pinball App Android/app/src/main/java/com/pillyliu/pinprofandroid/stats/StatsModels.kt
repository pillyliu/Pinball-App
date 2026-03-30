package com.pillyliu.pinprofandroid.stats

internal data class ScoreRow(
    val id: Int,
    val season: String,
    val bankNumber: Int,
    val player: String,
    val machine: String,
    val rawScore: Double,
    val points: Double,
)

internal data class StatPlayerLabel(
    val rawPlayer: String,
    val season: String?,
)

internal data class StatResult(
    val count: Int,
    val low: Double?,
    val lowPlayer: StatPlayerLabel?,
    val high: Double?,
    val highPlayer: StatPlayerLabel?,
    val mean: Double?,
    val median: Double?,
    val std: Double?,
)

internal data class StatsTableWidths(
    val season: Int,
    val bank: Int,
    val player: Int,
    val machine: Int,
    val score: Int,
    val points: Int,
)

internal data class StatsLoadResult(
    val rows: List<ScoreRow>,
    val updatedAtMs: Long?,
)
