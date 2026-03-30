package com.pillyliu.pinprofandroid.stats

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.data.formatLplPlayerNameForDisplay
import com.pillyliu.pinprofandroid.data.leaguePlayerNamesMatch
import com.pillyliu.pinprofandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinprofandroid.ui.EmptyLabel
import com.pillyliu.pinprofandroid.ui.FixedWidthTableCell
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens

@Composable
internal fun StatsTable(
    filtered: List<ScoreRow>,
    showFullLplLastName: Boolean,
    preferredLeaguePlayerName: String,
    isRefreshing: Boolean,
    initialLoadComplete: Boolean,
    modifier: Modifier = Modifier,
) {
    val hState = rememberScrollState()
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val baseTableWidth = 614f
        val scale = (maxWidth.value / baseTableWidth).coerceIn(1f, 1.8f)
        val widths = StatsTableWidths(
            season = (72 * scale).toInt(),
            bank = (52 * scale).toInt(),
            player = (130 * scale).toInt(),
            machine = (170 * scale).toInt(),
            score = (120 * scale).toInt(),
            points = (70 * scale).toInt(),
        )
        val tableWidth = widths.season + widths.bank + widths.player + widths.machine + widths.score + widths.points

        Row(
            modifier = Modifier.fillMaxSize().horizontalScroll(hState),
            horizontalArrangement = Arrangement.Center,
        ) {
            Column(
                modifier = Modifier
                    .width(tableWidth.dp)
                    .fillMaxHeight(),
            ) {
                StatsHeaderRow(widths)
                if (!initialLoadComplete && isRefreshing) {
                    Column(
                        modifier = Modifier.weight(1f, fill = true),
                        verticalArrangement = Arrangement.Center,
                    ) {
                        EmptyLabel("Loading data…")
                    }
                } else if (filtered.isEmpty()) {
                    Column(
                        modifier = Modifier.weight(1f, fill = true),
                        verticalArrangement = Arrangement.Center,
                    ) {
                        EmptyLabel("No rows - check filters or data source.")
                    }
                } else {
                    LazyColumn(modifier = Modifier.weight(1f, fill = true)) {
                        itemsIndexed(filtered, key = { _, row -> row.id }) { _, row ->
                            val isHighlighted = leaguePlayerNamesMatch(row.player, preferredLeaguePlayerName)
                            val accentColor = if (isHighlighted) PinballThemeTokens.colors.statsMeanMedian else Color.Unspecified
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(if (row.id % 2 == 0) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceContainerHigh)
                                    .padding(vertical = 6.dp),
                            ) {
                                FixedWidthTableCell(row.season, widths.season, bold = isHighlighted)
                                FixedWidthTableCell(row.bankNumber.toString(), widths.bank, bold = isHighlighted)
                                FixedWidthTableCell(
                                    formatLplPlayerNameForDisplay(row.player, showFullLplLastName),
                                    widths.player,
                                    bold = isHighlighted,
                                    color = accentColor,
                                )
                                FixedWidthTableCell(row.machine, widths.machine, bold = isHighlighted)
                                FixedWidthTableCell(formatStatsInt(row.rawScore), widths.score, bold = isHighlighted, color = accentColor)
                                FixedWidthTableCell(formatStatsInt(row.points), widths.points, bold = isHighlighted, color = accentColor)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
internal fun MachineStatsPanel(
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
            Text("Select a machine to see machine stats", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 12.sp)
            return@Column
        }
        MachineStatsTable(
            selectedLabel = selectedStatsBankLabel(season, bankNumber),
            selectedStats = bankStats,
            allSeasonsStats = historyStats,
        )
    }
}

@Composable
internal fun MachineStatsTable(selectedLabel: String, selectedStats: StatResult, allSeasonsStats: StatResult) {
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
            StatsHeaderCell("", modifier = Modifier.weight(0.7f))
            StatsHeaderCell(selectedLabel, modifier = Modifier.weight(1.65f))
            StatsHeaderCell("All Seasons", modifier = Modifier.weight(1.65f))
        }
        rowLabels.forEach { label ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 0.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                StatsStatLabelCell(label, modifier = Modifier.weight(0.7f))
                StatsStatValueCell(
                    label = label,
                    stats = selectedStats,
                    modifier = Modifier.weight(1.65f),
                )
                StatsStatValueCell(
                    label = label,
                    stats = allSeasonsStats,
                    modifier = Modifier.weight(1.65f),
                )
            }
        }
    }
}

@Composable
private fun StatsHeaderCell(text: String, modifier: Modifier, alignRight: Boolean = false) {
    Text(
        text = text,
        modifier = modifier,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        maxLines = 1,
        textAlign = if (alignRight) TextAlign.End else TextAlign.Start,
    )
}

@Composable
private fun StatsStatLabelCell(text: String, modifier: Modifier) {
    Text(
        text = text,
        modifier = modifier,
        color = MaterialTheme.colorScheme.onSurface,
        fontSize = 12.sp,
        fontWeight = FontWeight.Medium,
        maxLines = 1,
    )
}

@Composable
private fun StatsStatValueCell(label: String, stats: StatResult, modifier: Modifier) {
    val showFullLplLastName = rememberShowFullLplLastName()
    val valueColor = statsAccentColor(label)
    val value = when (label) {
        "High" -> formatStatsInt(stats.high)
        "Low" -> formatStatsInt(stats.low)
        "Avg" -> formatStatsInt(stats.mean)
        "Med" -> formatStatsInt(stats.median)
        "Std" -> formatStatsInt(stats.std)
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
            Text(
                text = formatStatsPlayerLabel(player, showFullLplLastName),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
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

@Composable
private fun statsAccentColor(label: String): Color {
    val darkMode = isSystemInDarkTheme()
    val base = when (label) {
        "High" -> Color(0xFF34D399)
        "Low" -> Color(0xFFF87171)
        "Avg", "Med" -> Color(0xFF7DD3FC)
        else -> MaterialTheme.colorScheme.onSurface
    }
    return if (label == "Std" || label == "Count") {
        base
    } else if (darkMode) {
        lerp(base, Color.White, 0.14f)
    } else {
        lerp(base, MaterialTheme.colorScheme.onSurface, 0.34f)
    }
}

@Composable
private fun StatsHeaderRow(widths: StatsTableWidths) {
    Row {
        FixedWidthTableCell(text = "Season", width = widths.season, bold = true, color = MaterialTheme.colorScheme.onSurface)
        FixedWidthTableCell(text = "Bank", width = widths.bank, bold = true, color = MaterialTheme.colorScheme.onSurface)
        FixedWidthTableCell(text = "Player", width = widths.player, bold = true, color = MaterialTheme.colorScheme.onSurface)
        FixedWidthTableCell(text = "Machine", width = widths.machine, bold = true, color = MaterialTheme.colorScheme.onSurface)
        FixedWidthTableCell(text = "Score", width = widths.score, bold = true, color = MaterialTheme.colorScheme.onSurface)
        FixedWidthTableCell(text = "Points", width = widths.points, bold = true, color = MaterialTheme.colorScheme.onSurface)
    }
}
