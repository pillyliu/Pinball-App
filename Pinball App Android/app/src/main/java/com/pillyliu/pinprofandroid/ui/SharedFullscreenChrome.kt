package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape

@Composable
fun AppFullscreenStatusOverlay(
    text: String,
    modifier: Modifier = Modifier,
    showsProgress: Boolean = false,
    foregroundColor: Color = PinballThemeTokens.colors.brandChalk,
) {
    val colors = PinballThemeTokens.colors
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .padding(20.dp)
                .background(
                    color = colors.panel.copy(alpha = 0.92f),
                    shape = RoundedCornerShape(18.dp),
                )
                .border(
                    width = 1.dp,
                    color = colors.brandGold.copy(alpha = 0.24f),
                    shape = RoundedCornerShape(18.dp),
                )
                .padding(horizontal = 18.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (showsProgress) {
                CircularProgressIndicator(color = colors.brandGold)
            }
            Text(
                text = text,
                color = foregroundColor,
                style = PinballThemeTokens.typography.emptyState,
                textAlign = TextAlign.Center,
            )
        }
    }
}
