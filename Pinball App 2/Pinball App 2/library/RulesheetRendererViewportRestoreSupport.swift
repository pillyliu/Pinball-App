import UIKit
import WebKit

extension RulesheetRenderer.Coordinator {
    func scheduleViewportAnchorCapture(in webView: WKWebView, delay: TimeInterval = 0.16) {
        guard didLoadPage else { return }
        guard !isAwaitingViewportRestore else { return }

        pendingViewportAnchorCapture?.cancel()
        let workItem = DispatchWorkItem { [weak self, weak webView] in
            guard let self, let webView else { return }
            self.captureViewportLayoutSnapshot(in: webView) { [weak self, weak webView] snapshot in
                guard let self, let webView else { return }
                guard let snapshot, RulesheetViewportRestoreSupport.layoutIsCoherent(snapshot) else { return }
                self.lastStableViewportLayoutSnapshot = snapshot
                self.captureViewportAnchor(in: webView) { [weak self] anchorJSON in
                    guard let self, let anchorJSON else { return }
                    self.lastViewportAnchorJSON = anchorJSON
                }
            }
        }

        pendingViewportAnchorCapture = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func captureViewportAnchor(
        in webView: WKWebView,
        completion: @escaping (String?) -> Void
    ) {
        let script = RulesheetWebChromeBridge.captureViewportAnchorScript()
        webView.evaluateJavaScript(script) { result, _ in
            completion(result as? String)
        }
    }

    func captureViewportLayoutSnapshot(
        in webView: WKWebView,
        completion: @escaping (RulesheetCombinedViewportLayoutSnapshot?) -> Void
    ) {
        let script = RulesheetWebChromeBridge.captureViewportLayoutSnapshotScript()
        webView.evaluateJavaScript(script) { [weak self, weak webView] result, _ in
            guard let self, let webView else {
                completion(nil)
                return
            }
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let domSnapshot = try? JSONDecoder().decode(RulesheetViewportLayoutSnapshot.self, from: data) else {
                completion(nil)
                return
            }

            completion(
                RulesheetCombinedViewportLayoutSnapshot(
                    dom: domSnapshot,
                    native: self.nativeViewportLayoutSnapshot(in: webView)
                )
            )
        }
    }

    func nativeViewportLayoutSnapshot(in webView: WKWebView) -> RulesheetNativeViewportLayoutSnapshot {
        RulesheetNativeViewportLayoutSnapshot(
            webViewSize: webView.bounds.size,
            scrollViewSize: webView.scrollView.bounds.size,
            contentHeight: webView.scrollView.contentSize.height,
            contentOffsetY: webView.scrollView.contentOffset.y
        )
    }

    func releaseViewportAnchorApplication(in webView: WKWebView, delay: TimeInterval = 0.12) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
            guard let self, let webView else { return }
            self.isApplyingViewportAnchor = false
            self.onProgressChange(self.currentScrollRatio(in: webView))
        }
    }
}
