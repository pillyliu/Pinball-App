package com.pillyliu.pinprofandroid.gameroom

internal fun looksLikePinsideChallengePage(html: String): Boolean {
    val lowered = html.lowercase()
    return lowered.contains("just a moment") &&
        (
            lowered.contains("cf_chl_") ||
                lowered.contains("challenge-platform") ||
                lowered.contains("enable javascript and cookies to continue")
            )
}

internal fun findPinsideCollectionSlugs(html: String): List<String> {
    val regex = Regex("""(?:https?:\/\/pinside\.com)?\/pinball\/machine\/([a-z0-9\-]+)""", RegexOption.IGNORE_CASE)
    val ordered = linkedSetOf<String>()
    regex.findAll(html).forEach { match ->
        val slug = match.groupValues.getOrNull(1)?.lowercase().orEmpty()
        if (slug.isNotBlank()) ordered += slug
    }
    return ordered.toList()
}

internal fun resolvePinsideSlugTitle(
    slug: String,
    groupMap: Map<String, String>,
): String {
    val mapped = groupMap[slug]?.trim().orEmpty()
    if (mapped.isNotEmpty() && mapped != "~") {
        return mapped
    }
    return humanizedPinsideSlugTitle(slug)
}

internal fun pinsideVariantFromSlug(slug: String): String? {
    val lowered = slug.lowercase()
    val anniversaryMatch = Regex("""(\d+)(st|nd|rd|th)-anniversary""", RegexOption.IGNORE_CASE)
        .find(lowered)
    if (anniversaryMatch != null) {
        val ordinal = "${anniversaryMatch.groupValues[1]}${anniversaryMatch.groupValues[2].lowercase()}"
        return "$ordinal Anniversary"
    }
    if (lowered.contains("anniversary")) {
        return "Anniversary"
    }
    return when {
        lowered.endsWith("-premium") -> "Premium"
        lowered.endsWith("-pro") -> "Pro"
        lowered.endsWith("-le") || lowered.contains("-limited-edition") -> "LE"
        lowered.endsWith("-ce") || lowered.contains("-collector") -> "CE"
        lowered.endsWith("-se") || lowered.contains("-special-edition") -> "SE"
        else -> null
    }
}

internal fun humanizedPinsideSlugTitle(slug: String): String {
    return slug
        .split("-")
        .filter { it.isNotBlank() }
        .joinToString(" ") { token ->
            token.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
        }
        .ifBlank { "Imported Machine" }
}
