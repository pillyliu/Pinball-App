package com.pillyliu.pinprofandroid.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Immutable
data class PinballSemanticColors(
    val background: Color,
    val panel: Color,
    val border: Color,
    val brandInk: Color,
    val brandGold: Color,
    val brandChalk: Color,
    val atmosphereTop: Color,
    val atmosphereBottom: Color,
    val atmosphereGlow: Color,
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

@Immutable
data class PinballTypographyTokens(
    val sectionTitle: TextStyle,
    val emptyState: TextStyle,
    val filterSummary: TextStyle,
    val dropdown: TextStyle,
    val dropdownItem: TextStyle,
    val tableCell: TextStyle,
    val shellLabel: TextStyle,
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

internal val LocalPinballTypographyTokens = compositionLocalOf<PinballTypographyTokens> {
    error("LocalPinballTypographyTokens not provided")
}

object PinballThemeTokens {
    val colors: PinballSemanticColors
        @Composable get() = LocalPinballSemanticColors.current

    val shapes: PinballShapeTokens
        @Composable get() = LocalPinballShapeTokens.current

    val spacing: PinballSpacingTokens
        @Composable get() = LocalPinballSpacingTokens.current

    val typography: PinballTypographyTokens
        @Composable get() = LocalPinballTypographyTokens.current
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

internal val DefaultPinballTypographyTokens = PinballTypographyTokens(
    sectionTitle = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.SemiBold),
    emptyState = TextStyle(fontSize = 13.sp),
    filterSummary = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.SemiBold),
    dropdown = TextStyle(fontSize = 13.sp),
    dropdownItem = TextStyle(fontSize = 12.sp),
    tableCell = TextStyle(fontSize = 13.sp),
    shellLabel = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium),
)
