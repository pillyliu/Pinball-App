package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Photo
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.library.ReferenceLink
import java.util.Locale

internal enum class AppVariantPillStyle {
    Resource,
    Mini,
    Standard,
    MachineTitle,
    EditSelector,
}

@Composable
internal fun AppResourceRow(
    label: String,
    content: @Composable () -> Unit,
) {
    val colors = PinballThemeTokens.colors
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = colors.brandChalk,
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.horizontalScroll(rememberScrollState()),
        ) {
            content()
        }
        Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
internal fun AppResourceChip(
    label: String,
    onClick: () -> Unit,
) {
    val colors = PinballThemeTokens.colors
    OutlinedButton(
        onClick = onClick,
        modifier = Modifier.defaultMinSize(minHeight = 32.dp),
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = colors.controlBackground,
            contentColor = colors.brandInk,
        ),
        border = BorderStroke(1.dp, colors.brandGold.copy(alpha = 0.34f)),
        shape = RoundedCornerShape(999.dp),
    ) {
        Text(label, fontSize = 12.sp)
    }
}

@Composable
internal fun AppUnavailableResourceChip() {
    val colors = PinballThemeTokens.colors
    Text(
        "Unavailable",
        fontSize = 12.sp,
        color = colors.brandChalk,
        modifier = Modifier
            .background(
                colors.brandGold.copy(alpha = 0.08f),
                RoundedCornerShape(999.dp),
            )
            .border(1.dp, colors.brandGold.copy(alpha = 0.22f), RoundedCornerShape(999.dp))
            .padding(horizontal = 10.dp, vertical = 7.dp),
    )
}

@Composable
internal fun AppVariantBadge(label: String) {
    AppVariantPill(label = label, style = AppVariantPillStyle.Resource)
}

@Composable
internal fun AppVariantPill(
    label: String,
    style: AppVariantPillStyle = AppVariantPillStyle.Resource,
    modifier: Modifier = Modifier,
    maxWidth: Dp? = null,
) {
    val colors = PinballThemeTokens.colors
    val textStyle = when (style) {
        AppVariantPillStyle.Resource -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.Mini -> MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp)
        AppVariantPillStyle.Standard -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.MachineTitle -> MaterialTheme.typography.labelMedium
        AppVariantPillStyle.EditSelector -> MaterialTheme.typography.bodyMedium
    }
    val horizontalPadding = when (style) {
        AppVariantPillStyle.Mini -> 6.dp
        AppVariantPillStyle.Resource,
        AppVariantPillStyle.Standard,
        AppVariantPillStyle.MachineTitle,
        AppVariantPillStyle.EditSelector -> 8.dp
    }
    Text(
        text = label,
        style = textStyle,
        color = colors.brandInk,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier
            .then(if (maxWidth != null) Modifier.widthIn(max = maxWidth) else Modifier)
            .background(
                colors.brandGold.copy(alpha = 0.16f),
                RoundedCornerShape(999.dp),
            )
            .border(1.dp, colors.brandGold.copy(alpha = 0.34f), RoundedCornerShape(999.dp))
            .padding(horizontal = horizontalPadding, vertical = if (style == AppVariantPillStyle.Resource) 5.dp else 3.dp),
    )
}

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
) {
    Text(
        text = text,
        fontSize = 16.sp,
        lineHeight = 17.sp,
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
    val label = link.label.lowercase(Locale.US)
    return when {
        "(tf)" in label -> "TF"
        "(pp)" in label -> "PP"
        "(papa)" in label -> "PAPA"
        "(bob)" in label -> "Bob"
        "(local)" in label || "(source)" in label -> "Local"
        else -> "Local"
    }
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
