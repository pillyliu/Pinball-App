package com.pillyliu.pinprofandroid.library

internal fun resolveRulesheetLinks(rulesheetLinks: List<CatalogRulesheetLinkRecord>): ResolvedRulesheetLinks {
    val sortedLinks = rulesheetLinks.sortedWith(compareCatalogRulesheetLinks())
    val links = sortedLinks.mapNotNull { link ->
        val url = normalizedOptionalString(link.url) ?: return@mapNotNull null
        ReferenceLink(label = catalogRulesheetLabel(link.provider, link.label, url), url = url)
    }
    val localPath = sortedLinks
        .asSequence()
        .mapNotNull { normalizedOptionalString(it.localPath) }
        .firstOrNull()
    return ResolvedRulesheetLinks(
        localPath = localPath,
        links = links,
    )
}

internal fun shouldSuppressLocalMarkdownRulesheetLink(link: ReferenceLink): Boolean {
    val destination = resolveLibraryUrl(link.destinationUrl)
    return link.rulesheetSourceKind == RulesheetSourceKind.PROF ||
        link.rulesheetSourceKind == RulesheetSourceKind.LOCAL ||
        isPinProfRulesheetUrl(destination) ||
        isLikelyPinProfMarkdownRulesheetUrl(destination)
}

internal fun mergeRulesheetLinks(primary: List<ReferenceLink>, secondary: List<ReferenceLink>): List<ReferenceLink> {
    val seen = linkedSetOf<String>()
    return buildList {
        for (link in primary + secondary) {
            val key = canonicalRulesheetMergeKey(link)
            if (!seen.add(key)) continue
            add(link)
        }
    }
}

private fun canonicalRulesheetMergeKey(link: ReferenceLink): String {
    val normalizedUrl = normalizedOptionalString(link.url)?.lowercase()
    if (normalizedUrl != null) return "url|$normalizedUrl"
    return "label|${link.label.trim().lowercase()}"
}

internal fun compareCatalogRulesheetLinks(): Comparator<CatalogRulesheetLinkRecord> =
    compareBy<CatalogRulesheetLinkRecord> {
        catalogRulesheetSortRank(it.provider, it.label, it.url)
    }.thenBy { it.priority ?: Int.MAX_VALUE }
        .thenBy { it.label.lowercase() }
        .thenBy { it.url.orEmpty().lowercase() }

internal fun catalogRulesheetSortRank(providerRawValue: String, label: String, url: String?): Int {
    return when (providerRawValue.lowercase()) {
        "local" -> RulesheetSourceKind.LOCAL.rank
        "prof" -> RulesheetSourceKind.PROF.rank
        "bob" -> RulesheetSourceKind.BOB.rank
        "papa" -> RulesheetSourceKind.PAPA.rank
        "pp" -> RulesheetSourceKind.PP.rank
        "tf" -> RulesheetSourceKind.TF.rank
        "opdb" -> RulesheetSourceKind.OPDB.rank
        else -> ReferenceLink(label = label, url = url).rulesheetSourceKind.rank
    }
}

internal fun catalogRulesheetLabel(providerRawValue: String, fallback: String, url: String? = null): String {
    return when (providerRawValue.lowercase()) {
        "tf" -> "Rulesheet (TF)"
        "pp" -> "Rulesheet (PP)"
        "bob" -> "Rulesheet (Bob)"
        "papa" -> "Rulesheet (PAPA)"
        "prof" -> "Rulesheet (PinProf)"
        "opdb" -> "Rulesheet (OPDB)"
        "local" -> "Rulesheet (Local)"
        else -> when (ReferenceLink(label = fallback, url = url).rulesheetSourceKind) {
            RulesheetSourceKind.PROF -> "Rulesheet (PinProf)"
            RulesheetSourceKind.BOB -> "Rulesheet (Bob)"
            RulesheetSourceKind.PAPA -> "Rulesheet (PAPA)"
            RulesheetSourceKind.PP -> "Rulesheet (PP)"
            RulesheetSourceKind.TF -> "Rulesheet (TF)"
            RulesheetSourceKind.OPDB -> "Rulesheet (OPDB)"
            RulesheetSourceKind.LOCAL -> "Rulesheet (Local)"
            RulesheetSourceKind.OTHER -> fallback
        }
    }
}

internal data class ResolvedRulesheetLinks(
    val localPath: String?,
    val links: List<ReferenceLink>,
)
