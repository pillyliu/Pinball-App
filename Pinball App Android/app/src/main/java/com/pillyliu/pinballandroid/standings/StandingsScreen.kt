package com.pillyliu.pinballandroid.standings

import android.content.res.Configuration
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.data.parseCsv
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.CardContainer
import com.pillyliu.pinballandroid.ui.Border
import com.pillyliu.pinballandroid.ui.CardBg
import com.pillyliu.pinballandroid.ui.EmptyLabel
import java.text.NumberFormat

private const val CSV_URL = "https://pillyliu.com/pinball/data/LPL_Standings.csv"

private data class StandingsCsvRow(
    val season: Int,
    val player: String,
    val total: Double,
    val rank: Int?,
    val eligible: String,
    val nights: String,
    val banks: List<Double>,
)

private data class Standing(
    val player: String,
    val seasonTotal: Double,
    val eligible: String,
    val nights: String,
    val banks: List<Double>,
)

private data class StandingsWidths(
    val rank: Int,
    val player: Int,
    val points: Int,
    val eligible: Int,
    val nights: Int,
    val bank: Int,
)

@Composable
fun StandingsScreen(contentPadding: PaddingValues) {
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    var rows by remember { mutableStateOf(emptyList<StandingsCsvRow>()) }
    var error by remember { mutableStateOf<String?>(null) }
    var selectedSeason by rememberSaveable { mutableStateOf<Int?>(null) }

    LaunchedEffect(Unit) {
        try {
            val cached = PinballDataCache.passthroughOrCachedText(CSV_URL)
            rows = parseStandings(cached.text.orEmpty())
            error = cached.statusMessage
            if (selectedSeason == null) {
                selectedSeason = rows.map { it.season }.distinct().maxOrNull()
            }
        } catch (t: Throwable) {
            error = t.message ?: "Failed to load standings"
        }
    }

    val seasons = rows.map { it.season }.toSet().sorted()
    val standingRows = buildStandings(rows, selectedSeason)

    AppScreen(contentPadding) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            CompactFilterCard {
                var expanded by remember { mutableStateOf(false) }
                OutlinedButton(
                    onClick = { expanded = true },
                    modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 38.dp),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 8.dp, vertical = 0.dp),
                    shape = RoundedCornerShape(10.dp),
                ) {
                    Text(selectedSeason?.let { "Season $it" } ?: "Select")
                }
                DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    seasons.forEach { season ->
                        DropdownMenuItem(text = { Text("Season $season") }, onClick = {
                            expanded = false
                            selectedSeason = season
                        })
                    }
                }
            }

            error?.let { Text(it, color = Color.Red) }

            CardContainer {
                BoxWithConstraints {
                    val baseTableWidth = 646f
                    val scaled = if (isLandscape) {
                        (maxWidth.value / baseTableWidth).coerceIn(1f, 1.7f)
                    } else {
                        1f
                    }
                    val widths = StandingsWidths(
                        rank = (34 * scaled).toInt(),
                        player = (136 * scaled).toInt(),
                        points = (68 * scaled).toInt(),
                        eligible = (38 * scaled).toInt(),
                        nights = (34 * scaled).toInt(),
                        bank = (42 * scaled).toInt(),
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                        horizontalArrangement = if (isLandscape) Arrangement.Center else Arrangement.Start,
                    ) {
                        Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                            HeaderRow(widths)
                            if (standingRows.isEmpty()) {
                                EmptyLabel("No rows. Check data source or season selection.")
                            } else {
                                standingRows.forEachIndexed { index, standing ->
                                    StandingRow(rank = index + 1, standing = standing, widths = widths)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HeaderRow(widths: StandingsWidths) {
    Row {
        Cell("#", widths.rank, bold = true)
        Cell("Player", widths.player, bold = true)
        Cell("Pts", widths.points, bold = true)
        Cell("Elg", widths.eligible, bold = true)
        Cell("N", widths.nights, bold = true)
        (1..8).forEach { Cell("B$it", widths.bank, bold = true) }
    }
}

@Composable
private fun StandingRow(rank: Int, standing: Standing, widths: StandingsWidths) {
    val rankColor = when (rank) {
        1 -> Color.Yellow
        2 -> Color(0xFFDBDBDB)
        3 -> Color(0xFFFFA948)
        else -> Color.White
    }
    Row(
        modifier = Modifier
            .background(if (rank % 2 == 0) Color(0xFF121212) else Color(0xFF222222))
            .padding(vertical = 4.dp),
    ) {
        Cell(rank.toString(), widths.rank, color = rankColor)
        Cell(standing.player, widths.player, bold = rank <= 8)
        Cell(fmt(standing.seasonTotal), widths.points)
        Cell(standing.eligible, widths.eligible)
        Cell(standing.nights, widths.nights)
        standing.banks.forEach { Cell(fmt(it), widths.bank) }
    }
}

@Composable
private fun Cell(text: String, width: Int, bold: Boolean = false, color: Color = Color.White) {
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
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        content()
    }
}

private fun buildStandings(rows: List<StandingsCsvRow>, selectedSeason: Int?): List<Standing> {
    if (selectedSeason == null) return emptyList()
    val seasonRows = rows.filter { it.season == selectedSeason }
    if (seasonRows.isEmpty()) return emptyList()

    val mapped = seasonRows.map {
        Standing(
            player = it.player,
            seasonTotal = it.total,
            eligible = it.eligible,
            nights = it.nights,
            banks = it.banks,
        )
    }

    val hasRankForAll = seasonRows.all { it.rank != null }
    if (hasRankForAll) {
        val rankMap = seasonRows.associate { it.player to (it.rank ?: Int.MAX_VALUE) }
        return mapped.sortedBy { rankMap[it.player] ?: Int.MAX_VALUE }
    }

    return mapped.sortedByDescending { it.seasonTotal }
}

private fun parseStandings(text: String): List<StandingsCsvRow> {
    val table = parseCsv(text)
    if (table.isEmpty()) return emptyList()

    val headers = table[0].map { normalize(it) }
    val required = listOf(
        "season", "player", "total", "bank_1", "bank_2", "bank_3", "bank_4",
        "bank_5", "bank_6", "bank_7", "bank_8",
    )
    if (required.any { it !in headers }) {
        throw IllegalStateException("Standings CSV missing required columns")
    }

    return table.drop(1).mapNotNull { row ->
        if (row.size != headers.size) return@mapNotNull null
        val dict = headers.zip(row).toMap()

        val season = coerceSeason(dict["season"].orEmpty())
        val player = dict["player"].orEmpty().trim()
        if (season <= 0 || player.isBlank()) return@mapNotNull null

        StandingsCsvRow(
            season = season,
            player = player,
            total = dict["total"].orEmpty().toDoubleOrNull() ?: 0.0,
            rank = dict["rank"].orEmpty().trim().toIntOrNull(),
            eligible = dict["eligible"].orEmpty().trim(),
            nights = dict["nights"].orEmpty().trim(),
            banks = (1..8).map { i -> dict["bank_$i"].orEmpty().toDoubleOrNull() ?: 0.0 },
        )
    }
}

private fun normalize(header: String): String {
    return header.replace("\uFEFF", "").trim().lowercase()
}

private fun coerceSeason(value: String): Int {
    val trimmed = value.trim()
    val digits = trimmed.filter { it.isDigit() }
    return digits.toIntOrNull() ?: trimmed.toIntOrNull() ?: 0
}

private fun fmt(value: Double): String = NumberFormat.getIntegerInstance().format(value.toLong())
