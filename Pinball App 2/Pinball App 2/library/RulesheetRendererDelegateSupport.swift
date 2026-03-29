import UIKit
import WebKit

extension RulesheetRenderer.Coordinator {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didLoadPage = true
        updateAnchorScrollInset(in: webView)
        applyPendingResumeIfPossible(in: webView)
        onProgressChange(currentScrollRatio(in: webView))
        scheduleViewportAnchorCapture(in: webView, delay: 0.08)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard navigationAction.navigationType == .linkActivated,
              let destination = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if isSameDocumentLink(destination, currentURL: webView.url) {
            scrollToFragment(destination.fragment, in: webView)
            decisionHandler(.cancel)
            return
        }

        UIApplication.shared.open(destination)
        decisionHandler(.cancel)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == RulesheetWebChromeBridge.chromeTapMessageName {
            onChromeToggle()
            return
        }

        guard message.name == RulesheetWebChromeBridge.fragmentScrollMessageName else { return }
        guard let webView, let fragment = message.body as? String else { return }
        scrollToFragment(fragment, in: webView, animated: true)
    }
}
