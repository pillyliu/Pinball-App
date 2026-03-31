package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun AppInlineStatusMessage(
    text: String,
    modifier: Modifier = Modifier,
    isError: Boolean = false,
) {
    androidx.compose.material3.Text(
        text = text,
        modifier = modifier.fillMaxWidth(),
        color = if (isError) MaterialTheme.colorScheme.error else PinballThemeTokens.colors.brandChalk,
        style = PinballThemeTokens.typography.emptyState,
    )
}

@Composable
fun AppInlineTaskStatus(
    text: String,
    modifier: Modifier = Modifier,
    showsProgress: Boolean = false,
    isError: Boolean = false,
) {
    val statusChrome = PinballThemeTokens.statusChrome
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(statusChrome.inlineSpacing),
    ) {
        if (showsProgress) {
            CircularProgressIndicator(
                modifier = Modifier.size(12.dp),
                strokeWidth = 1.75.dp,
                color = if (isError) MaterialTheme.colorScheme.error else PinballThemeTokens.colors.brandGold,
            )
        }
        AppInlineStatusMessage(
            text = text,
            isError = isError,
        )
    }
}

@Composable
fun AppSuccessBanner(
    text: String,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
    prominent: Boolean = false,
) {
    val colors = PinballThemeTokens.colors
    val statusChrome = PinballThemeTokens.statusChrome
    val iconSize = if (compact) 14.dp else 18.dp
    val contentColor = if (prominent) Color.White.copy(alpha = 0.98f) else colors.statsHigh
    val backgroundAlpha = when {
        prominent && compact -> 0.56f
        prominent -> 0.76f
        compact -> 0.18f
        else -> 0.24f
    }
    val borderAlpha = when {
        prominent && compact -> 0.72f
        prominent -> 0.92f
        compact -> 0.3f
        else -> 0.4f
    }
    val textStyle = if (compact) {
        PinballThemeTokens.typography.filterSummary
    } else {
        PinballThemeTokens.typography.filterSummary.copy(fontSize = 13.sp)
    }
    Row(
        modifier = modifier
            .background(
                colors.statsHigh.copy(alpha = backgroundAlpha),
                RoundedCornerShape(999.dp),
            )
            .border(
                1.dp,
                colors.statsHigh.copy(alpha = borderAlpha),
                RoundedCornerShape(999.dp),
            )
            .padding(
                horizontal = if (compact) statusChrome.successCompactHorizontal else statusChrome.successRegularHorizontal,
                vertical = if (compact) statusChrome.successCompactVertical else statusChrome.successRegularVertical,
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(
            if (compact) statusChrome.successCompactSpacing else statusChrome.successRegularSpacing,
        ),
    ) {
        Icon(
            imageVector = Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = contentColor,
            modifier = Modifier.size(iconSize),
        )
        androidx.compose.material3.Text(
            text = text,
            color = contentColor,
            style = textStyle,
            maxLines = 2,
        )
    }
}

@Composable
fun AppPanelStatusCard(
    text: String,
    modifier: Modifier = Modifier,
    showsProgress: Boolean = false,
    isError: Boolean = false,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    val statusChrome = PinballThemeTokens.statusChrome
    CardContainer(modifier = modifier) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Color.Transparent,
                    RoundedCornerShape(shapes.panelCorner),
                )
                .border(
                    width = 1.dp,
                    color = colors.border.copy(alpha = 0.18f),
                    shape = RoundedCornerShape(shapes.panelCorner),
                )
                .padding(
                    horizontal = statusChrome.panelPaddingHorizontal,
                    vertical = statusChrome.panelPaddingVertical,
                ),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(statusChrome.panelSpacing),
        ) {
            Box(
                modifier = Modifier
                    .width(statusChrome.panelAccentWidth)
                    .height(statusChrome.panelAccentHeight)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                if (isError) MaterialTheme.colorScheme.error else colors.brandGold,
                                colors.brandChalk.copy(alpha = 0.30f),
                            ),
                        ),
                        RoundedCornerShape(999.dp),
                    ),
            )
            AppInlineTaskStatus(
                text = text,
                showsProgress = showsProgress,
                isError = isError,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
fun AppPanelEmptyCard(
    text: String,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    val statusChrome = PinballThemeTokens.statusChrome
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(colors.controlBackground, RoundedCornerShape(shapes.controlCorner))
            .border(1.dp, colors.brandChalk.copy(alpha = 0.42f), RoundedCornerShape(shapes.controlCorner))
            .padding(
                horizontal = statusChrome.emptyCardPaddingHorizontal,
                vertical = statusChrome.emptyCardPaddingVertical,
            ),
    ) {
        EmptyLabel(text)
    }
}

@Composable
fun AppRefreshStatusRow(
    label: String,
    isRefreshing: Boolean,
    hasNewerData: Boolean,
    pulseAlpha: Float,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    val statusChrome = PinballThemeTokens.statusChrome
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.material3.Text(
            text = label,
            color = colors.brandChalk,
            fontSize = 11.sp,
        )
        if (isRefreshing) {
            Spacer(Modifier.width(statusChrome.refreshSpacing + 1.dp))
            CircularProgressIndicator(
                modifier = Modifier.size(10.dp),
                strokeWidth = 1.5.dp,
                color = colors.shellUnselectedContent,
            )
        } else {
            IconButton(
                onClick = onRefresh,
                modifier = Modifier.size(20.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.Refresh,
                    contentDescription = "Refresh data",
                    tint = colors.brandGold.copy(alpha = if (hasNewerData) pulseAlpha else 1f),
                    modifier = Modifier.size(12.dp),
                )
            }
        }
    }
}
