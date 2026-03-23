import SwiftUI
import UIKit
import CoreMotion
import Combine

enum AppShakeMotionTuning {
    static let updateInterval: TimeInterval = 1.0 / 30.0
    static let minimumAcceptedShakeInterval: TimeInterval = 0.85
    static let candidateWindow: TimeInterval = 0.18
    static let strongMagnitudeThreshold = 2.45
    static let combinedMagnitudeThreshold = 1.85
    static let combinedPeakAxisThreshold = 1.35
}

private struct AppInteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> EnablerViewController {
        EnablerViewController()
    }

    func updateUIViewController(_ uiViewController: EnablerViewController, context: Context) {
        uiViewController.configureInteractivePopIfNeeded()
    }

    final class EnablerViewController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            configureInteractivePopIfNeeded()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            configureInteractivePopIfNeeded()
        }

        func configureInteractivePopIfNeeded() {
            guard let nav = navigationController,
                  let gesture = nav.interactivePopGestureRecognizer else {
                return
            }
            gesture.isEnabled = nav.viewControllers.count > 1
            gesture.delegate = nil
        }
    }
}

private final class AppShakeMotionObserver: ObservableObject {
    private let motionManager = CMMotionManager()
    private var onShake: (() -> Void)?
    private var lastShakeAt = Date.distantPast
    private var candidateShakeAt: Date?

    func update(isEnabled: Bool, onShake: @escaping () -> Void) {
        self.onShake = onShake
        if isEnabled {
            startIfNeeded()
        } else {
            stop()
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        candidateShakeAt = nil
    }

    private func startIfNeeded() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = AppShakeMotionTuning.updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            process(motion)
        }
    }

    private func process(_ motion: CMDeviceMotion) {
        let acceleration = motion.userAcceleration
        let magnitude = sqrt(
            (acceleration.x * acceleration.x) +
            (acceleration.y * acceleration.y) +
            (acceleration.z * acceleration.z)
        )
        let peakAxis = max(abs(acceleration.x), max(abs(acceleration.y), abs(acceleration.z)))
        let now = Date()

        guard now.timeIntervalSince(lastShakeAt) > AppShakeMotionTuning.minimumAcceptedShakeInterval else { return }
        let exceedsThreshold =
            magnitude > AppShakeMotionTuning.strongMagnitudeThreshold ||
            (magnitude > AppShakeMotionTuning.combinedMagnitudeThreshold &&
                peakAxis > AppShakeMotionTuning.combinedPeakAxisThreshold)
        guard exceedsThreshold else {
            if let candidateShakeAt,
               now.timeIntervalSince(candidateShakeAt) > AppShakeMotionTuning.candidateWindow {
                self.candidateShakeAt = nil
            }
            return
        }

        if let candidateShakeAt,
           now.timeIntervalSince(candidateShakeAt) <= AppShakeMotionTuning.candidateWindow {
            self.candidateShakeAt = nil
            lastShakeAt = now
            onShake?()
            return
        }

        candidateShakeAt = now
    }

    deinit {
        stop()
    }
}

private struct AppShakeMotionModifier: ViewModifier {
    let isEnabled: Bool
    let onShake: () -> Void

    @StateObject private var observer = AppShakeMotionObserver()

    func body(content: Content) -> some View {
        content
            .onAppear {
                observer.update(isEnabled: isEnabled, onShake: onShake)
            }
            .onDisappear {
                observer.stop()
            }
            .onChange(of: isEnabled) { _, newValue in
                observer.update(isEnabled: newValue, onShake: onShake)
            }
    }
}

extension View {
    @ViewBuilder
    func appEdgeBackGesture(enabled: Bool = true) -> some View {
        if enabled {
            background(AppInteractivePopEnabler().allowsHitTesting(false))
        } else {
            self
        }
    }

    func appShakeMotionHandler(isEnabled: Bool = true, onShake: @escaping () -> Void) -> some View {
        modifier(AppShakeMotionModifier(isEnabled: isEnabled, onShake: onShake))
    }
}
