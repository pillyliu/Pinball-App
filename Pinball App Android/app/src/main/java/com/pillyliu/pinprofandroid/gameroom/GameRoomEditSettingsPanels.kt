package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppCompactIconButton
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer

@Composable
internal fun GameRoomVenueNameSettingsCard(
    context: GameRoomEditSettingsContext,
) {
    CardContainer {
        SectionHeader(
            title = "Name",
            expanded = context.nameExpanded,
            onToggle = { context.onNameExpandedChange(!context.nameExpanded) },
        )
        if (context.nameExpanded) {
            OutlinedTextField(
                value = context.venueNameDraft,
                onValueChange = context.onVenueNameDraftChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                label = { Text("GameRoom Name") },
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                AppPrimaryButton(
                    onClick = {
                        context.onSaveVenueName()
                        context.onShowSaveFeedback("GameRoom name saved")
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Save")
                }
            }
        }
    }
}
