package com.pillyliu.pinballandroid.library

import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

internal data class RulesheetRenderContent(
    val kind: RulesheetRenderKind,
    val body: String,
    val baseUrl: String,
)

internal enum class RulesheetRenderKind {
    MARKDOWN,
    HTML,
}

private data class RemoteFetchedDocument(
    val text: String,
    val mimeType: String?,
    val finalUrl: String,
)

private data class TiltForumsParsedDocument(
    val cooked: String,
    val canonicalUrl: String,
    val updatedAt: String?,
)

internal object RemoteRulesheetLoader {
    fun load(source: RulesheetRemoteSource): RulesheetRenderContent {
        return when (source) {
            is RulesheetRemoteSource.TiltForums -> loadTiltForums(source)
            is RulesheetRemoteSource.PinballPrimer -> loadPrimer(source)
            is RulesheetRemoteSource.BobsGuide, is RulesheetRemoteSource.Papa -> loadLegacyHtml(source)
        }
    }

    private fun loadTiltForums(source: RulesheetRemoteSource.TiltForums): RulesheetRenderContent {
        val apiUrl = tiltForumsApiUrl(source.url)
        val fetched = fetch(apiUrl)
        val parsed = parseTiltForumsPayload(fetched.text, source.url)
        return RulesheetRenderContent(
            kind = RulesheetRenderKind.HTML,
            body = """
                ${attributionHtml(source, parsed.canonicalUrl, parsed.updatedAt)}
                <div class="pinball-rulesheet remote-rulesheet tiltforums-rulesheet">
                ${parsed.cooked}
                </div>
            """.trimIndent(),
            baseUrl = parsed.canonicalUrl,
        )
    }

    private fun loadPrimer(source: RulesheetRemoteSource.PinballPrimer): RulesheetRenderContent {
        val fetched = fetch(source.url)
        return RulesheetRenderContent(
            kind = RulesheetRenderKind.HTML,
            body = """
                ${attributionHtml(source, fetched.finalUrl, null)}
                <div class="pinball-rulesheet remote-rulesheet primer-rulesheet">
                ${cleanupPrimerHtml(fetched.text)}
                </div>
            """.trimIndent(),
            baseUrl = fetched.finalUrl,
        )
    }

    private fun loadLegacyHtml(source: RulesheetRemoteSource): RulesheetRenderContent {
        val fetched = fetch(legacyFetchUrl(source))
        return RulesheetRenderContent(
            kind = RulesheetRenderKind.HTML,
            body = """
                ${attributionHtml(source, fetched.finalUrl, null)}
                <div class="pinball-rulesheet remote-rulesheet legacy-rulesheet">
                ${cleanupLegacyHtml(fetched.text, fetched.mimeType, source)}
                </div>
            """.trimIndent(),
            baseUrl = fetched.finalUrl,
        )
    }

    private fun fetch(rawUrl: String): RemoteFetchedDocument {
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

    private fun tiltForumsApiUrl(rawUrl: String): String {
        return if (rawUrl.contains("/posts/") && rawUrl.lowercase().endsWith(".json")) {
            rawUrl
        } else {
            rawUrl.substringBefore('?').let { if (it.lowercase().endsWith(".json")) it else "$it.json" }
        }
    }

    private fun parseTiltForumsPayload(payload: String, fallbackUrl: String): TiltForumsParsedDocument {
        val root = JSONObject(payload)
        val posts = root.optJSONObject("post_stream")?.optJSONArray("posts")
        val post = when {
            posts != null && posts.length() > 0 -> posts.optJSONObject(0)
            else -> root
        } ?: error("Invalid Tilt Forums payload.")
        val cooked = post.optString("cooked").trim().ifBlank { error("Missing Tilt Forums content.") }
        val topicSlug = post.optString("topic_slug").ifBlank { null }
        val topicId = post.optInt("topic_id").takeIf { it > 0 }
        val canonicalUrl = if (topicSlug != null && topicId != null) {
            "https://tiltforums.com/t/$topicSlug/$topicId"
        } else {
            canonicalTopicUrl(fallbackUrl)
        }
        return TiltForumsParsedDocument(
            cooked = cooked,
            canonicalUrl = canonicalUrl,
            updatedAt = post.optString("updated_at").ifBlank { null },
        )
    }

    private fun canonicalTopicUrl(rawUrl: String): String = rawUrl.substringBefore('?').removeSuffix(".json")

    private fun legacyFetchUrl(source: RulesheetRemoteSource): String {
        if (source !is RulesheetRemoteSource.BobsGuide) return source.url
        if (!source.url.contains("silverballmania.com")) return source.url
        val slug = source.url.substringAfterLast('/').takeIf { it.isNotBlank() } ?: return source.url
        return "https://rules.silverballmania.com/print/$slug"
    }

    private fun cleanupPrimerHtml(html: String): String {
        var cleaned = stripHtml(extractBodyHtml(html) ?: html, listOf(
            "(?is)<iframe\\b[^>]*>.*?</iframe>",
            "(?is)<script\\b[^>]*>.*?</script>",
            "(?is)<style\\b[^>]*>.*?</style>",
            "(?is)<!--.*?-->",
        ))
        val firstHeading = Regex("(?is)<h1\\b[^>]*>").find(cleaned)?.range?.first
        if (firstHeading != null && firstHeading >= 0) {
            cleaned = cleaned.substring(firstHeading)
        }
        return cleaned.trim()
    }

    private fun cleanupLegacyHtml(
        html: String,
        mimeType: String?,
        source: RulesheetRemoteSource,
    ): String {
        if (shouldTreatAsPlainText(html, mimeType)) {
            return "<pre class=\"rulesheet-preformatted\">${html.htmlEscaped()}</pre>"
        }
        if (source is RulesheetRemoteSource.BobsGuide) {
            extractMainHtml(html)?.let { main ->
                return stripHtml(main, listOf(
                    "(?is)<script\\b[^>]*>.*?</script>",
                    "(?is)<!--.*?-->",
                    "(?is)<a\\b[^>]*title=\"Print\"[^>]*>.*?</a>",
                )).trim()
            }
        }
        return stripHtml(extractBodyHtml(html) ?: html, listOf(
            "(?is)<\\?.*?\\?>",
            "(?is)<script\\b[^>]*>.*?</script>",
            "(?is)<style\\b[^>]*>.*?</style>",
            "(?is)<iframe\\b[^>]*>.*?</iframe>",
            "(?is)<!--.*?-->",
            "(?is)</?(html|head|body|meta|link)\\b[^>]*>",
        )).trim()
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

    private fun attributionHtml(
        source: RulesheetRemoteSource,
        displayUrl: String,
        updatedAt: String?,
    ): String {
        val updatedText = updatedAt?.takeIf { it.isNotBlank() }?.let { " | Updated: ${it.htmlEscaped()}" } ?: ""
        return """
            <small class="rulesheet-attribution">Source: ${source.sourceName.htmlEscaped()} | ${source.originalLinkLabel.htmlEscaped()}: <a href="${displayUrl.htmlEscaped()}">link</a>$updatedText | ${source.detailsText.htmlEscaped()} | Reformatted for readability and mobile use.</small>
        """.trimIndent()
    }
}

private fun String.htmlEscaped(): String {
    return replace("&", "&amp;")
        .replace("\"", "&quot;")
        .replace("'", "&#39;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
}
