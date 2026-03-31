import CoreGraphics
import CoreImage
import Dispatch
@preconcurrency import AVFoundation

enum ScoreScannerCameraAuthorizationRoute {
    case startSession
    case presentStatus(ScoreScannerStatus)
}

enum ScoreScannerSessionConfigurationError: Error {
    case unavailable
}

struct ScoreScannerSessionConfiguration {
    let device: AVCaptureDevice
    let defaultZoom: CGFloat
    let maxZoom: CGFloat
}

func scoreScannerApplyPortraitRotation(to connection: AVCaptureConnection) {
    if #available(iOS 17.0, *) {
        let portraitAngle: CGFloat = 90
        if connection.isVideoRotationAngleSupported(portraitAngle) {
            connection.videoRotationAngle = portraitAngle
        }
    } else if connection.isVideoOrientationSupported {
        connection.videoOrientation = .portrait
    }
}

nonisolated func scoreScannerPortraitOrientedFrame(from pixelBuffer: CVPixelBuffer) -> CIImage {
    CIImage(cvPixelBuffer: pixelBuffer)
        .oriented(forExifOrientation: Int32(CGImagePropertyOrientation.right.rawValue))
}

func scoreScannerCameraAuthorizationRoute(
    for status: AVAuthorizationStatus
) -> ScoreScannerCameraAuthorizationRoute {
    switch status {
    case .notDetermined:
        assertionFailure("Unexpected .notDetermined camera authorization status before permission request.")
        return .presentStatus(.cameraPermissionRequired)
    case .authorized:
        return .startSession
    case .restricted, .denied:
        return .presentStatus(.cameraPermissionRequired)
    @unknown default:
        return .presentStatus(.cameraUnavailable)
    }
}

func scoreScannerConfigureSession(
    _ session: AVCaptureSession,
    outputDelegate: AVCaptureVideoDataOutputSampleBufferDelegate,
    outputQueue: DispatchQueue
) throws -> ScoreScannerSessionConfiguration {
    session.beginConfiguration()
    session.sessionPreset = .hd1280x720

    defer {
        session.commitConfiguration()
    }

    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
        throw ScoreScannerSessionConfigurationError.unavailable
    }

    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
        throw ScoreScannerSessionConfigurationError.unavailable
    }
    session.addInput(input)

    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    output.setSampleBufferDelegate(outputDelegate, queue: outputQueue)

    guard session.canAddOutput(output) else {
        throw ScoreScannerSessionConfigurationError.unavailable
    }
    session.addOutput(output)

    try device.lockForConfiguration()
    if device.isFocusModeSupported(.continuousAutoFocus) {
        device.focusMode = .continuousAutoFocus
    }
    if device.isExposureModeSupported(.continuousAutoExposure) {
        device.exposureMode = .continuousAutoExposure
    }
    let defaultZoom: CGFloat = 1
    let maxZoom = max(defaultZoom, min(device.activeFormat.videoMaxZoomFactor, CGFloat(8)))
    device.videoZoomFactor = defaultZoom
    device.unlockForConfiguration()

    return ScoreScannerSessionConfiguration(
        device: device,
        defaultZoom: defaultZoom,
        maxZoom: maxZoom
    )
}

final class ScoreScannerVideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
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
        let fullFrame = scoreScannerPortraitOrientedFrame(from: pixelBuffer)
        onCaptureFrame(fullFrame)
    }
}
