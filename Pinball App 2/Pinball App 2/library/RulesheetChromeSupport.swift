import SwiftUI

struct RulesheetProgressPillButton: View {
    let currentProgressPercent: Int
    let isCurrentProgressSessionSaved: Bool
    let progressPillPulseOpacity: Double
    let progressPillBackdropOpacity: Double
    let rowHeight: CGFloat?
    let topPadding: CGFloat
    let trailingInset: CGFloat
    let onSaveProgress: () -> Void

    var body: some View {
        Button(action: onSaveProgress) {
            AppReadingProgressPill(
                text: "\(currentProgressPercent)%",
                saved: isCurrentProgressSessionSaved,
                pulseOpacity: progressPillPulseOpacity
            )
            .background {
                Capsule()
                    .fill(AppTheme.bg.opacity(progressPillBackdropOpacity))
            }
        }
        .buttonStyle(.plain)
        .frame(height: rowHeight)
        .padding(.top, topPadding)
        .padding(.trailing, trailingInset)
    }
}

struct RulesheetTopGradientOverlay: View {
    let isPortrait: Bool
    let topInset: CGFloat

    var body: some View {
        Group {
            if isPortrait {
                LinearGradient(
                    colors: [AppTheme.bg, AppTheme.bg.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: topInset + 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
        }
    }
}

struct RulesheetBackButtonOverlay: View {
    let isVisible: Bool
    let isPortrait: Bool
    let rowHeight: CGFloat
    let topPadding: CGFloat
    let gameName: String
    let dismiss: () -> Void

    var body: some View {
        Group {
            if isVisible {
                VStack {
                    HStack {
                        AppFullscreenBackButton(
                            action: dismiss,
                            accessibilityLabel: "Back from \(gameName)"
                        )
                        Spacer()
                    }
                    .frame(height: isPortrait ? rowHeight : nil)
                    .padding(.top, topPadding)
                    .padding(.horizontal, 16)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
    }
}
