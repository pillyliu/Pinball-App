package com.pillyliu.pinprofandroid.standings

internal data class StandingsCsvRow(
    val season: Int,
    val player: String,
    val total: Double,
    val rank: Int?,
    val eligible: String,
    val nights: String,
    val banks: List<Double>,
)

internal data class Standing(
    val rawPlayer: String,
    val seasonTotal: Double,
    val eligible: String,
    val nights: String,
    val banks: List<Double>,
)

internal data class StandingsWidths(
    val rank: Int,
    val player: Int,
    val points: Int,
    val eligible: Int,
    val nights: Int,
    val bank: Int,
)
