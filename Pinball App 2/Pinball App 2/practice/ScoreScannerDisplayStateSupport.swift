import Foundation

struct ScoreScannerLiveDisplayState {
    let candidateHighlights: [ScoreScannerCandidate]
    let liveCandidateReading: ScoreScannerLockedReading?
    let liveReadingText: String
    let status: ScoreScannerStatus
}

func scoreScannerLiveDisplayState(
    filteredAnalysis: ScoreOCRAnalysis,
    snapshot: ScoreStabilityService.Snapshot
) -> ScoreScannerLiveDisplayState {
    let displayedReading = scoreScannerDisplayedReading(
        from: snapshot,
        bestCandidate: filteredAnalysis.bestCandidate
    )

    let liveReadingText: String
    if let reading = snapshot.dominantReading {
        liveReadingText = reading.formattedScore
    } else if let best = filteredAnalysis.bestCandidate {
        liveReadingText = best.formattedScore
    } else {
        liveReadingText = "No reading yet"
    }

    return ScoreScannerLiveDisplayState(
        candidateHighlights: Array(filteredAnalysis.candidates.prefix(3)),
        liveCandidateReading: displayedReading,
        liveReadingText: liveReadingText,
        status: snapshot.state
    )
}

func scoreScannerFailureDisplayState(
    snapshot: ScoreStabilityService.Snapshot
) -> ScoreScannerLiveDisplayState {
    let locked = scoreScannerLockedReading(from: snapshot)
    return ScoreScannerLiveDisplayState(
        candidateHighlights: [],
        liveCandidateReading: nil,
        liveReadingText: locked?.formattedScore ?? "No reading yet",
        status: snapshot.state
    )
}
