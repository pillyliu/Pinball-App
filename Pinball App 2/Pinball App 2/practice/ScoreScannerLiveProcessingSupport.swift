import CoreImage
import UIKit

struct ScoreScannerLiveProcessingStart {
    let latestOrientedFrame: CIImage
    let croppedFrame: CIImage?
    let lastOCRTime: CFTimeInterval
    let isProcessingFrame: Bool
}

func scoreScannerPreferredFreezeReading(
    liveCandidateReading: ScoreScannerLockedReading?,
    snapshot: ScoreStabilityService.Snapshot?
) -> ScoreScannerLockedReading? {
    if let liveCandidateReading {
        return liveCandidateReading
    }
    return scoreScannerLockedReading(from: snapshot)
}

func scoreScannerShouldBufferFreezeFrame(
    _ candidate: ScoreScannerCandidate,
    frames: [Int: ScoreScannerBufferedFreezeFrame],
    now: Date = Date(),
    lifetime: TimeInterval
) -> (frames: [Int: ScoreScannerBufferedFreezeFrame], shouldBuffer: Bool) {
    let pruned = scoreScannerPrunedFreezeFrames(frames, now: now, lifetime: lifetime)
    let shouldBuffer = scoreScannerShouldReplaceBufferedFreezeFrame(
        candidate: candidate,
        existing: pruned[candidate.normalizedScore],
        now: now
    )
    return (pruned, shouldBuffer)
}

func scoreScannerUpdatedBufferedFreezeFrames(
    croppedFrame: CIImage,
    candidate: ScoreScannerCandidate,
    ciContext: CIContext,
    frames: [Int: ScoreScannerBufferedFreezeFrame],
    lifetime: TimeInterval,
    maximumCount: Int
) -> [Int: ScoreScannerBufferedFreezeFrame]? {
    guard let previewImage = scoreScannerPreviewImage(from: croppedFrame, ciContext: ciContext) else {
        return nil
    }
    let buffered = scoreScannerBufferedFreezeFrame(
        previewImage: previewImage,
        candidate: candidate
    )
    return scoreScannerUpdatedFreezeFrames(
        frames,
        adding: buffered,
        lifetime: lifetime,
        maximumCount: maximumCount
    )
}

func scoreScannerBufferedFreezePreview(
    for score: Int,
    frames: [Int: ScoreScannerBufferedFreezeFrame],
    lifetime: TimeInterval
) -> (frames: [Int: ScoreScannerBufferedFreezeFrame], image: UIImage?) {
    let pruned = scoreScannerPrunedFreezeFrames(
        frames,
        lifetime: lifetime
    )
    return (pruned, pruned[score]?.previewImage)
}

func scoreScannerLiveProcessingStart(
    fullFrame: CIImage,
    previewMapping: ScoreScannerPreviewMapping?,
    processingPaused: Bool,
    isProcessingFrame: Bool,
    lastOCRTime: CFTimeInterval,
    liveOCRInterval: CFTimeInterval,
    now: CFTimeInterval = CACurrentMediaTime()
) -> ScoreScannerLiveProcessingStart {
    guard !processingPaused, !isProcessingFrame else {
        return ScoreScannerLiveProcessingStart(
            latestOrientedFrame: fullFrame,
            croppedFrame: nil,
            lastOCRTime: lastOCRTime,
            isProcessingFrame: isProcessingFrame
        )
    }

    guard now - lastOCRTime >= liveOCRInterval else {
        return ScoreScannerLiveProcessingStart(
            latestOrientedFrame: fullFrame,
            croppedFrame: nil,
            lastOCRTime: lastOCRTime,
            isProcessingFrame: isProcessingFrame
        )
    }

    guard let croppedFrame = scoreScannerCrop(frame: fullFrame, previewMapping: previewMapping) else {
        return ScoreScannerLiveProcessingStart(
            latestOrientedFrame: fullFrame,
            croppedFrame: nil,
            lastOCRTime: lastOCRTime,
            isProcessingFrame: isProcessingFrame
        )
    }

    return ScoreScannerLiveProcessingStart(
        latestOrientedFrame: fullFrame,
        croppedFrame: croppedFrame,
        lastOCRTime: now,
        isProcessingFrame: true
    )
}
