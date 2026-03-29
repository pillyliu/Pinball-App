package com.pillyliu.pinprofandroid.library

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.unit.dp
import com.halilibo.richtext.markdown.Markdown
import com.halilibo.richtext.ui.RichTextStyle
import com.halilibo.richtext.ui.material3.RichText
import com.halilibo.richtext.ui.string.RichTextStringStyle
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle

@Composable
internal fun LibraryDetailGameInfoCard(
    infoStatus: String,
    markdown: String?,
) {
    CardContainer {
        SectionTitle("Game Info")
        when (infoStatus) {
            "loading" -> AppInlineTaskStatus(text = "Loading…", showsProgress = true)
            "missing" -> AppPanelEmptyCard(text = "No game info yet.")
            "error" -> AppInlineTaskStatus(text = "Could not load game info.", isError = true)
            else -> CompositionLocalProvider(LocalContentColor provides MaterialTheme.colorScheme.onSurface) {
                val linkColor = MaterialTheme.colorScheme.primary
                val gameInfoStyle = remember {
                    RichTextStyle.Default.copy(
                        stringStyle = RichTextStringStyle.Default.copy(
                            linkStyle = SpanStyle(color = linkColor),
                        ),
                    )
                }
                RichText(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 20.dp),
                    style = gameInfoStyle,
                ) {
                    Markdown(markdown.orEmpty())
                }
            }
        }
    }
}
