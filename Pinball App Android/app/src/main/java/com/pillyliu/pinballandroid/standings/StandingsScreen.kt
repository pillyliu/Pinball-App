package com.pillyliu.pinballandroid.standings

import android.content.res.Configuration
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.data.parseCsv
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.CardContainer
import com.pillyliu.pinballandroid.ui.CompactDropdownFilter
import com.pillyliu.pinballandroid.ui.EmptyLabel
import com.pillyliu.pinballandroid.ui.FixedWidthTableCell
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
            error = null
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
        Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            CompactDropdownFilter(
                selectedText = selectedSeason?.let { "Season $it" } ?: "Select",
                options = seasons.map { "Season $it" },
                onSelect = { label ->
                    selectedSeason = label.removePrefix("Season ").trim().toIntOrNull()
                },
                modifier = Modifier.fillMaxWidth(),
                minHeight = 38.dp,
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 10.dp, vertical = 0.dp),
                textSize = 12.sp,
                itemTextSize = 12.sp,
            )

            error?.let { Text(it, color = Color.Red) }

            CardContainer(modifier = Modifier.fillMaxWidth().weight(1f, fill = true)) {
                BoxWithConstraints {
                    val baseTableWidth = 646f
                    val scaled = (maxWidth.value / baseTableWidth).coerceIn(1f, 1.9f)
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
                        Column {
                            HeaderRow(widths)
                            if (standingRows.isEmpty()) {
                                EmptyLabel("No rows. Check data source or season selection.")
                            } else {
                                Column(modifier = Modifier.verticalScroll(rememberScrollState()).fillMaxSize()) {
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
}

@Composable
private fun HeaderRow(widths: StandingsWidths) {
    Row {
        FixedWidthTableCell("#", widths.rank, bold = true)
        FixedWidthTableCell("Player", widths.player, bold = true)
        FixedWidthTableCell("Pts", widths.points, bold = true)
        FixedWidthTableCell("Elg", widths.eligible, bold = true)
        FixedWidthTableCell("N", widths.nights, bold = true)
        (1..8).forEach { FixedWidthTableCell("B$it", widths.bank, bold = true) }
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
            .background(if (rank % 2 == 0) Color(0xFF0A0A0A) else Color(0xFF171717))
            .padding(vertical = 6.dp),
    ) {
        FixedWidthTableCell(rank.toString(), widths.rank, color = rankColor)
        FixedWidthTableCell(standing.player, widths.player, bold = rank <= 8)
        FixedWidthTableCell(fmt(standing.seasonTotal), widths.points)
        FixedWidthTableCell(standing.eligible, widths.eligible)
        FixedWidthTableCell(standing.nights, widths.nights)
        standing.banks.forEach { FixedWidthTableCell(fmt(it), widths.bank) }
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
