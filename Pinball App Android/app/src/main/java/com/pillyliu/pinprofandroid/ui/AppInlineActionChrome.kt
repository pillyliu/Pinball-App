package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.shape.RoundedCornerShape

@Composable
fun AppInlineActionChip(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    destructive: Boolean = false,
    enabled: Boolean = true,
    showsBorder: Boolean = true,
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
        border = if (showsBorder) BorderStroke(1.dp, borderColor) else null,
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
    fontSize: TextUnit = TextUnit.Unspecified,
) {
    val colors = PinballThemeTokens.colors
    Text(
        text = text,
        modifier = modifier.clickable(onClick = onClick),
        color = colors.brandGold,
        fontSize = fontSize,
        fontWeight = FontWeight.SemiBold,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
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
