package com.pillyliu.pinprofandroid.practice

import kotlin.math.abs
import kotlin.math.hypot

internal object ScoreScannerParsingService {
    fun rankedCandidates(observations: List<ScoreOcrObservation>): List<ScoreScannerCandidate> {
        val seen = linkedSetOf<Int>()
        return observations
            .mapNotNull(::candidateFrom)
            .sortedWith(::candidateSort)
            .filter { candidate -> seen.add(candidate.normalizedScore) }
    }

    fun normalizedScore(raw: String): Int? {
        val digits = raw.filter(Char::isDigit)
        val score = digits.toIntOrNull() ?: return null
        return score.takeIf { it > 0 }
    }

    fun formattedScore(score: Int): String {
        val digits = score.toString()
        if (digits.length <= 3) return digits
        return digits.reversed().chunked(3).joinToString(",").reversed()
    }

    fun formattedScoreInput(raw: String): String {
        val digits = raw.filter(Char::isDigit)
        val value = digits.toIntOrNull() ?: return digits
        return value.takeIf { it > 0 }?.let(::formattedScore).orEmpty()
    }

    private fun candidateFrom(observation: ScoreOcrObservation): ScoreScannerCandidate? {
        val normalized = normalizeOcrText(observation.text) ?: return null
        val centerX = observation.boundingBox.centerX()
        val centerY = observation.boundingBox.centerY()
        val distance = hypot(centerX - 0.5f, centerY - 0.5f)
        val maxDistance = hypot(0.5f, 0.5f)
        val centerBias = (1f - (distance / maxDistance)).coerceIn(0f, 1f).toDouble()

        return ScoreScannerCandidate(
            rawText = observation.text,
            normalizedScore = normalized.score,
            formattedScore = formattedScore(normalized.score),
            confidence = observation.confidence,
            boundingBox = observation.boundingBox,
            digitCount = normalized.digitCount,
            centerBias = centerBias,
        )
    }

    private fun candidateSort(
        lhs: ScoreScannerCandidate,
        rhs: ScoreScannerCandidate,
    ): Int {
        if (abs(lhs.digitCount - rhs.digitCount) >= 3) {
            return rhs.digitCount.compareTo(lhs.digitCount)
        }
        if (abs(lhs.centerBias - rhs.centerBias) > 0.001) {
            return rhs.centerBias.compareTo(lhs.centerBias)
        }
        if (lhs.digitCount != rhs.digitCount) {
            return rhs.digitCount.compareTo(lhs.digitCount)
        }
        return rhs.confidence.compareTo(lhs.confidence)
    }

    private fun normalizeOcrText(raw: String): NormalizedScore? {
        val strippedWhitespace = raw
            .replace(" ", "")
            .replace("\n", "")
            .trim()
        if (strippedWhitespace.isEmpty()) return null

        val mapped = buildString(strippedWhitespace.length) {
            strippedWhitespace.forEach { character ->
                append(
                    when (character) {
                        'O', 'o' -> '0'
                        'I', 'l' -> '1'
                        'S' -> '5'
                        else -> character
                    }
                )
            }
        }

        val bestRun = digitLikeRuns(mapped).maxWithOrNull(
            compareBy<String> { it.length }.thenBy { it }
        ) ?: return null

        val digits = bestRun.filter(Char::isDigit)
        if (digits.isEmpty() || digits.length > 15) return null
        val score = digits.toIntOrNull() ?: return null
        if (score <= 0) return null

        return NormalizedScore(score = score, digitCount = digits.length)
    }

    private fun digitLikeRuns(text: String): List<String> {
        val runs = mutableListOf<String>()
        val current = StringBuilder()
        text.forEach { character ->
            if (character.isDigit() || character == ',' || character == '.' || character == '\'') {
                current.append(character)
            } else if (current.isNotEmpty()) {
                runs += current.toString()
                current.clear()
            }
        }
        if (current.isNotEmpty()) {
            runs += current.toString()
        }
        return runs
    }

    private data class NormalizedScore(
        val score: Int,
        val digitCount: Int,
    )
}
