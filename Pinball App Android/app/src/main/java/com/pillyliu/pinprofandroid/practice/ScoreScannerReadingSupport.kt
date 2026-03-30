package com.pillyliu.pinprofandroid.practice

internal fun scoreScannerFilteredAnalysis(
    analysis: ScoreScannerAnalysis,
    minimumDigitCount: Int,
    minimumHorizontalPadding: Float,
    minimumVerticalPadding: Float,
): ScoreScannerAnalysis {
    val filteredCandidates = analysis.candidates.filter { candidate ->
        candidate.digitCount >= minimumDigitCount &&
            candidate.boundingBox.left >= minimumHorizontalPadding &&
            candidate.boundingBox.right <= (1f - minimumHorizontalPadding) &&
            candidate.boundingBox.top >= minimumVerticalPadding &&
            candidate.boundingBox.bottom <= (1f - minimumVerticalPadding)
    }

    return ScoreScannerAnalysis(
        bestCandidate = filteredCandidates.firstOrNull(),
        candidates = filteredCandidates,
    )
}

internal fun scoreScannerLockedReading(
    snapshot: ScoreScannerStabilityService.Snapshot?,
): ScoreScannerLockedReading? {
    val reading = snapshot?.dominantReading ?: return null
    return ScoreScannerLockedReading(
        score = reading.score,
        formattedScore = reading.formattedScore,
        rawText = reading.rawText,
        confidence = reading.confidence,
        averageConfidence = snapshot.averageConfidence,
    )
}

internal fun scoreScannerDisplayedReading(
    snapshot: ScoreScannerStabilityService.Snapshot?,
    bestCandidate: ScoreScannerCandidate?,
): ScoreScannerLockedReading? {
    scoreScannerLockedReading(snapshot)?.let { return it }
    val candidate = bestCandidate ?: return null
    return scoreScannerReadingFrom(candidate)
}

internal fun scoreScannerReadingFrom(candidate: ScoreScannerCandidate): ScoreScannerLockedReading {
    return ScoreScannerLockedReading(
        score = candidate.normalizedScore,
        formattedScore = candidate.formattedScore,
        rawText = candidate.rawText,
        confidence = candidate.confidence,
        averageConfidence = candidate.confidence,
    )
}

internal fun shouldAttemptScoreScannerLiveBitmapFallback(
    now: Long,
    lastFallbackAt: Long,
    snapshot: ScoreScannerStabilityService.Snapshot?,
    sourceBestCandidate: ScoreScannerCandidate?,
    liveBitmapFallbackIntervalMs: Long,
    strongLiveCandidateDigitCount: Int,
    strongLiveCandidateFormatQuality: Int,
): Boolean {
    if (now - lastFallbackAt < liveBitmapFallbackIntervalMs) return false
    if (snapshot?.state == ScoreScannerStatus.Locked) return false
    val candidate = sourceBestCandidate ?: return true
    return candidate.digitCount < strongLiveCandidateDigitCount ||
        candidate.formatQuality < strongLiveCandidateFormatQuality
}

internal fun mergeScoreScannerAnalyses(
    primary: ScoreScannerAnalysis,
    secondary: ScoreScannerAnalysis,
): ScoreScannerAnalysis {
    val rankedCandidates = ScoreScannerParsingService.rankCandidates(
        primary.candidates + secondary.candidates
    )
    return ScoreScannerAnalysis(
        bestCandidate = rankedCandidates.firstOrNull(),
        candidates = rankedCandidates,
    )
}
