package com.pillyliu.pinprofandroid.practice

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL
import java.time.LocalDateTime
import java.time.format.DateTimeFormatterBuilder
import java.util.Locale

internal object PrpaPublicProfileService {
    private val resultDateFormatter = DateTimeFormatterBuilder()
        .parseCaseInsensitive()
        .appendPattern("M/d/yyyy - h:mma")
        .toFormatter(Locale.US)

    suspend fun fetchProfile(playerID: String): PrpaPlayerProfile = withContext(Dispatchers.IO) {
        val html = URL("https://punkrockpinball.com/player/?prp_id=$playerID").readText()
        parseProfile(playerID, html)
    }

    private fun parseProfile(playerID: String, html: String): PrpaPlayerProfile {
        if (!html.contains("prpp-player-results", ignoreCase = true)) {
            throw IllegalStateException("The public PRPA profile layout did not match the expected format.")
        }

        val displayName = firstMatch(html, """<h1[^>]*>\s*(.*?)\s*</h1>""")?.cleanedPrpaHtmlText() ?: "PRPA Player"
        val scenesSection = html.slicePrpa(
            from = """<div class="prpp-summary-scenes">""",
            to = """</div>""",
        ).orEmpty()
        val scenes = allMatches(scenesSection, """<a [^>]*>([^<]+)</a>\s*<strong[^>]*>([^<]+)</strong>""")
            .mapNotNull { groups ->
                if (groups.size < 2) return@mapNotNull null
                PrpaSceneStanding(
                    name = groups[0].cleanedPrpaHtmlText(),
                    rank = groups[1].cleanedPrpaHtmlText(),
                )
            }

        val tableSection = html.slicePrpa(
            from = """<table class="prpp-table widefat striped">""",
            to = """</table>""",
        ).orEmpty()
        val tournaments = allMatches(
            tableSection,
            """<tr>\s*<td>(.*?)</td>\s*<td>([^<]+)</td>\s*<td>([^<]+)</td>\s*<td>([^<]+)</td>\s*</tr>""",
        ).mapNotNull { groups ->
            if (groups.size < 4) return@mapNotNull null
            val tournamentCell = groups[0]
            val dateLabel = groups[1].cleanedPrpaHtmlText()
            val date = runCatching { LocalDateTime.parse(dateLabel, resultDateFormatter) }.getOrNull() ?: return@mapNotNull null
            val name = firstMatch(tournamentCell, """<a [^>]*>([^<]+)</a>""")?.cleanedPrpaHtmlText()
                ?: tournamentCell.cleanedPrpaHtmlText()
            val eventType = firstMatch(tournamentCell, """<span class="prpp-badge[^"]*">([^<]+)</span>""")?.cleanedPrpaHtmlText()
            PrpaRecentTournament(
                name = name,
                eventType = eventType,
                date = date,
                dateLabel = dateLabel,
                placement = groups[2].cleanedPrpaHtmlText(),
                pointsGained = groups[3].cleanedPrpaHtmlText(),
            )
        }.sortedByDescending { it.date }

        return PrpaPlayerProfile(
            playerID = playerID,
            displayName = displayName,
            openPoints = summaryValue(html, "Open PRPA Points:") ?: "-",
            eventsPlayed = summaryValue(html, "Events Played:") ?: "-",
            openRanking = summaryValue(html, "Open Ranking:") ?: "-",
            averagePointsPerEvent = summaryValue(html, "Average Points/Event:") ?: "-",
            bestFinish = summaryValue(html, "Best Finish (by points):") ?: "-",
            worstFinish = summaryValue(html, "Worst Finish (by points):") ?: "-",
            ifpaPlayerID = summaryValue(html, "IFPA ID:"),
            lastEventDate = tournaments.firstOrNull()?.dateLabel,
            scenes = scenes,
            recentTournaments = tournaments.take(3),
        )
    }

    private fun summaryValue(text: String, label: String): String? {
        val pattern = """<li[^>]*>\s*<strong>\s*${Regex.escape(label)}\s*</strong>\s*(?:<span[^>]*>)?\s*([^<]+)"""
        return firstMatch(text, pattern)?.cleanedPrpaHtmlText()
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

private fun String.cleanedPrpaHtmlText(): String {
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

private fun String.slicePrpa(from: String, to: String): String? {
    val startIndex = indexOf(from)
    if (startIndex < 0) return null
    val contentStart = startIndex + from.length
    val endIndex = indexOf(to, startIndex = contentStart)
    if (endIndex < 0) return null
    return substring(contentStart, endIndex)
}
