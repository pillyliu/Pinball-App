import CoreGraphics

func scoreScannerLockedReading(from snapshot: ScoreStabilityService.Snapshot?) -> ScoreScannerLockedReading? {
    guard let snapshot, let reading = snapshot.dominantReading else { return nil }
    return ScoreScannerLockedReading(
        score: reading.score,
        formattedScore: reading.formattedScore,
        rawText: reading.rawText
    )
}

func scoreScannerDisplayedReading(
    from snapshot: ScoreStabilityService.Snapshot,
    bestCandidate: ScoreScannerCandidate?
) -> ScoreScannerLockedReading? {
    if let locked = scoreScannerLockedReading(from: snapshot) {
        return locked
    }
    guard let bestCandidate else { return nil }
    return scoreScannerReading(from: bestCandidate)
}

func scoreScannerReading(from candidate: ScoreScannerCandidate) -> ScoreScannerLockedReading {
    ScoreScannerLockedReading(
        score: candidate.normalizedScore,
        formattedScore: candidate.formattedScore,
        rawText: candidate.rawText
    )
}

func scoreScannerFilteredAnalysis(
    _ analysis: ScoreOCRAnalysis,
    minimumDigitCount: Int,
    minimumHorizontalPadding: CGFloat,
    minimumVerticalPadding: CGFloat
) -> ScoreOCRAnalysis {
    let filteredCandidates = analysis.candidates.filter { candidate in
        candidate.digitCount >= minimumDigitCount &&
        candidate.boundingBox.minX >= minimumHorizontalPadding &&
        candidate.boundingBox.maxX <= (1 - minimumHorizontalPadding) &&
        candidate.boundingBox.minY >= minimumVerticalPadding &&
        candidate.boundingBox.maxY <= (1 - minimumVerticalPadding)
    }
    return ScoreOCRAnalysis(bestCandidate: filteredCandidates.first, candidates: filteredCandidates)
}
