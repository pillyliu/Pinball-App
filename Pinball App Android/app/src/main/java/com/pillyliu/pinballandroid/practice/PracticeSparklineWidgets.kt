package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
internal fun ScoreTrendSparkline(values: List<Double>, modifier: Modifier = Modifier) {
    if (values.size < 2) {
        Box(
            modifier = modifier
                .fillMaxWidth()
                .height(180.dp)
                .background(
                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(10.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text("Need 2+ scores for trend", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        return
    }

    val maxValue = values.maxOrNull() ?: 1.0
    val intervals = 6
    val step = niceStep(maxValue / intervals)
    val top = kotlin.math.max(step * intervals, step)
    val highlightedTick = kotlin.math.floor(maxValue / step) * step
    val ticksAsc = (0..intervals).map { it * step }
    val ticksDesc = ticksAsc.reversed()
    val surfaceColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f)
    val lineColor = Color(0xFF22D3EE).copy(alpha = 0.95f)
    val gridColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.16f)
    val gridHighlightColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.30f)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(180.dp)
            .background(surfaceColor, shape = androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
            .padding(horizontal = 8.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Column(
            modifier = Modifier
                .width(48.dp)
                .fillMaxHeight(),
            verticalArrangement = Arrangement.SpaceBetween,
            horizontalAlignment = Alignment.End,
        ) {
            ticksDesc.forEach { tickValue ->
                val isHighlight = kotlin.math.abs(tickValue - highlightedTick) < 0.0001 && tickValue > 0 && tickValue < top
                Text(
                    axisLabel(tickValue),
                    style = MaterialTheme.typography.labelSmall,
                    color = if (isHighlight) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Canvas(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight(),
        ) {
            val plotWidth = size.width
            val plotHeight = size.height
            val pointInset = 4.dp.toPx()
            val effectiveWidth = (plotWidth - (pointInset * 2f)).coerceAtLeast(20.dp.toPx())

            ticksAsc.forEach { tickValue ->
                val y = plotHeight - (plotHeight * (tickValue / top).toFloat())
                val isHighlight = kotlin.math.abs(tickValue - highlightedTick) < 0.0001 && tickValue > 0 && tickValue < top
                drawLine(
                    color = if (isHighlight) gridHighlightColor else gridColor,
                    start = Offset(0f, y),
                    end = Offset(plotWidth, y),
                    strokeWidth = if (isHighlight) 1.2.dp.toPx() else 0.8.dp.toPx(),
                )
            }

            values.forEachIndexed { index, value ->
                if (index == values.lastIndex) return@forEachIndexed
                val x1 = pointInset + (effectiveWidth * (index.toFloat() / (values.size - 1)))
                val y1 = plotHeight - (plotHeight * (value / top).toFloat())
                val x2 = pointInset + (effectiveWidth * ((index + 1).toFloat() / (values.size - 1)))
                val y2 = plotHeight - (plotHeight * (values[index + 1] / top).toFloat())
                drawLine(
                    color = lineColor,
                    start = Offset(x1, y1),
                    end = Offset(x2, y2),
                    strokeWidth = 2.dp.toPx(),
                )
            }
        }
    }
}

@Composable
internal fun MechanicsTrendSparkline(logs: List<NoteEntry>) {
    val values = logs
        .takeLast(24)
        .mapNotNull { parseComfortFromMechanicsNote(it.note) }
    if (values.isEmpty()) return

    val min = values.minOrNull() ?: return
    val max = values.maxOrNull() ?: return
    val span = (max - min).coerceAtLeast(1f)
    val baselineColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.35f)
    val lineColor = MaterialTheme.colorScheme.tertiary

    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(54.dp),
    ) {
        val w = size.width
        val h = size.height
        val step = if (values.size <= 1) 0f else w / (values.size - 1)

        drawLine(
            color = baselineColor,
            start = Offset(0f, h - 1f),
            end = Offset(w, h - 1f),
            strokeWidth = 1f,
        )

        values.forEachIndexed { index, value ->
            if (index == 0) return@forEachIndexed
            val prev = values[index - 1]
            val x1 = (index - 1) * step
            val y1 = h - (((prev - min) / span) * (h - 4.dp.toPx()) + 2.dp.toPx())
            val x2 = index * step
            val y2 = h - (((value - min) / span) * (h - 4.dp.toPx()) + 2.dp.toPx())
            drawLine(
                color = lineColor,
                start = Offset(x1, y1),
                end = Offset(x2, y2),
                strokeWidth = 2.dp.toPx(),
            )
        }
    }
}
