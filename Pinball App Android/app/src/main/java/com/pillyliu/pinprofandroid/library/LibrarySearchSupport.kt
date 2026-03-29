package com.pillyliu.pinprofandroid.library

import java.text.Normalizer

internal fun normalizedSearchTokens(value: String): List<String> {
    val folded = Normalizer.normalize(value, Normalizer.Form.NFD)
        .replace(Regex("\\p{M}+"), "")
    return folded
        .lowercase()
        .split(Regex("[^a-z0-9]+"))
        .filter { it.isNotBlank() }
}

internal fun matchesSearchQuery(query: String, fields: Iterable<String?>): Boolean {
    val queryTokens = normalizedSearchTokens(query)
    if (queryTokens.isEmpty()) return true

    val haystackTokens = fields.flatMap { normalizedSearchTokens(it.orEmpty()) }
    if (haystackTokens.isEmpty()) return false

    return matchesSearchTokens(queryTokens, haystackTokens)
}

internal fun matchesSearchTokens(queryTokens: List<String>, haystackTokens: List<String>): Boolean {
    if (queryTokens.isEmpty()) return true
    if (haystackTokens.isEmpty()) return false
    return queryTokens.all { queryToken ->
        haystackTokens.any { haystackToken -> haystackToken.contains(queryToken) }
    }
}
