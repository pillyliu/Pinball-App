package com.pillyliu.pinprofandroid.league

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppInlineStatusMessage

@Composable
internal fun TargetsMiniPreview(
    rows: List<TargetPreviewRow>,
    bankLabel: String,
    metricIndex: Int,
    labelSize: TextUnit,
    headerSize: TextUnit,
    valueSize: TextUnit,
) {
    val valueColumnWidth = 150.dp
    val metric = remember(metricIndex) {
        when (metricIndex % 3) {
            0 -> TargetMetric.Second
            1 -> TargetMetric.Fourth
            else -> TargetMetric.Eighth
        }
    }
    val metricColor = when (metric) {
        TargetMetric.Second -> Color(0xFF2E8B57)
        TargetMetric.Fourth -> Color(0xFF3A7BD5)
        TargetMetric.Eighth -> Color(0xFF7D8597)
    }

    Text(
        bankLabel,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        fontWeight = FontWeight.SemiBold,
        fontSize = labelSize,
    )
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            "Game",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = headerSize,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.weight(1f))
        Box(modifier = Modifier.width(valueColumnWidth), contentAlignment = Alignment.CenterEnd) {
            Crossfade(targetState = metric, animationSpec = tween(1000), label = "targetsHeader") { current ->
                Text(
                    "${current.label} highest",
                    color = metricColor,
                    fontSize = headerSize,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }

    if (rows.isEmpty()) {
        AppInlineStatusMessage(text = "No target preview available yet")
        return
    }

    rows.take(5).forEach { row ->
        Row(modifier = Modifier.fillMaxWidth()) {
            Text(
                row.game,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = valueSize,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(8.dp))
            Box(modifier = Modifier.width(valueColumnWidth), contentAlignment = Alignment.CenterEnd) {
                Crossfade(targetState = metric, animationSpec = tween(1000), label = "targetsRow-${row.game}") { current ->
                    Text(
                        current.value(row).toGroupNumber(),
                        color = metricColor,
                        fontSize = valueSize,
                        fontWeight = FontWeight.SemiBold,
                        textAlign = TextAlign.End,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}
