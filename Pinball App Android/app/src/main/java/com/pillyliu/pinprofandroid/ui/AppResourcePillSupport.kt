package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

internal enum class AppVariantPillStyle {
    Resource,
    Mini,
    Overlay,
    Standard,
    MachineTitle,
    EditSelector,
}

private val AppVariantPillStyle.verticalOffset: Dp
    get() = when (this) {
        AppVariantPillStyle.Resource,
        AppVariantPillStyle.EditSelector -> 0.dp
        AppVariantPillStyle.Mini,
        AppVariantPillStyle.Overlay,
        AppVariantPillStyle.Standard,
        AppVariantPillStyle.MachineTitle -> (-1).dp
    }

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun AppResourceRow(
    label: String,
    content: @Composable () -> Unit,
) {
    val colors = PinballThemeTokens.colors
    Column(
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = colors.brandChalk,
        )
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            content()
        }
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
    val foreground = when (style) {
        AppVariantPillStyle.Overlay -> Color.White.copy(alpha = 0.96f)
        else -> colors.brandInk
    }
    val textStyle = when (style) {
        AppVariantPillStyle.Resource -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.Mini -> MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp)
        AppVariantPillStyle.Overlay -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.Standard -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.MachineTitle -> MaterialTheme.typography.labelMedium
        AppVariantPillStyle.EditSelector -> MaterialTheme.typography.bodyMedium
    }
    val horizontalPadding = when (style) {
        AppVariantPillStyle.Mini -> 6.dp
        AppVariantPillStyle.Overlay -> 7.dp
        AppVariantPillStyle.Resource,
        AppVariantPillStyle.Standard,
        AppVariantPillStyle.MachineTitle,
        AppVariantPillStyle.EditSelector -> 8.dp
    }
    Text(
        text = label,
        style = textStyle,
        color = foreground,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier
            .then(if (maxWidth != null) Modifier.widthIn(max = maxWidth) else Modifier)
            .background(
                colors.brandGold.copy(alpha = 0.16f),
                RoundedCornerShape(999.dp),
            )
            .border(1.dp, colors.brandGold.copy(alpha = 0.34f), RoundedCornerShape(999.dp))
            .padding(
                horizontal = horizontalPadding,
                vertical = when (style) {
                    AppVariantPillStyle.Resource -> 5.dp
                    AppVariantPillStyle.Overlay -> 2.dp
                    else -> 3.dp
                },
            )
            .offset(y = style.verticalOffset),
    )
}

@Composable
internal fun AppTintedPill(
    label: String,
    foreground: Color,
    style: AppVariantPillStyle = AppVariantPillStyle.Resource,
    modifier: Modifier = Modifier,
    maxWidth: Dp? = null,
) {
    val textStyle = when (style) {
        AppVariantPillStyle.Resource -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.Mini -> MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp)
        AppVariantPillStyle.Overlay -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.Standard -> MaterialTheme.typography.labelSmall
        AppVariantPillStyle.MachineTitle -> MaterialTheme.typography.labelMedium
        AppVariantPillStyle.EditSelector -> MaterialTheme.typography.bodyMedium
    }
    val horizontalPadding = when (style) {
        AppVariantPillStyle.Mini -> 6.dp
        AppVariantPillStyle.Overlay -> 7.dp
        AppVariantPillStyle.Resource,
        AppVariantPillStyle.Standard,
        AppVariantPillStyle.MachineTitle,
        AppVariantPillStyle.EditSelector -> 8.dp
    }
    Text(
        text = label,
        style = textStyle,
        color = foreground,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier
            .then(if (maxWidth != null) Modifier.widthIn(max = maxWidth) else Modifier)
            .background(
                foreground.copy(alpha = 0.16f),
                RoundedCornerShape(999.dp),
            )
            .border(1.dp, foreground.copy(alpha = 0.34f), RoundedCornerShape(999.dp))
            .padding(
                horizontal = horizontalPadding,
                vertical = when (style) {
                    AppVariantPillStyle.Resource -> 5.dp
                    AppVariantPillStyle.Overlay -> 2.dp
                    else -> 3.dp
                },
            )
            .offset(y = style.verticalOffset),
    )
}
