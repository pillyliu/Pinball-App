import UIKit
import WebKit

extension RulesheetRenderer.Coordinator {
    func beginViewportRestore(in webView: WKWebView) {
        viewportRestoreGeneration += 1
        isAwaitingViewportRestore = true
        pendingRestoreNeedsFreshLayout = true
        viewportRestoreRetryCount = 0
        stableViewportLayoutSampleCount = 0
        lastViewportLayoutSnapshot = nil
        viewportRestoreBaselineLayoutSnapshot = lastStableViewportLayoutSnapshot
        frozenViewportAnchorJSON = lastViewportAnchorJSON
        pendingViewportAnchorCapture?.cancel()
        pendingViewportRestoreWorkItem?.cancel()
        pendingRestoreNeedsFreshLayout = false
        scheduleViewportRestore(in: webView)
    }

    func scheduleViewportRestore(in webView: WKWebView, delay: TimeInterval = 0.12) {
        guard isAwaitingViewportRestore else { return }
        let generation = viewportRestoreGeneration
        pendingViewportRestoreWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self, weak webView] in
            guard let self, let webView else { return }
            guard self.viewportRestoreGeneration == generation else { return }
            guard self.isAwaitingViewportRestore else { return }

            if self.pendingRestoreNeedsFreshLayout {
                self.scheduleViewportRestore(in: webView, delay: delay)
                return
            }

            guard let baselineSnapshot = self.viewportRestoreBaselineLayoutSnapshot else {
                self.retryViewportRestoreIfNeeded(in: webView, generation: generation)
                return
            }

            self.captureViewportLayoutSnapshot(in: webView) { [weak self, weak webView] snapshot in
                guard let self, let webView, let snapshot else {
                    self?.retryViewportRestoreIfNeeded(in: webView, generation: generation)
                    return
                }
                guard self.viewportRestoreGeneration == generation else { return }

                guard RulesheetViewportRestoreSupport.layoutIsCoherent(snapshot) else {
                    self.retryViewportRestoreIfNeeded(in: webView, generation: generation)
                    return
                }

                let viewportStateChanged = RulesheetViewportRestoreSupport.stateChanged(
                    baseline: baselineSnapshot,
                    current: snapshot
                )

                guard viewportStateChanged else {
                    guard self.viewportRestoreRetryCount < 12 else {
                        self.finishViewportRestore(
                            in: webView,
                            releaseDelay: 0.01,
                            captureDelay: 0.08,
                            updateProgress: false
                        )
                        return
                    }
                    self.retryViewportRestoreIfNeeded(in: webView, generation: generation)
                    return
                }

                if let previousSnapshot = self.lastViewportLayoutSnapshot,
                   RulesheetViewportRestoreSupport.layoutIsStable(previous: previousSnapshot, current: snapshot) {
                    self.stableViewportLayoutSampleCount += 1
                } else {
                    self.stableViewportLayoutSampleCount = 0
                }

                self.lastViewportLayoutSnapshot = snapshot

                let layoutSettled = self.stableViewportLayoutSampleCount >= 1
                let shouldForceRestore = self.viewportRestoreRetryCount >= 9

                guard layoutSettled || shouldForceRestore else {
                    self.retryViewportRestoreIfNeeded(in: webView, generation: generation)
                    return
                }
                self.restoreViewportAnchorIfPossible(in: webView, generation: generation) { restored in
                    guard self.viewportRestoreGeneration == generation else { return }
                    if restored {
                        self.finishViewportRestore(
                            in: webView,
                            releaseDelay: 0.18,
                            captureDelay: 0.24,
                            updateProgress: true
                        )
                    } else {
                        self.retryViewportRestoreIfNeeded(in: webView, generation: generation)
                    }
                }
            }
        }

        pendingViewportRestoreWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func retryViewportRestoreIfNeeded(in webView: WKWebView?, generation: Int) {
        guard let webView else { return }
        guard isAwaitingViewportRestore else { return }
        guard viewportRestoreGeneration == generation else { return }
        guard viewportRestoreRetryCount < 12 else { return }

        viewportRestoreRetryCount += 1
        scheduleViewportRestore(in: webView)
    }

    func restoreViewportAnchorIfPossible(
        in webView: WKWebView,
        generation: Int,
        completion: @escaping (Bool) -> Void
    ) {
        guard isAwaitingViewportRestore else {
            completion(false)
            return
        }
        guard viewportRestoreGeneration == generation else {
            completion(false)
            return
        }
        guard let anchorJSON = frozenViewportAnchorJSON ?? lastViewportAnchorJSON else {
            completion(false)
            return
        }

        isApplyingViewportAnchor = true
        let script = RulesheetWebChromeBridge.restoreViewportAnchorScript(anchorJSON)
        webView.evaluateJavaScript(script) { result, _ in
            let restored = (result as? Bool) ?? false
            completion(restored)
        }
    }

    func finishViewportRestore(
        in webView: WKWebView,
        releaseDelay: TimeInterval,
        captureDelay: TimeInterval,
        updateProgress: Bool
    ) {
        clearViewportRestoreTrackingState()
        if updateProgress {
            onProgressChange(currentScrollRatio(in: webView))
        }
        releaseViewportAnchorApplication(in: webView, delay: releaseDelay)
        scheduleViewportAnchorCapture(in: webView, delay: captureDelay)
    }

    func clearViewportRestoreTrackingState() {
        isAwaitingViewportRestore = false
        pendingRestoreNeedsFreshLayout = false
        pendingViewportRestoreWorkItem?.cancel()
        pendingViewportRestoreWorkItem = nil
        viewportRestoreRetryCount = 0
        stableViewportLayoutSampleCount = 0
        lastViewportLayoutSnapshot = nil
        viewportRestoreBaselineLayoutSnapshot = nil
        frozenViewportAnchorJSON = nil
    }
}
