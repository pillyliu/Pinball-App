package com.pillyliu.pinprofandroid.settings

import android.text.method.LinkMovementMethod
import android.widget.TextView
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.text.HtmlCompat
import com.pillyliu.pinprofandroid.R
import com.pillyliu.pinprofandroid.data.rememberLplFullNameAccessUnlocked
import com.pillyliu.pinprofandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinprofandroid.data.setShowFullLplLastName
import com.pillyliu.pinprofandroid.data.unlockLplFullNameAccess
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppSwitch
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import com.pillyliu.pinprofandroid.ui.SectionTitle

@Composable
internal fun SettingsPrivacySection() {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val unlocked = rememberLplFullNameAccessUnlocked()
    val showFullLastName = rememberShowFullLplLastName()

    CardContainer {
        SectionTitle("Privacy")
        Text(
            "Lansing Pinball League names are shown as first name plus last initial by default.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (unlocked) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Show full last names for LPL data")
                AppSwitch(
                    checked = showFullLastName,
                    onCheckedChange = { setShowFullLplLastName(context, it) },
                )
            }
        } else {
            var password by remember { mutableStateOf("") }
            var error by remember { mutableStateOf<String?>(null) }
            OutlinedTextField(
                value = password,
                onValueChange = {
                    password = it
                    error = null
                },
                label = { Text("LPL full-name password") },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = androidx.compose.foundation.text.KeyboardActions(
                    onDone = {
                        focusManager.clearFocus()
                        if (unlockLplFullNameAccess(context, password)) {
                            password = ""
                            error = null
                        } else {
                            error = "Incorrect password."
                        }
                    },
                ),
            )
            AppPrimaryButton(
                onClick = {
                    if (unlockLplFullNameAccess(context, password)) {
                        password = ""
                        error = null
                    } else {
                        error = "Incorrect password."
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = password.isNotBlank(),
            ) {
                Text("Unlock Full Names")
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
    }
}

@Composable
internal fun SettingsAboutSection(
    onToggleIntroOverlayForNextLaunch: () -> Unit,
) {
    CardContainer {
        SectionTitle("About")
        Box(
            modifier = Modifier.fillMaxWidth(),
            contentAlignment = Alignment.Center,
        ) {
            Image(
                painter = painterResource(id = R.drawable.intro_launch_logo),
                contentDescription = "PinProf logo",
                modifier = Modifier
                    .fillMaxWidth(0.42f)
                    .heightIn(max = 140.dp)
                    .pointerInput(onToggleIntroOverlayForNextLaunch) {
                        detectTapGestures(
                            onDoubleTap = { onToggleIntroOverlayForNextLaunch() },
                        )
                    },
                contentScale = ContentScale.Fit,
            )
        }
        LinkedHtmlText(
            html = """
                PinProf is built on <a href="https://opdb.org/">OPDB</a> (Open Pinball Database) to provide machine and manufacturer data. Venue search is powered by <a href="https://www.pinballmap.com">Pinball Map</a>. Rulesheets are sourced from <a href="https://tiltforums.com/">Tiltforums</a>, <a href="https://rules.silverballmania.com/">Bob's Guide</a>, <a href="https://pinballprimer.github.io/">Pinball Primer</a>, and <a href="https://replayfoundation.org/papa/learning-center/player-guide/rule-sheets/">PAPA</a>. Playfield images were manually sourced or provided by OPDB. Videos are manually sourced as well as curated from <a href="https://matchplay.events/">Matchplay</a>.
            """.trimIndent(),
        )
    }
}

@Composable
private fun LinkedHtmlText(html: String) {
    val bodyColor = MaterialTheme.colorScheme.onSurfaceVariant.toArgb()
    val linkColor = PinballThemeTokens.colors.brandGold.toArgb()
    AndroidView(
        factory = { context ->
            TextView(context).apply {
                movementMethod = LinkMovementMethod.getInstance()
                setBackgroundColor(Color.Transparent.toArgb())
            }
        },
        update = { textView ->
            textView.text = HtmlCompat.fromHtml(html, HtmlCompat.FROM_HTML_MODE_LEGACY)
            textView.setTextColor(bodyColor)
            textView.setLinkTextColor(linkColor)
        },
    )
}
