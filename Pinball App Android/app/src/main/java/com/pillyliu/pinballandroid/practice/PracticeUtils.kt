package com.pillyliu.pinballandroid.practice

import androidx.compose.ui.unit.dp
import com.pillyliu.pinballandroid.library.LibraryActivityEvent
import com.pillyliu.pinballandroid.library.LibraryActivityKind
import org.json.JSONArray
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToLong

internal fun formatScore(value: Double): String {
    val rounded = value.roundToLong()
    return java.text.NumberFormat.getIntegerInstance(Locale.US).format(rounded)
}

internal fun signedCompact(value: Double): String {
    val sign = if (value >= 0) "+" else "-"
    return sign + String.format(Locale.US, "%.1f", kotlin.math.abs(value))
}

internal fun headToHeadPlotHeight(count: Int): androidx.compose.ui.unit.Dp {
    if (count <= 0) return 170.dp
    val rowHeight = 20.dp
    val rowSpacing = 6.dp
    val rows = count
    val content = (rowHeight * rows) + (rowSpacing * (rows - 1).coerceAtLeast(0)) + 14.dp
    return if (content > 170.dp) content else 170.dp
}

internal fun formatTimestamp(timestampMs: Long): String {
    return java.time.Instant.ofEpochMilli(timestampMs)
        .atZone(ZoneId.systemDefault())
        .format(DateTimeFormatter.ofPattern("MMM d, h:mm a", Locale.US))
}

internal fun formatShortDate(timestampMs: Long): String {
    return java.time.Instant.ofEpochMilli(timestampMs)
        .atZone(ZoneId.systemDefault())
        .toLocalDate()
        .format(DateTimeFormatter.ofPattern("MM/dd/yy", Locale.US))
}

internal fun formatIsoDate(timestampMs: Long): String {
    return java.time.Instant.ofEpochMilli(timestampMs)
        .atZone(ZoneId.systemDefault())
        .toLocalDate()
        .format(DateTimeFormatter.ISO_LOCAL_DATE)
}

internal fun parseIsoDate(value: String): Long? {
    val trimmed = value.trim()
    if (trimmed.isEmpty()) return null
    val local = runCatching { LocalDate.parse(trimmed, DateTimeFormatter.ISO_LOCAL_DATE) }.getOrNull() ?: return null
    return local.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
}

internal fun libraryActivitySummary(event: LibraryActivityEvent): String = when (event.kind) {
    LibraryActivityKind.BrowseGame -> "Browsed ${event.gameName} in Library"
    LibraryActivityKind.OpenRulesheet -> "Opened ${event.gameName} rulesheet from Library"
    LibraryActivityKind.OpenPlayfield -> "Opened ${event.gameName} playfield image from Library"
    LibraryActivityKind.TapVideo -> {
        val detail = event.detail?.takeIf { it.isNotBlank() }
        if (detail != null) {
            "Opened $detail video for ${event.gameName} in Library"
        } else {
            "Opened video for ${event.gameName} in Library"
        }
    }
}

internal fun JSONArray.toStringList(): List<String> = (0 until length()).mapNotNull { idx ->
    optString(idx).takeIf { it.isNotBlank() }
}

internal fun percentile(sorted: List<Double>, p: Double): Double {
    if (sorted.isEmpty()) return 0.0
    if (sorted.size == 1) return sorted[0]
    val clamped = p.coerceIn(0.0, 1.0)
    val index = clamped * (sorted.size - 1)
    val low = kotlin.math.floor(index).toInt()
    val high = kotlin.math.ceil(index).toInt()
    if (low == high) return sorted[low]
    val weight = index - low
    return sorted[low] + (sorted[high] - sorted[low]) * weight
}

internal fun stddev(values: List<Double>, mean: Double): Double {
    if (values.isEmpty()) return 0.0
    val variance = values.sumOf { v ->
        val d = v - mean
        d * d
    } / values.size
    return kotlin.math.sqrt(variance)
}
