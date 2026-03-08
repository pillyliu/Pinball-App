package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

val LocalBottomBarVisible = compositionLocalOf<MutableState<Boolean>> {
    error("LocalBottomBarVisible not provided")
}

@Composable
fun AppScreen(
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier,
    horizontalPadding: Dp = PinballThemeTokens.spacing.screenHorizontal,
    content: @Composable () -> Unit,
) {
    val colors = PinballThemeTokens.colors
    val spacing = PinballThemeTokens.spacing
    Box(
        modifier = Modifier
            .then(modifier)
            .fillMaxSize()
            .background(colors.background)
            .padding(contentPadding)
            .padding(horizontal = horizontalPadding, vertical = spacing.screenVerticalCompact),
    ) {
        content()
    }
}

@Composable
fun AppBackButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp,
    iconSize: Dp = 20.dp,
) {
    val colors = PinballThemeTokens.colors
    IconButton(
        onClick = onClick,
        modifier = modifier.size(size),
    ) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = "Back",
            tint = colors.shellSelectedContent,
            modifier = Modifier.size(iconSize),
        )
    }
}

@Composable
fun Modifier.iosEdgeSwipeBack(
    enabled: Boolean,
    onBack: () -> Unit,
): Modifier {
    if (!enabled) return this
    val edgeWidthPx = with(LocalDensity.current) { 28.dp.toPx() }
    val triggerDistancePx = with(LocalDensity.current) { 84.dp.toPx() }
    return this.pointerInput(enabled) {
        var tracking = false
        var triggered = false
        var distance = 0f
        detectHorizontalDragGestures(
            onDragStart = { offset ->
                tracking = offset.x <= edgeWidthPx
                triggered = false
                distance = 0f
            },
            onHorizontalDrag = { change, dragAmount ->
                if (!tracking || triggered) return@detectHorizontalDragGestures
                if (dragAmount > 0f) {
                    distance += dragAmount
                    change.consume()
                    if (distance >= triggerDistancePx) {
                        triggered = true
                        onBack()
                    }
                } else if (distance > 0f) {
                    distance = (distance + dragAmount).coerceAtLeast(0f)
                }
            },
            onDragEnd = {
                tracking = false
                triggered = false
                distance = 0f
            },
            onDragCancel = {
                tracking = false
                triggered = false
                distance = 0f
            },
        )
    }
}

@Composable
fun CardContainer(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    val spacing = PinballThemeTokens.spacing
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(colors.panel, RoundedCornerShape(shapes.panelCorner))
            .border(1.dp, colors.border.copy(alpha = 0.38f), RoundedCornerShape(shapes.panelCorner))
            .padding(spacing.panelPadding),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        content()
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(
        text = text,
        color = PinballThemeTokens.colors.shellSelectedContent,
        style = PinballThemeTokens.typography.sectionTitle,
    )
}

@Composable
fun EmptyLabel(text: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 20.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = PinballThemeTokens.colors.shellUnselectedContent,
            style = PinballThemeTokens.typography.emptyState,
        )
    }
}

@Composable
fun InsetFilterHeader(
    summaryText: String,
    onFilterClick: () -> Unit,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
) {
    val colors = PinballThemeTokens.colors
    val typography = PinballThemeTokens.typography
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(34.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) {
            AppBackButton(onClick = onBack, size = 32.dp, iconSize = 18.dp)
        } else {
            Spacer(modifier = Modifier.width(32.dp))
        }

        Text(
            text = summaryText,
            modifier = Modifier.weight(1f).padding(horizontal = 10.dp),
            color = colors.shellUnselectedContent,
            style = typography.filterSummary,
            maxLines = 1,
            textAlign = TextAlign.Center,
            overflow = TextOverflow.Ellipsis,
        )

        IconButton(onClick = onFilterClick, modifier = Modifier.size(32.dp)) {
            Icon(
                imageVector = Icons.Outlined.FilterList,
                contentDescription = "Filters",
                tint = colors.shellSelectedContent,
            )
        }
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
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = colors.shellUnselectedContent,
            fontSize = 11.sp,
        )
        if (isRefreshing) {
            Spacer(Modifier.width(6.dp))
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
                    tint = colors.shellUnselectedContent.copy(alpha = if (hasNewerData) pulseAlpha else 1f),
                    modifier = Modifier.size(12.dp),
                )
            }
        }
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
                Text(
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
                    Text(
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
