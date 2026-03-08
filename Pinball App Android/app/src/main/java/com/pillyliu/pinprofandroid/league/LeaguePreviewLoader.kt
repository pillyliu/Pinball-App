package com.pillyliu.pinprofandroid.league

import android.content.Context
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.data.parseCsv
import com.pillyliu.pinprofandroid.library.LibraryGameLookup
import com.pillyliu.pinprofandroid.library.LibraryGameLookupEntry
import com.pillyliu.pinprofandroid.library.loadLibraryExtraction
import com.pillyliu.pinprofandroid.practice.loadPreferredLeaguePlayerName
import com.pillyliu.pinprofandroid.practice.practiceSharedPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.abs

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

private fun buildStatsPreview(rows: List<StatsCsvRow>, preferredPlayer: String?): StatsPreviewPayload {
    if (rows.isEmpty()) return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")

    val selectedPlayer = resolvePlayerForStats(rows, preferredPlayer)
    val selected = rows.filter { matchesPreferredPlayer(it.player, selectedPlayer) }
    if (selected.isEmpty()) return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")

    val grouped = selected.groupBy { "${it.season}-${it.bank}" }
    val recentKey = grouped.keys.maxByOrNull { key ->
        grouped[key]?.maxOfOrNull(::latestSortValue) ?: 0L
    } ?: return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")
    val sample = grouped[recentKey]?.firstOrNull() ?: return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")

    val sortedMostRecentRows = grouped[recentKey].orEmpty().sortedBy { it.sourceOrder }
    val rowsForPreview = if (sortedMostRecentRows.size > 5) {
        val nonZeroScoreRows = sortedMostRecentRows.filter { abs(it.score) > 0.000001 }
        if (nonZeroScoreRows.size >= 5) nonZeroScoreRows else sortedMostRecentRows
    } else {
        sortedMostRecentRows
    }

    return StatsPreviewPayload(
        rows = rowsForPreview.take(5).map {
            StatsPreviewRow(machine = it.machine, score = it.score, points = it.points)
        },
        bankLabel = "Most Recent • S${sample.season} B${sample.bank}",
        playerRawName = sample.player,
    )
}

private fun resolvePlayerForStats(rows: List<StatsCsvRow>, preferredPlayer: String?): String {
    if (!preferredPlayer.isNullOrBlank() && rows.any { matchesPreferredPlayer(it.player, preferredPlayer) }) {
        return preferredPlayer
    }
    return rows.maxByOrNull(::latestSortValue)?.player ?: rows.first().player
}

private fun latestSortValue(row: StatsCsvRow): Long {
    val datePart = row.eventDate?.toEpochDay() ?: 0L
    return (datePart * 1_000_000L) + (row.season * 100L + row.bank)
}

private fun buildStandingsPreview(rows: List<StandingCsvRow>, selectedPlayer: String?): StandingsPreviewPayload {
    if (rows.isEmpty()) return StandingsPreviewPayload("Season", emptyList(), emptyList())
    val latestSeason = rows.maxOfOrNull { it.season } ?: return StandingsPreviewPayload("Season", emptyList(), emptyList())
    val seasonRows = rows.filter { it.season == latestSeason }
    if (seasonRows.isEmpty()) return StandingsPreviewPayload("Season $latestSeason", emptyList(), emptyList())

    val sorted = if (seasonRows.all { it.rank != null }) {
        seasonRows.sortedBy { it.rank ?: Int.MAX_VALUE }
    } else {
        seasonRows.sortedByDescending { it.total }
    }
    val previewRows = sorted.mapIndexed { index, row ->
        StandingsPreviewRow(rank = row.rank ?: (index + 1), rawPlayer = row.player, points = row.total)
    }
    val topRows = previewRows.take(5)

    if (!selectedPlayer.isNullOrBlank()) {
        val selectedIndex = previewRows.indexOfFirst { matchesPreferredPlayer(it.rawPlayer, selectedPlayer) }
        if (selectedIndex >= 0) {
            return StandingsPreviewPayload("Season $latestSeason", topRows, aroundRowsWindow(previewRows, selectedIndex))
        }
    }

    return StandingsPreviewPayload("Season $latestSeason", topRows, emptyList())
}

private fun parseStatsRows(text: String): List<StatsCsvRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()
    val header = table.first().map(::normalizeHeader)
    val seasonIndex = header.indexOf("season")
    val bankIndex = header.indexOf("banknumber")
    val playerIndex = header.indexOf("player")
    val machineIndex = header.indexOf("machine")
    val scoreIndex = header.indexOf("rawscore")
    val pointsIndex = header.indexOf("points")
    val eventDateIndex = header.indexOf("eventdate")

    if (listOf(seasonIndex, bankIndex, playerIndex, machineIndex, scoreIndex, pointsIndex).any { it < 0 }) {
        return emptyList()
    }

    return table.drop(1).mapIndexedNotNull { idx, row ->
        if (listOf(seasonIndex, bankIndex, playerIndex, machineIndex, scoreIndex, pointsIndex).any { it !in row.indices }) {
            return@mapIndexedNotNull null
        }
        val season = coerceSeason(row[seasonIndex])
        val bank = row[bankIndex].trim().toIntOrNull() ?: 0
        val player = row[playerIndex].trim()
        val machine = row[machineIndex].trim()
        val score = row[scoreIndex].trim().replace(",", "").toDoubleOrNull() ?: 0.0
        val points = row[pointsIndex].trim().replace(",", "").toDoubleOrNull() ?: 0.0
        val eventDate = if (eventDateIndex in row.indices) {
            runCatching { LocalDate.parse(row[eventDateIndex].trim(), DateTimeFormatter.ISO_LOCAL_DATE) }.getOrNull()
        } else {
            null
        }

        if (season <= 0 || bank <= 0 || player.isBlank() || machine.isBlank()) return@mapIndexedNotNull null
        if (score <= 0.0 && points <= 0.0) return@mapIndexedNotNull null

        StatsCsvRow(season, bank, player, machine, score, points, eventDate, idx)
    }
}

