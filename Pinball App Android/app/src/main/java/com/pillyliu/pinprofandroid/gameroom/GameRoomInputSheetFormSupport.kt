package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.runtime.Composable
import androidx.compose.material3.Text
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSecondaryButton

@Composable
internal fun GameRoomInputSheetFormBody(
    context: GameRoomInputSheetContext,
    openIssues: List<MachineIssue>,
) {
    when (context.selectedSheet) {
        GameRoomInputSheet.CleanGlass,
        GameRoomInputSheet.CleanPlayfield,
        GameRoomInputSheet.SwapBalls,
        GameRoomInputSheet.LevelMachine,
        GameRoomInputSheet.GeneralInspection,
        GameRoomInputSheet.CheckPitch -> GameRoomMaintenanceInputFields(context)
        GameRoomInputSheet.LogIssue,
        GameRoomInputSheet.ResolveIssue -> GameRoomIssueInputFields(context, openIssues)
        GameRoomInputSheet.OwnershipUpdate,
        GameRoomInputSheet.InstallMod,
        GameRoomInputSheet.ReplacePart,
        GameRoomInputSheet.LogPlays,
        GameRoomInputSheet.AddMedia -> GameRoomMachineEventInputFields(context)
    }

    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        AppSecondaryButton(
            onClick = {
                context.onIssueDraftAttachmentsChange(emptyList())
                context.onDismiss()
            },
        ) {
            Text("Cancel")
        }
        AppPrimaryButton(
            onClick = { saveGameRoomInputSheet(context) },
            enabled = when (context.selectedSheet) {
                GameRoomInputSheet.LogIssue -> context.inputIssueSymptomDraft.isNotBlank()
                GameRoomInputSheet.ResolveIssue -> !context.inputResolveIssueIDDraft.isNullOrBlank()
                GameRoomInputSheet.LogPlays -> context.inputPlayTotalDraft.isNotBlank()
                else -> true
            },
        ) {
            Text("Save")
        }
    }
}
