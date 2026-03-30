package com.pillyliu.pinprofandroid.practice

import java.text.NumberFormat
import java.util.Locale

internal object ScoreScannerParsingService {
    fun rankedCandidates(observations: List<ScoreOcrObservation>): List<ScoreScannerCandidate> {
        return rankCandidates(
            observations.mapNotNull(::scoreScannerCandidateFrom)
        )
    }

    fun rankCandidates(candidates: List<ScoreScannerCandidate>): List<ScoreScannerCandidate> {
        val seen = linkedSetOf<Long>()
        return candidates
            .sortedWith(::scoreScannerCandidateSort)
            .filter { candidate -> seen.add(candidate.normalizedScore) }
    }

    fun normalizedScore(raw: String): Long? {
        val digits = raw.filter(Char::isDigit)
        val score = digits.toLongOrNull() ?: return null
        return score.takeIf { it > 0 }
    }

    fun formattedScore(score: Long): String {
        val formatter = NumberFormat.getIntegerInstance(Locale.US)
        formatter.isGroupingUsed = true
        return formatter.format(score)
    }

    fun formattedScoreInput(raw: String): String {
        val digits = raw.filter(Char::isDigit)
        val value = digits.toLongOrNull()
        return when {
            digits.isEmpty() -> ""
            value == null -> digits
            value > 0 -> formattedScore(value)
            else -> digits
        }
    }
}
