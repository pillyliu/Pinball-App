package com.pillyliu.pinballandroid.stats

import android.content.res.Configuration
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
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
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.CardContainer
import com.pillyliu.pinballandroid.ui.EmptyLabel
import com.pillyliu.pinballandroid.ui.Border
import com.pillyliu.pinballandroid.ui.CardBg
import java.text.NumberFormat
import kotlinx.coroutines.Dispatchers
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

@Composable
fun StatsScreen(contentPadding: PaddingValues) {
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    var rows by remember { mutableStateOf(emptyList<ScoreRow>()) }
    var error by remember { mutableStateOf<String?>(null) }

    var season by rememberSaveable { mutableStateOf("") }
    var player by rememberSaveable { mutableStateOf("") }
    var bankNumber by rememberSaveable { mutableStateOf<Int?>(null) }
    var machine by rememberSaveable { mutableStateOf("") }

    LaunchedEffect(Unit) {
        try {
            val cached = PinballDataCache.passthroughOrCachedText(CSV_URL)
            rows = withContext(Dispatchers.IO) {
                parseScoreRows(cached.text.orEmpty())
            }
            error = null
        } catch (t: Throwable) {
            error = t.message ?: "Failed to load stats CSV"
        }
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
            modifier = Modifier.verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            CompactFilterCard {
                BoxWithConstraints {
                    val menuWidth = (maxWidth - 8.dp) / 2

                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilterMenu(
                                "Season",
                                season.ifEmpty { "All" },
                                listOf("All") + seasons,
                                modifier = Modifier.width(menuWidth),
                            ) {
                                season = if (it == "All") "" else it
                                player = ""
                                bankNumber = null
                                machine = ""
                            }
                            FilterMenu(
                                "Player",
                                player.ifEmpty { "All" },
                                listOf("All") + players,
                                modifier = Modifier.width(menuWidth),
                            ) {
                                player = if (it == "All") "" else it
                                bankNumber = null
                                machine = ""
                            }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilterMenu(
                                "Bank",
                                bankNumber?.toString() ?: "All",
                                listOf("All") + banks.map { it.toString() },
                                modifier = Modifier.width(menuWidth),
                            ) {
                                bankNumber = if (it == "All") null else it.toIntOrNull()
                                machine = ""
                            }
                            FilterMenu(
                                "Machine",
                                machine.ifEmpty { "All" },
                                listOf("All") + machines,
                                modifier = Modifier.width(menuWidth),
                            ) {
                                machine = if (it == "All") "" else it
                            }
                        }
                    }
                }
            }

            error?.let { Text(text = it, color = Color.Red) }

            if (isLandscape) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                    CardContainer(modifier = Modifier.weight(0.6f, fill = true)) {
                        StatsTable(filtered)
                    }
                    CardContainer(modifier = Modifier.weight(0.4f, fill = true)) {
                        MachineStatsPanel(machine, bankNumber, season, bankStats, historyStats)
                    }
                }
            } else {
                CardContainer {
                    StatsTable(filtered)
                }
                CardContainer {
                    MachineStatsPanel(machine, bankNumber, season, bankStats, historyStats)
                }
            }
        }
    }
}

@Composable
private fun StatsTable(filtered: List<ScoreRow>) {
    val hState = rememberScrollState()
    Row(modifier = Modifier.horizontalScroll(hState)) {
        Column {
            HeaderRow(listOf("Season", "Player", "Bank", "Machine", "Score", "Points"))
            if (filtered.isEmpty()) {
                EmptyLabel("No rows - check filters or data source.")
            } else {
                LazyColumn(modifier = Modifier.heightIn(max = 380.dp)) {
                    itemsIndexed(filtered, key = { _, row -> row.id }) { _, row ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(if (row.id % 2 == 0) Color(0xFF121212) else Color(0xFF222222))
                                .padding(vertical = 4.dp),
                        ) {
                            TableCell(row.season, 72)
                            TableCell(row.player, 130)
                            TableCell(row.bankNumber.toString(), 52)
                            TableCell(row.machine, 170)
                            TableCell(formatInt(row.rawScore), 120)
                            TableCell(formatInt(row.points), 70)
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
) {
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Text("Machine Stats", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        if (machine.isEmpty() || bankNumber == null || season.isEmpty()) {
            Text("Select season, bank, and machine to view detailed stats.", color = Color(0xFFD0D0D0), fontSize = 12.sp)
        }
        StatSection("Selected Bank", "$season - Bank ${bankNumber ?: "?"}", bankStats)
        StatSection("Historical (All Seasons)", "All Seasons", historyStats)
    }
}

@Composable
private fun StatSection(title: String, label: String, stats: StatResult) {
    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Text(title, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        if (stats.count == 0) {
            Text("No data - select filters.", color = Color(0xFFBDBDBD), fontSize = 12.sp)
            return
        }
        Text(label, color = Color(0xFFBABABA), fontSize = 14.sp)
        StatRow("High", formatInt(stats.high), stats.highPlayer, Color(0xFF8DE18A))
        StatRow("Low", formatInt(stats.low), stats.lowPlayer, Color(0xFFFF9292))
        StatRow("Mean", formatInt(stats.mean), null)
        StatRow("Median", formatInt(stats.median), null)
        StatRow("Std Dev", formatInt(stats.std), null)
        StatRow("Count", stats.count.toString(), null)
    }
}

@Composable
private fun StatRow(label: String, value: String, subtitle: String?, valueColor: Color = Color.White) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 0.5.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, color = Color(0xFFCBCBCB), fontSize = 13.sp)
        Column(horizontalAlignment = androidx.compose.ui.Alignment.End) {
            Text(value, color = valueColor, fontWeight = FontWeight.Medium, fontSize = 13.sp)
            subtitle?.let { Text("by $it", color = Color(0xFFA3A3A3), fontSize = 12.sp) }
        }
    }
}

@Composable
private fun FilterMenu(
    label: String,
    selected: String,
    options: List<String>,
    modifier: Modifier = Modifier,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier = modifier) {
        OutlinedButton(
            onClick = { expanded = true },
            modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 36.dp),
            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
            shape = RoundedCornerShape(10.dp),
        ) {
            Text(
                "$label: $selected",
                modifier = Modifier.fillMaxWidth(),
                fontSize = 12.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { option ->
                DropdownMenuItem(text = { Text(option) }, onClick = {
                    expanded = false
                    onSelect(option)
                })
            }
        }
    }
}

@Composable
private fun HeaderRow(headers: List<String>) {
    Row {
        headers.forEachIndexed { idx, header ->
            TableCell(
                text = header,
                width = when (idx) {
                    0 -> 72
                    1 -> 130
                    2 -> 52
                    3 -> 170
                    4 -> 120
                    else -> 70
                },
                bold = true,
                color = Color(0xFFCFCFCF),
            )
        }
    }
}

@Composable
private fun TableCell(text: String, width: Int, bold: Boolean = false, color: Color = Color.White) {
    Text(
        text = text,
        modifier = Modifier.width(width.dp).padding(horizontal = 3.dp),
        color = color,
        fontWeight = if (bold) FontWeight.SemiBold else FontWeight.Normal,
        fontSize = 13.sp,
        maxLines = 1,
    )
}

@Composable
private fun CompactFilterCard(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(CardBg, RoundedCornerShape(12.dp))
            .border(1.dp, Border, RoundedCornerShape(12.dp))
            .padding(horizontal = 7.dp, vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        content()
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

    fun label(row: ScoreRow): String = if (isBankScope) row.player else "${row.player} (${abbrSeason(row.season)})"

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
