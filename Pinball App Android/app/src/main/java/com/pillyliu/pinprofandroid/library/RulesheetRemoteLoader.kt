package com.pillyliu.pinprofandroid.library

internal data class RulesheetRenderContent(
    val kind: RulesheetRenderKind,
    val body: String,
    val baseUrl: String,
)

internal enum class RulesheetRenderKind {
    MARKDOWN,
    HTML,
}

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
        val fetched = fetchRemoteRulesheetDocument(apiUrl)
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
        val fetched = fetchRemoteRulesheetDocument(source.url)
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
        val fetched = fetchRemoteRulesheetDocument(legacyFetchUrl(source))
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
}
