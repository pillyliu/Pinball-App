package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun AppPassiveStatusChip(
    text: String,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    androidx.compose.material3.Text(
        text = text,
        fontSize = 11.sp,
        fontWeight = FontWeight.SemiBold,
        color = colors.brandInk,
        modifier = modifier
            .background(
                colors.controlBackground,
                RoundedCornerShape(shapes.controlCorner),
            )
            .border(1.dp, colors.brandGold.copy(alpha = 0.38f), RoundedCornerShape(shapes.controlCorner))
            .padding(horizontal = 6.dp, vertical = 3.dp),
    )
}

@Composable
fun AppTintedStatusChip(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
) {
    androidx.compose.material3.Text(
        text = text,
        fontSize = if (compact) 11.sp else 12.sp,
        fontWeight = FontWeight.SemiBold,
        color = color,
        modifier = modifier
            .background(
                color.copy(alpha = 0.16f),
                RoundedCornerShape(999.dp),
            )
            .border(1.dp, color.copy(alpha = 0.28f), RoundedCornerShape(999.dp))
            .padding(horizontal = if (compact) 6.dp else 8.dp, vertical = if (compact) 3.dp else 5.dp),
    )
}

@Composable
fun AppMetricPill(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    Column(
        modifier = modifier
            .background(
                colors.controlBackground,
                RoundedCornerShape(10.dp),
            )
            .border(1.dp, colors.brandGold.copy(alpha = 0.24f), RoundedCornerShape(10.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        androidx.compose.material3.Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = colors.brandChalk,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        androidx.compose.material3.Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
fun AppThreeColumnLegendHeader(
    columns: List<Pair<String, String?>>,
    primaryColors: List<Color>,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
) {
    require(columns.size == 3)
    require(primaryColors.size == 3)

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Row {
            columns.forEachIndexed { index, column ->
                androidx.compose.material3.Text(
                    text = column.first,
                    color = primaryColors[index],
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                    fontWeight = FontWeight.SemiBold,
                    fontSize = if (compact) 13.sp else 12.sp,
                )
            }
        }
        if (compact) {
            Row {
                columns.forEachIndexed { index, column ->
                    androidx.compose.material3.Text(
                        text = column.second.orEmpty(),
                        color = primaryColors[index],
                        textAlign = TextAlign.Center,
                        modifier = Modifier.weight(1f),
                        fontSize = 11.sp,
                    )
                }
            }
        }
    }
}
