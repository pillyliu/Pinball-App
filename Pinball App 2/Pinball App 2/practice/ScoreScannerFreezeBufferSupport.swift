import Foundation
import UIKit

struct ScoreScannerBufferedFreezeFrame {
    let score: Int
    let previewImage: UIImage
    let confidence: Float
    let digitCount: Int
    let formatQuality: Int
    let capturedAt: Date
}

func scoreScannerShouldReplaceBufferedFreezeFrame(
    candidate: ScoreScannerCandidate,
    existing: ScoreScannerBufferedFreezeFrame?,
    now: Date = Date()
) -> Bool {
    guard let existing else { return true }
    if candidate.formatQuality != existing.formatQuality {
        return candidate.formatQuality > existing.formatQuality
    }
    if candidate.digitCount != existing.digitCount {
        return candidate.digitCount > existing.digitCount
    }
    if candidate.confidence != existing.confidence {
        return candidate.confidence > existing.confidence
    }
    return now.timeIntervalSince(existing.capturedAt) > 0.4
}

func scoreScannerShouldStoreBufferedFreezeFrame(
    _ buffered: ScoreScannerBufferedFreezeFrame,
    replacing existing: ScoreScannerBufferedFreezeFrame?,
    now: Date = Date()
) -> Bool {
    guard let existing else { return true }
    if buffered.formatQuality != existing.formatQuality {
        return buffered.formatQuality > existing.formatQuality
    }
    if buffered.digitCount != existing.digitCount {
        return buffered.digitCount > existing.digitCount
    }
    if buffered.confidence != existing.confidence {
        return buffered.confidence > existing.confidence
    }
    return now.timeIntervalSince(existing.capturedAt) > 0.4
}

func scoreScannerBufferedFreezeFrame(
    previewImage: UIImage,
    candidate: ScoreScannerCandidate,
    capturedAt: Date = Date()
) -> ScoreScannerBufferedFreezeFrame {
    ScoreScannerBufferedFreezeFrame(
        score: candidate.normalizedScore,
        previewImage: previewImage,
        confidence: candidate.confidence,
        digitCount: candidate.digitCount,
        formatQuality: candidate.formatQuality,
        capturedAt: capturedAt
    )
}

func scoreScannerPrunedFreezeFrames(
    _ frames: [Int: ScoreScannerBufferedFreezeFrame],
    now: Date = Date(),
    lifetime: TimeInterval
) -> [Int: ScoreScannerBufferedFreezeFrame] {
    frames.filter { _, frame in
        now.timeIntervalSince(frame.capturedAt) <= lifetime
    }
}

func scoreScannerUpdatedFreezeFrames(
    _ frames: [Int: ScoreScannerBufferedFreezeFrame],
    adding buffered: ScoreScannerBufferedFreezeFrame,
    now: Date = Date(),
    lifetime: TimeInterval,
    maximumCount: Int
) -> [Int: ScoreScannerBufferedFreezeFrame] {
    var updated = scoreScannerPrunedFreezeFrames(frames, now: now, lifetime: lifetime)
    guard scoreScannerShouldStoreBufferedFreezeFrame(
        buffered,
        replacing: updated[buffered.score],
        now: now
    ) else {
        return updated
    }

    updated[buffered.score] = buffered
    if updated.count > maximumCount {
        let staleScores = updated.values
            .sorted(by: { $0.capturedAt < $1.capturedAt })
            .prefix(updated.count - maximumCount)
            .map(\.score)
        staleScores.forEach { updated.removeValue(forKey: $0) }
    }
    return updated
}
