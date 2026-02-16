package com.pillyliu.pinballandroid.league

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.shape.RoundedCornerShape
import android.content.res.Configuration
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.FormatListNumbered
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.data.parseCsv
import com.pillyliu.pinballandroid.data.redactPlayerNameForDisplay
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.CardContainer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.text.NumberFormat
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

enum class LeagueDestination(val title: String, val subtitle: String, val icon: ImageVector) {
    Stats("Stats", "Player trends and machine performance", Icons.Outlined.BarChart),
    Standings("Standings", "Season standings and points view", Icons.Outlined.FormatListNumbered),
    Targets("Targets", "Great game, main target, and floor goals", Icons.Outlined.Flag),
}

@Composable
fun LeagueScreen(
    contentPadding: PaddingValues,
    onOpenDestination: (LeagueDestination) -> Unit,
) {
    val previewState by produceState(initialValue = LeaguePreviewState()) {
        value = withContext(Dispatchers.IO) { loadLeaguePreviewState() }
    }

    var targetMetricIndex by rememberSaveable { mutableIntStateOf(0) }
    var showStatsScore by rememberSaveable { mutableStateOf(true) }

    LaunchedEffect(previewState.nextBankTargets) {
        while (true) {
            delay(3500)
            targetMetricIndex = (targetMetricIndex + 1) % 3
        }
    }

    LaunchedEffect(previewState.statsRecentRows) {
        while (true) {
            delay(3000)
            showStatsScore = !showStatsScore
        }
    }

    AppScreen(contentPadding) {
        androidx.compose.foundation.layout.BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            val compactHeight = maxHeight < 730.dp
            val tabletMode = maxWidth >= 600.dp
            val isLandscape = LocalConfiguration.current.orientation == Configuration.ORIENTATION_LANDSCAPE
            val cardGap = if (compactHeight) 8.dp else 10.dp
            val maxRows = if (compactHeight) 4 else 5
            val titleSize = if (tabletMode) 20.sp else 19.sp
            val subtitleSize = if (tabletMode) 16.sp else 15.sp
            val miniLabelSize = if (tabletMode) 15.sp else 14.sp
            val miniHeaderSize = if (tabletMode) 14.sp else 13.sp
            val miniValueSize = if (tabletMode) 15.sp else 14.sp
            val landscapeRowGap = if (compactHeight) 6.dp else 8.dp

            @Composable
            fun DestinationCard(destination: LeagueDestination, modifier: Modifier = Modifier) {
                LeagueCard(
                    destination = destination,
                    modifier = modifier,
                    onClick = { onOpenDestination(destination) },
                    titleSize = titleSize,
                    subtitleSize = subtitleSize,
                ) {
                    when (destination) {
                        LeagueDestination.Stats -> {
                            StatsMiniPreview(
                                rows = previewState.statsRecentRows.take(maxRows),
                                bankLabel = previewState.statsRecentBankLabel,
                                playerLabel = previewState.statsPlayerLabel,
                                showScore = showStatsScore,
                                labelSize = miniLabelSize,
                                headerSize = miniHeaderSize,
                                valueSize = miniValueSize,
                            )
                        }
                        LeagueDestination.Standings -> {
                            StandingsMiniPreview(
                                seasonLabel = previewState.standingsSeasonLabel,
                                rows = previewState.standingsTopRows.take(maxRows),
                                labelSize = miniLabelSize,
                                headerSize = miniHeaderSize,
                                valueSize = miniValueSize,
                            )
                        }
                        LeagueDestination.Targets -> {
                            TargetsMiniPreview(
                                rows = previewState.nextBankTargets.take(maxRows),
                                bankLabel = previewState.nextBankLabel,
                                metricIndex = targetMetricIndex,
                                labelSize = miniLabelSize,
                                headerSize = miniHeaderSize,
                                valueSize = miniValueSize,
                            )
                        }
                    }
                }
            }

            if (isLandscape) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(landscapeRowGap),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(IntrinsicSize.Min),
                        horizontalArrangement = Arrangement.spacedBy(cardGap),
                    ) {
                        DestinationCard(
                            LeagueDestination.Stats,
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight(),
                        )
                        DestinationCard(
                            LeagueDestination.Standings,
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight(),
                        )
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(IntrinsicSize.Min),
                        horizontalArrangement = Arrangement.spacedBy(cardGap),
                    ) {
                        DestinationCard(
                            LeagueDestination.Targets,
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight(),
                        )
                        Spacer(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight(),
                        )
                    }
                }
            } else {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(cardGap),
                ) {
                    DestinationCard(LeagueDestination.Stats, modifier = Modifier.weight(1f))
                    DestinationCard(LeagueDestination.Standings, modifier = Modifier.weight(1f))
                    DestinationCard(LeagueDestination.Targets, modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun LeagueCard(
    destination: LeagueDestination,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
    titleSize: androidx.compose.ui.unit.TextUnit,
    subtitleSize: androidx.compose.ui.unit.TextUnit,
    preview: @Composable () -> Unit,
) {
    CardContainer(
        modifier = Modifier
            .then(modifier)
            .fillMaxWidth()
            .heightIn(min = 0.dp)
            .clickable { onClick() },
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = destination.icon,
                contentDescription = destination.title,
                tint = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = destination.title,
                color = MaterialTheme.colorScheme.onSurface,
                fontWeight = FontWeight.SemiBold,
                fontSize = titleSize,
            )
            Spacer(Modifier.weight(1f))
            Icon(
                imageVector = Icons.Outlined.ChevronRight,
                contentDescription = "Open ${destination.title}",
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Text(
            text = destination.subtitle,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = subtitleSize,
            modifier = Modifier.padding(start = 28.dp),
        )

        Column(modifier = Modifier.padding(start = 28.dp)) {
            preview()
        }
    }
}

@Composable
private fun StatsMiniPreview(
    rows: List<StatsPreviewRow>,
    bankLabel: String,
    playerLabel: String,
    showScore: Boolean,
    labelSize: androidx.compose.ui.unit.TextUnit,
    headerSize: androidx.compose.ui.unit.TextUnit,
    valueSize: androidx.compose.ui.unit.TextUnit,
) {
    val valueColor = if (showScore) Color(0xFF2E8B57) else Color(0xFF3A7BD5)
    val valueColumnWidth = 122.dp
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            bankLabel,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.SemiBold,
            fontSize = labelSize,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (playerLabel.isNotBlank()) {
            Spacer(Modifier.width(8.dp))
            Text(
                playerLabel,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = headerSize,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.End,
                modifier = Modifier.weight(1f),
            )
        }
    }
    Row(modifier = Modifier.fillMaxWidth()) {
        Text("Game", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = headerSize, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.weight(1f))
        Box(modifier = Modifier.width(valueColumnWidth), contentAlignment = Alignment.CenterEnd) {
            Crossfade(
                targetState = showScore,
                animationSpec = tween(durationMillis = 750),
                label = "statsHeader",
            ) { score ->
                Text(
                    text = if (score) "Score" else "Pts",
                    color = valueColor,
                    fontSize = headerSize,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }

    if (rows.isEmpty()) {
        Text("Tap to open full stats", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = valueSize)
        return
    }

    rows.forEach { row ->
        Row(modifier = Modifier.fillMaxWidth()) {
            Text(
                row.machine,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = valueSize,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(8.dp))
            Box(modifier = Modifier.width(valueColumnWidth), contentAlignment = Alignment.CenterEnd) {
                Crossfade(
                    targetState = showScore,
                    animationSpec = tween(durationMillis = 750),
                    label = "statsRow-${row.machine}",
                ) { score ->
                    Text(
                        text = if (score) row.score.toWholeNumber() else row.points.toWholeNumber(),
                        color = valueColor,
                        fontSize = valueSize,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.End,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

@Composable
private fun StandingsMiniPreview(
    seasonLabel: String,
    rows: List<StandingsPreviewRow>,
    labelSize: androidx.compose.ui.unit.TextUnit,
    headerSize: androidx.compose.ui.unit.TextUnit,
    valueSize: androidx.compose.ui.unit.TextUnit,
) {
    Text(seasonLabel, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold, fontSize = labelSize)
    val placeColumnWidth = 34.dp
    val pointsColumnWidth = 84.dp
    val placePlayerGap = 8.dp
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            "#",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = headerSize,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Start,
            modifier = Modifier.width(placeColumnWidth),
        )
        Text(
            "Player",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = headerSize,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Start,
            modifier = Modifier.weight(1f).padding(start = placePlayerGap),
        )
        Text(
            "Pts",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = headerSize,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.End,
            modifier = Modifier.width(pointsColumnWidth),
        )
    }
    if (rows.isEmpty()) {
        Text("No standings preview available yet", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = valueSize)
        return
    }
    rows.forEach { row ->
        val isPodium = row.rank <= 3
        Row(modifier = Modifier.fillMaxWidth()) {
            Text(
                row.rank.toString(),
                color = rankColor(row.rank),
                fontSize = valueSize,
                fontWeight = if (isPodium) FontWeight.SemiBold else FontWeight.Normal,
                modifier = Modifier.width(placeColumnWidth),
                textAlign = TextAlign.Start,
            )
            Text(
                row.player,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = valueSize,
                fontWeight = if (isPodium) FontWeight.SemiBold else FontWeight.Normal,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).padding(start = placePlayerGap),
                textAlign = TextAlign.Start,
            )
            Text(
                row.points.toWholeNumber(),
                color = MaterialTheme.colorScheme.onSurface,
                fontSize = valueSize,
                fontWeight = if (isPodium) FontWeight.SemiBold else FontWeight.Normal,
                textAlign = TextAlign.End,
                modifier = Modifier.width(pointsColumnWidth),
            )
        }
    }
}

@Composable
private fun TargetsMiniPreview(
    rows: List<TargetPreviewRow>,
    bankLabel: String,
    metricIndex: Int,
    labelSize: androidx.compose.ui.unit.TextUnit,
    headerSize: androidx.compose.ui.unit.TextUnit,
    valueSize: androidx.compose.ui.unit.TextUnit,
) {
    val valueColumnWidth = 150.dp
    val metric = remember(metricIndex) {
        when (metricIndex % 3) {
            0 -> TargetMetric.Second
            1 -> TargetMetric.Fourth
            else -> TargetMetric.Eighth
        }
    }
    val metricColor = when (metric) {
        TargetMetric.Second -> Color(0xFF2E8B57)
        TargetMetric.Fourth -> Color(0xFF3A7BD5)
        TargetMetric.Eighth -> Color(0xFF7D8597)
    }

    Text(bankLabel, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold, fontSize = labelSize)
    Row(modifier = Modifier.fillMaxWidth()) {
        Text("Game", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = headerSize, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.weight(1f))
        Box(modifier = Modifier.width(valueColumnWidth), contentAlignment = Alignment.CenterEnd) {
            Crossfade(targetState = metric, animationSpec = tween(750), label = "targetsHeader") { current ->
                Text(
                    "${current.label} highest",
                    color = metricColor,
                    fontSize = headerSize,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }

    if (rows.isEmpty()) {
        Text("No target preview available yet", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = valueSize)
        return
    }

    rows.take(5).forEach { row ->
        Row(modifier = Modifier.fillMaxWidth()) {
            Text(
                row.game,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = valueSize,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(8.dp))
            Box(modifier = Modifier.width(valueColumnWidth), contentAlignment = Alignment.CenterEnd) {
                Crossfade(targetState = metric, animationSpec = tween(750), label = "targetsRow-${row.game}") { current ->
                    Text(
                        current.value(row).toGroupNumber(),
                        color = metricColor,
                        fontSize = valueSize,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.End,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

private enum class TargetMetric(val label: String) {
    Second("2nd"),
    Fourth("4th"),
    Eighth("8th"),
    ;

    fun value(row: TargetPreviewRow): Long = when (this) {
        Second -> row.second
        Fourth -> row.fourth
        Eighth -> row.eighth
    }
}

private data class LeaguePreviewState(
    val nextBankTargets: List<TargetPreviewRow> = emptyList(),
    val nextBankLabel: String = "Next Bank",
    val standingsSeasonLabel: String = "Season",
    val standingsTopRows: List<StandingsPreviewRow> = emptyList(),
    val statsRecentRows: List<StatsPreviewRow> = emptyList(),
    val statsRecentBankLabel: String = "Most Recent Bank",
    val statsPlayerLabel: String = "",
)

private data class TargetPreviewRow(
    val game: String,
    val second: Long,
    val fourth: Long,
    val eighth: Long,
    val bank: Int?,
    val order: Int,
)

private data class StandingsPreviewRow(
    val rank: Int,
    val player: String,
    val points: Double,
)

private data class StatsPreviewRow(
    val machine: String,
    val score: Double,
    val points: Double,
)

private data class StatsCsvRow(
    val season: Int,
    val bank: Int,
    val player: String,
    val machine: String,
    val score: Double,
    val points: Double,
    val eventDate: LocalDate?,
    val sourceOrder: Int,
)

private data class StandingCsvRow(
    val season: Int,
    val player: String,
    val total: Double,
    val rank: Int?,
)

private suspend fun loadLeaguePreviewState(): LeaguePreviewState {
    return try {
        val targetsCsv = PinballDataCache.passthroughOrCachedText("https://pillyliu.com/pinball/data/LPL_Targets.csv").text.orEmpty()
        val standingsCsv = PinballDataCache.passthroughOrCachedText("https://pillyliu.com/pinball/data/LPL_Standings.csv", allowMissing = true).text.orEmpty()
        val statsCsv = PinballDataCache.passthroughOrCachedText("https://pillyliu.com/pinball/data/LPL_Stats.csv", allowMissing = true).text.orEmpty()
        val libraryJson = PinballDataCache.passthroughOrCachedText("https://pillyliu.com/pinball/data/pinball_library.json", allowMissing = true).text

        val statsRows = parseStatsRows(statsCsv)
        val targets = mergeTargetsWithLibrary(parseTargetRows(targetsCsv), libraryJson)
        val standingsRows = parseStandingsRows(standingsCsv)

        val availableBanks = targets.mapNotNull { it.bank }.toSet()
        val nextBank = resolveNextBank(statsRows, availableBanks)
        val nextTargets = if (nextBank != null) {
            targets.filter { it.bank == nextBank }
                .sortedWith(compareBy<TargetPreviewRow> { it.order }.thenBy { it.game.lowercase(Locale.US) })
                .take(5)
        } else {
            targets.take(5)
        }

        val (seasonLabel, topRows) = buildStandingsPreview(standingsRows)
        val statsPreview = buildStatsPreview(statsRows)

        LeaguePreviewState(
            nextBankTargets = nextTargets,
            nextBankLabel = if (nextBank != null) "Next Bank • B$nextBank" else "Next Bank",
            standingsSeasonLabel = seasonLabel,
            standingsTopRows = topRows,
            statsRecentRows = statsPreview.rows,
            statsRecentBankLabel = statsPreview.bankLabel,
            statsPlayerLabel = statsPreview.playerLabel,
        )
    } catch (_: Throwable) {
        LeaguePreviewState()
    }
}

private data class StatsPreviewPayload(
    val rows: List<StatsPreviewRow>,
    val bankLabel: String,
    val playerLabel: String,
)

private fun buildStatsPreview(rows: List<StatsCsvRow>): StatsPreviewPayload {
    if (rows.isEmpty()) return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")

    val latest = rows.maxByOrNull { latestSortValue(it) } ?: return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")
    val selectedPlayer = latest.player
    val selected = rows.filter { normalizeHumanName(it.player) == normalizeHumanName(selectedPlayer) }
    if (selected.isEmpty()) return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")

    val grouped = selected.groupBy { "${it.season}-${it.bank}" }
    val recentKey = grouped.keys.maxByOrNull { key ->
        grouped[key]?.maxOfOrNull(::latestSortValue) ?: 0L
    } ?: return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")
    val sample = grouped[recentKey]?.firstOrNull() ?: return StatsPreviewPayload(emptyList(), "Most Recent Bank", "")

    val previewRows = grouped[recentKey]
        .orEmpty()
        .sortedBy { it.sourceOrder }
        .take(5)
        .map { StatsPreviewRow(machine = it.machine, score = it.score, points = it.points) }

    return StatsPreviewPayload(
        rows = previewRows,
        bankLabel = "Most Recent • S${sample.season} B${sample.bank}",
        playerLabel = redactPlayerNameForDisplay(sample.player),
    )
}

private fun latestSortValue(row: StatsCsvRow): Long {
    val datePart = row.eventDate?.toEpochDay() ?: 0L
    return (datePart * 1_000_000L) + (row.season * 100L + row.bank)
}

private fun buildStandingsPreview(rows: List<StandingCsvRow>): Pair<String, List<StandingsPreviewRow>> {
    if (rows.isEmpty()) return "Season" to emptyList()
    val latestSeason = rows.maxOfOrNull { it.season } ?: return "Season" to emptyList()
    val seasonRows = rows.filter { it.season == latestSeason }
    if (seasonRows.isEmpty()) return "Season $latestSeason" to emptyList()

    val hasRanks = seasonRows.all { it.rank != null }
    val sorted = if (hasRanks) {
        seasonRows.sortedBy { it.rank ?: Int.MAX_VALUE }
    } else {
        seasonRows.sortedByDescending { it.total }
    }
    val top = sorted.take(5).mapIndexed { index, row ->
        StandingsPreviewRow(
            rank = row.rank ?: (index + 1),
            player = redactPlayerNameForDisplay(row.player),
            points = row.total,
        )
    }
    return "Season $latestSeason" to top
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

private data class LibraryLookup(
    val normalizedName: String,
    val bank: Int?,
    val order: Int,
)

private fun mergeTargetsWithLibrary(targetRows: List<TargetPreviewRow>, libraryJson: String?): List<TargetPreviewRow> {
    if (libraryJson.isNullOrBlank()) return targetRows
    val lookups = try {
        val array = JSONArray(libraryJson)
        (0 until array.length()).map { index ->
            val item = array.getJSONObject(index)
            val group = item.optInt("group").takeIf { it > 0 }
            val pos = item.optInt("pos").takeIf { it > 0 }
            val weightedOrder = if (group != null && pos != null) (group * 1000) + pos else 100_000 + index
            LibraryLookup(
                normalizedName = normalizeMachineName(item.optString("name")),
                bank = item.optInt("bank").takeIf { it > 0 },
                order = weightedOrder,
            )
        }
    } catch (_: Throwable) {
        return targetRows
    }

    return targetRows.map { row ->
        val normalizedTarget = normalizeMachineName(row.game)
        val aliases = machineAliases[normalizedTarget].orEmpty()
        val keys = listOf(normalizedTarget) + aliases

        val match = lookups.firstOrNull { keys.contains(it.normalizedName) } ?: lookups.firstOrNull { entry ->
            keys.any { key -> entry.normalizedName.contains(key) || key.contains(entry.normalizedName) }
        }

        if (match == null) row else row.copy(bank = match.bank, order = match.order)
    }
}

private fun resolveNextBank(statsRows: List<StatsCsvRow>, availableBanks: Set<Int>): Int? {
    val sorted = availableBanks.sorted()
    if (sorted.isEmpty()) return null
    if (statsRows.isEmpty()) return sorted.first()

    val latestSeason = statsRows.maxOfOrNull { it.season } ?: return sorted.first()
    val played = statsRows
        .filter { it.season == latestSeason && it.bank in sorted }
        .map { it.bank }
        .toSet()

    return sorted.firstOrNull { it !in played } ?: sorted.first()
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
    return raw.lowercase(Locale.US).trim().split(Regex("\\s+")).filter { it.isNotBlank() }.joinToString(" ")
}

private fun normalizeMachineName(raw: String): String {
    return raw.lowercase(Locale.US).replace("&", " and ").filter { it.isLetterOrDigit() }
}

private val machineAliases = mapOf(
    "tmnt" to listOf("teenagemutantninjaturtles"),
    "thegetaway" to listOf("thegetawayhighspeedii"),
    "starwars2017" to listOf("starwars"),
    "jurassicparkstern2019" to listOf("jurassicpark", "jurassicpark2019"),
    "attackfrommars" to listOf("attackfrommarsremake"),
    "dungeonsanddragons" to listOf("dungeonsdragons"),
)

@Composable
private fun rankColor(rank: Int): Color = when (rank) {
    1 -> Color(0xFFFFD83D)
    2 -> Color(0xFF98A3B3)
    3 -> Color(0xFFC1845B)
    else -> MaterialTheme.colorScheme.onSurfaceVariant
}

private fun Long.toGroupNumber(): String = NumberFormat.getIntegerInstance().format(this)

private fun Double.toWholeNumber(): String = NumberFormat.getIntegerInstance().format(this.toLong())
