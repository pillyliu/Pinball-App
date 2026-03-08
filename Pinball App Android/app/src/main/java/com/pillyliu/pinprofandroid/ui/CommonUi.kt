package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Button
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.BorderStroke

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
    ) {
        PinballAtmosphereBackground()
        Box(
            modifier = Modifier
                .matchParentSize()
                .padding(contentPadding)
                .padding(horizontal = horizontalPadding, vertical = spacing.screenVerticalCompact),
        ) {
            content()
        }
    }
}

@Composable
fun PinballAtmosphereBackground(modifier: Modifier = Modifier) {
    val colors = PinballThemeTokens.colors
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(colors.atmosphereTop, colors.background, colors.atmosphereBottom),
                ),
            ),
    ) {
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(colors.atmosphereGlow.copy(alpha = 0.18f), Color.Transparent),
                        center = androidx.compose.ui.geometry.Offset(0f, 0f),
                        radius = 900f,
                    ),
                ),
        )
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(colors.brandChalk.copy(alpha = 0.12f), Color.Transparent),
                        center = androidx.compose.ui.geometry.Offset(1400f, 2600f),
                        radius = 1200f,
                    ),
                ),
        )
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
            tint = colors.brandGold,
            modifier = Modifier.size(iconSize),
        )
    }
}

@Composable
fun AppHeaderIconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    size: Dp = 38.dp,
    iconSize: Dp = 18.dp,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    IconButton(
        onClick = onClick,
        modifier = modifier
            .size(size)
            .background(
                colors.controlBackground.copy(alpha = 0.92f),
                RoundedCornerShape(shapes.controlCorner),
            )
            .border(
                1.dp,
                colors.brandGold.copy(alpha = 0.32f),
                RoundedCornerShape(shapes.controlCorner),
            ),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = colors.brandInk,
            modifier = Modifier.size(iconSize),
        )
    }
}

@Composable
fun AppScreenHeader(
    title: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    titleColor: Color = PinballThemeTokens.colors.brandInk,
    titleMaxLines: Int = 1,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AppBackButton(onClick = onBack)
        Text(
            text = title,
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 10.dp),
            color = titleColor,
            style = PinballThemeTokens.typography.sectionTitle,
            maxLines = titleMaxLines,
            textAlign = TextAlign.Center,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(modifier = Modifier.width(40.dp))
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
            .border(1.dp, colors.brandChalk.copy(alpha = 0.22f), RoundedCornerShape(shapes.panelCorner))
            .padding(spacing.panelPadding),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        CompositionLocalProvider(LocalContentColor provides colors.brandInk) {
            content()
        }
    }
}

@Composable
fun SectionTitle(text: String) {
    val colors = PinballThemeTokens.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .size(width = 6.dp, height = 18.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(colors.brandGold, colors.brandChalk),
                    ),
                    RoundedCornerShape(999.dp),
                ),
        )
        Text(
            text = text,
            color = colors.brandInk,
            style = PinballThemeTokens.typography.sectionTitle,
        )
    }
}

@Composable
fun AppCardSubheading(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        color = PinballThemeTokens.colors.brandInk,
        style = MaterialTheme.typography.bodySmall,
        fontWeight = FontWeight.SemiBold,
        modifier = modifier,
    )
}

data class AppMetricItem(
    val label: String,
    val value: String,
)

@Composable
fun AppMetricGrid(
    items: List<AppMetricItem>,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    val rows = items.chunked(2)
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        rows.forEach { rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                rowItems.forEach { item ->
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = item.label,
                            style = MaterialTheme.typography.bodySmall,
                            color = colors.brandChalk,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            text = item.value,
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.brandInk,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                if (rowItems.size == 1) {
                    Box(modifier = Modifier.weight(1f))
                }
            }
        }
    }
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
            color = PinballThemeTokens.colors.brandChalk,
            style = PinballThemeTokens.typography.emptyState,
        )
    }
}

@Composable
fun AppInlineStatusMessage(
    text: String,
    modifier: Modifier = Modifier,
    isError: Boolean = false,
) {
    Text(
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
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
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
) {
    val colors = PinballThemeTokens.colors
    val paddingHorizontal = if (compact) 8.dp else 10.dp
    val paddingVertical = if (compact) 5.dp else 7.dp
    val iconSize = if (compact) 14.dp else 16.dp
    Row(
        modifier = modifier
            .background(
                colors.statsHigh.copy(alpha = 0.16f),
                RoundedCornerShape(999.dp),
            )
            .border(
                1.dp,
                colors.statsHigh.copy(alpha = 0.28f),
                RoundedCornerShape(999.dp),
            )
            .padding(horizontal = paddingHorizontal, vertical = paddingVertical),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (compact) 6.dp else 8.dp),
    ) {
        Icon(
            imageVector = Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = colors.statsHigh,
            modifier = Modifier.size(iconSize),
        )
        Text(
            text = text,
            color = colors.statsHigh,
            style = PinballThemeTokens.typography.filterSummary,
            maxLines = 2,
        )
    }
}

