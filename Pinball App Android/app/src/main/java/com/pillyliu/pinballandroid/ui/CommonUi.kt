package com.pillyliu.pinballandroid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

val AppBg = Color(0xFF0A0A0A)
val CardBg = Color(0xFF171717)
val Border = Color(0xFF343434)
val ControlBg = Color(0xFF171717)
val ControlBorder = Color(0xFF404040)
val LocalBottomBarVisible = compositionLocalOf<MutableState<Boolean>> {
    error("LocalBottomBarVisible not provided")
}

@Composable
fun AppScreen(contentPadding: PaddingValues, content: @Composable () -> Unit) {
    val backgroundBrush = Brush.radialGradient(
        colors = listOf(Color(0x2338BDF8), Color.Transparent),
        center = Offset(220f, -80f),
        radius = 980f,
    )
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(AppBg)
            .background(backgroundBrush)
            .padding(contentPadding)
            .padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        content()
    }
}

@Composable
fun CardContainer(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(CardBg, RoundedCornerShape(12.dp))
            .border(1.dp, Border, RoundedCornerShape(12.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        content()
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(text = text, color = Color.White, fontWeight = FontWeight.SemiBold)
}

@Composable
fun EmptyLabel(text: String) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 20.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text = text, color = Color(0xFFBDBDBD))
    }
}
