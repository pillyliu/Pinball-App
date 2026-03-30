import Dispatch
@preconcurrency import AVFoundation

extension ScoreScannerViewModel {
    func checkAuthorizationAndStart() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authorizationStatus == .notDetermined {
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
            return
        }

        switch scoreScannerCameraAuthorizationRoute(for: authorizationStatus) {
        case .startSession:
            DispatchQueue.main.async {
                self.isCameraAuthorized = true
            }
            configureAndStartSessionIfNeeded()
        case let .presentStatus(status):
            DispatchQueue.main.async {
                self.isCameraAuthorized = false
                self.status = status
            }
        }
    }

    func configureAndStartSessionIfNeeded() {
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
                let configuration = try scoreScannerConfigureSession(
                    self.session,
                    outputDelegate: self.videoOutputDelegate,
                    outputQueue: self.captureQueue
                )

                self.currentDevice = configuration.device
                self.sessionConfigured = true
                shouldStartSession = true

                DispatchQueue.main.async {
                    self.availableZoomRange = configuration.defaultZoom...configuration.maxZoom
                    self.zoomFactor = configuration.defaultZoom
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
}

