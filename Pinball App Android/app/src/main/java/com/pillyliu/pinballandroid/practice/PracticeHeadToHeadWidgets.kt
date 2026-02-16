package com.pillyliu.pinballandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import androidx.compose.ui.unit.dp

@Composable
internal fun HeadToHeadGameRow(game: HeadToHeadGameStats) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(vertical = 3.dp)) {
        Text(game.gameName, style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(verticalArrangement = Arrangement.spacedBy(1.dp), modifier = Modifier.weight(1f)) {
                Text("Mean", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    "${formatScore(game.yourMean)} vs ${formatScore(game.opponentMean)}",
                    style = MaterialTheme.typography.labelSmall,
                )
            }
            Text(
                shortSignedDelta(game.meanDelta),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = if (game.meanDelta >= 0) Color(0xFF2E7D32) else Color(0xFFEF6C00),
            )
        }
    }
}

@Composable
internal fun HeadToHeadDeltaBars(games: List<HeadToHeadGameStats>, modifier: Modifier = Modifier) {
    if (games.isEmpty()) return
    val maxDelta = games.maxOf { kotlin.math.abs(it.meanDelta) }.takeIf { it > 0.0 } ?: 1.0
    Column(
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = modifier,
    ) {
        games.forEach { game ->
            val ratio = (kotlin.math.abs(game.meanDelta) / maxDelta).toFloat().coerceIn(0f, 1f)
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    game.gameName,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(0.34f),
                )
                Box(
                    modifier = Modifier
                        .weight(0.50f)
                        .height(20.dp)
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f),
                            shape = androidx.compose.foundation.shape.RoundedCornerShape(4.dp),
                        ),
                ) {
                    Row(modifier = Modifier.fillMaxSize()) {
                        Box(modifier = Modifier.weight(1f).fillMaxHeight(), contentAlignment = Alignment.CenterEnd) {
                            if (game.meanDelta < 0) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxHeight()
                                        .fillMaxWidth(ratio)
                                        .background(
                                            Color(0xFFEF6C00).copy(alpha = 0.85f),
                                            shape = androidx.compose.foundation.shape.RoundedCornerShape(4.dp),
                                        ),
                                )
                            }
                        }
                        Box(modifier = Modifier.weight(1f).fillMaxHeight(), contentAlignment = Alignment.CenterStart) {
                            if (game.meanDelta >= 0) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxHeight()
                                        .fillMaxWidth(ratio)
                                        .background(
                                            Color(0xFF2E7D32).copy(alpha = 0.85f),
                                            shape = androidx.compose.foundation.shape.RoundedCornerShape(4.dp),
                                        ),
                                )
                            }
                        }
                    }
                    Box(
                        modifier = Modifier
                            .align(Alignment.Center)
                            .width(1.dp)
                            .fillMaxHeight()
                            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.28f)),
                    )
                }
                Text(
                    shortSignedDeltaCompact(game.meanDelta),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = if (game.meanDelta >= 0) Color(0xFF2E7D32) else Color(0xFFEF6C00),
                    textAlign = TextAlign.End,
                    modifier = Modifier.weight(0.16f),
                )
            }
        }
    }
}
