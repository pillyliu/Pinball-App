import SwiftUI
import Combine
import UIKit

struct ScoreScannerView: View {
    let onUseReading: (Int) -> Void
    let onClose: () -> Void

    @StateObject private var viewModel = ScoreScannerViewModel()
    @StateObject private var keyboardObserver = KeyboardFrameObserver()
    @State private var stableViewportSize: CGSize = .zero
    @State private var manualEntryFocused = false

    var body: some View {
        GeometryReader { geometry in
            let layoutSize = resolvedLayoutSize(for: geometry.size)
            let targetRect = ScoreScannerTargetBoxLayout.rect(
                in: layoutSize,
                safeAreaInsets: geometry.safeAreaInsets
            )
            let controlsBottomPadding = resolvedControlsBottomPadding(for: geometry.safeAreaInsets)

            AppFullscreenStage {
                if viewModel.isCameraAuthorized {
                    CameraPreviewView(session: viewModel.session) { previewLayer in
                        viewModel.attachPreviewLayer(previewLayer)
                        viewModel.updateTargetRect(targetRect)
                    }
                    .ignoresSafeArea()
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .ignoresSafeArea()
                }

                frozenPreview(targetRect: targetRect)

                ScoreScannerTargetOverlay(
                    targetRect: targetRect,
                    candidateHighlights: viewModel.candidateHighlights
                )
                    .ignoresSafeArea()

                topBar
                    .padding(.leading, 18)
                    .padding(.top, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                header(targetRect: targetRect, containerSize: layoutSize)
                liveReadingPanel(targetRect: targetRect, containerSize: layoutSize)

                if viewModel.isFrozen, keyboardObserver.overlap > 0 {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture(perform: dismissKeyboard)
                }

                VStack(spacing: 14) {
                    if viewModel.isFrozen {
                        ScoreConfirmationSheet(
                            status: viewModel.status,
                            lockedReading: viewModel.lockedReading,
                            confirmationText: $viewModel.confirmationText,
                            validationMessage: viewModel.confirmationValidationMessage,
                            onManualEntryFocusChange: { isFocused in
                                manualEntryFocused = isFocused
                            },
                            onUseReading: useReading,
                            onRetake: viewModel.retake
                        )
                    } else {
                        scannerControls
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, controlsBottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isFrozen)
                .animation(.easeInOut(duration: 0.22), value: keyboardObserver.overlap)

                if viewModel.status == .cameraPermissionRequired {
                    cameraOverlayCard(
                        title: viewModel.status.title,
                        detail: viewModel.status.detail,
                        actionTitle: "Open Settings"
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } else if viewModel.status == .cameraUnavailable {
                    cameraOverlayCard(
                        title: viewModel.status.title,
                        detail: viewModel.status.detail,
                        actionTitle: nil,
                        action: {}
                    )
                }
            }
            .ignoresSafeArea(.keyboard)
            .statusBarHidden()
            .onAppear {
                updateStableViewportSize(with: geometry.size)
                viewModel.onAppear()
                viewModel.updateTargetRect(targetRect)
            }
            .onChange(of: geometry.size) { _, _ in
                updateStableViewportSize(with: geometry.size)
                viewModel.updateTargetRect(targetRect)
            }
            .onDisappear {
                viewModel.onDisappear()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        Button(action: onClose) {
            HStack(spacing: 8) {
                Image(systemName: "xmark")
                    .font(.headline)
                Text("Close")
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color.black.opacity(0.42), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func header(targetRect: CGRect, containerSize: CGSize) -> some View {
        VStack(spacing: 6) {
            Text("Align the score display inside the box")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .position(x: containerSize.width / 2, y: max(targetRect.minY - 84, 78))
    }

    private func liveReadingPanel(targetRect: CGRect, containerSize: CGSize) -> some View {
        Button {
            viewModel.freezeDisplayedCandidate()
        } label: {
            VStack(spacing: 10) {
                Text(viewModel.status.title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(statusColor)

                Text(viewModel.liveReadingText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.white)

                Text(viewModel.status.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .opacity(viewModel.liveCandidateReading == nil || viewModel.isFrozen ? 1 : 0.98)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.liveCandidateReading == nil || viewModel.isFrozen)
        .position(
            x: containerSize.width / 2,
            y: min(targetRect.maxY + 86, containerSize.height - 220)
        )
    }

    private var scannerControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                controlButton(title: "1x", systemImage: nil, disabled: false) {
                    viewModel.setZoomFactor(viewModel.availableZoomRange.lowerBound)
                }

                controlButton(title: "8x", systemImage: nil, disabled: viewModel.availableZoomRange.upperBound < 8) {
                    viewModel.setZoomFactor(min(8, viewModel.availableZoomRange.upperBound))
                }

                controlButton(
                    title: "Freeze",
                    systemImage: "camera.metering.center.weighted",
                    disabled: false,
                    stackIconAboveTitle: true
                ) {
                    viewModel.freezeCurrentFrame()
                }
            }

            VStack(spacing: 6) {
                HStack {
                    Text("Zoom")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1fx", viewModel.zoomFactor))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { viewModel.zoomFactor },
                        set: { viewModel.setZoomFactor($0) }
                    ),
                    in: viewModel.availableZoomRange
                )
                .tint(.white)
            }
            .padding(14)
            .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .stableCandidate:
            return .yellow
        case .locked:
            return .green
        case .failedNoReading:
            return .orange
        case .cameraPermissionRequired, .cameraUnavailable:
            return .red
        case .searching, .reading:
            return .white.opacity(0.9)
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func resolvedControlsBottomPadding(for safeAreaInsets: EdgeInsets) -> CGFloat {
        if keyboardObserver.overlap > 0 {
            return max(
                keyboardObserver.overlap,
                max(safeAreaInsets.bottom, 18)
            )
        }
        return max(safeAreaInsets.bottom, 18)
    }

    private func resolvedLayoutSize(for currentSize: CGSize) -> CGSize {
        guard stableViewportSize.width > 0, stableViewportSize.height > 0 else {
            return currentSize
        }
        return keyboardObserver.overlap > 0 || manualEntryFocused ? stableViewportSize : currentSize
    }

    private func updateStableViewportSize(with size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard stableViewportSize.width > 0, stableViewportSize.height > 0 else {
            stableViewportSize = size
            return
        }

        // Treat width changes as a real viewport change, but ignore same-width height
        // reductions so the keyboard cannot collapse the scanner overlay geometry.
        if abs(size.width - stableViewportSize.width) > 1 {
            stableViewportSize = size
            return
        }

        stableViewportSize = CGSize(
            width: max(stableViewportSize.width, size.width),
            height: max(stableViewportSize.height, size.height)
        )
    }

    private func controlButton(
        title: String,
        systemImage: String?,
        disabled: Bool,
        stackIconAboveTitle: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if stackIconAboveTitle, let systemImage {
                    VStack(spacing: 4) {
                        Image(systemName: systemImage)
                            .font(.body.weight(.semibold))
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                } else {
                    HStack(spacing: 6) {
                        if let systemImage {
                            Image(systemName: systemImage)
                        }
                        Text(title)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Color.white.opacity(0.4) : .white)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(disabled ? 0.08 : 0.14), lineWidth: 1)
        )
        .disabled(disabled)
    }

    private func cameraOverlayCard(
        title: String,
        detail: String,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.headline)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func useReading() {
        guard let score = viewModel.validatedConfirmedScore() else { return }
        onUseReading(score)
    }

    @ViewBuilder
    private func frozenPreview(targetRect: CGRect) -> some View {
        if let frozenPreview = viewModel.frozenPreviewImage {
            GeometryReader { _ in
                Color.black.ignoresSafeArea()

                Image(uiImage: frozenPreview)
                    .resizable()
                    .frame(width: targetRect.width, height: targetRect.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .position(x: targetRect.midX, y: targetRect.midY)
            }
            .ignoresSafeArea()
            .transition(.opacity)
        }
    }
}

private final class KeyboardFrameObserver: ObservableObject {
    @Published private(set) var overlap: CGFloat = 0

    private var notificationTokens: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        notificationTokens = [
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handle(notification: notification)
            },
            center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handle(notification: notification)
            }
        ]
    }

    deinit {
        let center = NotificationCenter.default
        notificationTokens.forEach(center.removeObserver)
    }

    private func handle(notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            overlap = 0
            return
        }

        let screenBounds = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds }
            .first ?? CGRect(x: 0, y: 0, width: endFrame.width, height: endFrame.maxY)
        overlap = max(0, screenBounds.maxY - endFrame.minY)
    }
}

private struct ScoreScannerTargetOverlay: View {
    let targetRect: CGRect
    let candidateHighlights: [ScoreScannerCandidate]

    var body: some View {
        GeometryReader { geometry in
            let fullRect = CGRect(origin: .zero, size: geometry.size)
            Path { path in
                path.addRect(fullRect)
                path.addRoundedRect(in: targetRect, cornerSize: CGSize(width: 18, height: 18))
            }
            .fill(
                Color.black.opacity(0.46),
                style: FillStyle(eoFill: true)
            )

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.92), lineWidth: 2)
                .frame(width: targetRect.width, height: targetRect.height)
                .position(x: targetRect.midX, y: targetRect.midY)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.yellow.opacity(0.22), lineWidth: 6)
                .blur(radius: 8)
                .frame(width: targetRect.width, height: targetRect.height)
                .position(x: targetRect.midX, y: targetRect.midY)

            ForEach(Array(candidateHighlights.enumerated()), id: \.offset) { _, candidate in
                let box = overlayRect(for: candidate.boundingBox)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.95), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.green.opacity(0.12))
                    )
                    .frame(width: box.width, height: box.height)
                    .position(x: box.midX, y: box.midY)

                Text(candidate.formattedScore)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.92), in: Capsule())
                    .foregroundStyle(.black)
                    .position(
                        x: min(max(box.midX, targetRect.minX + 44), targetRect.maxX - 44),
                        y: max(box.minY - 14, targetRect.minY + 12)
                    )
            }
        }
    }

    private func overlayRect(for normalizedBox: CGRect) -> CGRect {
        let width = targetRect.width * normalizedBox.width
        let height = targetRect.height * normalizedBox.height
        let x = targetRect.minX + (normalizedBox.minX * targetRect.width)
        let y = targetRect.minY + ((1 - normalizedBox.maxY) * targetRect.height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
