package com.pillyliu.pinprofandroid.practice

import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

internal data class PrpaSceneStanding(
    val name: String,
    val rank: String,
)

internal data class PrpaRecentTournament(
    val name: String,
    val eventType: String?,
    val date: LocalDateTime,
    val dateLabel: String,
    val placement: String,
    val pointsGained: String,
)

internal data class PrpaPlayerProfile(
    val playerID: String,
    val displayName: String,
    val openPoints: String,
    val eventsPlayed: String,
    val openRanking: String,
    val averagePointsPerEvent: String,
    val bestFinish: String,
    val worstFinish: String,
    val ifpaPlayerID: String?,
    val lastEventDate: String?,
    val scenes: List<PrpaSceneStanding>,
    val recentTournaments: List<PrpaRecentTournament>,
)

internal data class PrpaCachedProfileSnapshot(
    val profile: PrpaPlayerProfile,
    val cachedAtEpochMs: Long,
)

private val prpaCachedAtFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("MMM d, yyyy h:mm a", Locale.US)

internal fun formatPrpaCachedAt(epochMs: Long): String {
    return Instant.ofEpochMilli(epochMs)
        .atZone(ZoneId.systemDefault())
        .format(prpaCachedAtFormatter)
}
