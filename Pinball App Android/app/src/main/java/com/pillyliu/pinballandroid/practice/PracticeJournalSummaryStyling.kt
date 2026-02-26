package com.pillyliu.pinballandroid.practice

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle

private enum class JournalTokenColor { Primary, Game, Screen, Score, Note }

private data class JournalToken(val text: String, val color: JournalTokenColor)

@Composable
internal fun StyledPracticeJournalSummaryText(
    summary: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
) {
    val colors = MaterialTheme.colorScheme
    val isDark = isSystemInDarkTheme()
    val annotated = buildAnnotatedString {
        journalSummaryTokens(summary).forEach { token ->
            withStyle(
                SpanStyle(
                    color = when (token.color) {
                        JournalTokenColor.Primary -> colors.onSurface
                        JournalTokenColor.Game -> if (isDark) androidx.compose.ui.graphics.Color(0xFF6EE7F9) else androidx.compose.ui.graphics.Color(0xFF065F46)
                        JournalTokenColor.Screen -> if (isDark) androidx.compose.ui.graphics.Color(0xFFBFDBFE) else androidx.compose.ui.graphics.Color(0xFF1E40AF)
                        JournalTokenColor.Score -> if (isDark) androidx.compose.ui.graphics.Color(0xFFFCD34D) else androidx.compose.ui.graphics.Color(0xFF9A3412)
                        JournalTokenColor.Note -> if (isDark) androidx.compose.ui.graphics.Color(0xFFE6EDF9) else androidx.compose.ui.graphics.Color(0xFF374151)
                    },
                    fontWeight = when (token.color) {
                        JournalTokenColor.Primary, JournalTokenColor.Note -> null
                        else -> FontWeight.SemiBold
                    },
                )
            ) {
                append(token.text)
            }
        }
    }
    Text(text = annotated, style = style, modifier = modifier)
}

private fun journalSummaryTokens(summary: String): List<JournalToken> {
    parseScoreSummary(summary)?.let { (value, game, context) ->
        return listOf(
            JournalToken("Score: ", JournalTokenColor.Primary),
            JournalToken(value, JournalTokenColor.Score),
            JournalToken(" • ", JournalTokenColor.Primary),
            JournalToken(game, JournalTokenColor.Game),
            JournalToken(" ($context)", JournalTokenColor.Screen),
        )
    }

    parseStructuredPracticeSummary(summary)?.let { return it }
    parseStructuredStudySummary(summary)?.let { return it }
    parseStructuredGameNoteSummary(summary)?.let { return it }

    parseBulletGameSummary(summary)?.let { (prefix, game) ->
        return listOf(
            JournalToken(prefix, JournalTokenColor.Primary),
            JournalToken("\n• ", JournalTokenColor.Screen),
            JournalToken(game, JournalTokenColor.Game),
        )
    }

    parseLibrarySummary(summary)?.let { return it }
    parsePracticePlayfieldSummary(summary)?.let { return it }
    parsePracticeRulesheetSummary(summary)?.let { return it }
    parsePracticeVideoSummary(summary)?.let { return it }
    parsePracticeProgressSummary(summary)?.let { return it }
    parsePracticeBrowsedSummary(summary)?.let { return it }

    return listOf(JournalToken(summary, JournalTokenColor.Primary))
}

private fun parseScoreSummary(summary: String): Triple<String, String, String>? {
    if (!summary.startsWith("Score: ")) return null
    val rest = summary.removePrefix("Score: ")
    val bullet = rest.indexOf(" • ")
    val contextStart = rest.lastIndexOf(" (")
    if (bullet <= 0 || contextStart <= bullet || !rest.endsWith(")")) return null
    val value = rest.substring(0, bullet)
    val game = rest.substring(bullet + 3, contextStart).trim()
    val context = rest.substring(contextStart + 2, rest.length - 1)
    if (value.isBlank() || game.isBlank() || context.isBlank()) return null
    return Triple(value, game, context)
}

private fun parseBulletGameSummary(summary: String): Pair<String, String>? {
    val split = summary.split("\n• ", limit = 2)
    if (split.size != 2 || split[1].isBlank()) return null
    return split[0] to split[1]
}

