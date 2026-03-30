import SwiftUI
import Combine
@preconcurrency import AVFoundation
import CoreImage
import UIKit

final class ScoreScannerViewModel: NSObject, ObservableObject {
    @Published var isCameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @Published var status: ScoreScannerStatus = .searching
    @Published var liveReadingText: String = "No reading yet"
    @Published var liveCandidateReading: ScoreScannerLockedReading?
    @Published var candidateHighlights: [ScoreScannerCandidate] = []
    @Published var lockedReading: ScoreScannerLockedReading?
    @Published var isFrozen = false
    @Published var frozenPreviewImage: UIImage?
    @Published var zoomFactor: CGFloat = 1
    @Published var availableZoomRange: ClosedRange<CGFloat> = 1...8
    @Published var confirmationText: String = ""
    @Published var confirmationValidationMessage: String?

    let session = AVCaptureSession()

    let sessionQueue = DispatchQueue(label: "score-scanner.session", qos: .userInitiated)
    let captureQueue = DispatchQueue(label: "score-scanner.capture", qos: .userInitiated)
    let ocrQueue = DispatchQueue(label: "score-scanner.ocr", qos: .userInitiated)
    let ciContext = CIContext()
    let ocrService = ScoreOCRService()
    let stabilityService = ScoreStabilityService()
    let liveOCRInterval: CFTimeInterval = 0.34
    let minimumLiveDigitCount = 5
    let minimumFinalDigitCount = 4
    let bufferedFreezeFrameLifetime: TimeInterval = 1.5
    let maximumBufferedFreezeFrames = 4

    var sessionConfigured = false
    var currentDevice: AVCaptureDevice?
    lazy var videoOutputDelegate = ScoreScannerVideoOutputDelegate { [weak self] fullFrame in
        Task { @MainActor [weak self] in
            self?.handleCapturedFrame(fullFrame)
        }
    }
    // Keep frame-processing state on captureQueue so freeze/retake/OCR callbacks share one owner.
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    var previewMapping: ScoreScannerPreviewMapping?
    var latestOrientedFrame: CIImage?
    var latestSnapshot: ScoreStabilityService.Snapshot?
    var bufferedFreezeFrames: [Int: ScoreScannerBufferedFreezeFrame] = [:]
    var lastOCRTime: CFTimeInterval = 0
    var isProcessingFrame = false
    var processingPaused = false
    var displayMode: ScoreScannerDisplayMode = .lcd

    func onAppear() {
        checkAuthorizationAndStart()
    }

    func onDisappear() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        if let connection = layer.connection {
            scoreScannerApplyPortraitRotation(to: connection)
        }
    }

    func updateTargetRect(_ targetRect: CGRect) {
        guard let previewLayer,
              previewLayer.bounds.width > 0,
              previewLayer.bounds.height > 0 else { return }
        let layerRect = targetRect.intersection(previewLayer.bounds)
        guard !layerRect.isNull, !layerRect.isEmpty else { return }
        let mapping = ScoreScannerPreviewMapping(
            previewBounds: previewLayer.bounds,
            targetRect: layerRect.standardized
        )
        captureQueue.async { [weak self] in
            self?.previewMapping = mapping
        }
    }

    func setZoomFactor(_ proposed: CGFloat) {
        let clamped = min(max(proposed, availableZoomRange.lowerBound), availableZoomRange.upperBound)
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = clamped
                DispatchQueue.main.async {
                    self.zoomFactor = clamped
                }
            } catch {}
        }
    }

    func freezeCurrentFrame() {
        let preferredReading = preferredFreezeReading()
        let frame = captureQueue.sync { latestOrientedFrame }
        freeze(
            using: frame,
            preferredReading: preferredReading,
            preferredPreviewImage: preferredReading.flatMap { bufferedFreezePreviewImage(for: $0.score) }
        )
    }

    func freezeDisplayedCandidate() {
        guard !isFrozen else { return }
        let preferredReading = preferredFreezeReading()
        guard let preferredReading else { return }
        let frame = captureQueue.sync { latestOrientedFrame }
        freeze(
            using: frame,
            preferredReading: preferredReading,
            preferredPreviewImage: bufferedFreezePreviewImage(for: preferredReading.score)
        )
    }

    func retake() {
        captureQueue.sync { [weak self] in
            guard let self else { return }
            self.processingPaused = false
            self.latestSnapshot = nil
            self.stabilityService.reset()
            self.lastOCRTime = 0
            self.isProcessingFrame = false
            self.bufferedFreezeFrames.removeAll()
        }

        DispatchQueue.main.async {
            self.isFrozen = false
            self.frozenPreviewImage = nil
            self.lockedReading = nil
            self.liveCandidateReading = nil
            self.candidateHighlights = []
            self.confirmationText = ""
            self.confirmationValidationMessage = nil
            self.liveReadingText = "No reading yet"
            self.status = .searching
        }
    }

    func validatedConfirmedScore() -> Int? {
        guard let score = ScoreParsingService.normalizedScore(fromManualInput: confirmationText) else {
            confirmationValidationMessage = "Enter a valid score above 0."
            return nil
        }

        let formatted = ScoreParsingService.formattedScore(score: score)
        if confirmationText != formatted {
            confirmationText = formatted
        }
        confirmationValidationMessage = nil
        return score
    }
}
