package com.pillyliu.pinprofandroid.library

internal fun resolvedCatalogVariantLabel(title: String, explicitVariant: String?): String? {
    normalizeCatalogVariantLabel(explicitVariant)?.let { return it }
    val trimmedTitle = title.trim()
    if (!trimmedTitle.endsWith(")")) return null
    val openParenIndex = trimmedTitle.lastIndexOf('(')
    if (openParenIndex <= 0) return null
    val rawSuffix = trimmedTitle.substring(openParenIndex + 1, trimmedTitle.length - 1).trim()
    if (!looksLikeCatalogVariantSuffix(rawSuffix)) return null
    return normalizeCatalogVariantLabel(rawSuffix)
}

internal fun resolvedCatalogDisplayTitle(title: String, explicitVariant: String?): String {
    val trimmedTitle = title.trim()
    if (!trimmedTitle.endsWith(")")) return trimmedTitle
    val openParenIndex = trimmedTitle.lastIndexOf('(')
    if (openParenIndex <= 0) return trimmedTitle
    val rawSuffix = trimmedTitle.substring(openParenIndex + 1, trimmedTitle.length - 1).trim()
    val normalizedSuffix = normalizeCatalogVariantLabel(rawSuffix)
    val normalizedExplicit = normalizeCatalogVariantLabel(explicitVariant)
    if (!looksLikeCatalogVariantSuffix(rawSuffix)) return trimmedTitle
    if (normalizedExplicit != null && normalizedSuffix != null && normalizedExplicit != normalizedSuffix) {
        return trimmedTitle
    }
    return trimmedTitle.substring(0, openParenIndex).trim().ifBlank { trimmedTitle }
}

private fun looksLikeCatalogVariantSuffix(value: String): Boolean {
    val lowered = value.trim().lowercase()
    if (lowered.isBlank()) return false
    return lowered == "premium" ||
        lowered == "pro" ||
        lowered == "le" ||
        lowered == "ce" ||
        lowered == "se" ||
        lowered == "home" ||
        lowered == "arcade" ||
        lowered == "wizard" ||
        lowered.contains("anniversary") ||
        lowered.contains("limited edition") ||
        lowered.contains("special edition") ||
        lowered.contains("collector") ||
        lowered == "premium/le" ||
        lowered == "premium le" ||
        lowered == "premium-le"
}

internal fun normalizeCatalogVariantLabel(value: String?): String? {
    val trimmed = value?.trim().orEmpty()
    if (trimmed.isBlank()) return null
    val lowered = trimmed.lowercase()
    return when {
        lowered == "null" || lowered == "none" -> null
        lowered == "premium" -> "Premium"
        lowered == "pro" -> "Pro"
        lowered == "le" || lowered.contains("limited edition") -> "LE"
        lowered == "ce" || lowered.contains("collector") -> "CE"
        lowered == "se" || lowered.contains("special edition") -> "SE"
        lowered == "arcade" -> "Arcade"
        lowered == "wizard" -> "Wizard"
        lowered == "premium/le" || lowered == "premium le" || lowered == "premium-le" -> "Premium/LE"
        lowered.contains("anniversary") -> trimmed.split(" ")
            .filter { it.isNotBlank() }
            .joinToString(" ") { token ->
                when (token.lowercase()) {
                    "le", "ce", "se" -> token.uppercase()
                    else -> token.replaceFirstChar { ch -> if (ch.isLowerCase()) ch.titlecase() else ch.toString() }
                }
            }
        else -> trimmed
    }
}