@Composable
fun RowScope.AppSwipeRevealActionButton(
    modifier: Modifier,
    tint: Color,
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .padding(horizontal = 1.dp)
            .fillMaxHeight()
            .background(tint, shape = RoundedCornerShape(6.dp))
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = contentDescription, tint = Color.White)
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
    CardContainer(modifier = modifier) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Color.Transparent,
                    RoundedCornerShape(shapes.panelCorner),
                ),
        ) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .border(
                        width = 1.dp,
                        color = colors.border.copy(alpha = 0.18f),
                        shape = RoundedCornerShape(shapes.panelCorner),
                    ),
            )
            Box(
                modifier = Modifier
                    .width(5.dp)
                    .height(36.dp)
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
                modifier = Modifier.padding(start = 12.dp),
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
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(colors.controlBackground, RoundedCornerShape(shapes.controlCorner))
            .border(1.dp, colors.brandChalk.copy(alpha = 0.42f), RoundedCornerShape(shapes.controlCorner))
            .padding(horizontal = 10.dp, vertical = 6.dp),
    ) {
        EmptyLabel(text)
    }
}

@Composable
fun AppControlCard(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(horizontal = 10.dp, vertical = 8.dp),
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(colors.controlBackground, RoundedCornerShape(shapes.controlCorner))
            .border(1.dp, colors.brandGold.copy(alpha = 0.28f), RoundedCornerShape(shapes.controlCorner))
            .padding(contentPadding),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        content = content,
    )
}

@Composable
fun AppExternalLinkButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    Button(
        onClick = onClick,
        modifier = modifier,
        shape = RoundedCornerShape(shapes.controlCorner),
        border = BorderStroke(1.dp, colors.brandGold.copy(alpha = 0.34f)),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 10.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = colors.controlBackground,
            contentColor = colors.brandInk,
        ),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
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
            color = colors.brandChalk,
            style = typography.filterSummary,
            maxLines = 1,
            textAlign = TextAlign.Center,
            overflow = TextOverflow.Ellipsis,
        )

        IconButton(onClick = onFilterClick, modifier = Modifier.size(32.dp)) {
            Icon(
                imageVector = Icons.Outlined.FilterList,
                contentDescription = "Filters",
                tint = colors.brandGold,
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
            color = colors.brandChalk,
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
                    tint = colors.brandGold.copy(alpha = if (hasNewerData) pulseAlpha else 1f),
                    modifier = Modifier.size(12.dp),
                )
            }
        }
    }
}

