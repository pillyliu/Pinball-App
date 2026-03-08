package com.pillyliu.pinprofandroid.league

import android.content.Context
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.library.LibraryGameLookup
import com.pillyliu.pinprofandroid.library.loadLibraryExtraction
import com.pillyliu.pinprofandroid.practice.loadPreferredLeaguePlayerName
import com.pillyliu.pinprofandroid.practice.practiceSharedPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Locale

internal suspend fun loadLeaguePreviewState(context: Context): LeaguePreviewState = withContext(Dispatchers.IO) {
    try {
        val targetsCsv = PinballDataCache.passthroughOrCachedText("https://pillyliu.com/pinball/data/LPL_Targets.csv").text.orEmpty()
        val standingsCsv = PinballDataCache.passthroughOrCachedText("https://pillyliu.com/pinball/data/LPL_Standings.csv", allowMissing = true).text.orEmpty()
        val statsCsv = PinballDataCache.passthroughOrCachedText("https://pillyliu.com/pinball/data/LPL_Stats.csv", allowMissing = true).text.orEmpty()
        val libraryEntries = LibraryGameLookup.buildEntries(loadLibraryExtraction(context).payload.games)
        val selectedPlayer = loadPreferredLeaguePlayerName(practiceSharedPreferences(context))

        val statsRows = parseStatsRows(statsCsv)
        val targets = mergeTargetsWithLibrary(parseTargetRows(targetsCsv), libraryEntries)
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
