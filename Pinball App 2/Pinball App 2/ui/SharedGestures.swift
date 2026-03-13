import SwiftUI
import UIKit
import CoreMotion
import Combine

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
    }

    private func startIfNeeded() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
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

        guard now.timeIntervalSince(lastShakeAt) > 0.85 else { return }
        guard magnitude > 2.15 || (magnitude > 1.55 && peakAxis > 1.15) else { return }

        lastShakeAt = now
        onShake?()
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
    func appEdgeBackGesture(dismiss _: DismissAction) -> some View {
        background(AppInteractivePopEnabler().allowsHitTesting(false))
    }

    func appShakeMotionHandler(isEnabled: Bool = true, onShake: @escaping () -> Void) -> some View {
        modifier(AppShakeMotionModifier(isEnabled: isEnabled, onShake: onShake))
    }
}
