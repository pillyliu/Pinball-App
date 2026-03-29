import SwiftUI

struct RulesheetScreenSurface: View {
    let layoutMetrics: RulesheetScreenLayoutMetrics
    let status: LoadStatus
    let content: RulesheetRenderContent?
    let fallbackURL: URL?
    let resumeTarget: CGFloat?
    let resumeRequestID: Int
    let currentProgressPercent: Int
    let isCurrentProgressSessionSaved: Bool
    let progressPillPulseOpacity: Double
    let progressPillBackdropOpacity: Double
    let showsBackButton: Bool
    let gameName: String
    let onDismiss: () -> Void
    let onChromeToggle: () -> Void
    let onProgressChange: (CGFloat) -> Void
    let onSaveProgress: () -> Void

    var body: some View {
        ZStack {
            AppBackground()

            RulesheetScreenContent(
                status: status,
                content: content,
                fallbackURL: fallbackURL,
                anchorScrollInset: layoutMetrics.anchorScrollInset,
                resumeTarget: resumeTarget,
                resumeRequestID: resumeRequestID,
                currentProgressPercent: currentProgressPercent,
                isCurrentProgressSessionSaved: isCurrentProgressSessionSaved,
                progressPillPulseOpacity: progressPillPulseOpacity,
                progressPillBackdropOpacity: progressPillBackdropOpacity,
                progressPillTopPadding: layoutMetrics.progressPillTopPadding,
                progressPillTrailingInset: layoutMetrics.progressPillTrailingInset,
                progressRowHeight: layoutMetrics.progressRowHeight,
                onChromeToggle: onChromeToggle,
                onProgressChange: onProgressChange,
                onSaveProgress: onSaveProgress
            )

            RulesheetTopGradientOverlay(
                isPortrait: layoutMetrics.isPortrait,
                topInset: layoutMetrics.topInset
            )

            RulesheetBackButtonOverlay(
                isVisible: showsBackButton,
                isPortrait: layoutMetrics.isPortrait,
                rowHeight: layoutMetrics.fullscreenChromeRowHeight,
                topPadding: layoutMetrics.backButtonTopPadding,
                gameName: gameName,
                dismiss: onDismiss
            )
        }
    }
}

struct RulesheetScreenContent: View {
    let status: LoadStatus
    let content: RulesheetRenderContent?
    let fallbackURL: URL?
    let anchorScrollInset: CGFloat
    let resumeTarget: CGFloat?
    let resumeRequestID: Int
    let currentProgressPercent: Int
    let isCurrentProgressSessionSaved: Bool
    let progressPillPulseOpacity: Double
    let progressPillBackdropOpacity: Double
    let progressPillTopPadding: CGFloat
    let progressPillTrailingInset: CGFloat
    let progressRowHeight: CGFloat?
    let onChromeToggle: () -> Void
    let onProgressChange: (CGFloat) -> Void
    let onSaveProgress: () -> Void

    var body: some View {
        switch status {
        case .idle, .loading:
            AppFullscreenStatusOverlay(text: "Loading rulesheet…", showsProgress: true)
        case .missing:
            AppFullscreenStatusOverlay(text: "Rulesheet not available.")
        case .error:
            AppFullscreenStatusOverlay(text: "Could not load rulesheet.")
        case .loaded:
            if let content {
                ZStack(alignment: .topTrailing) {
                    RulesheetRenderer(
                        content: content,
                        anchorScrollInset: anchorScrollInset,
                        resumeTarget: resumeTarget,
                        resumeRequestID: resumeRequestID,
                        onChromeToggle: onChromeToggle,
                        onProgressChange: onProgressChange
                    )

                    RulesheetProgressPillButton(
                        currentProgressPercent: currentProgressPercent,
                        isCurrentProgressSessionSaved: isCurrentProgressSessionSaved,
                        progressPillPulseOpacity: progressPillPulseOpacity,
                        progressPillBackdropOpacity: progressPillBackdropOpacity,
                        rowHeight: progressRowHeight,
                        topPadding: progressPillTopPadding,
                        trailingInset: progressPillTrailingInset,
                        onSaveProgress: onSaveProgress
                    )
                }
            } else if let fallbackURL {
                RulesheetWebFallbackView(
                    url: fallbackURL,
                    anchorScrollInset: anchorScrollInset,
                    onChromeToggle: onChromeToggle
                )
            }
        }
    }
}