@Composable
fun AppInlineActionChip(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    destructive: Boolean = false,
    enabled: Boolean = true,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    val contentColor = if (destructive) MaterialTheme.colorScheme.error else colors.brandInk
    val borderColor = if (destructive) MaterialTheme.colorScheme.error.copy(alpha = 0.28f) else colors.brandGold.copy(alpha = 0.38f)
    TextButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier,
        shape = RoundedCornerShape(shapes.controlCorner),
        border = BorderStroke(1.dp, borderColor),
        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 3.dp),
        colors = ButtonDefaults.textButtonColors(
            containerColor = colors.controlBackground,
            contentColor = contentColor,
            disabledContainerColor = colors.controlBackground.copy(alpha = 0.6f),
            disabledContentColor = contentColor.copy(alpha = 0.6f),
        ),
    ) {
        Text(
            text = text,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
fun AppTextAction(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    destructive: Boolean = false,
) {
    val colors = PinballThemeTokens.colors
    val contentColor = if (destructive) MaterialTheme.colorScheme.error else colors.brandGold
    TextButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier,
        colors = ButtonDefaults.textButtonColors(
            contentColor = contentColor,
            disabledContentColor = contentColor.copy(alpha = 0.55f),
        ),
    ) {
        Text(
            text = text,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
fun AppInlineLinkAction(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    TextButton(
        onClick = onClick,
        modifier = modifier,
        contentPadding = PaddingValues(0.dp),
        colors = ButtonDefaults.textButtonColors(
            contentColor = Color(0xFF7DC4FA),
        ),
    ) {
        Text(
            text = text,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
fun AppTopBarDropdownTrigger(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    contentDescription: String = "Open menu",
) {
    val colors = PinballThemeTokens.colors
    TextButton(
        onClick = onClick,
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 0.dp, vertical = 0.dp),
        colors = ButtonDefaults.textButtonColors(
            contentColor = colors.brandInk,
        ),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                text = text,
                modifier = Modifier.weight(1f),
                color = colors.brandInk,
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Start,
            )
            Icon(
                imageVector = Icons.Filled.ArrowDropDown,
                contentDescription = contentDescription,
                tint = colors.brandGold,
            )
        }
    }
}

@Composable
fun AppSelectableRowButton(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    TextButton(
        onClick = onClick,
        modifier = modifier,
        contentPadding = PaddingValues(0.dp),
        colors = ButtonDefaults.textButtonColors(
            contentColor = colors.brandInk,
        ),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    if (selected) colors.brandGold.copy(alpha = 0.14f) else Color.Transparent,
                    shape = RoundedCornerShape(shapes.controlCorner),
                )
                .border(
                    width = 1.dp,
                    color = if (selected) colors.brandGold.copy(alpha = 0.42f) else Color.Transparent,
                    shape = RoundedCornerShape(shapes.controlCorner),
                )
                .padding(horizontal = 10.dp, vertical = 6.dp),
        ) {
            Text(
                text = text,
                color = if (selected) colors.brandInk else colors.brandChalk,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
fun AppSecondaryButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    minHeight: Dp = 40.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
    content: @Composable RowScope.() -> Unit,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.defaultMinSize(minHeight = minHeight),
        shape = RoundedCornerShape(shapes.controlCorner),
        border = BorderStroke(
            1.dp,
            if (enabled) colors.brandGold.copy(alpha = 0.38f) else colors.brandChalk.copy(alpha = 0.18f),
        ),
        contentPadding = contentPadding,
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = colors.controlBackground,
            contentColor = colors.brandInk,
            disabledContainerColor = colors.controlBackground.copy(alpha = 0.65f),
            disabledContentColor = colors.brandChalk.copy(alpha = 0.7f),
        ),
        content = content,
    )
}

@Composable
fun AppPrimaryButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    minHeight: Dp = 40.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
    content: @Composable RowScope.() -> Unit,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    val buttonInk = Color(0xFF261700)
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.defaultMinSize(minHeight = minHeight),
        shape = RoundedCornerShape(shapes.controlCorner),
        contentPadding = contentPadding,
        colors = ButtonDefaults.buttonColors(
            containerColor = colors.brandGold.copy(alpha = 0.92f),
            contentColor = buttonInk,
            disabledContainerColor = colors.brandGold.copy(alpha = 0.24f),
            disabledContentColor = buttonInk.copy(alpha = 0.55f),
        ),
        content = content,
    )
}

@Composable
fun AppDestructiveButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    minHeight: Dp = 40.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
    content: @Composable RowScope.() -> Unit,
) {
    val shapes = PinballThemeTokens.shapes
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.defaultMinSize(minHeight = minHeight),
        shape = RoundedCornerShape(shapes.controlCorner),
        contentPadding = contentPadding,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.error.copy(alpha = 0.92f),
            contentColor = MaterialTheme.colorScheme.onError,
            disabledContainerColor = MaterialTheme.colorScheme.error.copy(alpha = 0.24f),
            disabledContentColor = MaterialTheme.colorScheme.onError.copy(alpha = 0.55f),
        ),
        content = content,
    )
}

@Composable
fun AppPassiveStatusChip(
    text: String,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    Text(
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
fun AppSelectionPill(
    text: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val colors = PinballThemeTokens.colors
    Text(
        text = text,
        fontSize = 12.sp,
        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
        color = if (selected) colors.brandInk else MaterialTheme.colorScheme.onSurface,
        modifier = modifier
            .background(
                if (selected) colors.brandGold.copy(alpha = 0.22f) else colors.controlBackground,
                RoundedCornerShape(999.dp),
            )
            .border(
                1.dp,
                if (selected) colors.brandGold.copy(alpha = 0.52f) else colors.brandChalk.copy(alpha = 0.35f),
                RoundedCornerShape(999.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
    )
}

@Composable
fun AppTintedStatusChip(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
) {
    Text(
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
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = colors.brandChalk,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
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
