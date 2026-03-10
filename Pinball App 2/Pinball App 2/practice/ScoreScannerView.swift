import SwiftUI

struct ScoreScannerView: View {
    let onUseReading: (Int) -> Void
    let onClose: () -> Void

    @StateObject private var viewModel = ScoreScannerViewModel()

    var body: some View {
        GeometryReader { geometry in
            let targetRect = ScoreScannerTargetBoxLayout.rect(
                in: geometry.size,
                safeAreaInsets: geometry.safeAreaInsets
            )

            ZStack {
                Color.black.ignoresSafeArea()

                CameraPreviewView(session: viewModel.session) { previewLayer in
                    viewModel.attachPreviewLayer(previewLayer)
                    viewModel.updateTargetRect(targetRect)
                }
                .ignoresSafeArea()

                if let frozenPreview = viewModel.frozenPreviewImage {
                    Image(uiImage: frozenPreview)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                ScoreScannerTargetOverlay(targetRect: targetRect)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, geometry.safeAreaInsets.top + 10)

                header(targetRect: targetRect, containerSize: geometry.size)
                liveReadingPanel(targetRect: targetRect, containerSize: geometry.size)

                VStack(spacing: 14) {
                    if viewModel.isFrozen {
                        ScoreConfirmationSheet(
                            status: viewModel.status,
                            lockedReading: viewModel.lockedReading,
                            confirmationText: $viewModel.confirmationText,
                            validationMessage: viewModel.confirmationValidationMessage,
                            onUseReading: useReading,
                            onRetake: viewModel.retake
                        )
                    } else {
                        scannerControls
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 18))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isFrozen)

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
            .statusBarHidden()
            .onAppear {
                viewModel.onAppear()
                viewModel.updateTargetRect(targetRect)
            }
            .onChange(of: geometry.size) { _, _ in
                viewModel.updateTargetRect(targetRect)
            }
            .onDisappear {
                viewModel.onDisappear()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Label("Close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.34), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func header(targetRect: CGRect, containerSize: CGSize) -> some View {
        VStack(spacing: 6) {
            Text("Align the score display inside the box")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Tilt slightly if reflections block digits")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity)
        .position(x: containerSize.width / 2, y: max(targetRect.minY - 54, 96))
    }

    private func liveReadingPanel(targetRect: CGRect, containerSize: CGSize) -> some View {
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
        .position(
            x: containerSize.width / 2,
            y: min(targetRect.maxY + 86, containerSize.height - 220)
        )
    }

    private var scannerControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                controlButton(
                    title: viewModel.torchEnabled ? "Torch On" : "Torch",
                    systemImage: viewModel.torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill",
                    disabled: !viewModel.hasTorch,
                    action: viewModel.toggleTorch
                )

                controlButton(title: "1x", systemImage: nil, disabled: false) {
                    viewModel.setZoomFactor(1)
                }

                controlButton(title: "2x", systemImage: nil, disabled: viewModel.availableZoomRange.upperBound < 2) {
                    viewModel.setZoomFactor(min(2, viewModel.availableZoomRange.upperBound))
                }

                controlButton(title: "Freeze", systemImage: "camera.metering.center.weighted", disabled: false) {
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

    private func controlButton(
        title: String,
        systemImage: String?,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
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
}

private struct ScoreScannerTargetOverlay: View {
    let targetRect: CGRect

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
        }
    }
}
