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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.data.formatLplPlayerNameForDisplay
import com.pillyliu.pinprofandroid.ui.AppInlineStatusMessage

@Composable
internal fun StatsMiniPreview(
    rows: List<StatsPreviewRow>,
    bankLabel: String,
    playerLabel: String,
    showFullLplLastName: Boolean,
    showScore: Boolean,
    labelSize: TextUnit,
    headerSize: TextUnit,
    valueSize: TextUnit,
) {
    val valueColor = if (showScore) Color(0xFF2E8B57) else Color(0xFF3A7BD5)
    val valueColumnWidth = 122.dp
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            bankLabel,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.SemiBold,
            fontSize = labelSize,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (playerLabel.isNotBlank()) {
            Spacer(Modifier.width(8.dp))
            Text(
                formatLplPlayerNameForDisplay(playerLabel, showFullLplLastName),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = headerSize,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.End,
                modifier = Modifier.weight(1f),
            )
        }
    }
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            "Game",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = headerSize,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.weight(1f))
        Box(modifier = Modifier.width(valueColumnWidth), contentAlignment = Alignment.CenterEnd) {
            Crossfade(targetState = showScore, animationSpec = tween(durationMillis = 1000), label = "statsHeader") { score ->
                Text(
                    text = if (score) "Score" else "Pts",
                    color = valueColor,
                    fontSize = headerSize,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.End,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }

    if (rows.isEmpty()) {
        AppInlineStatusMessage(text = "Tap to open full stats")
        return
    }

    rows.forEach { row ->
        Row(modifier = Modifier.fillMaxWidth()) {
            Text(
                row.machine,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = valueSize,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(8.dp))
            Box(modifier = Modifier.width(valueColumnWidth), contentAlignment = Alignment.CenterEnd) {
                Crossfade(targetState = showScore, animationSpec = tween(durationMillis = 1000), label = "statsRow-${row.machine}") { score ->
                    Text(
                        text = if (score) row.score.toWholeNumber() else row.points.toWholeNumber(),
                        color = valueColor,
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
