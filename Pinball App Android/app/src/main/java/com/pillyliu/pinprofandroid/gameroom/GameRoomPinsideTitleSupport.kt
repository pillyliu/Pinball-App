package com.pillyliu.pinprofandroid.gameroom

internal fun canonicalPinsideDisplayedTitle(
    title: String,
    fallbackVariant: String?,
): Pair<String, String?> {
    val trimmedTitle = title.trim()
    if (!trimmedTitle.endsWith(")")) {
        return trimmedTitle to fallbackVariant
    }
    val openParenIndex = trimmedTitle.lastIndexOf('(')
    if (openParenIndex <= 0) {
        return trimmedTitle to fallbackVariant
    }
    val baseTitle = trimmedTitle.substring(0, openParenIndex).trim()
    val rawVariant = trimmedTitle.substring(openParenIndex + 1, trimmedTitle.length - 1).trim()
    val normalizedVariant = normalizedPinsideVariantLabel(rawVariant)
    val resolvedVariant = preferredPinsideVariantLabel(
        parsedVariant = normalizedVariant,
        fallbackVariant = fallbackVariant,
    )
    return if (baseTitle.isNotBlank() && resolvedVariant != null) {
        baseTitle to resolvedVariant
    } else {
        trimmedTitle to fallbackVariant
    }
}

private fun preferredPinsideVariantLabel(
    parsedVariant: String?,
    fallbackVariant: String?,
): String? {
    val normalizedParsed = parsedVariant?.trim()?.ifBlank { null }
    val normalizedFallback = fallbackVariant?.trim()?.ifBlank { null }
    if (normalizedParsed == null) return normalizedFallback
    if (normalizedFallback == null) return normalizedParsed

    val parsedLower = normalizedParsed.lowercase()
    val fallbackLower = normalizedFallback.lowercase()
    val bothAnniversary = parsedLower.contains("anniversary") && fallbackLower.contains("anniversary")
    if (bothAnniversary) {
        if (parsedLower == fallbackLower) return normalizedFallback
        val fallbackPrefix = "$fallbackLower "
        if (parsedLower.startsWith(fallbackPrefix)) {
            return normalizedFallback
        }
    }
    return normalizedParsed
}

private fun normalizedPinsideVariantLabel(value: String): String? {
    val lowered = value.trim().lowercase()
    if (lowered.isBlank()) return null
    return when {
        lowered == "premium" || lowered == "premium edition" -> "Premium"
        lowered == "pro" || lowered == "pro edition" -> "Pro"
        lowered == "le" || lowered == "limited edition" -> "LE"
        lowered == "ce" || lowered.contains("collector") -> "CE"
        lowered == "se" || lowered.contains("special edition") -> "SE"
        lowered.contains("anniversary") -> value.trim()
        else -> null
    }
}