private fun parseStructuredPracticeSummary(summary: String): List<JournalToken>? {
    if (!summary.startsWith("Practice:\n")) return null
    val split = summary.removePrefix("Practice:\n").split("\n• ", limit = 2)
    if (split.size != 2 || split[1].isBlank()) return null
    val bodyLines = split[0].lines().map { it.trimEnd() }.dropLastWhile { it.isBlank() }
    val valueLine = bodyLines.firstOrNull()?.trim().orEmpty().ifBlank { "Practice session" }
    val noteText = bodyLines.drop(1).joinToString("\n").trim().ifBlank { null }
    return buildList {
        add(JournalToken("Practice", JournalTokenColor.Screen))
        add(JournalToken(":\n", JournalTokenColor.Primary))
        add(JournalToken(valueLine, JournalTokenColor.Screen))
        if (noteText != null) {
            add(JournalToken("\n", JournalTokenColor.Primary))
            add(JournalToken(noteText, JournalTokenColor.Note))
        }
        add(JournalToken("\n• ", JournalTokenColor.Screen))
        add(JournalToken(split[1], JournalTokenColor.Game))
    }
}

private fun parseStructuredGameNoteSummary(summary: String): List<JournalToken>? {
    if (!summary.startsWith("Game Note:\n")) return null
    val split = summary.removePrefix("Game Note:\n").split("\n• ", limit = 2)
    if (split.size != 2 || split[1].isBlank()) return null
    return listOf(
        JournalToken("Game Note", JournalTokenColor.Screen),
        JournalToken(":\n", JournalTokenColor.Primary),
        JournalToken(split[0], JournalTokenColor.Note),
        JournalToken("\n• ", JournalTokenColor.Screen),
        JournalToken(split[1], JournalTokenColor.Game),
    )
}

private fun parseStructuredStudySummary(summary: String): List<JournalToken>? {
    val headers = listOf(
        "Rulesheet" to "Rulesheet",
        "Tutorial Video" to "Tutorial Video",
        "Gameplay Video" to "Gameplay Video",
        "Playfield" to "Playfield",
    )
    val header = headers.firstOrNull { summary.startsWith("${it.first}:\n") } ?: return null
    val split = summary.removePrefix("${header.first}:\n").split("\n• ", limit = 2)
    if (split.size != 2 || split[1].isBlank()) return null
    val bodyLines = split[0].lines().map { it.trimEnd() }.dropLastWhile { it.isBlank() }
    val valueLine = bodyLines.firstOrNull()?.trim().orEmpty()
    if (valueLine.isBlank()) return null
    val noteText = bodyLines.drop(1).joinToString("\n").trim().ifBlank { null }
    return buildList {
        add(JournalToken(header.second, JournalTokenColor.Screen))
        add(JournalToken(":\n", JournalTokenColor.Primary))
        when {
            valueLine.startsWith("Progress: ") -> {
                add(JournalToken("Progress", JournalTokenColor.Screen))
                add(JournalToken(": ", JournalTokenColor.Primary))
                add(JournalToken(valueLine.removePrefix("Progress: "), JournalTokenColor.Screen))
            }
            valueLine.equals("Viewed playfield", ignoreCase = true) -> {
                add(JournalToken("Viewed ", JournalTokenColor.Primary))
                add(JournalToken("playfield", JournalTokenColor.Screen))
            }
            else -> add(JournalToken(valueLine, JournalTokenColor.Screen))
        }
        if (noteText != null) {
            add(JournalToken("\n", JournalTokenColor.Primary))
            add(JournalToken(noteText, JournalTokenColor.Note))
        }
        add(JournalToken("\n• ", JournalTokenColor.Screen))
        add(JournalToken(split[1], JournalTokenColor.Game))
    }
}