private fun parseStandingsRows(text: String): List<StandingCsvRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()
    val header = table.first().map(::normalizeHeader)
    val seasonIndex = header.indexOf("season")
    val playerIndex = header.indexOf("player")
    val totalIndex = header.indexOf("total")
    val rankIndex = header.indexOf("rank")
    if (listOf(seasonIndex, playerIndex, totalIndex).any { it < 0 }) return emptyList()

    return table.drop(1).mapNotNull { row ->
        if (listOf(seasonIndex, playerIndex, totalIndex).any { it !in row.indices }) return@mapNotNull null
        val season = coerceSeason(row[seasonIndex])
        val player = row[playerIndex].trim()
        val total = row[totalIndex].trim().replace(",", "").toDoubleOrNull() ?: 0.0
        val rank = if (rankIndex in row.indices) row[rankIndex].trim().toIntOrNull() else null
        if (season <= 0 || player.isBlank()) return@mapNotNull null
        StandingCsvRow(season, player, total, rank)
    }
}

private fun parseTargetRows(text: String): List<TargetPreviewRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()
    val header = table.first().map(::normalizeHeader)
    val gameIndex = header.indexOf("game")
    val secondIndex = header.indexOf("second_highest_avg")
    val fourthIndex = header.indexOf("fourth_highest_avg")
    val eighthIndex = header.indexOf("eighth_highest_avg")
    if (listOf(gameIndex, secondIndex, fourthIndex, eighthIndex).any { it < 0 }) return emptyList()

    return table.drop(1).mapNotNull { row ->
        if (listOf(gameIndex, secondIndex, fourthIndex, eighthIndex).any { it !in row.indices }) return@mapNotNull null
        val game = row[gameIndex].trim()
        if (game.isBlank()) return@mapNotNull null
        TargetPreviewRow(
            game = game,
            second = row[secondIndex].trim().toLongOrNull() ?: 0L,
            fourth = row[fourthIndex].trim().toLongOrNull() ?: 0L,
            eighth = row[eighthIndex].trim().toLongOrNull() ?: 0L,
            bank = null,
            order = Int.MAX_VALUE,
        )
    }
}

private fun mergeTargetsWithLibrary(
    targetRows: List<TargetPreviewRow>,
    libraryEntries: List<LibraryGameLookupEntry>,
): List<TargetPreviewRow> {
    return targetRows.map { row ->
        val match = LibraryGameLookup.bestMatch(row.game, libraryEntries)
        if (match == null) row else row.copy(bank = match.bank, order = match.order)
    }
}

private fun resolveNextBank(statsRows: List<StatsCsvRow>, availableBanks: Set<Int>, preferredPlayer: String?): Int? {
    val sorted = availableBanks.sorted()
    if (sorted.isEmpty()) return null
    if (statsRows.isEmpty()) return sorted.first()

    val scopedRows = scopedStatsRows(statsRows, preferredPlayer)
    if (scopedRows.isEmpty()) return sorted.first()

    val latestSeason = scopedRows.maxOfOrNull { it.season } ?: return sorted.first()
    val played = scopedRows
        .filter { it.season == latestSeason && it.bank in sorted }
        .map { it.bank }
        .toSet()

    return sorted.firstOrNull { it !in played } ?: sorted.first()
}

private fun scopedStatsRows(rows: List<StatsCsvRow>, preferredPlayer: String?): List<StatsCsvRow> {
    if (preferredPlayer.isNullOrBlank()) return rows
    val selectedRows = rows.filter { matchesPreferredPlayer(it.player, preferredPlayer) }
    return if (selectedRows.isEmpty()) rows else selectedRows
}

private fun normalizeHeader(value: String): String {
    return value.replace("\uFEFF", "").replace("\u0000", "").trim().lowercase(Locale.US)
}

private fun coerceSeason(raw: String): Int {
    val trimmed = raw.trim()
    val digits = trimmed.filter { it.isDigit() }
    return digits.toIntOrNull() ?: trimmed.toIntOrNull() ?: 0
}

private fun normalizeHumanName(raw: String): String {
    val normalized = raw.lowercase(Locale.US)
        .map { ch -> if (ch.isLetterOrDigit() || ch.isWhitespace()) ch else ' ' }
        .joinToString(separator = "")
    return normalized.trim().split(Regex("\\s+")).filter { it.isNotBlank() }.joinToString(" ")
}

internal fun matchesPreferredPlayer(candidate: String, preferred: String): Boolean {
    return normalizeHumanName(candidate) == normalizeHumanName(preferred)
}

private fun aroundRowsWindow(
    rows: List<StandingsPreviewRow>,
    selectedIndex: Int,
    windowSize: Int = 5,
): List<StandingsPreviewRow> {
    if (rows.isEmpty()) return emptyList()
    val clampedIndex = selectedIndex.coerceIn(0, rows.lastIndex)
    val edge = windowSize / 2
    val start = when {
        clampedIndex <= edge -> 0
        clampedIndex >= rows.size - edge - 1 -> maxOf(0, rows.size - windowSize)
        else -> clampedIndex - edge
    }
    val end = minOf(rows.size, start + windowSize)
    return rows.subList(start, end)
}
