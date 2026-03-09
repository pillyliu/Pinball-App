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

struct AppFullscreenBackButton: View {
    let action: () -> Void
    var accessibilityLabel: String = "Back"

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.brandInk)
                .padding(14)
                .background(.regularMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(AppTheme.brandGold.opacity(0.45), lineWidth: 1)
                )
                .clipShape(Circle())
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

struct AppFullscreenStatusOverlay: View {
    let text: String
    var showsProgress: Bool = false
    var foregroundColor: Color = AppTheme.brandChalk

    var body: some View {
        VStack {
            VStack(spacing: 10) {
                if showsProgress {
                    ProgressView()
                        .tint(AppTheme.brandGold)
                }
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(foregroundColor)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.brandGold.opacity(0.24), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(20)
    }
}
