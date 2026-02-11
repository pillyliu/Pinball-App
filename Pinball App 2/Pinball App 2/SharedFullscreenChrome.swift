import SwiftUI
import Combine

@MainActor
final class FullscreenChromeController: ObservableObject {
    @Published var isVisible = false
    private var hideWorkItem: DispatchWorkItem?

    func resetOnAppear() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        isVisible = false
    }

    func cleanupOnDisappear() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    func toggle(
        reduceMotion: Bool,
        showDuration: Double = 0.16,
        hideDuration: Double = 0.2,
        autoHideAfter: Double = 1.8
    ) {
        if isVisible {
            hide(reduceMotion: reduceMotion, duration: hideDuration)
        } else {
            showTemporarily(
                reduceMotion: reduceMotion,
                showDuration: showDuration,
                hideDuration: hideDuration,
                autoHideAfter: autoHideAfter
            )
        }
    }

    func showTemporarily(
        reduceMotion: Bool,
        showDuration: Double = 0.16,
        hideDuration: Double = 0.2,
        autoHideAfter: Double = 1.8
    ) {
        setVisible(true, reduceMotion: reduceMotion, duration: showDuration)
        scheduleAutoHide(
            reduceMotion: reduceMotion,
            hideDuration: hideDuration,
            autoHideAfter: autoHideAfter
        )
    }

    private func hide(reduceMotion: Bool, duration: Double) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        setVisible(false, reduceMotion: reduceMotion, duration: duration)
    }

    private func scheduleAutoHide(
        reduceMotion: Bool,
        hideDuration: Double,
        autoHideAfter: Double
    ) {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.setVisible(false, reduceMotion: reduceMotion, duration: hideDuration)
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideAfter, execute: workItem)
    }

    private func setVisible(_ visible: Bool, reduceMotion: Bool, duration: Double) {
        if reduceMotion {
            isVisible = visible
        } else {
            withAnimation(.easeInOut(duration: duration)) {
                isVisible = visible
            }
        }
    }
}
