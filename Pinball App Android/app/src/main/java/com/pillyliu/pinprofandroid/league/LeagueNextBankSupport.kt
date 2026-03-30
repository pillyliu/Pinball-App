package com.pillyliu.pinprofandroid.league

internal fun resolveNextBank(statsRows: List<StatsCsvRow>, availableBanks: Set<Int>, preferredPlayer: String?): Int? {
    val sorted = availableBanks.sorted()
    if (sorted.isEmpty()) return null
    if (statsRows.isEmpty()) return sorted.first()

    val scopedRows = scopedLeagueStatsRows(statsRows, preferredPlayer)
    if (scopedRows.isEmpty()) return sorted.first()

    val latestSeason = scopedRows.maxOfOrNull { it.season } ?: return sorted.first()
    val played = scopedRows
        .filter { it.season == latestSeason && it.bank in sorted }
        .map { it.bank }
        .toSet()

    return sorted.firstOrNull { it !in played } ?: sorted.first()
}
