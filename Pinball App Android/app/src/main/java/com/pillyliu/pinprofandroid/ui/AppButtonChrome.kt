package com.pillyliu.pinprofandroid.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.shape.RoundedCornerShape

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
    val shape = RoundedCornerShape(shapes.controlCorner)
    val interactionSource = remember { MutableInteractionSource() }
    val pressed by interactionSource.collectIsPressedAsState()

    val containerColor by animateColorAsState(
        targetValue = when {
            !enabled -> colors.brandGold.copy(alpha = 0.24f)
            pressed -> lerp(colors.brandGold.copy(alpha = 0.92f), colors.brandOnGold, 0.22f)
            else -> colors.brandGold.copy(alpha = 0.92f)
        },
        label = "appPrimaryButtonContainerColor",
    )

    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.defaultMinSize(minHeight = minHeight),
        shape = shape,
        contentPadding = contentPadding,
        interactionSource = interactionSource,
        colors = ButtonDefaults.buttonColors(
            containerColor = containerColor,
            contentColor = colors.brandOnGold,
            disabledContainerColor = colors.brandGold.copy(alpha = 0.24f),
            disabledContentColor = colors.brandOnGold.copy(alpha = 0.55f),
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
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.defaultMinSize(minHeight = minHeight),
        shape = RoundedCornerShape(shapes.controlCorner),
        border = BorderStroke(
            1.dp,
            if (enabled) MaterialTheme.colorScheme.error.copy(alpha = 0.34f) else MaterialTheme.colorScheme.error.copy(alpha = 0.18f),
        ),
        contentPadding = contentPadding,
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = MaterialTheme.colorScheme.error.copy(alpha = 0.10f),
            contentColor = MaterialTheme.colorScheme.error,
            disabledContainerColor = MaterialTheme.colorScheme.error.copy(alpha = 0.06f),
            disabledContentColor = MaterialTheme.colorScheme.error.copy(alpha = 0.55f),
        ),
        content = content,
    )
}
