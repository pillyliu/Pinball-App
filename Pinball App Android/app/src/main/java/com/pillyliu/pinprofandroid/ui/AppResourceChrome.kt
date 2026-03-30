package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.library.ReferenceLink
import com.pillyliu.pinprofandroid.library.shortRulesheetTitle

@Composable
internal fun AppOverlayMetadataBadge(
    label: String,
    modifier: Modifier = Modifier,
) {
    val colors = PinballThemeTokens.colors
    Text(
        text = label,
        fontSize = 9.sp,
        color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.96f),
        maxLines = 1,
        modifier = modifier
            .background(
                colors.brandInk.copy(alpha = 0.54f),
                RoundedCornerShape(999.dp),
            )
            .border(0.7.dp, colors.brandGold.copy(alpha = 0.38f), RoundedCornerShape(999.dp))
            .padding(horizontal = 5.dp, vertical = 1.dp),
    )
}

@Composable
internal fun AppOverlayTitle(
    text: String,
    modifier: Modifier = Modifier,
    lineHeight: androidx.compose.ui.unit.TextUnit = 17.sp,
) {
    Text(
        text = text,
        fontSize = 16.sp,
        lineHeight = lineHeight,
        color = Color.White,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
        style = MaterialTheme.typography.titleSmall.copy(
            shadow = Shadow(
                color = Color.Black.copy(alpha = 1f),
                blurRadius = 4f,
            ),
        ),
        modifier = modifier,
    )
}

@Composable
internal fun AppOverlayTitleWithVariant(
    text: String,
    variant: String?,
    modifier: Modifier = Modifier,
    lineHeight: androidx.compose.ui.unit.TextUnit = 17.sp,
) {
    val resolvedVariant = variant?.trim()?.takeIf { it.isNotEmpty() }
    if (resolvedVariant == null) {
        AppOverlayTitle(text = text, modifier = modifier, lineHeight = lineHeight)
        return
    }

    AppInlineTextWithPill(
        text = text,
        pillLabel = resolvedVariant,
        maxLines = 2,
        textColor = Color.White,
        textStyle = MaterialTheme.typography.titleSmall.copy(
            fontSize = 16.sp,
            lineHeight = lineHeight,
            shadow = Shadow(
                color = Color.Black.copy(alpha = 1f),
                blurRadius = 4f,
            ),
        ),
        pillTextStyle = MaterialTheme.typography.labelSmall,
        pillHorizontalPadding = 7.dp,
        pillVerticalPadding = 2.dp,
        modifier = modifier,
    ) { label ->
        AppVariantPill(
            label = label,
            style = AppVariantPillStyle.Overlay,
        )
    }
}

@Composable
internal fun AppInlineTintedMetaWithPill(
    text: String,
    pillLabel: String,
    pillForeground: Color,
    modifier: Modifier = Modifier,
) {
    AppInlineTextWithPill(
        text = text,
        pillLabel = pillLabel,
        maxLines = 1,
        textColor = PinballThemeTokens.colors.brandInk,
        textStyle = MaterialTheme.typography.bodySmall.copy(fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold),
        pillTextStyle = MaterialTheme.typography.labelMedium,
        pillHorizontalPadding = 8.dp,
        pillVerticalPadding = 3.dp,
        modifier = modifier,
    ) { label ->
        AppTintedPill(
            label = label,
            foreground = pillForeground,
            style = AppVariantPillStyle.MachineTitle,
        )
    }
}


@Composable
internal fun AppOverlaySubtitle(
    text: String,
    modifier: Modifier = Modifier,
    alpha: Float = 0.96f,
) {
    Text(
        text = text,
        fontSize = 12.sp,
        lineHeight = 14.sp,
        color = Color.White.copy(alpha = alpha),
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        style = MaterialTheme.typography.bodySmall.copy(
            shadow = Shadow(
                color = Color.Black.copy(alpha = 0.9f),
                blurRadius = 3f,
            ),
        ),
        modifier = modifier,
    )
}

@Composable
internal fun AppReadingProgressPill(
    text: String,
    saved: Boolean,
    modifier: Modifier = Modifier,
    alpha: Float = 1f,
) {
    val colors = PinballThemeTokens.colors
    val foreground = if (saved) colors.statsHigh else colors.brandInk
    val background = if (saved) {
        colors.statsHigh.copy(alpha = 0.18f)
    } else {
        colors.controlBackground.copy(alpha = 0.88f)
    }
    val border = if (saved) {
        colors.statsHigh.copy(alpha = 0.34f)
    } else {
        colors.brandChalk.copy(alpha = 0.24f)
    }
    Text(
        text = text,
        style = MaterialTheme.typography.labelSmall,
        color = foreground,
        modifier = modifier
            .graphicsLayer { this.alpha = alpha }
            .background(background, RoundedCornerShape(999.dp))
            .border(0.8.dp, border, RoundedCornerShape(999.dp))
            .padding(horizontal = 9.dp, vertical = 5.dp),
    )
}

internal fun appShortRulesheetTitle(link: ReferenceLink): String {
    return link.shortRulesheetTitle
}

@Composable
internal fun AppMediaPreviewPlaceholder(
    modifier: Modifier = Modifier,
    message: String? = null,
    showsProgress: Boolean = false,
) {
    val colors = PinballThemeTokens.colors
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(colors.atmosphereBottom, RoundedCornerShape(12.dp))
            .border(1.dp, colors.brandChalk.copy(alpha = 0.2f), RoundedCornerShape(12.dp)),
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.foundation.layout.Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            if (showsProgress) {
                CircularProgressIndicator(
                    modifier = Modifier.defaultMinSize(minWidth = 18.dp, minHeight = 18.dp),
                    strokeWidth = 1.75.dp,
                    color = colors.brandGold,
                )
            } else {
                Icon(
                    imageVector = Icons.Outlined.Photo,
                    contentDescription = null,
                    tint = colors.brandGold,
                )
            }
            message?.let {
                Text(
                    text = it,
                    color = colors.brandChalk,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }
}

@Composable
internal fun appVideoTileContainerColor(selected: Boolean) =
    if (selected) {
        PinballThemeTokens.colors.brandGold.copy(alpha = 0.14f)
    } else {
        PinballThemeTokens.colors.controlBackground.copy(alpha = 0.88f)
    }

@Composable
internal fun appVideoTileBorderColor(selected: Boolean) =
    if (selected) {
        PinballThemeTokens.colors.brandGold.copy(alpha = 0.62f)
    } else {
        PinballThemeTokens.colors.brandChalk.copy(alpha = 0.26f)
    }

@Composable
internal fun appVideoTileLabelColor(selected: Boolean) =
    if (selected) {
        PinballThemeTokens.colors.brandInk
    } else {
        MaterialTheme.colorScheme.onSurface
    }
