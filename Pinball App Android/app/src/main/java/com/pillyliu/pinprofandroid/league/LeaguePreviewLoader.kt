package com.pillyliu.pinprofandroid.league

import android.content.Context
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.library.hostedLeagueStatsPath
import com.pillyliu.pinprofandroid.library.hostedLeagueStandingsPath
import com.pillyliu.pinprofandroid.library.hostedResolvedLeagueTargetsPath
import com.pillyliu.pinprofandroid.practice.loadResolvedLeagueTargets
import com.pillyliu.pinprofandroid.practice.loadPreferredLeaguePlayerName
import com.pillyliu.pinprofandroid.practice.practiceSharedPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

internal object LeaguePreviewRefreshEvents {
    private val _version = MutableStateFlow(0L)
    val version = _version.asStateFlow()

    fun notifyChanged() {
        _version.value = System.currentTimeMillis()
    }
}

internal suspend fun loadLeaguePreviewState(context: Context): LeaguePreviewState = withContext(Dispatchers.IO) {
    try {
        val standingsCsv = PinballDataCache.passthroughOrCachedText(hostedLeagueStandingsPath, allowMissing = true).text.orEmpty()
        val statsCsv = PinballDataCache.passthroughOrCachedText(hostedLeagueStatsPath, allowMissing = true).text.orEmpty()
        val selectedPlayer = loadPreferredLeaguePlayerName(practiceSharedPreferences(context))

        val statsRows = parseStatsRows(statsCsv)
        val targets = loadResolvedLeagueTargets(hostedResolvedLeagueTargetsPath).map { row ->
            TargetPreviewRow(
                game = row.game,
                second = row.secondHighestAvg,
                fourth = row.fourthHighestAvg,
                eighth = row.eighthHighestAvg,
                bank = row.bank,
                order = row.order,
            )
        }
        val standingsRows = parseStandingsRows(standingsCsv)

        val availableBanks = targets.mapNotNull { it.bank }.toSet()
        val nextBank = resolveNextBank(statsRows, availableBanks, selectedPlayer)
        val nextTargets = if (nextBank != null) {
            targets.filter { it.bank == nextBank }
                .sortedWith(compareBy<TargetPreviewRow> { it.order }.thenBy { it.game.lowercase(Locale.US) })
                .take(5)
        } else {
            targets.take(5)
        }

        val standingsPreview = buildStandingsPreview(standingsRows, selectedPlayer)
        val statsPreview = buildStatsPreview(statsRows, selectedPlayer)

        LeaguePreviewState(
            nextBankTargets = nextTargets,
            nextBankLabel = if (nextBank != null) "Next Bank • B$nextBank" else "Next Bank",
            standingsSeasonLabel = standingsPreview.seasonLabel,
            standingsTopRows = standingsPreview.topRows,
            standingsAroundRows = standingsPreview.aroundRows,
            statsRecentRows = statsPreview.rows,
            statsRecentBankLabel = statsPreview.bankLabel,
            statsPlayerRawName = statsPreview.playerRawName,
        )
    } catch (_: Throwable) {
        LeaguePreviewState()
    }
}
