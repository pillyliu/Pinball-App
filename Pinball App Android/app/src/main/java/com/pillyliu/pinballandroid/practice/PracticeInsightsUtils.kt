package com.pillyliu.pinballandroid.practice

import java.util.Locale
import kotlin.math.pow
import kotlin.math.roundToInt

internal fun shortSignedDelta(value: Double): String {
    val sign = if (value > 0) "+" else if (value < 0) "-" else ""
    return sign + formatScore(kotlin.math.abs(value))
}

internal fun shortSignedDeltaCompact(value: Double): String {
    val sign = if (value > 0) "+" else if (value < 0) "-" else ""
    val abs = kotlin.math.abs(value)
    val compact = when {
        abs >= 1_000_000_000 -> String.format(Locale.US, "%.1fB", abs / 1_000_000_000.0)
        abs >= 1_000_000 -> String.format(Locale.US, "%.1fM", abs / 1_000_000.0)
        abs >= 1_000 -> String.format(Locale.US, "%.0fK", abs / 1_000.0)
        else -> abs.roundToInt().toString()
    }
    return sign + compact
}

internal fun niceStep(raw: Double): Double {
    val safeRaw = kotlin.math.max(1.0, raw)
    val magnitude = 10.0.pow(kotlin.math.floor(kotlin.math.log10(safeRaw)))
    val normalized = safeRaw / magnitude
    val niceNormalized = when {
        normalized <= 1.0 -> 1.0
        normalized <= 2.0 -> 2.0
        normalized <= 5.0 -> 5.0
        else -> 10.0
    }
    return niceNormalized * magnitude
}

internal fun axisLabel(value: Double): String {
    return when {
        value >= 1_000_000_000 -> {
            val billions = value / 1_000_000_000
            val rounded = if (kotlin.math.abs(billions.roundToInt().toDouble() - billions) < 0.05) {
                billions.roundToInt().toString()
            } else {
                String.format(Locale.US, "%.1f", billions)
            }
            "$rounded bil"
        }
        value >= 1_000_000 -> {
            val millions = value / 1_000_000
            val rounded = if (kotlin.math.abs(millions.roundToInt().toDouble() - millions) < 0.05) {
                millions.roundToInt().toString()
            } else {
                String.format(Locale.US, "%.1f", millions)
            }
            "$rounded mil"
        }
        else -> java.text.NumberFormat.getIntegerInstance(Locale.US).format(value.roundToInt().toLong())
    }
}

internal fun parseComfortFromMechanicsNote(note: String): Float? {
    val match = Regex("competency\\s+(\\d(?:\\.\\d+)?)\\/5", RegexOption.IGNORE_CASE).find(note) ?: return null
    return match.groupValues.getOrNull(1)?.toFloatOrNull()
}
