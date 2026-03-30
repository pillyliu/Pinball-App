import SwiftUI

struct GameRoomFloatingSaveFeedbackOverlay: View {
    private static let fadeInDuration = 0.14
    private static let fadeOutDuration = 0.18
    private static let totalDisplayDuration = 1.2

    let token: Int
    let text: String?

    @State private var displayedText: String?
    @State private var isVisible = false
    @State private var showTask: Task<Void, Never>?
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let displayedText {
                AppSuccessBanner(text: displayedText, prominent: true)
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.985)
                    .offset(y: isVisible ? 0 : 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onChange(of: token) { _, newValue in
            guard newValue > 0, let text, !text.isEmpty else { return }
            show(text)
        }
        .onDisappear {
            showTask?.cancel()
            hideTask?.cancel()
        }
    }

    @MainActor
    private func show(_ text: String) {
        showTask?.cancel()
        hideTask?.cancel()
        displayedText = text

        if !isVisible {
            showTask = Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: Self.fadeInDuration)) {
                    isVisible = true
                }
                showTask = nil
            }
        }

        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.totalDisplayDuration - Self.fadeOutDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: Self.fadeOutDuration)) {
                isVisible = false
            }
            try? await Task.sleep(for: .seconds(Self.fadeOutDuration))
            guard !Task.isCancelled else { return }
            if !isVisible {
                displayedText = nil
            }
            showTask = nil
            hideTask = nil
        }
    }
}
