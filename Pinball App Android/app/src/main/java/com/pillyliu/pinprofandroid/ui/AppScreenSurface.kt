package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

val LocalBottomBarVisible = compositionLocalOf<MutableState<Boolean>> {
    error("LocalBottomBarVisible not provided")
}

@Composable
fun AppScreen(
    contentPadding: PaddingValues,
    modifier: Modifier = Modifier,
    horizontalPadding: Dp = PinballThemeTokens.spacing.screenHorizontal,
    content: @Composable () -> Unit,
) {
    val spacing = PinballThemeTokens.spacing
    Box(
        modifier = Modifier
            .then(modifier)
            .fillMaxSize()
            .dismissKeyboardOnTapOutside()
    ) {
        PinballAtmosphereBackground()
        Box(
            modifier = Modifier
                .matchParentSize()
                .consumeWindowInsets(contentPadding)
                .padding(contentPadding)
                .padding(horizontal = horizontalPadding, vertical = spacing.screenVerticalCompact),
        ) {
            content()
        }
    }
}

@Composable
fun AppRouteScreen(
    contentPadding: PaddingValues,
    canGoBack: Boolean,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    horizontalPadding: Dp = PinballThemeTokens.spacing.screenHorizontal,
    content: @Composable () -> Unit,
) {
    AppScreen(
        contentPadding = contentPadding,
        modifier = modifier.iosEdgeSwipeBack(enabled = canGoBack, onBack = onBack),
        horizontalPadding = horizontalPadding,
        content = content,
    )
}

@Composable
fun Modifier.iosEdgeSwipeBack(
    enabled: Boolean,
    onBack: () -> Unit,
): Modifier {
    if (!enabled) return this
    val edgeWidthPx = with(LocalDensity.current) { 28.dp.toPx() }
    val triggerDistancePx = with(LocalDensity.current) { 84.dp.toPx() }
    return this.pointerInput(enabled) {
        var tracking = false
        var triggered = false
        var distance = 0f
        detectHorizontalDragGestures(
            onDragStart = { offset ->
                tracking = offset.x <= edgeWidthPx
                triggered = false
                distance = 0f
            },
            onHorizontalDrag = { change, dragAmount ->
                if (!tracking || triggered) return@detectHorizontalDragGestures
                if (dragAmount > 0f) {
                    distance += dragAmount
                    change.consume()
                    if (distance >= triggerDistancePx) {
                        triggered = true
                        onBack()
                    }
                } else if (distance > 0f) {
                    distance = (distance + dragAmount).coerceAtLeast(0f)
                }
            },
            onDragEnd = {
                tracking = false
                triggered = false
                distance = 0f
            },
            onDragCancel = {
                tracking = false
                triggered = false
                distance = 0f
            },
        )
    }
}

@Composable
fun Modifier.dismissKeyboardOnTapOutside(): Modifier {
    val focusManager = LocalFocusManager.current
    val keyboardController = LocalSoftwareKeyboardController.current
    return this.pointerInput(focusManager, keyboardController) {
        detectTapGestures {
            focusManager.clearFocus(force = true)
            keyboardController?.hide()
        }
    }
}

@Composable
fun PinballAtmosphereBackground(modifier: Modifier = Modifier) {
    val colors = PinballThemeTokens.colors
    val atmosphere = PinballThemeTokens.atmosphere
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(colors.atmosphereTop, colors.background, colors.atmosphereBottom),
                ),
            ),
    ) {
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(colors.atmosphereGlow.copy(alpha = atmosphere.primaryGlowAlpha), Color.Transparent),
                        center = Offset(0f, 0f),
                        radius = 900f,
                    ),
                ),
        )
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    Brush.radialGradient(
                        colors = listOf(colors.brandChalk.copy(alpha = atmosphere.secondaryGlowAlpha), Color.Transparent),
                        center = Offset(1400f, 2600f),
                        radius = 1200f,
                    ),
                ),
        )
    }
}
