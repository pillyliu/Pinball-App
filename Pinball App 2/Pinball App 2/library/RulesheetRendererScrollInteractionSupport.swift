import UIKit
import WebKit

extension RulesheetRenderer.Coordinator {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let webView else { return }
        let ratio = currentScrollRatio(in: webView)
        onProgressChange(ratio)
        guard !isApplyingViewportAnchor, !isAwaitingViewportRestore else { return }
        scheduleViewportAnchorCapture(in: webView)
    }

    func handleResumeRequest(ratio: CGFloat?, requestID: Int, in webView: WKWebView) {
        guard let ratio else { return }
        guard requestID != lastHandledResumeRequestID else { return }

        let clamped = min(max(ratio, 0), 1)
        if didLoadPage, canApplyRatio(in: webView) {
            applyRatio(clamped, in: webView, animated: true)
            lastHandledResumeRequestID = requestID
            pendingResumeRatio = nil
            pendingResumeRequestID = nil
        } else {
            pendingResumeRatio = clamped
            pendingResumeRequestID = requestID
        }
    }

    func applyPendingResumeIfPossible(in webView: WKWebView) {
        guard let pending = pendingResumeRatio else { return }
        guard let queuedRequestID = pendingResumeRequestID else { return }
        guard queuedRequestID != lastHandledResumeRequestID else { return }
        guard canApplyRatio(in: webView) else { return }
        applyRatio(pending, in: webView, animated: true)
        lastHandledResumeRequestID = queuedRequestID
        pendingResumeRatio = nil
        pendingResumeRequestID = nil
    }

    func applyRatio(_ ratio: CGFloat, in webView: WKWebView, animated: Bool = false) {
        let scrollView = webView.scrollView
        let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        guard maxY > 0 else { return }
        let clamped = min(max(ratio, 0), 1)
        let targetY = clamped * maxY
        guard abs(scrollView.contentOffset.y - targetY) > 1 else { return }

        isApplyingViewportAnchor = true
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: targetY), animated: animated)
        let releaseDelay = animated ? animatedResumeReleaseDelay : 0.12
        let captureDelay = animated ? animatedResumeCaptureDelay : 0.08
        releaseViewportAnchorApplication(in: webView, delay: releaseDelay)
        scheduleViewportAnchorCapture(in: webView, delay: captureDelay)
        onProgressChange(clamped)
    }

    func currentScrollRatio(in webView: WKWebView) -> CGFloat {
        let scrollView = webView.scrollView
        let maxY = max(1, scrollView.contentSize.height - scrollView.bounds.height)
        return min(max(scrollView.contentOffset.y / maxY, 0), 1)
    }

    func updateAnchorScrollInset(in webView: WKWebView) {
        let script = RulesheetWebChromeBridge.setAnchorScrollInsetScript(anchorScrollInset)
        webView.evaluateJavaScript(script)
    }

    func handleRotationLayoutChangeIfNeeded(in webView: WKWebView) {
        let size = webView.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        defer {
            lastKnownViewSize = size
            lastKnownAnchorScrollInset = anchorScrollInset
        }

        let sizeChanged = lastKnownViewSize != .zero && (
            abs(lastKnownViewSize.width - size.width) > 1 ||
            abs(lastKnownViewSize.height - size.height) > 1
        )
        let insetChanged = if let lastKnownAnchorScrollInset {
            abs(lastKnownAnchorScrollInset - anchorScrollInset) > 0.5
        } else {
            false
        }

        guard didLoadPage, sizeChanged || insetChanged else { return }

        beginViewportRestore(in: webView)
    }

    func prepareForContentReload() {
        didLoadPage = false
        pendingViewportAnchorCapture?.cancel()
        pendingViewportAnchorCapture = nil
        pendingViewportRestoreWorkItem?.cancel()
        pendingViewportRestoreWorkItem = nil
        lastViewportAnchorJSON = nil
        frozenViewportAnchorJSON = nil
        isApplyingViewportAnchor = false
        isAwaitingViewportRestore = false
        pendingRestoreNeedsFreshLayout = false
        viewportRestoreRetryCount = 0
        stableViewportLayoutSampleCount = 0
        lastViewportLayoutSnapshot = nil
        lastStableViewportLayoutSnapshot = nil
        viewportRestoreBaselineLayoutSnapshot = nil
        lastKnownViewSize = .zero
        lastKnownAnchorScrollInset = nil
    }

    func scrollToFragment(_ fragment: String?, in webView: WKWebView, animated: Bool = true) {
        guard let fragment, !fragment.isEmpty else { return }
        let script = RulesheetWebChromeBridge.scrollToFragmentScript(
            fragment,
            behavior: animated ? "smooth" : "auto"
        )
        isApplyingViewportAnchor = true
        webView.evaluateJavaScript(script) { [weak self, weak webView] _, _ in
            guard let self, let webView else { return }
            let releaseDelay = animated ? self.animatedFragmentReleaseDelay : 0.12
            let captureDelay = animated ? self.animatedFragmentCaptureDelay : 0.08
            self.releaseViewportAnchorApplication(in: webView, delay: releaseDelay)
            self.scheduleViewportAnchorCapture(in: webView, delay: captureDelay)
        }
    }

    func canApplyRatio(in webView: WKWebView) -> Bool {
        let scrollView = webView.scrollView
        return scrollView.contentSize.height > scrollView.bounds.height + 1
    }

    func isSameDocumentLink(_ destination: URL, currentURL: URL?) -> Bool {
        guard let currentURL else { return destination.fragment != nil }

        guard destination.fragment != nil else { return false }
        var lhs = URLComponents(url: destination, resolvingAgainstBaseURL: false)
        var rhs = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)
        lhs?.fragment = nil
        rhs?.fragment = nil
        return lhs?.url == rhs?.url
    }
}
