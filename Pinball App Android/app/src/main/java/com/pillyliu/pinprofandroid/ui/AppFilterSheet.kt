package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppFilterSheet(
    title: String,
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    val spacing = PinballThemeTokens.spacing
    val typography = PinballThemeTokens.typography
    ModalBottomSheet(onDismissRequest = onDismissRequest) {
        Column(
            modifier = modifier
                .fillMaxWidth()
                .padding(horizontal = spacing.screenHorizontal, vertical = spacing.controlVertical),
            verticalArrangement = Arrangement.spacedBy(spacing.screenVerticalCompact + spacing.controlVertical),
        ) {
            Text(
                text = title,
                color = PinballThemeTokens.colors.shellSelectedContent,
                style = typography.sectionTitle,
            )
            content()
            TextButton(
                onClick = onDismissRequest,
                modifier = Modifier.align(Alignment.End),
            ) {
                Text("Done", style = typography.shellLabel)
            }
        }
    }
}