private fun parseLibrarySummary(summary: String): List<JournalToken>? {
    if (summary.startsWith("Browsed ") && summary.endsWith(" in Library")) {
        val game = summary.removePrefix("Browsed ").removeSuffix(" in Library")
        return listOf(
            JournalToken("Browsed ", JournalTokenColor.Primary),
            JournalToken(game, JournalTokenColor.Game),
            JournalToken(" in ", JournalTokenColor.Primary),
            JournalToken("Library", JournalTokenColor.Screen),
        )
    }
    if (summary.startsWith("Opened ") && summary.endsWith(" rulesheet from Library")) {
        val game = summary.removePrefix("Opened ").removeSuffix(" rulesheet from Library")
        return listOf(
            JournalToken("Opened ", JournalTokenColor.Primary),
            JournalToken(game, JournalTokenColor.Game),
            JournalToken(" rulesheet", JournalTokenColor.Screen),
            JournalToken(" from ", JournalTokenColor.Primary),
            JournalToken("Library", JournalTokenColor.Screen),
        )
    }
    if (summary.startsWith("Opened ") && summary.endsWith(" playfield image from Library")) {
        val game = summary.removePrefix("Opened ").removeSuffix(" playfield image from Library")
        return listOf(
            JournalToken("Opened ", JournalTokenColor.Primary),
            JournalToken(game, JournalTokenColor.Game),
            JournalToken(" playfield image", JournalTokenColor.Screen),
            JournalToken(" from ", JournalTokenColor.Primary),
            JournalToken("Library", JournalTokenColor.Screen),
        )
    }
    if (summary.startsWith("Opened ") && summary.endsWith(" in Library")) {
        val marker = " video for "
        val idx = summary.indexOf(marker)
        if (idx > "Opened ".length) {
            val detail = summary.substring("Opened ".length, idx)
            val game = summary.substring(idx + marker.length, summary.length - " in Library".length)
            return listOf(
                JournalToken("Opened ", JournalTokenColor.Primary),
                JournalToken(detail, JournalTokenColor.Screen),
                JournalToken(" video", JournalTokenColor.Screen),
                JournalToken(" for ", JournalTokenColor.Primary),
                JournalToken(game, JournalTokenColor.Game),
                JournalToken(" in ", JournalTokenColor.Primary),
                JournalToken("Library", JournalTokenColor.Screen),
            )
        }
    }
    return null
}

private fun parsePracticePlayfieldSummary(summary: String): List<JournalToken>? {
    if (!summary.startsWith("Viewed ")) return null
    val marker = " playfield"
    val idx = summary.indexOf(marker)
    if (idx <= "Viewed ".length) return null
    val game = summary.substring("Viewed ".length, idx)
    if (game.isBlank()) return null
    val suffix = summary.substring(idx + marker.length)
    val note = when {
        suffix.isEmpty() -> null
        suffix.startsWith(": ") -> suffix.removePrefix(": ")
        else -> return null
    }
    return buildList {
        add(JournalToken("Viewed ", JournalTokenColor.Primary))
        add(JournalToken(game, JournalTokenColor.Game))
        add(JournalToken(" ", JournalTokenColor.Primary))
        add(JournalToken("playfield", JournalTokenColor.Screen))
        if (!note.isNullOrEmpty()) add(JournalToken(": $note", JournalTokenColor.Primary))
    }
}

private fun parsePracticeRulesheetSummary(summary: String): List<JournalToken>? {
    if (!summary.startsWith("Read ") || !summary.endsWith(" rulesheet")) return null
    val body = summary.removePrefix("Read ").removeSuffix(" rulesheet")
    val ofIdx = body.indexOf(" of ")
    return if (ofIdx > 0) {
        val progress = body.substring(0, ofIdx)
        val game = body.substring(ofIdx + 4)
        if (progress.isBlank() || game.isBlank()) null else listOf(
            JournalToken("Read ", JournalTokenColor.Primary),
            JournalToken(progress, JournalTokenColor.Screen),
            JournalToken(" of ", JournalTokenColor.Primary),
            JournalToken(game, JournalTokenColor.Game),
            JournalToken(" ", JournalTokenColor.Primary),
            JournalToken("rulesheet", JournalTokenColor.Screen),
        )
    } else {
        if (body.isBlank()) null else listOf(
            JournalToken("Read ", JournalTokenColor.Primary),
            JournalToken(body, JournalTokenColor.Game),
            JournalToken(" ", JournalTokenColor.Primary),
            JournalToken("rulesheet", JournalTokenColor.Screen),
        )
    }
}

