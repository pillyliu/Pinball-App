package com.pillyliu.pinprofandroid.library

import java.net.URL

private fun normalizedRulesheetMarkdownPath(pathOrUrl: String?): String? {
    val resolved = resolveLibraryUrl(pathOrUrl) ?: return null
    return runCatching { URL(resolved).path.lowercase() }
        .getOrNull()
        ?.takeIf { it.isNotBlank() }
}

internal fun isLikelyPinProfMarkdownRulesheetUrl(url: String?): Boolean {
    val raw = url?.trim()?.takeIf { it.isNotEmpty() } ?: return false
    val normalizedRaw = raw.lowercase()
    if (
        normalizedRaw.endsWith("-rulesheet.md") ||
        normalizedRaw.contains("/pinball/rulesheets/") ||
        normalizedRaw.contains("/rules/") && normalizedRaw.contains("source=local")
    ) {
        return true
    }
    val resolvedPath = normalizedRulesheetMarkdownPath(raw) ?: return false
    return resolvedPath.startsWith("/pinball/rulesheets/") ||
        resolvedPath.endsWith("-rulesheet.md") ||
        (resolvedPath.startsWith("/rules/") && normalizedRaw.contains("source=local"))
}

internal val PinballGame.rulesheetPathCandidates: List<String>
    get() = listOfNotNull(
        normalizeLibraryCachePath(rulesheetLocal),
    ).distinct()

internal val PinballGame.hasLocalRulesheetResource: Boolean
    get() = rulesheetPathCandidates.isNotEmpty()

internal val PinballGame.displayedRulesheetLinks: List<ReferenceLink>
    get() {
        val localRulesheetBasenames = rulesheetPathCandidates.mapNotNull { candidate ->
            normalizedRulesheetMarkdownPath(candidate)
                ?.substringAfterLast('/')
                ?.takeIf { it.isNotBlank() }
        }.toSet()

        return orderedRulesheetLinks
            .filterNot { link ->
                val destination = resolveLibraryUrl(link.destinationUrl)
                val destinationBasename = normalizedRulesheetMarkdownPath(destination)
                    ?.substringAfterLast('/')
                    ?.takeIf { it.isNotBlank() }
                hasLocalRulesheetResource && (
                    link.rulesheetSourceKind == RulesheetSourceKind.PROF ||
                        link.rulesheetSourceKind == RulesheetSourceKind.LOCAL ||
                        isPinProfRulesheetUrl(destination) ||
                        isLikelyPinProfMarkdownRulesheetUrl(destination) ||
                        (destinationBasename != null && destinationBasename in localRulesheetBasenames)
                    )
            }
            .filter { link ->
                link.destinationUrl != null || link.embeddedRulesheetSource != null
            }
    }

internal val PinballGame.gameinfoPathCandidates: List<String>
    get() = listOfNotNull(
        localAssetKey?.let { "/pinball/gameinfo/${it}-gameinfo.md" },
    ).distinct()

internal val PinballGame.hasRulesheetResource: Boolean
    get() = hasLocalRulesheetResource || rulesheetLinks.isNotEmpty() || !rulesheetUrl.isNullOrBlank()
