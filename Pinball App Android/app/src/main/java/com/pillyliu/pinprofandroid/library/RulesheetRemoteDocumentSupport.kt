package com.pillyliu.pinprofandroid.library

import java.net.HttpURLConnection
import java.net.URL

internal data class RemoteFetchedDocument(
    val text: String,
    val mimeType: String?,
    val finalUrl: String,
)

internal fun fetchRemoteRulesheetDocument(rawUrl: String): RemoteFetchedDocument {
    var connection: HttpURLConnection? = null
    return try {
        connection = URL(rawUrl).openConnection() as HttpURLConnection
        connection.instanceFollowRedirects = true
        connection.connectTimeout = 20_000
        connection.readTimeout = 20_000
        connection.setRequestProperty("User-Agent", "Mozilla/5.0 PinballApp/1.0")
        connection.connect()
        val code = connection.responseCode
        if (code !in 200..299) error("Remote rulesheet request failed ($code)")
        val text = connection.inputStream.bufferedReader().use { it.readText() }
        RemoteFetchedDocument(
            text = text,
            mimeType = connection.contentType,
            finalUrl = connection.url.toString(),
        )
    } finally {
        connection?.disconnect()
    }
}

internal fun legacyFetchUrl(source: RulesheetRemoteSource): String {
    if (source !is RulesheetRemoteSource.BobsGuide) return source.url
    if (!source.url.contains("silverballmania.com")) return source.url
    val slug = source.url.substringAfterLast('/').takeIf { it.isNotBlank() } ?: return source.url
    return "https://rules.silverballmania.com/print/$slug"
}

internal fun cleanupPrimerHtml(html: String): String {
    var cleaned = stripHtml(
        extractBodyHtml(html) ?: html,
        listOf(
            "(?is)<iframe\\b[^>]*>.*?</iframe>",
            "(?is)<script\\b[^>]*>.*?</script>",
            "(?is)<style\\b[^>]*>.*?</style>",
            "(?is)<!--.*?-->",
        ),
    )
    val firstHeading = Regex("(?is)<h1\\b[^>]*>").find(cleaned)?.range?.first
    if (firstHeading != null && firstHeading >= 0) {
        cleaned = cleaned.substring(firstHeading)
    }
    return cleaned.trim()
}

internal fun cleanupLegacyHtml(
    html: String,
    mimeType: String?,
    source: RulesheetRemoteSource,
): String {
    if (shouldTreatAsPlainText(html, mimeType)) {
        return "<pre class=\"rulesheet-preformatted\">${html.htmlEscaped()}</pre>"
    }
    if (source is RulesheetRemoteSource.BobsGuide) {
        extractMainHtml(html)?.let { main ->
            return stripHtml(
                main,
                listOf(
                    "(?is)<script\\b[^>]*>.*?</script>",
                    "(?is)<!--.*?-->",
                    "(?is)<a\\b[^>]*title=\"Print\"[^>]*>.*?</a>",
                ),
            ).trim()
        }
    }
    return stripHtml(
        extractBodyHtml(html) ?: html,
        listOf(
            "(?is)<\\?.*?\\?>",
            "(?is)<script\\b[^>]*>.*?</script>",
            "(?is)<style\\b[^>]*>.*?</style>",
            "(?is)<iframe\\b[^>]*>.*?</iframe>",
            "(?is)<!--.*?-->",
            "(?is)</?(html|head|body|meta|link)\\b[^>]*>",
        ),
    ).trim()
}

internal fun attributionHtml(
    source: RulesheetRemoteSource,
    displayUrl: String,
    updatedAt: String?,
): String {
    val updatedText = updatedAt?.takeIf { it.isNotBlank() }?.let { " | Updated: ${it.htmlEscaped()}" } ?: ""
    return """
        <small class="rulesheet-attribution">Source: ${source.sourceName.htmlEscaped()} | ${source.originalLinkLabel.htmlEscaped()}: <a href="${displayUrl.htmlEscaped()}">link</a>$updatedText | ${source.detailsText.htmlEscaped()} | Reformatted for readability and mobile use.</small>
    """.trimIndent()
}

private fun shouldTreatAsPlainText(html: String, mimeType: String?): Boolean {
    if (mimeType?.contains("text/plain", ignoreCase = true) == true) return true
    return !Regex("<[a-zA-Z!/][^>]*>").containsMatchIn(html)
}

private fun extractMainHtml(html: String): String? =
    Regex("(?is)<main\\b[^>]*>(.*?)</main>").find(html)?.groupValues?.getOrNull(1)

private fun extractBodyHtml(html: String): String? =
    Regex("(?is)<body\\b[^>]*>(.*?)</body>").find(html)?.groupValues?.getOrNull(1)

private fun stripHtml(html: String, patterns: List<String>): String {
    return patterns.fold(html) { current, pattern -> current.replace(Regex(pattern), "") }
}

internal fun String.htmlEscaped(): String {
    return replace("&", "&amp;")
        .replace("\"", "&quot;")
        .replace("'", "&#39;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
}
