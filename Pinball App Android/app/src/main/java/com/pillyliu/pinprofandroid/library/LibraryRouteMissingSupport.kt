package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton

@Composable
internal fun LibraryRouteMissingScreen(
    contentPadding: PaddingValues,
    games: List<PinballGame>,
    message: String,
    onBack: () -> Unit,
) {
    if (games.isEmpty()) {
        AppScreen(contentPadding) {
            AppPanelEmptyCard(text = message)
        }
    } else {
        AppScreen(contentPadding) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                AppPanelEmptyCard(text = message)
                AppSecondaryButton(onClick = onBack) {
                    Text("Back to Library")
                }
            }
        }
    }
}
