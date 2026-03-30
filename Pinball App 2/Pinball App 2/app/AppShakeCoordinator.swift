import SwiftUI
import UIKit
import Combine

@MainActor
final class AppShakeCoordinator: ObservableObject {
    @Published private(set) var overlayLevel: AppShakeWarningLevel?

    private let nativeUndoAvailabilityProvider: () -> Bool
    private let hapticsPlayer: (AppShakeWarningLevel) -> Void
    private var fallbackShakeCount = 0
    private var overlayToken = 0

    init() {
        self.nativeUndoAvailabilityProvider = { AppShakeCoordinator.nativeUndoWouldHandleShake() }
        self.hapticsPlayer = { AppShakeWarningHaptics.play($0) }
    }

    init(
        nativeUndoAvailabilityProvider: @escaping () -> Bool,
        hapticsPlayer: @escaping (AppShakeWarningLevel) -> Void
    ) {
        self.nativeUndoAvailabilityProvider = nativeUndoAvailabilityProvider
        self.hapticsPlayer = hapticsPlayer
    }

    nonisolated deinit {}

    func handleDetectedShake() {
        guard !nativeUndoAvailabilityProvider() else {
            return
        }
        guard overlayLevel != .tilt else { return }

        fallbackShakeCount = min(fallbackShakeCount + 1, AppShakeWarningLevel.tilt.rawValue)
        let level = AppShakeWarningLevel(rawValue: fallbackShakeCount) ?? .danger
        if level == .tilt {
            fallbackShakeCount = 0
        }
        present(level)
    }

    private func present(_ level: AppShakeWarningLevel) {
        overlayToken += 1
        let currentToken = overlayToken
        hapticsPlayer(level)
        withAnimation(.easeInOut(duration: 0.18)) {
            overlayLevel = level
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: level.displayDurationNanoseconds)
            guard let self else { return }
            guard currentToken == self.overlayToken else { return }
            withAnimation(.easeOut(duration: 0.30)) {
                self.overlayLevel = nil
            }
        }
    }

    private static func nativeUndoWouldHandleShake() -> Bool {
        guard UIApplication.shared.applicationSupportsShakeToEdit else { return false }

        if let responder = UIResponder.currentFirstResponder,
           responder.undoManager?.canUndo == true || responder.undoManager?.canRedo == true {
            return true
        }

        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        let undoManagers: [UndoManager?] = [
            keyWindow?.undoManager,
            keyWindow?.rootViewController?.undoManager
        ]
        return undoManagers.contains { manager in
            manager?.canUndo == true || manager?.canRedo == true
        }
    }
}

private extension UIResponder {
    static weak var storedFirstResponder: UIResponder?

    static var currentFirstResponder: UIResponder? {
        storedFirstResponder = nil
        UIApplication.shared.sendAction(#selector(captureFirstResponder), to: nil, from: nil, for: nil)
        return storedFirstResponder
    }

    @objc
    func captureFirstResponder() {
        UIResponder.storedFirstResponder = self
    }
}
