package com.pillyliu.pinprofandroid.league

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import java.text.NumberFormat

@Composable
internal fun leagueRankColor(rank: Int): Color {
    val colors = PinballThemeTokens.colors
    return when (rank) {
        1 -> colors.podiumGold
        2 -> colors.podiumSilver
        3 -> colors.podiumBronze
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
}

internal fun Long.toGroupNumber(): String = NumberFormat.getIntegerInstance().format(this)

internal fun Double.toWholeNumber(): String = NumberFormat.getIntegerInstance().format(this.toLong())
