package com.pillyliu.pinprofandroid.library

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import java.util.Locale

internal fun buildRulesheetHtml(
    renderedBody: String,
    bodyColorHex: String,
    mutedColorHex: String,
    linkColorHex: String,
    linkSoftHex: String,
    codeBgHex: String,
    panelHex: String,
    panelStrongHex: String,
    tableBorderHex: String,
    blockquoteBarHex: String,
): String {
    val styles = rulesheetHtmlStyles(
        bodyColorHex = bodyColorHex,
        mutedColorHex = mutedColorHex,
        linkColorHex = linkColorHex,
        linkSoftHex = linkSoftHex,
        codeBgHex = codeBgHex,
        panelHex = panelHex,
        panelStrongHex = panelStrongHex,
        tableBorderHex = tableBorderHex,
        blockquoteBarHex = blockquoteBarHex,
    )
    val tableScript = rulesheetTableWrapperScript()
    return """
        <!doctype html>
        <html>
        <head>
            <meta charset=\"utf-8\" />
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
            <style>
                $styles
            </style>
        </head>
        <body>
            <article id=\"content\">$renderedBody</article>
            <script>
                $tableScript
            </script>
        </body>
        </html>
    """.trimIndent()
}

internal fun Color.toCssHex(): String {
    val argb = toArgb()
    val red = (argb shr 16) and 0xFF
    val green = (argb shr 8) and 0xFF
    val blue = argb and 0xFF
    return String.format(Locale.US, "#%02X%02X%02X", red, green, blue)
}
