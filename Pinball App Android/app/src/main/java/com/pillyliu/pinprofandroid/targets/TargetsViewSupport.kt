package com.pillyliu.pinprofandroid.targets

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.ui.CompactDropdownFilter
import com.pillyliu.pinprofandroid.ui.FixedWidthTableCell

internal fun targetLegendColumns(isLandscape: Boolean): List<Pair<String, String?>> {
    return if (isLandscape) {
        listOf(
            "2nd highest \"great game\"" to null,
            "4th highest main target" to null,
            "8th highest solid floor" to null,
        )
    } else {
        listOf(
            "2nd highest" to "\"great game\"",
            "4th highest" to "main target",
            "8th highest" to "solid floor",
        )
    }
}

@Composable
internal fun TargetSortMenu(
    selected: TargetSortOption,
    onSelect: (TargetSortOption) -> Unit,
    modifier: Modifier = Modifier,
) {
    CompactDropdownFilter(
        selectedText = "Sort: ${selected.label}",
        options = TargetSortOption.entries.map { "Sort: ${it.label}" },
        onSelect = { label ->
            val raw = label.removePrefix("Sort: ").trim()
            val option = TargetSortOption.entries.firstOrNull { it.label == raw } ?: selected
            onSelect(option)
        },
        modifier = modifier,
        minHeight = 34.dp,
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 3.dp),
        textSize = 12.sp,
        itemTextSize = 12.sp,
    )
}

@Composable
internal fun TargetBankMenu(
    selectedBank: Int?,
    bankOptions: List<Int>,
    onSelect: (Int?) -> Unit,
    modifier: Modifier = Modifier,
) {
    CompactDropdownFilter(
        selectedText = selectedBank?.let { "Bank $it" } ?: "All banks",
        options = listOf("All banks") + bankOptions.map { "Bank $it" },
        onSelect = { label ->
            if (label == "All banks") {
                onSelect(null)
            } else {
                onSelect(label.removePrefix("Bank ").trim().toIntOrNull())
            }
        },
        modifier = modifier,
        minHeight = 34.dp,
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 3.dp),
        textSize = 12.sp,
        itemTextSize = 12.sp,
    )
}

@Composable
internal fun TargetsHeader(gameWidth: Int, bankWidth: Int, scoreWidth: Int) {
    Row {
        FixedWidthTableCell("Game", gameWidth, bold = true, horizontalPadding = 5.dp)
        FixedWidthTableCell("B", bankWidth, bold = true, horizontalPadding = 5.dp)
        FixedWidthTableCell("2nd", scoreWidth, bold = true, horizontalPadding = 5.dp)
        FixedWidthTableCell("4th", scoreWidth, bold = true, horizontalPadding = 5.dp)
        FixedWidthTableCell("8th", scoreWidth, bold = true, horizontalPadding = 5.dp)
    }
}

@Composable
internal fun TargetRowView(index: Int, row: TargetRow, gameWidth: Int, bankWidth: Int, scoreWidth: Int) {
    Row(
        modifier = Modifier
            .background(if (index % 2 == 0) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(vertical = 5.dp),
    ) {
        FixedWidthTableCell(
            text = row.target.game,
            width = gameWidth,
            maxLines = 1,
            horizontalPadding = 5.dp,
            overflow = TextOverflow.Ellipsis,
        )
        FixedWidthTableCell(row.bank?.toString() ?: "-", bankWidth, horizontalPadding = 5.dp)
        FixedWidthTableCell(formatTargetScore(row.target.great), scoreWidth, color = targetAccentColor(TargetColorRole.Great), horizontalPadding = 5.dp)
        FixedWidthTableCell(formatTargetScore(row.target.main), scoreWidth, color = targetAccentColor(TargetColorRole.Main), horizontalPadding = 5.dp)
        FixedWidthTableCell(formatTargetScore(row.target.floor), scoreWidth, color = targetAccentColor(TargetColorRole.Floor), horizontalPadding = 5.dp)
    }
}

@Composable
internal fun targetAccentColor(role: TargetColorRole): Color {
    val darkMode = isSystemInDarkTheme()
    val base = when (role) {
        TargetColorRole.Great -> Color(0xFF34D399)
        TargetColorRole.Main -> Color(0xFF60A5FA)
        TargetColorRole.Floor -> Color(0xFF9CA3AF)
    }
    return if (darkMode) {
        lerp(base, Color.White, 0.16f)
    } else {
        lerp(base, MaterialTheme.colorScheme.onSurface, 0.36f)
    }
}
