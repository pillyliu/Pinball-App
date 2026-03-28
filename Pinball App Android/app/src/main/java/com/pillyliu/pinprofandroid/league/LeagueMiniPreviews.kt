package com.pillyliu.pinprofandroid.league

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.HorizontalDivider
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
import com.pillyliu.pinprofandroid.data.formatLplPlayerNameForDisplay
import com.pillyliu.pinprofandroid.ui.AppInlineStatusMessage
import com.pillyliu.pinprofandroid.ui.AppTintedStatusChip
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import java.text.NumberFormat

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
        Text("Game", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = headerSize, fontWeight = FontWeight.SemiBold)
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

@Composable
internal fun StandingsMiniPreview(
    seasonLabel: String,
    showAround: Boolean,
    topRows: List<StandingsPreviewRow>,
    aroundRows: List<StandingsPreviewRow>,
    currentPlayerRow: StandingsPreviewRow?,
    showFullLplLastName: Boolean,
    labelSize: TextUnit,
    headerSize: TextUnit,
    valueSize: TextUnit,
) {
    val mode = if (showAround) "Around You" else "Top 5"
    val colors = PinballThemeTokens.colors
    val usesExpandedStandingsLayout = (currentPlayerRow?.rank ?: 0) > 5
    val dividerThickness = 2.dp
    val dividerVerticalPadding = 1.dp

    Crossfade(targetState = mode, animationSpec = tween(durationMillis = 1000), label = "standingsModeBlock") { activeMode ->
        val rows = if (activeMode == "Around You") aroundRows else topRows
        val placeColumnWidth = 34.dp
        val pointsColumnWidth = 84.dp
        val placePlayerGap = 8.dp

        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(seasonLabel, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold, fontSize = labelSize)
                Spacer(Modifier.width(6.dp))
                AppTintedStatusChip(
                    text = activeMode,
                    color = Color(0xFF3A7BD5),
                    compact = true,
                )
            }

            Row(modifier = Modifier.fillMaxWidth()) {
                Text("#", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = headerSize, fontWeight = FontWeight.SemiBold, modifier = Modifier.width(placeColumnWidth))
                Text(
                    "Player",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = headerSize,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f).padding(start = placePlayerGap),
                )
                Text(
                    "Pts",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    fontSize = headerSize,
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.End,
                    modifier = Modifier.width(pointsColumnWidth),
                )
            }

            if (rows.isEmpty()) {
                AppInlineStatusMessage(
                    text = if (activeMode == "Around You") {
                        "Set a league player name in Practice to enable Around You"
                    } else {
                        "No standings preview available yet"
                    },
                )
            } else {
                rows.forEach { row ->
                    StandingsMiniPreviewRow(
                        row = row,
                        emphasized = currentPlayerRow == row,
                        showFullLplLastName = showFullLplLastName,
                        valueSize = valueSize,
                        placeColumnWidth = placeColumnWidth,
                        pointsColumnWidth = pointsColumnWidth,
                        placePlayerGap = placePlayerGap,
                    )
                }

                if (activeMode == "Top 5" && usesExpandedStandingsLayout && currentPlayerRow != null) {
                    Spacer(modifier = Modifier.height(dividerVerticalPadding))
                    HorizontalDivider(
                        thickness = dividerThickness,
                        color = colors.brandInk.copy(alpha = 0.28f),
                    )
                    Spacer(modifier = Modifier.height(dividerVerticalPadding))
                    StandingsMiniPreviewRow(
                        row = currentPlayerRow,
                        emphasized = true,
                        showFullLplLastName = showFullLplLastName,
                        valueSize = valueSize,
                        placeColumnWidth = placeColumnWidth,
                        pointsColumnWidth = pointsColumnWidth,
                        placePlayerGap = placePlayerGap,
                    )
                } else if (activeMode == "Around You" && usesExpandedStandingsLayout) {
                    Spacer(modifier = Modifier.height(dividerThickness + (dividerVerticalPadding * 2)))
                }
            }
        }
    }
}

@Composable
private fun StandingsMiniPreviewRow(
    row: StandingsPreviewRow,
    emphasized: Boolean,
    showFullLplLastName: Boolean,
    valueSize: TextUnit,
    placeColumnWidth: androidx.compose.ui.unit.Dp,
    pointsColumnWidth: androidx.compose.ui.unit.Dp,
    placePlayerGap: androidx.compose.ui.unit.Dp,
) {
    val colors = PinballThemeTokens.colors
    val isPodium = row.rank <= 3
    val rankColor = if (emphasized && row.rank > 3) colors.statsMeanMedian else leagueRankColor(row.rank)
    val playerColor = if (emphasized) colors.brandInk else MaterialTheme.colorScheme.onSurfaceVariant
    val valueColor = if (emphasized) colors.statsMeanMedian else MaterialTheme.colorScheme.onSurface
    val rankWeight = if (emphasized || isPodium) FontWeight.SemiBold else FontWeight.Normal
    val playerWeight = if (emphasized || isPodium) FontWeight.SemiBold else FontWeight.Normal
    val valueWeight = if (emphasized || isPodium) FontWeight.SemiBold else FontWeight.Normal

    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            row.rank.toString(),
            color = rankColor,
            fontSize = valueSize,
            fontWeight = rankWeight,
            modifier = Modifier.width(placeColumnWidth),
        )
        Text(
            formatLplPlayerNameForDisplay(row.rawPlayer, showFullLplLastName),
            color = playerColor,
            fontSize = valueSize,
            fontWeight = playerWeight,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f).padding(start = placePlayerGap),
        )
        Text(
            row.points.toWholeNumber(),
            color = valueColor,
            fontSize = valueSize,
            fontWeight = valueWeight,
            textAlign = TextAlign.End,
            modifier = Modifier.width(pointsColumnWidth),
        )
    }
}

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

    Text(bankLabel, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold, fontSize = labelSize)
    Row(modifier = Modifier.fillMaxWidth()) {
        Text("Game", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = headerSize, fontWeight = FontWeight.SemiBold)
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

@Composable
private fun leagueRankColor(rank: Int): Color {
    val colors = PinballThemeTokens.colors
    return when (rank) {
        1 -> colors.podiumGold
        2 -> colors.podiumSilver
        3 -> colors.podiumBronze
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
}

private fun Long.toGroupNumber(): String = NumberFormat.getIntegerInstance().format(this)

private fun Double.toWholeNumber(): String = NumberFormat.getIntegerInstance().format(this.toLong())
