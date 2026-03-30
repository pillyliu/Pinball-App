import SwiftUI
import Combine
import UIKit

struct ScoreScannerClosePill: View {
    let onClose: () -> Void

    var body: some View {
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
}

struct ScoreScannerHeader: View {
    let targetRect: CGRect
    let containerSize: CGSize

    var body: some View {
        VStack(spacing: 6) {
            Text("Align the score display inside the box")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .position(x: containerSize.width / 2, y: max(targetRect.minY - 84, 78))
    }
}

struct ScoreScannerLiveReadingPanel: View {
    let status: ScoreScannerStatus
    let liveReadingText: String
    let liveCandidateReading: ScoreScannerLockedReading?
    let isFrozen: Bool
    let targetRect: CGRect
    let containerSize: CGSize
    let onFreezeDisplayedCandidate: () -> Void

    var body: some View {
        Button(action: onFreezeDisplayedCandidate) {
            VStack(spacing: 10) {
                Text(status.title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(scoreScannerStatusColor(status))

                Text(liveReadingText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.white)

                Text(status.detail)
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
            .opacity(liveCandidateReading == nil || isFrozen ? 1 : 0.98)
        }
        .buttonStyle(.plain)
        .disabled(liveCandidateReading == nil || isFrozen)
        .position(
            x: containerSize.width / 2,
            y: min(targetRect.maxY + 86, containerSize.height - 220)
        )
    }
}

struct ScoreScannerControls: View {
    let zoomFactor: CGFloat
    let availableZoomRange: ClosedRange<CGFloat>
    let onSetZoomFactor: (CGFloat) -> Void
    let onFreezeCurrentFrame: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                scoreScannerControlButton(title: "1x", systemImage: nil, disabled: false) {
                    onSetZoomFactor(availableZoomRange.lowerBound)
                }

                scoreScannerControlButton(title: "8x", systemImage: nil, disabled: availableZoomRange.upperBound < 8) {
                    onSetZoomFactor(min(8, availableZoomRange.upperBound))
                }

                scoreScannerControlButton(
                    title: "Freeze",
                    systemImage: "camera.metering.center.weighted",
                    disabled: false,
                    stackIconAboveTitle: true,
                    action: onFreezeCurrentFrame
                )
            }

            VStack(spacing: 6) {
                HStack {
                    Text("Zoom")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1fx", zoomFactor))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { zoomFactor },
                        set: onSetZoomFactor
                    ),
                    in: availableZoomRange
                )
                .tint(.white)
            }
            .padding(14)
            .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

struct ScoreScannerCameraOverlayCard: View {
    let title: String
    let detail: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
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
}

struct ScoreScannerFrozenPreview: View {
    let frozenPreviewImage: UIImage?
    let targetRect: CGRect

    var body: some View {
        Group {
            if let frozenPreviewImage {
                GeometryReader { _ in
                    Color.black.ignoresSafeArea()

                    Image(uiImage: frozenPreviewImage)
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
}

final class ScoreScannerKeyboardFrameObserver: ObservableObject {
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

struct ScoreScannerTargetOverlay: View {
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
                let box = scoreScannerOverlayRect(for: candidate.boundingBox, targetRect: targetRect)

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
}

func scoreScannerResolvedControlsBottomPadding(
    keyboardOverlap: CGFloat,
    safeAreaInsets: EdgeInsets
) -> CGFloat {
    if keyboardOverlap > 0 {
        return max(
            keyboardOverlap,
            max(safeAreaInsets.bottom, 18)
        )
    }
    return max(safeAreaInsets.bottom, 18)
}

func scoreScannerResolvedLayoutSize(
    currentSize: CGSize,
    stableViewportSize: CGSize,
    keyboardOverlap: CGFloat,
    manualEntryFocused: Bool
) -> CGSize {
    guard stableViewportSize.width > 0, stableViewportSize.height > 0 else {
        return currentSize
    }
    return keyboardOverlap > 0 || manualEntryFocused ? stableViewportSize : currentSize
}

func scoreScannerUpdatedStableViewportSize(
    currentStableViewportSize: CGSize,
    size: CGSize
) -> CGSize {
    guard size.width > 0, size.height > 0 else { return currentStableViewportSize }
    guard currentStableViewportSize.width > 0, currentStableViewportSize.height > 0 else {
        return size
    }

    if abs(size.width - currentStableViewportSize.width) > 1 {
        return size
    }

    return CGSize(
        width: max(currentStableViewportSize.width, size.width),
        height: max(currentStableViewportSize.height, size.height)
    )
}

private func scoreScannerControlButton(
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

private func scoreScannerOverlayRect(for normalizedBox: CGRect, targetRect: CGRect) -> CGRect {
    let width = targetRect.width * normalizedBox.width
    let height = targetRect.height * normalizedBox.height
    let x = targetRect.minX + (normalizedBox.minX * targetRect.width)
    let y = targetRect.minY + ((1 - normalizedBox.maxY) * targetRect.height)
    return CGRect(x: x, y: y, width: width, height: height)
}

private func scoreScannerStatusColor(_ status: ScoreScannerStatus) -> Color {
    switch status {
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
