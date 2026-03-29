import SwiftUI
import UIKit
import WebKit

struct RulesheetRenderer: UIViewRepresentable {
    let content: RulesheetRenderContent
    let anchorScrollInset: CGFloat
    let resumeTarget: CGFloat?
    let resumeRequestID: Int
    let onChromeToggle: () -> Void
    let onProgressChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            anchorScrollInset: anchorScrollInset,
            onChromeToggle: onChromeToggle,
            onProgressChange: onProgressChange
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = makeRulesheetWebViewConfiguration(
            messageHandler: context.coordinator,
            anchorScrollInset: anchorScrollInset,
            includesFragmentScrollHandler: true
        )

        let webView = RulesheetTrackingWebView(frame: .zero, configuration: configuration)
        webView.applyRulesheetBaseAppearance()
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        webView.onLayoutSubviews = { [weak coordinator = context.coordinator, weak webView] in
            guard let coordinator, let webView else { return }
            coordinator.handleRotationLayoutChangeIfNeeded(in: webView)
        }
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.anchorScrollInset = anchorScrollInset
        context.coordinator.onChromeToggle = onChromeToggle
        context.coordinator.onProgressChange = onProgressChange
        context.coordinator.updateAnchorScrollInset(in: webView)
        context.coordinator.handleResumeRequest(ratio: resumeTarget, requestID: resumeRequestID, in: webView)
        guard context.coordinator.lastContent != content else { return }
        context.coordinator.prepareForContentReload()
        context.coordinator.lastContent = content
        webView.loadHTMLString(
            RulesheetHTMLDocumentBuilder.html(for: content),
            baseURL: content.baseURL ?? URL(string: "https://pillyliu.com")
        )
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: RulesheetWebChromeBridge.chromeTapMessageName)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: RulesheetWebChromeBridge.fragmentScrollMessageName)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate, WKScriptMessageHandler {
        var lastContent: RulesheetRenderContent?
        weak var webView: WKWebView?
        var anchorScrollInset: CGFloat
        var onChromeToggle: () -> Void
        var onProgressChange: (CGFloat) -> Void
        var didLoadPage = false
        var lastHandledResumeRequestID: Int = -1
        var pendingResumeRatio: CGFloat?
        var pendingResumeRequestID: Int?
        var lastKnownViewSize: CGSize = .zero
        var lastKnownAnchorScrollInset: CGFloat?
        var lastViewportAnchorJSON: String?
        var frozenViewportAnchorJSON: String?
        var isApplyingViewportAnchor = false
        var isAwaitingViewportRestore = false
        var pendingRestoreNeedsFreshLayout = false
        var viewportRestoreGeneration = 0
        var viewportRestoreRetryCount = 0
        var stableViewportLayoutSampleCount = 0
        var lastViewportLayoutSnapshot: RulesheetCombinedViewportLayoutSnapshot?
        var lastStableViewportLayoutSnapshot: RulesheetCombinedViewportLayoutSnapshot?
        var pendingViewportAnchorCapture: DispatchWorkItem?
        var pendingViewportRestoreWorkItem: DispatchWorkItem?
        var viewportRestoreBaselineLayoutSnapshot: RulesheetCombinedViewportLayoutSnapshot?
        let animatedFragmentReleaseDelay: TimeInterval = 0.4
        let animatedFragmentCaptureDelay: TimeInterval = 0.48
        let animatedResumeReleaseDelay: TimeInterval = 0.38
        let animatedResumeCaptureDelay: TimeInterval = 0.46

        init(
            anchorScrollInset: CGFloat,
            onChromeToggle: @escaping () -> Void,
            onProgressChange: @escaping (CGFloat) -> Void
        ) {
            self.anchorScrollInset = anchorScrollInset
            self.onChromeToggle = onChromeToggle
            self.onProgressChange = onProgressChange
        }
    }
}
