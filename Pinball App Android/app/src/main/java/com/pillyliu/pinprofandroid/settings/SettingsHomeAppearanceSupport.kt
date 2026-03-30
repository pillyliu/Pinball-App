package com.pillyliu.pinprofandroid.settings

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.pillyliu.pinprofandroid.data.AppDisplayMode
import com.pillyliu.pinprofandroid.data.rememberAppDisplayMode
import com.pillyliu.pinprofandroid.data.setAppDisplayMode
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle
import com.pillyliu.pinprofandroid.ui.pinballSegmentedButtonColors

@Composable
internal fun SettingsAppearanceSection() {
    val context = LocalContext.current
    val displayMode = rememberAppDisplayMode()

    CardContainer {
        SectionTitle("Appearance")
        Text(
            "Choose whether PinProf follows the system appearance or stays in light or dark mode.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        SingleChoiceSegmentedButtonRow(
            modifier = Modifier.fillMaxWidth(),
        ) {
            AppDisplayMode.entries.forEachIndexed { index, mode ->
                SegmentedButton(
                    selected = displayMode == mode,
                    onClick = { setAppDisplayMode(context, mode) },
                    label = { Text(mode.label) },
                    colors = pinballSegmentedButtonColors(),
                    shape = SegmentedButtonDefaults.itemShape(index = index, count = AppDisplayMode.entries.size),
                )
            }
        }
    }
}
