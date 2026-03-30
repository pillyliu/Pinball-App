package com.pillyliu.pinprofandroid.standings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.data.formatLplPlayerNameForDisplay
import com.pillyliu.pinprofandroid.ui.FixedWidthTableCell
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens

@Composable
internal fun StandingsHeaderRow(widths: StandingsWidths) {
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
internal fun StandingsRow(
    rank: Int,
    standing: Standing,
    widths: StandingsWidths,
    showFullLplLastName: Boolean,
    isHighlighted: Boolean,
) {
    val colors = PinballThemeTokens.colors
    val highlightedTextColor = colors.statsMeanMedian
    val rankColor = if (isHighlighted && rank > 3) highlightedTextColor else podiumRankColor(rank)
    val playerColor = if (isHighlighted) highlightedTextColor else Color.Unspecified
    val dataColor = if (isHighlighted) highlightedTextColor else Color.Unspecified
    Row(
        modifier = Modifier
            .background(if (rank % 2 == 0) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(vertical = 6.dp),
    ) {
        FixedWidthTableCell(rank.toString(), widths.rank, color = rankColor, bold = isHighlighted || rank <= 3)
        FixedWidthTableCell(
            formatLplPlayerNameForDisplay(standing.rawPlayer, showFullLplLastName),
            widths.player,
            bold = isHighlighted || rank <= 8,
            color = playerColor,
        )
        FixedWidthTableCell(formatStandingsValue(standing.seasonTotal), widths.points, bold = isHighlighted, color = dataColor)
        FixedWidthTableCell(standing.eligible, widths.eligible, bold = isHighlighted, color = dataColor)
        FixedWidthTableCell(standing.nights, widths.nights, bold = isHighlighted, color = dataColor)
        standing.banks.forEach { FixedWidthTableCell(formatStandingsValue(it), widths.bank, bold = isHighlighted, color = dataColor) }
    }
}

@Composable
internal fun podiumRankColor(rank: Int): Color {
    val colors = PinballThemeTokens.colors
    return when (rank) {
        1 -> colors.podiumGold
        2 -> colors.podiumSilver
        3 -> colors.podiumBronze
        else -> MaterialTheme.colorScheme.onSurface
    }
}
