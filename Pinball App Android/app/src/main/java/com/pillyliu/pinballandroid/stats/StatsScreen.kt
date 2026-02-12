package com.pillyliu.pinballandroid.stats

import android.content.res.Configuration
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.data.parseCsv
import com.pillyliu.pinballandroid.data.redactPlayerNameForDisplay
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.CardContainer
import com.pillyliu.pinballandroid.ui.EmptyLabel
import com.pillyliu.pinballandroid.ui.ControlBg
import com.pillyliu.pinballandroid.ui.ControlBorder
import com.pillyliu.pinballandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinballandroid.ui.DropdownOption
import com.pillyliu.pinballandroid.ui.FixedWidthTableCell
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.math.pow
import kotlin.math.sqrt

private const val CSV_URL = "https://pillyliu.com/pinball/data/LPL_Stats.csv"

private data class ScoreRow(
    val id: Int,
    val season: String,
    val bankNumber: Int,
    val player: String,
    val machine: String,
    val rawScore: Double,
    val points: Double,
)

private data class StatResult(
    val count: Int,
    val low: Double?,
    val lowPlayer: String?,
    val high: Double?,
    val highPlayer: String?,
    val mean: Double?,
    val median: Double?,
    val std: Double?,
)

private data class StatsTableWidths(
    val season: Int,
    val player: Int,
    val bank: Int,
    val machine: Int,
    val score: Int,
    val points: Int,
)