private fun parsePracticeVideoSummary(summary: String): List<JournalToken>? {
    if (summary.startsWith("Tutorial for ")) {
        val idx = summary.indexOf(": ")
        if (idx > "Tutorial for ".length) {
            val game = summary.substring("Tutorial for ".length, idx)
            val value = summary.substring(idx + 2)
            if (game.isNotBlank()) {
                return listOf(
                    JournalToken("Tutorial", JournalTokenColor.Screen),
                    JournalToken(" for ", JournalTokenColor.Primary),
                    JournalToken(game, JournalTokenColor.Game),
                    JournalToken(": ", JournalTokenColor.Primary),
                    JournalToken(value, JournalTokenColor.Primary),
                )
            }
        }
    }
    if (summary.startsWith("Gameplay for ")) {
        val idx = summary.indexOf(": ")
        if (idx > "Gameplay for ".length) {
            val game = summary.substring("Gameplay for ".length, idx)
            val value = summary.substring(idx + 2)
            if (game.isNotBlank()) {
                return listOf(
                    JournalToken("Gameplay", JournalTokenColor.Screen),
                    JournalToken(" for ", JournalTokenColor.Primary),
                    JournalToken(game, JournalTokenColor.Game),
                    JournalToken(": ", JournalTokenColor.Primary),
                    JournalToken(value, JournalTokenColor.Primary),
                )
            }
        }
    }
    if (summary.startsWith("Updated tutorial progress for ")) {
        val game = summary.removePrefix("Updated tutorial progress for ")
        if (game.isNotBlank()) {
            return listOf(
                JournalToken("Updated ", JournalTokenColor.Primary),
                JournalToken("tutorial", JournalTokenColor.Screen),
                JournalToken(" progress for ", JournalTokenColor.Primary),
                JournalToken(game, JournalTokenColor.Game),
            )
        }
    }
    if (summary.startsWith("Updated gameplay progress for ")) {
        val game = summary.removePrefix("Updated gameplay progress for ")
        if (game.isNotBlank()) {
            return listOf(
                JournalToken("Updated ", JournalTokenColor.Primary),
                JournalToken("gameplay", JournalTokenColor.Screen),
                JournalToken(" progress for ", JournalTokenColor.Primary),
                JournalToken(game, JournalTokenColor.Game),
            )
        }
    }
    return null
}

private fun parsePracticeProgressSummary(summary: String): List<JournalToken>? {
    if (summary.startsWith("Practice progress ")) {
        val onIdx = summary.indexOf(" on ")
        if (onIdx > "Practice progress ".length) {
            val value = summary.substring("Practice progress ".length, onIdx)
            val game = summary.substring(onIdx + 4)
            if (value.isNotBlank() && game.isNotBlank()) {
                return listOf(
                    JournalToken("Practice", JournalTokenColor.Screen),
                    JournalToken(" progress ", JournalTokenColor.Primary),
                    JournalToken(value, JournalTokenColor.Screen),
                    JournalToken(" on ", JournalTokenColor.Primary),
                    JournalToken(game, JournalTokenColor.Game),
                )
            }
        }
    }
    if (summary.startsWith("Logged practice for ")) {
        val game = summary.removePrefix("Logged practice for ")
        if (game.isNotBlank()) {
            return listOf(
                JournalToken("Logged ", JournalTokenColor.Primary),
                JournalToken("practice", JournalTokenColor.Screen),
                JournalToken(" for ", JournalTokenColor.Primary),
                JournalToken(game, JournalTokenColor.Game),
            )
        }
    }
    return null
}

private fun parsePracticeBrowsedSummary(summary: String): List<JournalToken>? {
    if (!summary.startsWith("Browsed ") || summary.endsWith(" in Library")) return null
    val game = summary.removePrefix("Browsed ")
    if (game.isBlank()) return null
    return listOf(
        JournalToken("Browsed ", JournalTokenColor.Primary),
        JournalToken(game, JournalTokenColor.Game),
    )
}
