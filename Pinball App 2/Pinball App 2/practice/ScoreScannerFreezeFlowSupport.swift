import CoreImage
import UIKit

extension ScoreScannerViewModel {
    func freeze(
        using frame: CIImage?,
        preferredReading: ScoreScannerLockedReading?,
        preferredPreviewImage: UIImage?
    ) {
        guard frame != nil || preferredPreviewImage != nil else { return }

        let mapping = captureQueue.sync { () -> ScoreScannerPreviewMapping? in
            processingPaused = true
            return previewMapping
        }
        let cropped = frame.flatMap { scoreScannerCrop(frame: $0, previewMapping: mapping) }
        let previewSource = cropped ?? frame
        let previewImage = preferredPreviewImage ?? previewSource.flatMap { scoreScannerPreviewImage(from: $0, ciContext: ciContext) }
        let frozenOcrImage = previewImage.flatMap(scoreScannerOCRImage(from:)) ?? cropped
        DispatchQueue.main.async {
            self.isFrozen = true
            self.frozenPreviewImage = previewImage
            self.lockedReading = preferredReading
            if let preferredReading {
                self.confirmationText = preferredReading.formattedScore
            }
            self.confirmationValidationMessage = nil
            self.status = preferredReading == nil ? .stableCandidate : .locked
        }

        ocrQueue.async { [weak self] in
            guard let self, let frozenOcrImage else { return }
            do {
                let analysis = try self.ocrService.recognize(
                    in: frozenOcrImage,
                    mode: .finalPass,
                    displayMode: self.displayMode
                )
                let filteredAnalysis = scoreScannerFilteredAnalysis(
                    analysis,
                    minimumDigitCount: self.minimumFinalDigitCount,
                    minimumHorizontalPadding: 0.04,
                    minimumVerticalPadding: 0.04
                )
                let locked = filteredAnalysis.bestCandidate.map(scoreScannerReading(from:)) ?? preferredReading
                DispatchQueue.main.async {
                    self.candidateHighlights = filteredAnalysis.candidates
                    self.lockedReading = locked
                    if let locked {
                        self.confirmationText = locked.formattedScore
                        self.status = .locked
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if let preferredReading {
                        self.lockedReading = preferredReading
                        self.confirmationText = preferredReading.formattedScore
                        self.status = .locked
                    }
                }
            }
        }
    }

    func process(
        analysis: ScoreOCRAnalysis,
        fullFrame: CIImage,
        croppedFrame: CIImage
    ) {
        let filteredAnalysis = scoreScannerFilteredAnalysis(
            analysis,
            minimumDigitCount: minimumLiveDigitCount,
            minimumHorizontalPadding: 0.10,
            minimumVerticalPadding: 0.10
        )
        if let candidate = filteredAnalysis.bestCandidate,
           shouldBufferFreezeFrame(for: candidate) {
            bufferFreezeFrame(croppedFrame: croppedFrame, candidate: candidate)
        }
        let snapshot = captureQueue.sync { () -> ScoreStabilityService.Snapshot in
            let snapshot = stabilityService.ingest(candidate: filteredAnalysis.bestCandidate)
            latestSnapshot = snapshot
            return snapshot
        }
        let displayState = scoreScannerLiveDisplayState(
            filteredAnalysis: filteredAnalysis,
            snapshot: snapshot
        )

        DispatchQueue.main.async {
            self.candidateHighlights = displayState.candidateHighlights
            self.liveCandidateReading = displayState.liveCandidateReading
            self.liveReadingText = displayState.liveReadingText
            self.status = displayState.status
        }

        if snapshot.state == .locked, let locked = scoreScannerLockedReading(from: snapshot) {
            DispatchQueue.main.async {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
            freeze(
                using: fullFrame,
                preferredReading: locked,
                preferredPreviewImage: bufferedFreezePreviewImage(for: locked.score)
            )
        }
    }

    func preferredFreezeReading() -> ScoreScannerLockedReading? {
        let snapshot = captureQueue.sync { latestSnapshot }
        return scoreScannerPreferredFreezeReading(
            liveCandidateReading: liveCandidateReading,
            snapshot: snapshot
        )
    }

    func shouldBufferFreezeFrame(for candidate: ScoreScannerCandidate) -> Bool {
        captureQueue.sync {
            let result = scoreScannerShouldBufferFreezeFrame(
                candidate,
                frames: bufferedFreezeFrames,
                lifetime: bufferedFreezeFrameLifetime
            )
            bufferedFreezeFrames = result.frames
            return result.shouldBuffer
        }
    }

    func bufferFreezeFrame(croppedFrame: CIImage, candidate: ScoreScannerCandidate) {
        captureQueue.async { [weak self] in
            guard let self else { return }
            guard let updatedFrames = scoreScannerUpdatedBufferedFreezeFrames(
                croppedFrame: croppedFrame,
                candidate: candidate,
                ciContext: self.ciContext,
                frames: self.bufferedFreezeFrames,
                lifetime: self.bufferedFreezeFrameLifetime,
                maximumCount: self.maximumBufferedFreezeFrames
            ) else { return }
            self.bufferedFreezeFrames = updatedFrames
        }
    }

    func bufferedFreezePreviewImage(for score: Int) -> UIImage? {
        captureQueue.sync {
            let result = scoreScannerBufferedFreezePreview(
                for: score,
                frames: bufferedFreezeFrames,
                lifetime: bufferedFreezeFrameLifetime
            )
            bufferedFreezeFrames = result.frames
            return result.image
        }
    }

    func handleCapturedFrame(_ fullFrame: CIImage) {
        guard let cropped = beginLiveProcessing(for: fullFrame) else { return }

        ocrQueue.async { [weak self] in
            guard let self else { return }
            defer {
                self.finishLiveProcessing()
            }

            do {
                let analysis = try self.ocrService.recognize(in: cropped, mode: .livePreview, displayMode: self.displayMode)
                self.process(analysis: analysis, fullFrame: fullFrame, croppedFrame: cropped)
            } catch {
                let snapshot = self.captureQueue.sync { () -> ScoreStabilityService.Snapshot in
                    let snapshot = self.stabilityService.ingest(candidate: nil)
                    self.latestSnapshot = snapshot
                    return snapshot
                }
                let locked = scoreScannerLockedReading(from: snapshot)
                if snapshot.state == .locked, let locked {
                    DispatchQueue.main.async {
                        let feedback = UINotificationFeedbackGenerator()
                        feedback.notificationOccurred(.success)
                    }
                    self.freeze(
                        using: fullFrame,
                        preferredReading: locked,
                        preferredPreviewImage: self.bufferedFreezePreviewImage(for: locked.score)
                    )
                } else {
                    let displayState = scoreScannerFailureDisplayState(snapshot: snapshot)
                    DispatchQueue.main.async {
                        self.candidateHighlights = displayState.candidateHighlights
                        self.liveReadingText = displayState.liveReadingText
                        self.status = displayState.status
                    }
                }
            }
        }
    }

    func beginLiveProcessing(for fullFrame: CIImage) -> CIImage? {
        captureQueue.sync {
            let start = scoreScannerLiveProcessingStart(
                fullFrame: fullFrame,
                previewMapping: previewMapping,
                processingPaused: processingPaused,
                isProcessingFrame: isProcessingFrame,
                lastOCRTime: lastOCRTime,
                liveOCRInterval: liveOCRInterval
            )
            latestOrientedFrame = start.latestOrientedFrame
            lastOCRTime = start.lastOCRTime
            isProcessingFrame = start.isProcessingFrame
            return start.croppedFrame
        }
    }

    func finishLiveProcessing() {
        captureQueue.async { [weak self] in
            self?.isProcessingFrame = false
        }
    }
}
