import SwiftUI
import Combine
@preconcurrency import AVFoundation
import CoreImage
import ImageIO
import UIKit

final class ScoreScannerViewModel: NSObject, ObservableObject {
    @Published private(set) var isCameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @Published private(set) var status: ScoreScannerStatus = .searching
    @Published private(set) var liveReadingText: String = "No reading yet"
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
        let frame = captureQueue.sync { latestOrientedFrame }
        freeze(using: frame, preferredReading: latestLockedReading(from: latestSnapshot))
    }

    func retake() {
        captureQueue.async { [weak self] in
            guard let self else { return }
            self.processingPaused = false
            self.latestSnapshot = nil
            self.stabilityService.reset()
            self.lastOCRTime = 0
            self.isProcessingFrame = false
        }

        DispatchQueue.main.async {
            self.isFrozen = false
            self.frozenPreviewImage = nil
            self.lockedReading = nil
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

    private func freeze(using frame: CIImage?, preferredReading: ScoreScannerLockedReading?) {
        guard let frame else { return }

        captureQueue.async { [weak self] in
            self?.processingPaused = true
        }

        let mapping = captureQueue.sync { previewMapping }
        let cropped = crop(frame: frame, previewMapping: mapping)
        let previewImage = renderPreviewImage(from: cropped ?? frame)
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
            guard let self, let cropped else { return }
            do {
                let analysis = try self.ocrService.recognize(in: cropped, mode: .finalPass, displayMode: self.displayMode)
                let filteredAnalysis = self.filteredAnalysis(
                    analysis,
                    minimumDigitCount: self.minimumFinalDigitCount,
                    minimumHorizontalPadding: 0.04,
                    minimumVerticalPadding: 0.04
                )
                let locked = filteredAnalysis.bestCandidate.map {
                    ScoreScannerLockedReading(
                        score: $0.normalizedScore,
                        formattedScore: $0.formattedScore,
                        rawText: $0.rawText,
                        confidence: $0.confidence,
                        averageConfidence: $0.confidence
                    )
                } ?? preferredReading
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
                        self.status = .locked
                    }
                }
            }
        }
    }

    private func process(analysis: ScoreOCRAnalysis, fullFrame: CIImage) {
        let filteredAnalysis = filteredAnalysis(
            analysis,
            minimumDigitCount: minimumLiveDigitCount,
            minimumHorizontalPadding: 0.10,
            minimumVerticalPadding: 0.10
        )
        let snapshot = captureQueue.sync { () -> ScoreStabilityService.Snapshot in
            let snapshot = stabilityService.ingest(candidate: filteredAnalysis.bestCandidate)
            latestSnapshot = snapshot
            return snapshot
        }

        DispatchQueue.main.async {
            self.candidateHighlights = Array(filteredAnalysis.candidates.prefix(3))
            self.rawReadingText = filteredAnalysis.bestCandidate?.rawText ?? ""
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
            freeze(using: fullFrame, preferredReading: locked)
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
                self.process(analysis: analysis, fullFrame: fullFrame)
            } catch {
                let snapshot = self.captureQueue.sync { () -> ScoreStabilityService.Snapshot in
                    let snapshot = self.stabilityService.ingest(candidate: nil)
                    self.latestSnapshot = snapshot
                    return snapshot
                }
                DispatchQueue.main.async {
                    self.status = snapshot.state
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
