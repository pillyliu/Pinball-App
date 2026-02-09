package com.pillyliu.pinballandroid.stats

import android.content.res.Configuration
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
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
import com.pillyliu.pinballandroid.ui.ControlBg
import com.pillyliu.pinballandroid.ui.ControlBorder
import java.text.NumberFormat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.pow
import kotlin.math.sqrt

private const val CSV_URL = "https://pillyliu.com/pinball/data/LPL_Stats.csv"
private data class FilterOption(val value: String, val label: String)

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
            val seasonOptions = listOf(FilterOption("", "S: All")) + seasons.map { FilterOption(it, abbrSeason(it)) }
            val playerOptions = listOf(FilterOption("", "Player: All")) + players.map { FilterOption(it, it) }
            val bankOptions = listOf(FilterOption("", "B: All")) + banks.map { FilterOption(it.toString(), "B$it") }
            val machineOptions = listOf(FilterOption("", "Machine: All")) + machines.map { FilterOption(it, it) }

            if (isLandscape) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    FilterMenu(selectedText = seasonDisplayText(season), options = seasonOptions, modifier = Modifier.weight(1f)) {
                        season = it
                        player = ""
                        bankNumber = null
                        machine = ""
                    }
                    FilterMenu(selectedText = playerDisplayText(player), options = playerOptions, modifier = Modifier.weight(1f)) {
                        player = it
                        bankNumber = null
                        machine = ""
                    }
                    FilterMenu(selectedText = bankDisplayText(bankNumber), options = bankOptions, modifier = Modifier.weight(1f)) {
                        bankNumber = it.toIntOrNull()
                        machine = ""
                    }
                    FilterMenu(selectedText = machineDisplayText(machine), options = machineOptions, modifier = Modifier.weight(1f)) {
                        machine = it
                    }
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
                        FilterMenu(selectedText = seasonDisplayText(season), options = seasonOptions, modifier = Modifier.weight(3f)) {
                            season = it
                            player = ""
                            bankNumber = null
                            machine = ""
                        }
                        FilterMenu(selectedText = playerDisplayText(player), options = playerOptions, modifier = Modifier.weight(7f)) {
                            player = it
                            bankNumber = null
                            machine = ""
                        }
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        FilterMenu(selectedText = bankDisplayText(bankNumber), options = bankOptions, modifier = Modifier.weight(3f)) {
                            bankNumber = it.toIntOrNull()
                            machine = ""
                        }
                        FilterMenu(selectedText = machineDisplayText(machine), options = machineOptions, modifier = Modifier.weight(7f)) {
                            machine = it
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
                                .background(if (row.id % 2 == 0) Color(0xFF0A0A0A) else Color(0xFF171717))
                                .padding(vertical = 6.dp),
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
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text("Machine Stats", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        if (machine.isEmpty()) {
            Text("Select a machine to view detailed stats.", color = Color(0xFFD0D0D0), fontSize = 12.sp)
            return@Column
        }
        if (bankNumber == null || season.isEmpty()) {
            Text("Select season, bank, and machine to view detailed stats.", color = Color(0xFFD0D0D0), fontSize = 12.sp)
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
            modifier = Modifier.fillMaxWidth().padding(bottom = 2.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            HeaderCell("", modifier = Modifier.weight(0.9f))
            HeaderCell(selectedLabel, modifier = Modifier.weight(1.55f), alignRight = true)
            HeaderCell("All Seasons", modifier = Modifier.weight(1.55f), alignRight = true)
        }
        rowLabels.forEachIndexed { idx, label ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 0.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                StatLabelCell(label, modifier = Modifier.weight(0.9f))
                StatValueCell(
                    label = label,
                    stats = selectedStats,
                    isAllSeasons = false,
                    modifier = Modifier.weight(1.55f),
                )
                StatValueCell(
                    label = label,
                    stats = allSeasonsStats,
                    isAllSeasons = true,
                    modifier = Modifier.weight(1.55f),
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
        modifier = modifier.padding(vertical = 1.dp),
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

    Column(modifier = modifier.padding(vertical = 1.dp)) {
        Text(
            text = value,
            color = valueColor,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.End,
            modifier = Modifier.fillMaxWidth(),
            maxLines = 1,
        )
        if (label == "High" || label == "Low") {
            val playerText = if (player.isNullOrBlank()) "-" else if (isAllSeasons) player else player.substringBefore(" (S")
            Text(
                text = playerText,
                color = Color(0xFF737373),
                fontSize = 10.sp,
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth(),
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
private fun playerDisplayText(player: String): String = if (player.isBlank()) "Player: All" else player
private fun machineDisplayText(machine: String): String = if (machine.isBlank()) "Machine: All" else machine

@Composable
private fun FilterMenu(
    selectedText: String,
    options: List<FilterOption>,
    modifier: Modifier = Modifier,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val density = LocalDensity.current
    var menuWidth by remember { mutableStateOf(0.dp) }
    Box(modifier = modifier.fillMaxWidth()) {
        OutlinedButton(
            onClick = { expanded = true },
            modifier = Modifier
                .fillMaxWidth()
                .defaultMinSize(minHeight = 40.dp)
                .onGloballyPositioned { coordinates ->
                    menuWidth = with(density) { coordinates.size.width.toDp() }
                },
            contentPadding = PaddingValues(start = 10.dp, end = 28.dp, top = 7.dp, bottom = 7.dp),
            shape = RoundedCornerShape(11.dp),
            border = BorderStroke(1.dp, ControlBorder),
            colors = ButtonDefaults.outlinedButtonColors(
                containerColor = ControlBg,
                contentColor = Color.White,
            ),
        ) {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    selectedText,
                    modifier = Modifier.weight(1f),
                    fontSize = 13.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Start,
                )
                Spacer(modifier = Modifier.width(6.dp))
            }
        }
        Icon(
            imageVector = Icons.Filled.KeyboardArrowDown,
            contentDescription = null,
            tint = Color(0xFFC6C6C6),
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 8.dp)
                .size(18.dp),
        )
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = if (menuWidth > 0.dp) Modifier.width(menuWidth) else Modifier,
        ) {
            options.forEach { option ->
                DropdownMenuItem(text = { Text(option.label, fontSize = 12.sp) }, onClick = {
                    expanded = false
                    onSelect(option.value)
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
