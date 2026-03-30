package com.pillyliu.pinprofandroid.practice

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

internal object IfpaPublicProfileService {
    private val resultDateFormatter = DateTimeFormatter.ofPattern("MMM dd, yyyy", Locale.US)

    suspend fun fetchProfile(playerID: String): IfpaPlayerProfile = withContext(Dispatchers.IO) {
        val html = URL("https://www.ifpapinball.com/players/view.php?p=$playerID").readText()
        parseProfile(playerID, html)
    }

    private fun parseProfile(playerID: String, html: String): IfpaPlayerProfile {
        val displayName = firstMatch(html, """<h1>\s*(.*?)\s*</h1>""")?.cleanedHtmlText() ?: "IFPA Player"
        val profilePhotoUrl = firstMatch(html, """<div id="playerpic" class="widget widget_text">\s*<img [^>]*src="([^"]+)"""")
        val cityState = firstMatch(html, """<td class="right">Location:</td>\s*<td>([^<]+)</td>""")?.cleanedHtmlText()
        val country = firstMatch(html, """<td class="right">Country:</td>\s*<td>([^<]+)</td>""")?.cleanedHtmlText()
        val location = when {
            !cityState.isNullOrBlank() && !country.isNullOrBlank() -> "$cityState, $country"
            !cityState.isNullOrBlank() -> cityState
            !country.isNullOrBlank() -> country
            else -> null
        }

        val rankingPattern = """<td class="right"><a href="/rankings/overall\.php">Open Ranking</a>:</td>\s*<td class="right">([^<]+)</td>\s*<td>([^<]+)</td>"""
        val currentRank = firstMatch(html, rankingPattern, 1)?.cleanedHtmlText() ?: throw IllegalStateException("Missing IFPA rank")
        val currentWpprPoints = firstMatch(html, rankingPattern, 2)?.cleanedHtmlText() ?: throw IllegalStateException("Missing IFPA points")
        val rating = firstMatch(html, """<td class="right">Rating:</td>\s*<td class="right">([^<]+)</td>\s*<td>([^<]+)</td>""", 2)?.cleanedHtmlText()
            ?: throw IllegalStateException("Missing IFPA rating")

        val seriesPattern = """<h4 class="widgettitle">([^<]+)</h4>\s*<table class="width100 infoTable">\s*<tr>\s*<td class="right width50"><a [^>]+>([^<]+)</a></td>\s*<td class="center">([^<]+)</td>"""
        val seriesLabel = firstMatch(html, seriesPattern, 1)?.cleanedHtmlText()
        val seriesRegion = firstMatch(html, seriesPattern, 2)?.cleanedHtmlText()
        val seriesRankValue = firstMatch(html, seriesPattern, 3)?.cleanedHtmlText()
        val seriesRank = if (!seriesRegion.isNullOrBlank() && !seriesRankValue.isNullOrBlank()) "$seriesRegion $seriesRankValue" else null

        val activeSection = html.slice(
            from = """<div style="display: none;" id="divactive">""",
            to = """<!-- Past Results -->""",
        ).orEmpty()
        val rowPattern = """<tr>\s*<td>.*?<a href="[^"]+">([^<]+)</a>\s*</td>\s*<td>([^<]+)</td>\s*<td class="center">([^<]+)</td>\s*<td align="center">([^<]+)</td>\s*<td align="center">([^<]+)</td>\s*</tr>"""
        val tournaments = allMatches(activeSection, rowPattern).mapNotNull { groups ->
            if (groups.size < 5) return@mapNotNull null
            val dateLabel = groups[3].cleanedHtmlText()
            val date = runCatching { LocalDate.parse(dateLabel, resultDateFormatter) }.getOrNull() ?: return@mapNotNull null
            IfpaRecentTournament(
                name = groups[0].cleanedHtmlText(),
                date = date,
                dateLabel = dateLabel,
                finish = groups[2].cleanedHtmlText(),
                pointsGained = groups[4].cleanedHtmlText(),
            )
        }.sortedByDescending { it.date }

        return IfpaPlayerProfile(
            playerID = playerID,
            displayName = displayName,
            location = location,
            profilePhotoUrl = profilePhotoUrl,
            currentRank = currentRank,
            currentWpprPoints = currentWpprPoints,
            rating = rating,
            lastEventDate = tournaments.firstOrNull()?.dateLabel,
            seriesLabel = seriesLabel,
            seriesRank = seriesRank,
            recentTournaments = tournaments.take(3),
        )
    }

    private fun firstMatch(text: String, pattern: String, group: Int = 1): String? {
        return Regex(pattern, setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL))
            .find(text)
            ?.groupValues
            ?.getOrNull(group)
    }

    private fun allMatches(text: String, pattern: String): List<List<String>> {
        return Regex(pattern, setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL))
            .findAll(text)
            .map { it.groupValues.drop(1) }
            .toList()
    }
}

private fun String.cleanedHtmlText(): String {
    return this
        .replace(Regex("<[^>]+>"), " ")
        .replace("&amp;", "&")
        .replace("&nbsp;", " ")
        .replace("&#8211;", "-")
        .replace("&ndash;", "-")
        .replace("&#8217;", "'")
        .replace("&#039;", "'")
        .replace("&quot;", "\"")
        .replace(Regex("\\s+"), " ")
        .trim()
}

private fun String.slice(from: String, to: String): String? {
    val startIndex = indexOf(from)
    if (startIndex < 0) return null
    val contentStart = startIndex + from.length
    val endIndex = indexOf(to, startIndex = contentStart)
    if (endIndex < 0) return null
    return substring(contentStart, endIndex)
}
