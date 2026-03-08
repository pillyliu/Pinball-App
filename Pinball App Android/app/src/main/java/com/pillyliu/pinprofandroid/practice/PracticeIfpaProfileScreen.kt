package com.pillyliu.pinprofandroid.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.SectionTitle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

internal data class IfpaRecentTournament(
    val name: String,
    val date: LocalDate,
    val dateLabel: String,
    val finish: String,
    val pointsGained: String,
)

internal data class IfpaPlayerProfile(
    val playerID: String,
    val displayName: String,
    val location: String?,
    val profilePhotoUrl: String?,
    val currentRank: String,
    val currentWpprPoints: String,
    val rating: String,
    val lastEventDate: String?,
    val seriesLabel: String?,
    val seriesRank: String?,
    val recentTournaments: List<IfpaRecentTournament>,
)

@Composable
internal fun PracticeIfpaProfileScreen(
    playerName: String,
    ifpaPlayerID: String,
) {
    val trimmedIfpaPlayerID = ifpaPlayerID.trim()
    var profile by remember(trimmedIfpaPlayerID) { mutableStateOf<IfpaPlayerProfile?>(null) }
    var isLoading by remember(trimmedIfpaPlayerID) { mutableStateOf(false) }
    var errorMessage by remember(trimmedIfpaPlayerID) { mutableStateOf<String?>(null) }
    val uriHandler = LocalUriHandler.current

    suspend fun loadProfile() {
        if (trimmedIfpaPlayerID.isBlank()) return
        isLoading = true
        errorMessage = null
        runCatching {
            IfpaPublicProfileService.fetchProfile(trimmedIfpaPlayerID)
        }.onSuccess {
            profile = it
        }.onFailure {
            profile = null
            errorMessage = it.message ?: "Could not load IFPA profile."
        }
        isLoading = false
    }

    LaunchedEffect(trimmedIfpaPlayerID) {
        profile = null
        if (trimmedIfpaPlayerID.isNotBlank()) {
            loadProfile()
        }
    }

    when {
        trimmedIfpaPlayerID.isBlank() -> {
            CardContainer {
                Text(
                    "Add your IFPA ID in Practice Settings to load your public ranking snapshot here.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        isLoading && profile == null -> {
            CardContainer {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    CircularProgressIndicator()
                }
            }
        }

        profile != null -> {
            val loadedProfile = profile!!
            CardContainer {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Column(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = playerName.trim().ifBlank { loadedProfile.displayName },
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            text = "IFPA #${loadedProfile.playerID}",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        loadedProfile.location?.let {
                            Text(
                                text = it,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }

                    if (!loadedProfile.profilePhotoUrl.isNullOrBlank()) {
                        AsyncImage(
                            model = loadedProfile.profilePhotoUrl,
                            contentDescription = "IFPA profile picture",
                            modifier = Modifier
                                .size(92.dp)
                                .clip(RoundedCornerShape(14.dp)),
                            contentScale = ContentScale.Crop,
                        )
                    }
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                IfpaStatCard(title = "Rank", value = loadedProfile.currentRank, modifier = Modifier.weight(1f))
                IfpaStatCard(title = "WPPR", value = loadedProfile.currentWpprPoints, modifier = Modifier.weight(1f))
                IfpaStatCard(title = "Rating", value = loadedProfile.rating, modifier = Modifier.weight(1f))
            }

            if (loadedProfile.lastEventDate != null || loadedProfile.seriesRank != null) {
                CardContainer {
                    SectionTitle("At a Glance")
                    loadedProfile.lastEventDate?.let {
                        IfpaInfoRow(label = "Last event", value = it)
                    }
                    if (!loadedProfile.seriesLabel.isNullOrBlank() && !loadedProfile.seriesRank.isNullOrBlank()) {
                        IfpaInfoRow(label = loadedProfile.seriesLabel, value = loadedProfile.seriesRank)
                    }
                }
            }

            CardContainer {
                SectionTitle("Recent Tournaments")
                if (loadedProfile.recentTournaments.isEmpty()) {
                    Text(
                        "No recent tournament results were found on the public IFPA profile.",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                } else {
                    loadedProfile.recentTournaments.forEachIndexed { index, tournament ->
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(tournament.name, fontWeight = FontWeight.SemiBold)
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                IfpaInfoColumn(label = "Date", value = tournament.dateLabel)
                                IfpaInfoColumn(label = "Finish", value = tournament.finish)
                                IfpaInfoColumn(label = "Points", value = tournament.pointsGained)
                            }
                        }
                        if (index != loadedProfile.recentTournaments.lastIndex) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(1.dp)
                                    .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.3f)),
                            )
                        }
                    }
                }
            }

            Button(onClick = {
                uriHandler.openUri("https://www.ifpapinball.com/players/view.php?p=${loadedProfile.playerID}")
            }) {
                Text("Open full IFPA profile")
            }
        }

        errorMessage != null -> {
            CardContainer {
                SectionTitle("Could not load IFPA profile")
                Text(errorMessage!!, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Button(onClick = {
                    profile = null
                    errorMessage = null
                }) {
                    Text("Try Again")
                }
            }
            LaunchedEffect(errorMessage) {
                if (errorMessage == null) loadProfile()
            }
        }
    }
}

@Composable
private fun IfpaStatCard(
    title: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    CardContainer(modifier = modifier) {
        Text(title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun IfpaInfoRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value)
    }
}

@Composable
private fun IfpaInfoColumn(label: String, value: String) {
    Column(horizontalAlignment = Alignment.Start) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value)
    }
}

private object IfpaPublicProfileService {
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
