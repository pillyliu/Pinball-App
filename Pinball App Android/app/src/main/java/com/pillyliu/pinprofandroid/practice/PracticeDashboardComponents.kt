package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppMetricPill
import com.pillyliu.pinprofandroid.ui.AppTintedStatusChip
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens

@Composable
internal fun DashboardStatusChip(text: String, color: Color, modifier: Modifier = Modifier) {
    AppTintedStatusChip(
        text = text,
        color = color,
        modifier = modifier,
    )
}

@Composable
internal fun DashboardMetricPill(label: String, value: String, modifier: Modifier = Modifier) {
    AppMetricPill(label = label, value = value, modifier = modifier)
}

@Composable
internal fun GroupProgressWheel(taskProgress: Map<String, Int>, modifier: Modifier = Modifier) {
    val keys = listOf("playfield", "rulesheet", "tutorial", "gameplay", "practice")
    val trackColor = PinballThemeTokens.colors.brandInk.copy(alpha = 0.30f)
    val colors = mapOf(
        "playfield" to Color(0xFF0E7490),
        "rulesheet" to Color(0xFF1D4ED8),
        "tutorial" to Color(0xFFB45309),
        "gameplay" to Color(0xFF6D28D9),
        "practice" to Color(0xFF047857),
    )
    Canvas(modifier = modifier) {
        val segment = 360f / keys.size
        val gap = 6f
        val strokeWidth = 5.8.dp.toPx()
        val inset = strokeWidth / 2f
        val arcSize = Size(size.width - (inset * 2f), size.height - (inset * 2f))
        keys.forEachIndexed { index, key ->
            val start = -90f + (index * segment) + (gap / 2f)
            val sweep = segment - gap
            val progress = ((taskProgress[key] ?: 0).coerceIn(0, 100) / 100f)

            drawArc(
                color = trackColor,
                startAngle = start,
                sweepAngle = sweep,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = arcSize,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
            )
            if (progress > 0f) {
                drawArc(
                    color = colors[key] ?: Color.Gray,
                    startAngle = start,
                    sweepAngle = sweep * progress,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = arcSize,
                    style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                )
            }
        }
    }
}

internal fun progressSummary(taskProgress: Map<String, Int>): String {
    return "Playfield ${taskProgress["playfield"] ?: 0}%  •  Rules ${taskProgress["rulesheet"] ?: 0}%  •  Tutorial ${taskProgress["tutorial"] ?: 0}%  •  Gameplay ${taskProgress["gameplay"] ?: 0}%  •  Practice ${taskProgress["practice"] ?: 0}%"
}