@Composable
fun StatsScreen(contentPadding: PaddingValues) {
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    var rows by remember { mutableStateOf(emptyList<ScoreRow>()) }
    var error by remember { mutableStateOf<String?>(null) }
    var dataUpdatedAtMs by remember { mutableStateOf<Long?>(null) }
    var isRefreshing by remember { mutableStateOf(false) }
    var hasNewerData by remember { mutableStateOf(false) }
    var initialLoadComplete by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val pulseTransition = rememberInfiniteTransition(label = "statsRefreshPulse")
    val pulseAlpha by pulseTransition.animateFloat(
        initialValue = 1f,
        targetValue = 0.35f,
        animationSpec = infiniteRepeatable(animation = tween(650), repeatMode = RepeatMode.Reverse),
        label = "statsRefreshPulseAlpha",
    )

    var season by rememberSaveable { mutableStateOf("") }
    var player by rememberSaveable { mutableStateOf("") }
    var bankNumber by rememberSaveable { mutableStateOf<Int?>(null) }
    var machine by rememberSaveable { mutableStateOf("") }

    fun refresh(force: Boolean) {
        if (isRefreshing) return
        scope.launch {
            isRefreshing = true
            try {
                val cached = if (force) {
                    PinballDataCache.forceRefreshText(CSV_URL)
                } else {
                    PinballDataCache.passthroughOrCachedText(CSV_URL)
                }
                rows = withContext(Dispatchers.IO) {
                    parseScoreRows(cached.text.orEmpty())
                }
                dataUpdatedAtMs = cached.updatedAtMs
                if (rows.isNotEmpty()) {
                    val seasonsNow = rows.map { it.season }.toSet().sortedWith(::compareSeasons)
                    if (season.isBlank() || season !in seasonsNow) {
                        season = seasonsNow.lastOrNull().orEmpty()
                        player = ""
                        bankNumber = null
                        machine = ""
                    }

                    val playersNow = rows
                        .filter { season.isEmpty() || it.season == season }
                        .map { it.player }
                        .toSet()
                    if (player.isNotEmpty() && player !in playersNow) {
                        player = ""
                        bankNumber = null
                        machine = ""
                    }

                    val banksNow = rows
                        .filter { (season.isEmpty() || it.season == season) && (player.isEmpty() || it.player == player) }
                        .map { it.bankNumber }
                        .toSet()
                    if (bankNumber != null && bankNumber !in banksNow) {
                        bankNumber = null
                        machine = ""
                    }

                    val machinesNow = rows
                        .filter {
                            (season.isEmpty() || it.season == season) &&
                                (player.isEmpty() || it.player == player) &&
                                (bankNumber == null || it.bankNumber == bankNumber)
                        }
                        .map { it.machine }
                        .filter { it.isNotBlank() }
                        .toSet()
                    if (machine.isNotEmpty() && machine !in machinesNow) {
                        machine = ""
                    }
                }
                error = null
                if (dataUpdatedAtMs != null) {
                    scope.launch {
                        val remoteHasNewer = PinballDataCache.hasRemoteUpdate(CSV_URL)
                        hasNewerData = remoteHasNewer
                    }
                } else {
                    hasNewerData = false
                }
            } catch (t: Throwable) {
                error = t.message ?: "Failed to load stats CSV"
            } finally {
                isRefreshing = false
                initialLoadComplete = true
            }
        }
    }

    LaunchedEffect(Unit) {
        refresh(false)
    }

    val seasons = rows.map { it.season }.toSet().sortedWith(::compareSeasons)

    LaunchedEffect(seasons) {
        if (seasons.isEmpty()) return@LaunchedEffect
        if (season.isBlank() || season !in seasons) {
            season = seasons.last()
            player = ""
            bankNumber = null
            machine = ""
        }
    }
    val players = rows.filter { season.isEmpty() || it.season == season }.map { it.player }.toSet().sorted()
    val banks = rows.filter { (season.isEmpty() || it.season == season) && (player.isEmpty() || it.player == player) }
        .map { it.bankNumber }
        .toSet()
        .sorted()
    val machines = rows.filter {
        (season.isEmpty() || it.season == season) &&
            (player.isEmpty() || it.player == player) &&
            (bankNumber == null || it.bankNumber == bankNumber)
    }.map { it.machine }.filter { it.isNotBlank() }.toSet().sorted()

    val filtered = rows.filter {
        (season.isEmpty() || it.season == season) &&
            (player.isEmpty() || it.player == player) &&
            (bankNumber == null || it.bankNumber == bankNumber) &&
            (machine.isEmpty() || it.machine == machine)
    }

    val bankStats = computeStats(
        rows.filter {
            season.isNotEmpty() && it.season == season &&
                bankNumber != null && it.bankNumber == bankNumber &&
                machine.isNotEmpty() && it.machine == machine
        },
        true,
    )
    val historyStats = computeStats(rows.filter { machine.isNotEmpty() && it.machine == machine }, false)

    AppScreen(contentPadding) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val seasonOptions = listOf(DropdownOption("", "S: All")) + seasons.map { DropdownOption(it, abbrSeason(it)) }
            val playerOptions = listOf(DropdownOption("", "Player: All")) + players.map { DropdownOption(it, it) }
            val bankOptions = listOf(DropdownOption("", "B: All")) + banks.map { DropdownOption(it.toString(), "B$it") }
            val machineOptions = listOf(DropdownOption("", "Machine: All")) + machines.map { DropdownOption(it, it) }

            if (isLandscape) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    AnchoredDropdownFilter(
                        selectedText = seasonDisplayText(season),
                        options = seasonOptions,
                        modifier = Modifier.weight(1f),
                        onSelect = {
                        season = it
                        player = ""
                        bankNumber = null
                        machine = ""
                    },
                    )
                    AnchoredDropdownFilter(
                        selectedText = playerDisplayText(player),
                        options = playerOptions,
                        modifier = Modifier.weight(1f),
                        onSelect = {
                        player = it
                        bankNumber = null
                        machine = ""
                    },
                    )
                    AnchoredDropdownFilter(
                        selectedText = bankDisplayText(bankNumber),
                        options = bankOptions,
                        modifier = Modifier.weight(1f),
                        onSelect = {
                        bankNumber = it.toIntOrNull()
                        machine = ""
                    },
                    )
                    AnchoredDropdownFilter(
                        selectedText = machineDisplayText(machine),
                        options = machineOptions,
                        modifier = Modifier.weight(1f),
                        onSelect = {
                        machine = it
                    },
                    )
                }
            } else {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        AnchoredDropdownFilter(
                            selectedText = seasonDisplayText(season),
                            options = seasonOptions,
                            modifier = Modifier.weight(3f),
                            onSelect = {
                            season = it
                            player = ""
                            bankNumber = null
                            machine = ""
                        },
                        )
                        AnchoredDropdownFilter(
                            selectedText = playerDisplayText(player),
                            options = playerOptions,
                            modifier = Modifier.weight(7f),
                            onSelect = {
                            player = it
                            bankNumber = null
                            machine = ""
                        },
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        AnchoredDropdownFilter(
                            selectedText = bankDisplayText(bankNumber),
                            options = bankOptions,
                            modifier = Modifier.weight(3f),
                            onSelect = {
                            bankNumber = it.toIntOrNull()
                            machine = ""
                        },
                        )
                        AnchoredDropdownFilter(
                            selectedText = machineDisplayText(machine),
                            options = machineOptions,
                            modifier = Modifier.weight(7f),
                            onSelect = {
                            machine = it
                        },
                        )
                    }
                }
            }

            error?.let { Text(text = it, color = Color.Red) }
            dataUpdatedAtMs?.let { updatedAt ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "Data updated at ${formatUpdatedAt(updatedAt)}",
                        color = Color(0xFF9CA3AF),
                        fontSize = 11.sp,
                    )
                    if (isRefreshing) {
                        Spacer(Modifier.width(6.dp))
                        CircularProgressIndicator(
                            modifier = Modifier.size(10.dp),
                            strokeWidth = 1.5.dp,
                            color = Color(0xFF9CA3AF),
                        )
                    } else {
                        IconButton(
                            onClick = { refresh(true) },
                            modifier = Modifier.size(20.dp),
                        ) {
                            Icon(
                                imageVector = Icons.Filled.Refresh,
                                contentDescription = "Refresh data",
                                tint = Color(0xFF9CA3AF).copy(alpha = if (hasNewerData) pulseAlpha else 1f),
                                modifier = Modifier.size(12.dp),
                            )
                        }
                    }
                }
            }

            if (isLandscape) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxWidth().weight(1f, fill = true),
                ) {
                    CardContainer(modifier = Modifier.weight(0.6f, fill = true)) {
                        StatsTable(
                            filtered = filtered,
                            isRefreshing = isRefreshing,
                            initialLoadComplete = initialLoadComplete,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                    CardContainer(modifier = Modifier.weight(0.4f, fill = true)) {
                        MachineStatsPanel(
                            machine = machine,
                            bankNumber = bankNumber,
                            season = season,
                            bankStats = bankStats,
                            historyStats = historyStats,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                }
            } else {
                CardContainer(modifier = Modifier.fillMaxWidth().weight(1f, fill = true)) {
                    StatsTable(
                        filtered = filtered,
                        isRefreshing = isRefreshing,
                        initialLoadComplete = initialLoadComplete,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
                CardContainer(modifier = Modifier.fillMaxWidth()) {
                    MachineStatsPanel(
                        machine = machine,
                        bankNumber = bankNumber,
                        season = season,
                        bankStats = bankStats,
                        historyStats = historyStats,
                    )
                }
            }
        }
    }
}

@Composable
private fun StatsTable(
    filtered: List<ScoreRow>,
    isRefreshing: Boolean,
    initialLoadComplete: Boolean,
    modifier: Modifier = Modifier,
) {
    val hState = rememberScrollState()
    BoxWithConstraints(modifier = modifier) {
        val baseTableWidth = 614f
        val scale = (maxWidth.value / baseTableWidth).coerceIn(1f, 1.8f)
        val widths = StatsTableWidths(
            season = (72 * scale).toInt(),
            player = (130 * scale).toInt(),
            bank = (52 * scale).toInt(),
            machine = (170 * scale).toInt(),
            score = (120 * scale).toInt(),
            points = (70 * scale).toInt(),
        )
        val tableWidth = widths.season + widths.player + widths.bank + widths.machine + widths.score + widths.points

        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(hState),
            horizontalArrangement = Arrangement.Center,
        ) {
            Column(modifier = Modifier.width(tableWidth.dp)) {
                HeaderRow(widths)
                if (!initialLoadComplete && isRefreshing) {
                    EmptyLabel("Loading data…")
                } else if (filtered.isEmpty()) {
                    EmptyLabel("No rows - check filters or data source.")
                } else {
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        itemsIndexed(filtered, key = { _, row -> row.id }) { _, row ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(if (row.id % 2 == 0) Color(0xFF0A0A0A) else Color(0xFF171717))
                                    .padding(vertical = 6.dp),
                            ) {
                                FixedWidthTableCell(row.season, widths.season)
                                FixedWidthTableCell(redactPlayerNameForDisplay(row.player), widths.player)
                                FixedWidthTableCell(row.bankNumber.toString(), widths.bank)
                                FixedWidthTableCell(row.machine, widths.machine)
                                FixedWidthTableCell(formatInt(row.rawScore), widths.score)
                                FixedWidthTableCell(formatInt(row.points), widths.points)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MachineStatsPanel(
    machine: String,
    bankNumber: Int?,
    season: String,
    bankStats: StatResult,
    historyStats: StatResult,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        if (machine.isEmpty()) {
            Text("Select a machine to see machine stats", color = Color(0xFFD0D0D0), fontSize = 12.sp)
            return@Column
        }
        MachineStatsTable(
            selectedLabel = selectedBankLabel(season, bankNumber),
            selectedStats = bankStats,
            allSeasonsStats = historyStats,
        )
    }
}

@Composable
private fun MachineStatsTable(selectedLabel: String, selectedStats: StatResult, allSeasonsStats: StatResult) {
    val rowLabels = listOf("High", "Low", "Avg", "Med", "Std", "Count")
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 0.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            HeaderCell("", modifier = Modifier.weight(0.7f))
            HeaderCell(selectedLabel, modifier = Modifier.weight(1.65f))
            HeaderCell("All Seasons", modifier = Modifier.weight(1.65f))
        }
        rowLabels.forEachIndexed { idx, label ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 0.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                StatLabelCell(label, modifier = Modifier.weight(0.7f))
                StatValueCell(
                    label = label,
                    stats = selectedStats,
                    isAllSeasons = false,
                    modifier = Modifier.weight(1.65f),
                )
                StatValueCell(
                    label = label,
                    stats = allSeasonsStats,
                    isAllSeasons = true,
                    modifier = Modifier.weight(1.65f),
                )
            }
        }
    }
}

@Composable
private fun HeaderCell(text: String, modifier: Modifier, alignRight: Boolean = false) {
    Text(
        text = text,
        modifier = modifier,
        color = Color(0xFFBDBDBD),
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        maxLines = 1,
        textAlign = if (alignRight) TextAlign.End else TextAlign.Start,
    )
}

@Composable
private fun StatLabelCell(text: String, modifier: Modifier) {
    Text(
        text = text,
        modifier = modifier,
        color = Color(0xFFD7D7D7),
        fontSize = 12.sp,
        fontWeight = FontWeight.Medium,
        maxLines = 1,
    )
}

@Composable
private fun StatValueCell(label: String, stats: StatResult, isAllSeasons: Boolean, modifier: Modifier) {
    val valueColor = when (label) {
        "High" -> Color(0xFF6EE7B7)
        "Low" -> Color(0xFFFCA5A5)
        "Avg", "Med" -> Color(0xFF7DD3FC)
        else -> Color(0xFFE5E5E5)
    }
    val value = when (label) {
        "High" -> formatInt(stats.high)
        "Low" -> formatInt(stats.low)
        "Avg" -> formatInt(stats.mean)
        "Med" -> formatInt(stats.median)
        "Std" -> formatInt(stats.std)
        "Count" -> if (stats.count > 0) stats.count.toString() else "-"
        else -> "-"
    }
    val player = when (label) {
        "High" -> stats.highPlayer
        "Low" -> stats.lowPlayer
        else -> null
    }

    Column(modifier = modifier) {
        Text(
            text = value,
            color = valueColor,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Start,
            modifier = Modifier.fillMaxWidth(),
            maxLines = 1,
        )
        if (label == "High" || label == "Low") {
            val playerText = if (player.isNullOrBlank()) "-" else if (isAllSeasons) player else player.substringBefore(" (S")
            Text(
                text = redactPlayerNameForDisplay(playerText),
                color = Color(0xFF737373),
                fontSize = 9.sp,
                textAlign = TextAlign.Start,
                lineHeight = 9.sp,
                modifier = Modifier.fillMaxWidth().padding(top = 0.dp),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

private fun selectedBankLabel(season: String, bankNumber: Int?): String {
    val seasonLabel = if (season.isBlank()) "S?" else abbrSeason(season)
    val bankLabel = bankNumber?.let { "B$it" } ?: "B?"
    return "$seasonLabel $bankLabel"
}

private fun seasonDisplayText(season: String): String = if (season.isBlank()) "S: All" else abbrSeason(season)
private fun bankDisplayText(bankNumber: Int?): String = bankNumber?.let { "B$it" } ?: "B: All"
private fun playerDisplayText(player: String): String = if (player.isBlank()) "Player: All" else redactPlayerNameForDisplay(player)
private fun machineDisplayText(machine: String): String = if (machine.isBlank()) "Machine: All" else machine

@Composable
private fun HeaderRow(widths: StatsTableWidths) {
    Row {
        FixedWidthTableCell(text = "Season", width = widths.season, bold = true, color = Color(0xFFCFCFCF))
        FixedWidthTableCell(text = "Player", width = widths.player, bold = true, color = Color(0xFFCFCFCF))
        FixedWidthTableCell(text = "Bank", width = widths.bank, bold = true, color = Color(0xFFCFCFCF))
        FixedWidthTableCell(text = "Machine", width = widths.machine, bold = true, color = Color(0xFFCFCFCF))
        FixedWidthTableCell(text = "Score", width = widths.score, bold = true, color = Color(0xFFCFCFCF))
        FixedWidthTableCell(text = "Points", width = widths.points, bold = true, color = Color(0xFFCFCFCF))
    }
}

private fun parseScoreRows(text: String): List<ScoreRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()
    val headers = table.first().map { it.trim() }

    fun idx(name: String): Int = headers.indexOfFirst { it.equals(name, ignoreCase = true) }

    val seasonIdx = idx("Season")
    val bankNumberIdx = idx("BankNumber")
    val playerIdx = idx("Player")
    val machineIdx = idx("Machine")
    val rawScoreIdx = idx("RawScore")
    val pointsIdx = idx("Points")

    if (listOf(seasonIdx, bankNumberIdx, playerIdx, machineIdx, rawScoreIdx, pointsIdx).any { it < 0 }) return emptyList()

    return table.drop(1).mapIndexedNotNull { offset, row ->
        if (row.size != headers.size) return@mapIndexedNotNull null
        ScoreRow(
            id = offset,
            season = normalizeSeason(row[seasonIdx]),
            bankNumber = row[bankNumberIdx].trim().toIntOrNull() ?: 0,
            player = row[playerIdx].trim(),
            machine = row[machineIdx].trim(),
            rawScore = row[rawScoreIdx].trim().toDoubleOrNull() ?: 0.0,
            points = row[pointsIdx].trim().toDoubleOrNull() ?: 0.0,
        )
    }
}

private fun normalizeSeason(raw: String): String {
    val trimmed = raw.trim()
    val digits = trimmed.filter { it.isDigit() }
    return if (digits.isNotEmpty()) digits else trimmed
}

private fun compareSeasons(left: String, right: String): Int {
    val leftNumber = left.toLongOrNull()
    val rightNumber = right.toLongOrNull()
    return when {
        leftNumber != null && rightNumber != null -> leftNumber.compareTo(rightNumber)
        else -> left.compareTo(right)
    }
}

private fun computeStats(scope: List<ScoreRow>, isBankScope: Boolean): StatResult {
    val values = scope.map { it.rawScore }.filter { it.isFinite() && it > 0 }
    if (values.isEmpty()) return StatResult(0, null, null, null, null, null, null, null)

    val sorted = values.sorted()
    val count = values.size
    val low = sorted.first()
    val high = sorted.last()
    val mean = values.sum() / count
    val median = if (count % 2 == 0) (sorted[count / 2 - 1] + sorted[count / 2]) / 2 else sorted[(count - 1) / 2]
    val variance = values.sumOf { (it - mean).pow(2) } / count
    val std = sqrt(variance)

    val lowRow = scope.firstOrNull { it.rawScore == low }
    val highRow = scope.firstOrNull { it.rawScore == high }

    fun label(row: ScoreRow): String =
        if (isBankScope) redactPlayerNameForDisplay(row.player) else "${redactPlayerNameForDisplay(row.player)} (${abbrSeason(row.season)})"

    return StatResult(
        count = count,
        low = low,
        lowPlayer = lowRow?.let(::label),
        high = high,
        highPlayer = highRow?.let(::label),
        mean = mean,
        median = median,
        std = std,
    )
}

private fun abbrSeason(season: String): String {
    val digits = season.filter { it.isDigit() }
    return if (digits.isNotEmpty()) "S$digits" else season
}

private fun formatInt(value: Double?): String {
    if (value == null || !value.isFinite()) return "-"
    return NumberFormat.getIntegerInstance().format(value.toLong())
}

private fun formatUpdatedAt(epochMs: Long): String {
    return SimpleDateFormat("MMM d, h:mm a", Locale.getDefault()).format(Date(epochMs))
}
