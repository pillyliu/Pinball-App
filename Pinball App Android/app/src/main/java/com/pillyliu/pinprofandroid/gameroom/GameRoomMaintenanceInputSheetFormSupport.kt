package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

@Composable
internal fun GameRoomMaintenanceInputFields(context: GameRoomInputSheetContext) {
    when (context.selectedSheet) {
        GameRoomInputSheet.CleanGlass,
        GameRoomInputSheet.CleanPlayfield,
        GameRoomInputSheet.SwapBalls,
        GameRoomInputSheet.LevelMachine,
        GameRoomInputSheet.GeneralInspection -> {
            if (
                context.selectedSheet == GameRoomInputSheet.CleanGlass ||
                context.selectedSheet == GameRoomInputSheet.CleanPlayfield
            ) {
                OutlinedTextField(
                    value = context.inputConsumableDraft,
                    onValueChange = context.onInputConsumableDraftChange,
                    label = { Text("Cleaner / Consumable") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
            }
            OutlinedTextField(
                value = context.inputNotesDraft,
                onValueChange = context.onInputNotesDraftChange,
                label = { Text("Notes") },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        GameRoomInputSheet.CheckPitch -> {
            OutlinedTextField(
                value = context.inputPitchValueDraft,
                onValueChange = context.onInputPitchValueDraftChange,
                label = { Text("Pitch (degrees)") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            OutlinedTextField(
                value = context.inputPitchPointDraft,
                onValueChange = context.onInputPitchPointDraftChange,
                label = { Text("Measurement Point") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )
            OutlinedTextField(
                value = context.inputNotesDraft,
                onValueChange = context.onInputNotesDraftChange,
                label = { Text("Notes") },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        else -> Unit
    }
}
