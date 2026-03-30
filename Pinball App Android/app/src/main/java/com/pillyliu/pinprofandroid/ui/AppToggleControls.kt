package com.pillyliu.pinprofandroid.ui

import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

@Composable
fun pinballSwitchColors() = SwitchDefaults.colors(
    checkedThumbColor = PinballThemeTokens.colors.brandGold,
    checkedTrackColor = PinballThemeTokens.colors.brandGold.copy(alpha = 0.42f),
    checkedBorderColor = PinballThemeTokens.colors.brandGold.copy(alpha = 0.62f),
    checkedIconColor = Color(0xFF261700),
    uncheckedThumbColor = PinballThemeTokens.colors.controlBackground,
    uncheckedTrackColor = PinballThemeTokens.colors.controlBackground.copy(alpha = 0.92f),
    uncheckedBorderColor = PinballThemeTokens.colors.brandChalk.copy(alpha = 0.36f),
    disabledCheckedThumbColor = PinballThemeTokens.colors.brandGold.copy(alpha = 0.46f),
    disabledCheckedTrackColor = PinballThemeTokens.colors.brandGold.copy(alpha = 0.18f),
    disabledCheckedBorderColor = PinballThemeTokens.colors.brandGold.copy(alpha = 0.26f),
    disabledUncheckedThumbColor = PinballThemeTokens.colors.controlBackground.copy(alpha = 0.55f),
    disabledUncheckedTrackColor = PinballThemeTokens.colors.controlBackground.copy(alpha = 0.42f),
    disabledUncheckedBorderColor = PinballThemeTokens.colors.brandChalk.copy(alpha = 0.18f),
)

@Composable
fun AppSwitch(
    checked: Boolean,
    onCheckedChange: ((Boolean) -> Unit)?,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Switch(
        checked = checked,
        onCheckedChange = onCheckedChange,
        modifier = modifier,
        enabled = enabled,
        colors = pinballSwitchColors(),
    )
}

@Composable
fun pinballCheckboxColors() = CheckboxDefaults.colors(
    checkedColor = PinballThemeTokens.colors.brandGold.copy(alpha = 0.92f),
    checkmarkColor = Color(0xFF261700),
    uncheckedColor = PinballThemeTokens.colors.brandChalk.copy(alpha = 0.84f),
    disabledCheckedColor = PinballThemeTokens.colors.brandGold.copy(alpha = 0.42f),
    disabledUncheckedColor = PinballThemeTokens.colors.brandChalk.copy(alpha = 0.34f),
)

@Composable
fun AppCheckbox(
    checked: Boolean,
    onCheckedChange: ((Boolean) -> Unit)?,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Checkbox(
        checked = checked,
        onCheckedChange = onCheckedChange,
        modifier = modifier,
        enabled = enabled,
        colors = pinballCheckboxColors(),
    )
}
