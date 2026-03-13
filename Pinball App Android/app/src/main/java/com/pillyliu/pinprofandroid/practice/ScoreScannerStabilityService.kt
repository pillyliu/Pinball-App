package com.pillyliu.pinprofandroid.practice

import kotlin.math.abs

internal class ScoreScannerStabilityService(
    private val configuration: Configuration = Configuration(),
) {
    data class Configuration(
        val maxRecentReadings: Int = 6,
        val requiredMatches: Int = 3,
        val minimumAverageConfidence: Float = 0.38f,
        val failedAfterMisses: Int = 5,
    )

    data class Reading(
        val score: Long,
        val formattedScore: String,
        val rawText: String,
        val digitCount: Int,
        val confidence: Float,
        val timestampMs: Long,
    )

    data class Snapshot(
        val state: ScoreScannerStatus,
        val dominantReading: Reading?,
        val occurrences: Int,
        val averageConfidence: Float,
    )

    private val recentReadings = ArrayDeque<Reading>()
    private var consecutiveMisses = 0

    fun reset() {
        recentReadings.clear()
        consecutiveMisses = 0
    }

    fun ingest(candidate: ScoreScannerCandidate?): Snapshot {
        if (candidate != null) {
            consecutiveMisses = 0
            recentReadings += Reading(
                score = candidate.normalizedScore,
                formattedScore = candidate.formattedScore,
                rawText = candidate.rawText,
                digitCount = candidate.digitCount,
                confidence = candidate.confidence,
                timestampMs = System.currentTimeMillis(),
            )
            while (recentReadings.size > configuration.maxRecentReadings) {
                recentReadings.removeFirst()
            }
        } else {
            consecutiveMisses += 1
            if (consecutiveMisses >= configuration.failedAfterMisses) {
                recentReadings.clear()
                return Snapshot(
                    state = ScoreScannerStatus.FailedNoReading,
                    dominantReading = null,
                    occurrences = 0,
                    averageConfidence = 0f,
                )
            }
        }

        val dominant = dominantConsensus()
            ?: return Snapshot(
                state = if (consecutiveMisses > 0) ScoreScannerStatus.FailedNoReading else ScoreScannerStatus.Searching,
                dominantReading = null,
                occurrences = 0,
                averageConfidence = 0f,
            )

        return when {
            dominant.occurrences >= configuration.requiredMatches &&
                dominant.averageConfidence >= configuration.minimumAverageConfidence -> Snapshot(
                    state = ScoreScannerStatus.Locked,
                    dominantReading = dominant.reading,
                    occurrences = dominant.occurrences,
                    averageConfidence = dominant.averageConfidence,
                )

            dominant.occurrences >= maxOf(2, configuration.requiredMatches - 1) -> Snapshot(
                state = ScoreScannerStatus.StableCandidate,
                dominantReading = dominant.reading,
                occurrences = dominant.occurrences,
                averageConfidence = dominant.averageConfidence,
            )

            else -> Snapshot(
                state = ScoreScannerStatus.Reading,
                dominantReading = dominant.reading,
                occurrences = dominant.occurrences,
                averageConfidence = dominant.averageConfidence,
            )
        }
    }

    private fun dominantConsensus(): Consensus? {
        val ranked = recentReadings
            .groupBy { it.score }
            .values
            .mapNotNull { bucket ->
                val best = bucket.maxWithOrNull(
                    compareBy<Reading> { it.confidence }.thenBy { it.timestampMs }
                ) ?: return@mapNotNull null
                val averageConfidence = bucket.map { it.confidence }.average().toFloat()
                Consensus(
                    reading = best,
                    occurrences = bucket.size,
                    averageConfidence = averageConfidence,
                )
            }

        return ranked.maxWithOrNull { lhs, rhs ->
            when {
                abs(lhs.occurrences - rhs.occurrences) >= 2 ->
                    lhs.occurrences.compareTo(rhs.occurrences)
                lhs.reading.digitCount != rhs.reading.digitCount ->
                    lhs.reading.digitCount.compareTo(rhs.reading.digitCount)
                lhs.occurrences != rhs.occurrences ->
                    lhs.occurrences.compareTo(rhs.occurrences)
                lhs.averageConfidence != rhs.averageConfidence ->
                    lhs.averageConfidence.compareTo(rhs.averageConfidence)
                else -> lhs.reading.timestampMs.compareTo(rhs.reading.timestampMs)
            }
        }
    }

    private data class Consensus(
        val reading: Reading,
        val occurrences: Int,
        val averageConfidence: Float,
    )
}
