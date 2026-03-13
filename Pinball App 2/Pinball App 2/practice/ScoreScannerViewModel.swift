import SwiftUI
import Combine
@preconcurrency import AVFoundation
import CoreImage
import UIKit

final class ScoreScannerViewModel: NSObject, ObservableObject {
    private struct BufferedFreezeFrame {
        let score: Int
        let previewImage: UIImage
        let confidence: Float
        let digitCount: Int
        let formatQuality: Int
        let capturedAt: Date
    }

    @Published private(set) var isCameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @Published private(set) var status: ScoreScannerStatus = .searching
    @Published private(set) var liveReadingText: String = "No reading yet"
    @Published private(set) var liveCandidateReading: ScoreScannerLockedReading?
    @Published private(set) var rawReadingText: String = ""
    @Published private(set) var candidateHighlights: [ScoreScannerCandidate] = []
    @Published private(set) var lockedReading: ScoreScannerLockedReading?
    @Published private(set) var isFrozen = false
    @Published private(set) var frozenPreviewImage: UIImage?
    @Published private(set) var zoomFactor: CGFloat = 1
    @Published private(set) var availableZoomRange: ClosedRange<CGFloat> = 1...8
    @Published var confirmationText: String = ""
    @Published var confirmationValidationMessage: String?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "score-scanner.session", qos: .userInitiated)
    private let captureQueue = DispatchQueue(label: "score-scanner.capture", qos: .userInitiated)
    private let ocrQueue = DispatchQueue(label: "score-scanner.ocr", qos: .userInitiated)
    private let ciContext = CIContext()
    private let ocrService = ScoreOCRService()
    private let stabilityService = ScoreStabilityService()
    private let liveOCRInterval: CFTimeInterval = 0.34
    private let minimumLiveDigitCount = 5
    private let minimumFinalDigitCount = 4
    private let bufferedFreezeFrameLifetime: TimeInterval = 1.5
    private let maximumBufferedFreezeFrames = 4

    private var sessionConfigured = false
    private var currentDevice: AVCaptureDevice?
    private lazy var videoOutputDelegate = ScoreScannerVideoOutputDelegate { [weak self] fullFrame in
        Task { @MainActor [weak self] in
            self?.handleCapturedFrame(fullFrame)
        }
    }
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var previewMapping: ScoreScannerPreviewMapping?
    private var latestOrientedFrame: CIImage?
    private var latestSnapshot: ScoreStabilityService.Snapshot?
    private var bufferedFreezeFrames: [Int: BufferedFreezeFrame] = [:]
    private var lastOCRTime: CFTimeInterval = 0
    private var isProcessingFrame = false
    private var processingPaused = false
    private var displayMode: ScoreScannerDisplayMode = .lcd

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
            applyPortraitRotation(to: connection)
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
        captureQueue.async { [weak self] in
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
            self.rawReadingText = ""
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

    private func checkAuthorizationAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isCameraAuthorized = true
            }
            configureAndStartSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    DispatchQueue.main.async {
                        self.isCameraAuthorized = true
                    }
                    self.configureAndStartSessionIfNeeded()
                } else {
                    DispatchQueue.main.async {
                        self.isCameraAuthorized = false
                        self.status = .cameraPermissionRequired
                    }
                }
            }
        case .restricted, .denied:
            DispatchQueue.main.async {
                self.isCameraAuthorized = false
                self.status = .cameraPermissionRequired
            }
        @unknown default:
            DispatchQueue.main.async {
                self.isCameraAuthorized = false
                self.status = .cameraUnavailable
            }
        }
    }

    private func configureAndStartSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.sessionConfigured else {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                return
            }

            var shouldStartSession = false

            do {
                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720

                defer {
                    self.session.commitConfiguration()
                }

                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    DispatchQueue.main.async {
                        self.status = .cameraUnavailable
                    }
                    return
                }

                let input = try AVCaptureDeviceInput(device: device)
                guard self.session.canAddInput(input) else {
                    DispatchQueue.main.async {
                        self.status = .cameraUnavailable
                    }
                    return
                }
                self.session.addInput(input)

                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.setSampleBufferDelegate(self.videoOutputDelegate, queue: self.captureQueue)

                guard self.session.canAddOutput(output) else {
                    DispatchQueue.main.async {
                        self.status = .cameraUnavailable
                    }
                    return
                }
                self.session.addOutput(output)

                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                let deviceMaxZoom = max(CGFloat(1), min(device.activeFormat.videoMaxZoomFactor, CGFloat(8)))
                let defaultZoom = CGFloat(1)
                device.videoZoomFactor = defaultZoom
                device.unlockForConfiguration()

                currentDevice = device
                sessionConfigured = true
                shouldStartSession = true

                let maxZoom = max(defaultZoom, deviceMaxZoom)
                DispatchQueue.main.async {
                    self.availableZoomRange = defaultZoom...maxZoom
                    self.zoomFactor = defaultZoom
                    self.status = .searching
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = .cameraUnavailable
                }
                return
            }

            if shouldStartSession, !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func freeze(
        using frame: CIImage?,
        preferredReading: ScoreScannerLockedReading?,
        preferredPreviewImage: UIImage?
    ) {
        guard frame != nil || preferredPreviewImage != nil else { return }

        captureQueue.async { [weak self] in
            self?.processingPaused = true
        }

        let mapping = captureQueue.sync { previewMapping }
        let cropped = frame.flatMap { crop(frame: $0, previewMapping: mapping) }
        let previewSource = cropped ?? frame
        let previewImage = preferredPreviewImage ?? previewSource.flatMap(renderPreviewImage(from:))
        let frozenOcrImage = previewImage.flatMap(renderedOCRImage(from:)) ?? cropped
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
                let filteredAnalysis = self.filteredAnalysis(
                    analysis,
                    minimumDigitCount: self.minimumFinalDigitCount,
                    minimumHorizontalPadding: 0.04,
                    minimumVerticalPadding: 0.04
                )
                let locked = filteredAnalysis.bestCandidate.map(candidateReading(from:)) ?? preferredReading
                DispatchQueue.main.async {
                    self.candidateHighlights = filteredAnalysis.candidates
                    self.lockedReading = locked
                    if let locked {
                        self.confirmationText = locked.formattedScore
                        self.rawReadingText = locked.rawText
                        self.status = .locked
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if let preferredReading {
                        self.lockedReading = preferredReading
                        self.confirmationText = preferredReading.formattedScore
                        self.rawReadingText = preferredReading.rawText
                        self.status = .locked
                    }
                }
            }
        }
    }

    private func process(
        analysis: ScoreOCRAnalysis,
        fullFrame: CIImage,
        croppedFrame: CIImage
    ) {
        let filteredAnalysis = filteredAnalysis(
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

        DispatchQueue.main.async {
            let displayedReading = self.displayedReading(
                from: snapshot,
                bestCandidate: filteredAnalysis.bestCandidate
            )

            self.candidateHighlights = Array(filteredAnalysis.candidates.prefix(3))
            self.rawReadingText = filteredAnalysis.bestCandidate?.rawText ?? ""
            self.liveCandidateReading = displayedReading
            if let reading = snapshot.dominantReading {
                self.liveReadingText = reading.formattedScore
            } else if let best = filteredAnalysis.bestCandidate {
                self.liveReadingText = best.formattedScore
            } else {
                self.liveReadingText = "No reading yet"
            }
            self.status = snapshot.state
        }

        if snapshot.state == .locked, let locked = latestLockedReading(from: snapshot) {
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

    private func latestLockedReading(from snapshot: ScoreStabilityService.Snapshot?) -> ScoreScannerLockedReading? {
        guard let snapshot, let reading = snapshot.dominantReading else { return nil }
        return ScoreScannerLockedReading(
            score: reading.score,
            formattedScore: reading.formattedScore,
            rawText: reading.rawText,
            confidence: reading.confidence,
            averageConfidence: snapshot.averageConfidence
        )
    }

    private func displayedReading(
        from snapshot: ScoreStabilityService.Snapshot,
        bestCandidate: ScoreScannerCandidate?
    ) -> ScoreScannerLockedReading? {
        if let locked = latestLockedReading(from: snapshot) {
            return locked
        }
        guard let bestCandidate else { return nil }
        return candidateReading(from: bestCandidate)
    }

    private func candidateReading(from candidate: ScoreScannerCandidate) -> ScoreScannerLockedReading {
        ScoreScannerLockedReading(
            score: candidate.normalizedScore,
            formattedScore: candidate.formattedScore,
            rawText: candidate.rawText,
            confidence: candidate.confidence,
            averageConfidence: candidate.confidence
        )
    }

    private func preferredFreezeReading() -> ScoreScannerLockedReading? {
        liveCandidateReading ?? latestLockedReading(from: latestSnapshot)
    }

    private func crop(frame: CIImage, previewMapping: ScoreScannerPreviewMapping?) -> CIImage? {
        let cropRect: CGRect?
        if let previewMapping {
            cropRect = ScoreScannerFrameMapper.cropRect(
                frameExtent: frame.extent,
                previewMapping: previewMapping
            )
        } else {
            cropRect = ScoreScannerFrameMapper.cropRect(
                frameExtent: frame.extent,
                normalizedRect: ScoreScannerTargetBoxLayout.fallbackNormalizedRect
            )
        }

        guard let cropRect else { return nil }
        return frame.cropped(to: cropRect)
    }

    private func renderPreviewImage(from frame: CIImage) -> UIImage? {
        let normalizedFrame = frame.transformed(
            by: CGAffineTransform(translationX: -frame.extent.minX, y: -frame.extent.minY)
        )
        let normalizedExtent = normalizedFrame.extent.integral
        guard let cgImage = ciContext.createCGImage(normalizedFrame, from: normalizedExtent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func renderedOCRImage(from image: UIImage) -> CIImage? {
        if let cgImage = image.cgImage {
            return CIImage(cgImage: cgImage)
        }
        return image.ciImage
    }

    private func shouldBufferFreezeFrame(for candidate: ScoreScannerCandidate) -> Bool {
        captureQueue.sync {
            pruneBufferedFreezeFrames()
            guard let existing = bufferedFreezeFrames[candidate.normalizedScore] else { return true }
            if candidate.formatQuality != existing.formatQuality {
                return candidate.formatQuality > existing.formatQuality
            }
            if candidate.digitCount != existing.digitCount {
                return candidate.digitCount > existing.digitCount
            }
            if candidate.confidence != existing.confidence {
                return candidate.confidence > existing.confidence
            }
            return Date().timeIntervalSince(existing.capturedAt) > 0.4
        }
    }

    private func bufferFreezeFrame(croppedFrame: CIImage, candidate: ScoreScannerCandidate) {
        guard let previewImage = renderPreviewImage(from: croppedFrame) else { return }
        let buffered = BufferedFreezeFrame(
            score: candidate.normalizedScore,
            previewImage: previewImage,
            confidence: candidate.confidence,
            digitCount: candidate.digitCount,
            formatQuality: candidate.formatQuality,
            capturedAt: Date()
        )
        captureQueue.async { [weak self] in
            guard let self else { return }
            self.pruneBufferedFreezeFrames()
            if let existing = self.bufferedFreezeFrames[buffered.score] {
                if buffered.formatQuality < existing.formatQuality { return }
                if buffered.formatQuality == existing.formatQuality && buffered.digitCount < existing.digitCount { return }
                if buffered.formatQuality == existing.formatQuality &&
                    buffered.digitCount == existing.digitCount &&
                    buffered.confidence < existing.confidence {
                    return
                }
            }
            self.bufferedFreezeFrames[buffered.score] = buffered
            if self.bufferedFreezeFrames.count > self.maximumBufferedFreezeFrames {
                let staleScores = self.bufferedFreezeFrames.values
                    .sorted(by: { $0.capturedAt < $1.capturedAt })
                    .prefix(self.bufferedFreezeFrames.count - self.maximumBufferedFreezeFrames)
                    .map(\.score)
                staleScores.forEach { self.bufferedFreezeFrames.removeValue(forKey: $0) }
            }
        }
    }

    private func bufferedFreezePreviewImage(for score: Int) -> UIImage? {
        captureQueue.sync {
            pruneBufferedFreezeFrames()
            return bufferedFreezeFrames[score]?.previewImage
        }
    }

    private func pruneBufferedFreezeFrames(now: Date = Date()) {
        bufferedFreezeFrames = bufferedFreezeFrames.filter { _, frame in
            now.timeIntervalSince(frame.capturedAt) <= bufferedFreezeFrameLifetime
        }
    }

    private func filteredAnalysis(
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

    private func applyPortraitRotation(to connection: AVCaptureConnection) {
        if #available(iOS 17.0, *) {
            let portraitAngle: CGFloat = 90
            if connection.isVideoRotationAngleSupported(portraitAngle) {
                connection.videoRotationAngle = portraitAngle
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    fileprivate func handleCapturedFrame(_ fullFrame: CIImage) {
        captureQueue.async { [weak self] in
            self?.latestOrientedFrame = fullFrame
        }

        if processingPaused || isProcessingFrame {
            return
        }

        let now = CACurrentMediaTime()
        guard now - lastOCRTime >= liveOCRInterval else { return }
        lastOCRTime = now
        isProcessingFrame = true

        let mapping = captureQueue.sync { previewMapping }

        guard let cropped = crop(frame: fullFrame, previewMapping: mapping) else {
            isProcessingFrame = false
            return
        }

        ocrQueue.async { [weak self] in
            guard let self else { return }
            defer {
                self.captureQueue.async {
                    self.isProcessingFrame = false
                }
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
                if snapshot.state == .locked, let locked = self.latestLockedReading(from: snapshot) {
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
                    let locked = self.latestLockedReading(from: snapshot)
                    DispatchQueue.main.async {
                        self.candidateHighlights = []
                        self.rawReadingText = locked?.rawText ?? ""
                        self.liveReadingText = locked?.formattedScore ?? "No reading yet"
                        self.status = snapshot.state
                    }
                }
            }
        }
    }

    nonisolated fileprivate static func portraitOrientedFrame(from pixelBuffer: CVPixelBuffer) -> CIImage {
        CIImage(cvPixelBuffer: pixelBuffer)
            .oriented(forExifOrientation: Int32(CGImagePropertyOrientation.right.rawValue))
    }
}

private final class ScoreScannerVideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated private let onCaptureFrame: (CIImage) -> Void

    init(onCaptureFrame: @escaping (CIImage) -> Void) {
        self.onCaptureFrame = onCaptureFrame
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let fullFrame = ScoreScannerViewModel.portraitOrientedFrame(from: pixelBuffer)
        onCaptureFrame(fullFrame)
    }
}
