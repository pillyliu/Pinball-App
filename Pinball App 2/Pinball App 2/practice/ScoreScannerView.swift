import SwiftUI
import UIKit

struct ScoreScannerView: View {
    let onUseReading: (Int) -> Void
    let onClose: () -> Void

    @StateObject private var viewModel = ScoreScannerViewModel()
    @StateObject private var keyboardObserver = ScoreScannerKeyboardFrameObserver()
    @State private var stableViewportSize: CGSize = .zero
    @State private var manualEntryFocused = false

    var body: some View {
        GeometryReader { geometry in
            let layoutSize = scoreScannerResolvedLayoutSize(
                currentSize: geometry.size,
                stableViewportSize: stableViewportSize,
                keyboardOverlap: keyboardObserver.overlap,
                manualEntryFocused: manualEntryFocused
            )
            let targetRect = ScoreScannerTargetBoxLayout.rect(
                in: layoutSize,
                safeAreaInsets: geometry.safeAreaInsets
            )
            let controlsBottomPadding = scoreScannerResolvedControlsBottomPadding(
                keyboardOverlap: keyboardObserver.overlap,
                safeAreaInsets: geometry.safeAreaInsets
            )

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

                ScoreScannerFrozenPreview(
                    frozenPreviewImage: viewModel.frozenPreviewImage,
                    targetRect: targetRect
                )

                ScoreScannerTargetOverlay(
                    targetRect: targetRect,
                    candidateHighlights: viewModel.candidateHighlights
                )
                .ignoresSafeArea()

                ScoreScannerClosePill(onClose: onClose)
                    .padding(.leading, 18)
                    .padding(.top, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                ScoreScannerHeader(targetRect: targetRect, containerSize: layoutSize)
                ScoreScannerLiveReadingPanel(
                    status: viewModel.status,
                    liveReadingText: viewModel.liveReadingText,
                    liveCandidateReading: viewModel.liveCandidateReading,
                    isFrozen: viewModel.isFrozen,
                    targetRect: targetRect,
                    containerSize: layoutSize,
                    onFreezeDisplayedCandidate: viewModel.freezeDisplayedCandidate
                )

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
                        ScoreScannerControls(
                            zoomFactor: viewModel.zoomFactor,
                            availableZoomRange: viewModel.availableZoomRange,
                            onSetZoomFactor: viewModel.setZoomFactor,
                            onFreezeCurrentFrame: viewModel.freezeCurrentFrame
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, controlsBottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isFrozen)
                .animation(.easeInOut(duration: 0.22), value: keyboardObserver.overlap)

                if viewModel.status == .cameraPermissionRequired {
                    ScoreScannerCameraOverlayCard(
                        title: viewModel.status.title,
                        detail: viewModel.status.detail,
                        actionTitle: "Open Settings"
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } else if viewModel.status == .cameraUnavailable {
                    ScoreScannerCameraOverlayCard(
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
                stableViewportSize = scoreScannerUpdatedStableViewportSize(
                    currentStableViewportSize: stableViewportSize,
                    size: geometry.size
                )
                viewModel.onAppear()
                viewModel.updateTargetRect(targetRect)
            }
            .onChange(of: geometry.size) { _, _ in
                stableViewportSize = scoreScannerUpdatedStableViewportSize(
                    currentStableViewportSize: stableViewportSize,
                    size: geometry.size
                )
                viewModel.updateTargetRect(targetRect)
            }
            .onDisappear {
                viewModel.onDisappear()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func useReading() {
        guard let score = viewModel.validatedConfirmedScore() else { return }
        onUseReading(score)
    }
}
