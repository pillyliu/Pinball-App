package com.pillyliu.pinprofandroid.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Immutable
data class PinballSemanticColors(
    val background: Color,
    val panel: Color,
    val border: Color,
    val controlBackground: Color,
    val controlBorder: Color,
    val rowOdd: Color,
    val rowEven: Color,
    val shellSurface: Color,
    val shellIndicator: Color,
    val shellSelectedContent: Color,
    val shellUnselectedContent: Color,
    val statsHigh: Color,
    val statsLow: Color,
    val statsMeanMedian: Color,
    val podiumGold: Color,
    val podiumSilver: Color,
    val podiumBronze: Color,
    val targetGreat: Color,
    val targetMain: Color,
    val targetFloor: Color,
    val rulesheetLink: Color,
)

@Immutable
data class PinballShapeTokens(
    val panelCorner: Dp,
    val controlCorner: Dp,
)

@Immutable
data class PinballSpacingTokens(
    val screenHorizontal: Dp,
    val screenVerticalCompact: Dp,
    val panelPadding: Dp,
    val controlHorizontal: Dp,
    val controlVertical: Dp,
    val shellBarHeight: Dp,
    val shellBottomPadding: Dp,
    val shellContentBottomInset: Dp,
)

internal val LocalPinballSemanticColors = compositionLocalOf<PinballSemanticColors> {
    error("LocalPinballSemanticColors not provided")
}

internal val LocalPinballShapeTokens = compositionLocalOf<PinballShapeTokens> {
    error("LocalPinballShapeTokens not provided")
}

internal val LocalPinballSpacingTokens = compositionLocalOf<PinballSpacingTokens> {
    error("LocalPinballSpacingTokens not provided")
}

object PinballThemeTokens {
    val colors: PinballSemanticColors
        @Composable get() = LocalPinballSemanticColors.current

    val shapes: PinballShapeTokens
        @Composable get() = LocalPinballShapeTokens.current

    val spacing: PinballSpacingTokens
        @Composable get() = LocalPinballSpacingTokens.current
}

internal val DefaultPinballShapeTokens = PinballShapeTokens(
    panelCorner = 12.dp,
    controlCorner = 10.dp,
)

internal val DefaultPinballSpacingTokens = PinballSpacingTokens(
    screenHorizontal = 14.dp,
    screenVerticalCompact = 8.dp,
    panelPadding = 12.dp,
    controlHorizontal = 12.dp,
    controlVertical = 6.dp,
    shellBarHeight = 66.dp,
    shellBottomPadding = 8.dp,
    shellContentBottomInset = 74.dp,
)
