import SwiftUI
import Combine
import AVFoundation
import CoreImage
import ImageIO
import UIKit

final class ScoreScannerViewModel: NSObject, ObservableObject {
    @Published private(set) var status: ScoreScannerStatus = .searching
    @Published private(set) var liveReadingText: String = "No reading yet"
    @Published private(set) var rawReadingText: String = ""
    @Published private(set) var lockedReading: ScoreScannerLockedReading?
    @Published private(set) var isFrozen = false
    @Published private(set) var frozenPreviewImage: UIImage?
    @Published private(set) var torchEnabled = false
    @Published private(set) var zoomFactor: CGFloat = 1
    @Published private(set) var availableZoomRange: ClosedRange<CGFloat> = 1...2
    @Published private(set) var hasTorch = false
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

    private var sessionConfigured = false
    private var currentDevice: AVCaptureDevice?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var normalizedROI = ScoreScannerTargetBoxLayout.fallbackNormalizedRect
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
        if let connection = layer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    func updateTargetRect(_ targetRect: CGRect) {
        guard let previewLayer else { return }
        let normalized = previewLayer.metadataOutputRectConverted(fromLayerRect: targetRect).standardized
        captureQueue.async { [weak self] in
            self?.normalizedROI = normalized
        }
    }

    func toggleTorch() {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                if device.torchMode == .on {
                    device.torchMode = .off
                    device.unlockForConfiguration()
                    DispatchQueue.main.async {
                        self.torchEnabled = false
                    }
                } else {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                    device.unlockForConfiguration()
                    DispatchQueue.main.async {
                        self.torchEnabled = true
                    }
                }
            } catch {
                device.unlockForConfiguration()
            }
        }
    }

    func setZoomFactor(_ proposed: CGFloat) {
        let clamped = min(max(proposed, availableZoomRange.lowerBound), availableZoomRange.upperBound)
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentDevice else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.zoomFactor = clamped
                }
            } catch {
                device.unlockForConfiguration()
            }
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
            configureAndStartSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureAndStartSessionIfNeeded()
                } else {
                    DispatchQueue.main.async {
                        self.status = .cameraPermissionRequired
                    }
                }
            }
        case .restricted, .denied:
            DispatchQueue.main.async {
                self.status = .cameraPermissionRequired
            }
        @unknown default:
            DispatchQueue.main.async {
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

            do {
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
                output.setSampleBufferDelegate(self, queue: self.captureQueue)

                guard self.session.canAddOutput(output) else {
                    DispatchQueue.main.async {
                        self.status = .cameraUnavailable
                    }
                    return
                }
                self.session.addOutput(output)

                if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }

                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.videoZoomFactor = 1
                device.unlockForConfiguration()

                currentDevice = device
                sessionConfigured = true

                let maxZoom = max(CGFloat(2), min(device.activeFormat.videoMaxZoomFactor, CGFloat(3)))
                DispatchQueue.main.async {
                    self.availableZoomRange = 1...maxZoom
                    self.zoomFactor = 1
                    self.hasTorch = device.hasTorch
                    self.torchEnabled = false
                    self.status = .searching
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = .cameraUnavailable
                }
                return
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func freeze(using frame: CIImage?, preferredReading: ScoreScannerLockedReading?) {
        guard let frame else { return }

        captureQueue.async { [weak self] in
            self?.processingPaused = true
        }

        let previewImage = renderPreviewImage(from: frame)
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

        let roi = captureQueue.sync { normalizedROI }
        let cropped = crop(frame: frame, normalizedRect: roi)
        ocrQueue.async { [weak self] in
            guard let self, let cropped else { return }
            do {
                let analysis = try self.ocrService.recognize(in: cropped, mode: .finalPass, displayMode: self.displayMode)
                let locked = analysis.bestCandidate.map {
                    ScoreScannerLockedReading(
                        score: $0.normalizedScore,
                        formattedScore: $0.formattedScore,
                        rawText: $0.rawText,
                        confidence: $0.confidence,
                        averageConfidence: $0.confidence
                    )
                } ?? preferredReading
                DispatchQueue.main.async {
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
        let snapshot = captureQueue.sync { () -> ScoreStabilityService.Snapshot in
            let snapshot = stabilityService.ingest(candidate: analysis.bestCandidate)
            latestSnapshot = snapshot
            return snapshot
        }

        DispatchQueue.main.async {
            self.rawReadingText = analysis.bestCandidate?.rawText ?? ""
            if let reading = snapshot.dominantReading {
                self.liveReadingText = reading.formattedScore
            } else if let best = analysis.bestCandidate {
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

    private func crop(frame: CIImage, normalizedRect: CGRect) -> CIImage? {
        let bounds = frame.extent
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let width = bounds.width * normalizedRect.width
        let height = bounds.height * normalizedRect.height
        let x = bounds.origin.x + (bounds.width * normalizedRect.minX)
        let y = bounds.origin.y + (bounds.height * (1 - normalizedRect.maxY))
        let cropRect = CGRect(x: x, y: y, width: width, height: height).integral

        guard cropRect.width > 0, cropRect.height > 0 else { return nil }
        return frame.cropped(to: cropRect)
    }

    private func renderPreviewImage(from frame: CIImage) -> UIImage? {
        guard let cgImage = ciContext.createCGImage(frame, from: frame.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

extension ScoreScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        if processingPaused || isProcessingFrame {
            return
        }

        let now = CACurrentMediaTime()
        guard now - lastOCRTime >= liveOCRInterval else { return }
        lastOCRTime = now
        isProcessingFrame = true

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessingFrame = false
            return
        }

        let fullFrame = CIImage(cvPixelBuffer: pixelBuffer)
            .oriented(forExifOrientation: Int32(CGImagePropertyOrientation.right.rawValue))

        latestOrientedFrame = fullFrame
        let roi = normalizedROI

        guard let cropped = crop(frame: fullFrame, normalizedRect: roi) else {
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
}
