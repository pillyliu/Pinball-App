package com.pillyliu.pinprofandroid.practice

import com.pillyliu.pinprofandroid.library.PinballGame
import java.util.Locale

internal fun practiceDisplayTitleForGames(games: List<PinballGame>): String {
    val baseCandidates = games
        .map { practiceNormalizedDisplayBaseTitle(it.name) }
        .filter { it.isNotBlank() }
    practicePreferredDisplayTitleCandidate(baseCandidates)?.let { return it }

    val opdbCandidates = games
        .mapNotNull { it.opdbName?.trim()?.takeIf(String::isNotBlank) }
        .map(::practiceNormalizedDisplayBaseTitle)
        .filter { it.isNotBlank() }
    practicePreferredDisplayTitleCandidate(opdbCandidates)?.let { return it }

    return games.map { it.name }.minWithOrNull(practiceDisplayTitleComparator()) ?: "Unknown Game"
}

internal fun practiceDisplayTitleForKey(
    canonicalGameId: String,
    games: List<PinballGame>,
): String? {
    val trimmed = canonicalGameId.trim()
    if (trimmed.isBlank()) return null
    val grouped = games.filter { it.practiceKey == trimmed }
    if (grouped.isEmpty()) return null
    return practiceDisplayTitleForGames(grouped)
}

private fun practiceNormalizedDisplayBaseTitle(raw: String): String {
    var current = raw.trim()
    if (current.isBlank()) return ""

    val pattern = Regex("\\s*\\([^()]*\\)\\s*$")
    while (true) {
        val replaced = pattern.replace(current, "").trim()
        if (replaced.isBlank() || replaced == current) break
        current = replaced
    }

    return current
}

private fun practicePreferredDisplayTitleCandidate(candidates: List<String>): String? {
    val normalized = candidates.map { it.trim() }.filter { it.isNotBlank() }
    if (normalized.isEmpty()) return null

    val grouped = normalized.groupBy { it.lowercase(Locale.US) }
    return grouped.values
        .mapNotNull { group -> group.minWithOrNull(practiceDisplayTitleComparator()) }
        .maxWithOrNull(
            compareBy<String> { grouped[it.lowercase(Locale.US)]?.size ?: 0 }
                .thenByDescending { -it.length }
                .thenByDescending { it.lowercase(Locale.US) }
        )
}

private fun practiceDisplayTitleComparator(): Comparator<String> {
    return compareBy<String> { it.trim().length }.thenBy { it.lowercase(Locale.US) }
}
