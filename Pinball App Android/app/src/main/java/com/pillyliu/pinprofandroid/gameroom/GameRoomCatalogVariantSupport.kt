package com.pillyliu.pinprofandroid.gameroom

import com.pillyliu.pinprofandroid.library.resolvedCatalogDisplayTitle
import com.pillyliu.pinprofandroid.library.resolvedCatalogVariantLabel

internal fun parseCatalogName(title: String, explicitVariant: String?): ParsedCatalogName {
    val trimmedTitle = title.trim()
    return ParsedCatalogName(
        displayTitle = resolvedCatalogDisplayTitle(
            title = trimmedTitle,
            explicitVariant = explicitVariant,
        ),
        displayVariant = resolvedCatalogVariantLabel(
            title = trimmedTitle,
            explicitVariant = explicitVariant,
        ),
    )
}

internal fun normalizeVariantLabel(value: String?): String? {
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

internal fun sanitizeVariantOptions(values: List<String>): List<String> {
    val normalized = values.mapNotNull(::normalizeVariantLabel).toMutableSet()
    if ("Premium/LE" !in normalized) {
        return normalized.toList()
    }
    normalized.remove("Premium/LE")
    normalized += "Premium"
    normalized += "LE"
    return normalized.toList()
}

internal fun variantMatchesSelection(candidate: String?, selected: String?): Boolean {
    val normalizedCandidate = normalizeVariantLabel(candidate)?.lowercase() ?: return false
    val normalizedSelected = normalizeVariantLabel(selected)?.lowercase() ?: return false
    if (normalizedCandidate == normalizedSelected) return true
    if (normalizedCandidate == "premium/le") {
        return normalizedSelected == "premium" || normalizedSelected == "le"
    }
    return false
}

internal fun exactVariantMatchesSelection(candidate: String?, selected: String?): Boolean {
    val normalizedCandidate = normalizeVariantLabel(candidate)?.lowercase() ?: return false
    val normalizedSelected = normalizeVariantLabel(selected)?.lowercase() ?: return false
    return normalizedCandidate == normalizedSelected
}

internal fun normalizedCatalogGameID(value: String): String =
    value.trim().lowercase()
