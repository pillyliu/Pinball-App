package com.pillyliu.pinballandroid.library

import android.os.Bundle
import android.os.Parcel
import androidx.compose.runtime.saveable.Saver
import org.commonmark.ext.gfm.tables.TablesExtension
import org.commonmark.parser.Parser
import org.commonmark.renderer.html.HtmlRenderer

internal const val RULESHEET_BOTTOM_MARKDOWN_FILLER = "\n\n<br>\n<br>\n"

private val markdownExtensions = listOf(TablesExtension.create())
private val markdownParser: Parser = Parser.builder().extensions(markdownExtensions).build()
private val markdownRenderer: HtmlRenderer = HtmlRenderer.builder().extensions(markdownExtensions).build()

internal val bundleParcelSaver = Saver<Bundle, ByteArray>(
    save = { bundle ->
        val parcel = Parcel.obtain()
        try {
            bundle.writeToParcel(parcel, 0)
            parcel.marshall()
        } finally {
            parcel.recycle()
        }
    },
    restore = { bytes ->
        val parcel = Parcel.obtain()
        try {
            parcel.unmarshall(bytes, 0, bytes.size)
            parcel.setDataPosition(0)
            Bundle.CREATOR.createFromParcel(parcel)
        } finally {
            parcel.recycle()
        }
    },
)

internal fun normalizeRulesheet(input: String): String {
    var text = input.replace("\r\n", "\n")
    if (text.startsWith("---\n")) {
        val start = 4
        val end = text.indexOf("\n---", start)
        if (end >= 0) {
            val after = text.indexOf('\n', end + 4)
            if (after >= 0 && after + 1 < text.length) {
                text = text.substring(after + 1)
            }
        }
    }
    return text.trim()
}

internal fun renderMarkdownHtml(markdown: String): String {
    return markdownRenderer.render(markdownParser.parse(markdown))
}
