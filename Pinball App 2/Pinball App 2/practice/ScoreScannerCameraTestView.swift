import SwiftUI
import Combine
@preconcurrency import AVFoundation

struct ScoreScannerCameraTestView: View {
    let onClose: () -> Void

    @StateObject private var viewModel = ScoreScannerCameraTestViewModel()

    var body: some View {
        AppFullscreenStage {
            if let session = viewModel.session, viewModel.authorizationStatus == .authorized {
                CameraPreviewView(session: session) { previewLayer in
                    viewModel.attachPreviewLayer(previewLayer)
                }
                .ignoresSafeArea()
            }

            Button(action: onClose) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.headline)
                    Text("Close")
                        .font(.headline.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Color.black.opacity(0.42), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.leading, 18)
            .padding(.top, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(spacing: 12) {
                Text("Camera Test")
                    .font(.headline)
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                if let actionTitle = viewModel.primaryActionTitle {
                    Button(actionTitle, action: viewModel.performPrimaryAction)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 18)
            .padding(.bottom, 32)

            if viewModel.showsPermissionPrompt {
                permissionCard
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    private var permissionCard: some View {
        VStack(spacing: 12) {
            Text("Camera access required")
                .font(.headline)

            Text("Allow camera access to test the scanner preview on-device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

@MainActor
final class ScoreScannerCameraTestViewModel: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var showsPermissionPrompt = false
    @Published private(set) var statusMessage = "This is a preview-only camera test."

    @Published private(set) var session: AVCaptureSession?

    private var sessionConfigured = false
    private var isCameraAuthorized: Bool {
        authorizationStatus == .authorized
    }

    var primaryActionTitle: String? {
        switch authorizationStatus {
        case .notDetermined:
            return "Request Camera Permission"
        case .authorized:
            return session == nil ? "Start Preview" : nil
        case .restricted, .denied:
            return nil
        @unknown default:
            return nil
        }
    }

    func onAppear() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        syncStatusMessage()
    }

    func performPrimaryAction() {
        switch authorizationStatus {
        case .notDetermined:
            requestPermission()
        case .authorized:
            startPreview()
        case .restricted, .denied:
            showsPermissionPrompt = true
        @unknown default:
            statusMessage = "Rear camera unavailable."
        }
    }

    func onDisappear() {
        if let session, session.isRunning {
            session.stopRunning()
        }
    }

    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        if let connection = layer.connection {
            applyPortraitRotation(to: connection)
        }
    }

    private func requestPermission() {
        statusMessage = "Requesting camera permission."
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                self.showsPermissionPrompt = !granted
                self.syncStatusMessage()
            }
        }
    }

    private func startPreview() {
        statusMessage = "Starting rear camera preview."

        guard !sessionConfigured else {
            if let session, !session.isRunning {
                session.startRunning()
            }
            statusMessage = "Rear camera preview active."
            return
        }

        let session = AVCaptureSession()
        var shouldStartSession = false

        do {
            session.beginConfiguration()
            session.sessionPreset = .high

            defer {
                session.commitConfiguration()
            }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                statusMessage = "Rear camera unavailable."
                return
            }

            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                statusMessage = "Could not attach rear camera."
                return
            }

            session.addInput(input)
            self.session = session
            self.sessionConfigured = true
            shouldStartSession = true
        } catch {
            statusMessage = "Could not start rear camera."
            return
        }

        if shouldStartSession {
            session.startRunning()
            statusMessage = "Rear camera preview active."
        }
    }

    private func syncStatusMessage() {
        switch authorizationStatus {
        case .authorized:
            statusMessage = session == nil
                ? "Camera permission granted. Tap Start Preview to open the rear camera."
                : "Rear camera preview active."
            showsPermissionPrompt = false
        case .notDetermined:
            statusMessage = "This is a preview-only camera test. Tap Request Camera Permission first."
            showsPermissionPrompt = false
        case .restricted, .denied:
            statusMessage = "Camera permission denied."
            showsPermissionPrompt = true
        @unknown default:
            statusMessage = "Rear camera unavailable."
            showsPermissionPrompt = false
        }
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
}
