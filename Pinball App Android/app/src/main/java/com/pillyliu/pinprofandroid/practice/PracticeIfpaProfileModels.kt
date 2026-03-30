package com.pillyliu.pinprofandroid.practice

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

internal data class IfpaRecentTournament(
    val name: String,
    val date: LocalDate,
    val dateLabel: String,
    val finish: String,
    val pointsGained: String,
)

internal data class IfpaPlayerProfile(
    val playerID: String,
    val displayName: String,
    val location: String?,
    val profilePhotoUrl: String?,
    val currentRank: String,
    val currentWpprPoints: String,
    val rating: String,
    val lastEventDate: String?,
    val seriesLabel: String?,
    val seriesRank: String?,
    val recentTournaments: List<IfpaRecentTournament>,
)

internal data class IfpaCachedProfileSnapshot(
    val profile: IfpaPlayerProfile,
    val cachedAtEpochMs: Long,
)

private val ifpaCachedAtFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("MMM d, yyyy h:mm a", Locale.US)

internal fun formatIfpaCachedAt(epochMs: Long): String {
    return Instant.ofEpochMilli(epochMs)
        .atZone(ZoneId.systemDefault())
        .format(ifpaCachedAtFormatter)
}
