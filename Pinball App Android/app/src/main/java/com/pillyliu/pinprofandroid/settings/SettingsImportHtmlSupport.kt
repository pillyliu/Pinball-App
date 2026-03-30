package com.pillyliu.pinprofandroid.settings

import android.text.method.LinkMovementMethod
import android.widget.TextView
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.text.HtmlCompat
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens

@Composable
internal fun LinkedHtmlText(
    html: String,
    modifier: Modifier = Modifier,
) {
    val bodyColor = MaterialTheme.colorScheme.onSurfaceVariant
    val linkColor = PinballThemeTokens.colors.brandGold
    AndroidView(
        modifier = modifier,
        factory = { context ->
            TextView(context).apply {
                movementMethod = LinkMovementMethod.getInstance()
                linksClickable = true
                setBackgroundColor(Color.Transparent.toArgb())
            }
        },
        update = { view ->
            view.textSize = 12f
            view.setTextColor(bodyColor.toArgb())
            view.setLinkTextColor(linkColor.toArgb())
            view.text = HtmlCompat.fromHtml(html, HtmlCompat.FROM_HTML_MODE_LEGACY)
        },
    )
}
