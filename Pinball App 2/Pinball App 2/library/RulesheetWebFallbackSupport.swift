import SwiftUI
import WebKit

struct RulesheetWebFallbackView: UIViewRepresentable {
    let url: URL
    let anchorScrollInset: CGFloat
    let onChromeToggle: () -> Void

    init(
        url: URL,
        anchorScrollInset: CGFloat = 56,
        onChromeToggle: @escaping () -> Void = {}
    ) {
        self.url = url
        self.anchorScrollInset = anchorScrollInset
        self.onChromeToggle = onChromeToggle
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChromeToggle: onChromeToggle)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = makeRulesheetWebViewConfiguration(
            messageHandler: context.coordinator,
            anchorScrollInset: anchorScrollInset
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.applyRulesheetBaseAppearance()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onChromeToggle = onChromeToggle
        webView.evaluateJavaScript(RulesheetWebChromeBridge.setAnchorScrollInsetScript(anchorScrollInset))
        guard context.coordinator.lastURL != url else { return }
        context.coordinator.lastURL = url
        webView.load(URLRequest(url: url))
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: RulesheetWebChromeBridge.chromeTapMessageName)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastURL: URL?
        var onChromeToggle: () -> Void

        init(onChromeToggle: @escaping () -> Void) {
            self.onChromeToggle = onChromeToggle
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == RulesheetWebChromeBridge.chromeTapMessageName else { return }
            onChromeToggle()
        }
    }
}

struct ExternalRulesheetWebScreen: View {
    let title: String
    let url: URL

    var body: some View {
        RulesheetWebFallbackView(url: url)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
