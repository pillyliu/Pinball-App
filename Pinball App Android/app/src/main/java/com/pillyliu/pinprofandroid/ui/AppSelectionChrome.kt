package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LocalMinimumInteractiveComponentSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun AppSelectableRowButton(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    highlightCorner: Dp = PinballThemeTokens.shapes.controlCorner,
) {
    val colors = PinballThemeTokens.colors
    val highlightShape = RoundedCornerShape(highlightCorner)
    CompositionLocalProvider(LocalMinimumInteractiveComponentSize provides 0.dp) {
        Box(
            modifier = modifier
                .defaultMinSize(minHeight = 0.dp)
                .clip(highlightShape)
                .clickable(
                    role = Role.Button,
                    onClick = onClick,
                )
                .background(
                    if (selected) colors.brandGold.copy(alpha = 0.14f) else Color.Transparent,
                    shape = highlightShape,
                )
                .border(
                    width = 1.dp,
                    color = if (selected) colors.brandGold.copy(alpha = 0.42f) else Color.Transparent,
                    shape = highlightShape,
                )
                .padding(horizontal = 10.dp, vertical = 4.dp),
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
