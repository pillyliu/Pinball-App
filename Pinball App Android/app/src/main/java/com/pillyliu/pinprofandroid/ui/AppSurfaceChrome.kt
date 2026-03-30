package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalMinimumInteractiveComponentSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

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
    size: Dp = 40.dp,
    iconSize: Dp = 21.dp,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) {
        IconButton(
            onClick = onClick,
            modifier = modifier
                .defaultMinSize(minWidth = 0.dp, minHeight = 0.dp)
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
}

@Composable
fun AppCompactIconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    destructive: Boolean = false,
    tintOverride: Color? = null,
    size: Dp = 32.dp,
    iconSize: Dp = 18.dp,
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    val borderColor = if (destructive) {
        androidx.compose.material3.MaterialTheme.colorScheme.error.copy(alpha = 0.32f)
    } else {
        colors.brandGold.copy(alpha = 0.28f)
    }
    val contentColor = tintOverride ?: if (destructive) androidx.compose.material3.MaterialTheme.colorScheme.error else colors.brandInk
    CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) {
        IconButton(
            onClick = onClick,
            enabled = enabled,
            modifier = modifier
                .defaultMinSize(minWidth = 0.dp, minHeight = 0.dp)
                .size(size)
                .background(
                    colors.controlBackground.copy(alpha = if (enabled) 0.94f else 0.66f),
                    RoundedCornerShape(shapes.controlCorner),
                )
                .border(
                    1.dp,
                    borderColor.copy(alpha = if (enabled) borderColor.alpha else borderColor.alpha * 0.6f),
                    RoundedCornerShape(shapes.controlCorner),
                ),
        ) {
            Icon(
                imageVector = icon,
                contentDescription = contentDescription,
                tint = contentColor.copy(alpha = if (enabled) 1f else 0.5f),
                modifier = Modifier.size(iconSize),
            )
        }
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
