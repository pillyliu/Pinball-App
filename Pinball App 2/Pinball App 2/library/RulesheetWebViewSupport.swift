import UIKit
import WebKit

final class RulesheetTrackingWebView: WKWebView {
    var onLayoutSubviews: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutSubviews?()
    }
}

func makeRulesheetWebViewConfiguration(
    messageHandler: WKScriptMessageHandler,
    anchorScrollInset: CGFloat,
    includesFragmentScrollHandler: Bool = false
) -> WKWebViewConfiguration {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true

    let userContentController = WKUserContentController()
    userContentController.add(messageHandler, name: RulesheetWebChromeBridge.chromeTapMessageName)
    if includesFragmentScrollHandler {
        userContentController.add(messageHandler, name: RulesheetWebChromeBridge.fragmentScrollMessageName)
    }
    userContentController.addUserScript(
        WKUserScript(
            source: RulesheetWebChromeBridge.userScriptSource(initialAnchorScrollInset: anchorScrollInset),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    )

    configuration.userContentController = userContentController
    return configuration
}

extension WKWebView {
    func applyRulesheetBaseAppearance() {
        isOpaque = false
        backgroundColor = .clear
        scrollView.backgroundColor = .clear
    }
}

enum RulesheetWebChromeBridge {
    static let chromeTapMessageName = "rulesheetChromeTap"
    static let fragmentScrollMessageName = "rulesheetFragmentScroll"

    static func userScriptSource(initialAnchorScrollInset: CGFloat) -> String {
        RulesheetWebBridgeTemplate.script(
            initialAnchorScrollInset: initialAnchorScrollInset,
            chromeTapMessageName: chromeTapMessageName,
            fragmentScrollMessageName: fragmentScrollMessageName
        )
    }

    static func setAnchorScrollInsetScript(_ inset: CGFloat) -> String {
        "window.__pinballSetAnchorScrollInset && window.__pinballSetAnchorScrollInset(\(String(format: "%.2f", inset)));"
    }

    static func captureViewportAnchorScript() -> String {
        "window.__pinballCaptureViewportAnchor && window.__pinballCaptureViewportAnchor();"
    }

    static func captureViewportLayoutSnapshotScript() -> String {
        "window.__pinballCaptureViewportLayoutSnapshot ? JSON.stringify(window.__pinballCaptureViewportLayoutSnapshot()) : null;"
    }

    static func restoreViewportAnchorScript(_ anchorJSON: String) -> String {
        let encoded = (try? String(data: JSONEncoder().encode(anchorJSON), encoding: .utf8)) ?? "\"\""
        return "window.__pinballRestoreViewportAnchor && window.__pinballRestoreViewportAnchor(\(encoded));"
    }

    static func scrollToFragmentScript(_ fragment: String, behavior: String = "auto") -> String {
        let encoded = (try? String(data: JSONEncoder().encode(fragment), encoding: .utf8)) ?? "\"\""
        let encodedBehavior = (try? String(data: JSONEncoder().encode(behavior), encoding: .utf8)) ?? "\"auto\""
        return "window.__pinballScrollToFragment && window.__pinballScrollToFragment(\(encoded), \(encodedBehavior));"
    }
}

private enum RulesheetWebBridgeTemplate {
    private static let resourceName = "RulesheetWebBridge"
    private static let chromeTapPlaceholder = "__PINBALL_CHROME_TAP_MESSAGE_NAME__"
    private static let fragmentScrollPlaceholder = "__PINBALL_FRAGMENT_SCROLL_MESSAGE_NAME__"
    private static let anchorInsetPlaceholder = "__PINBALL_INITIAL_ANCHOR_SCROLL_INSET__"

    static func script(
        initialAnchorScrollInset: CGFloat,
        chromeTapMessageName: String,
        fragmentScrollMessageName: String
    ) -> String {
        guard let template = loadTemplate() else {
            assertionFailure("Missing bundled RulesheetWebBridge.js resource")
            return ""
        }

        return template
            .replacingOccurrences(of: chromeTapPlaceholder, with: chromeTapMessageName)
            .replacingOccurrences(of: fragmentScrollPlaceholder, with: fragmentScrollMessageName)
            .replacingOccurrences(
                of: anchorInsetPlaceholder,
                with: String(format: "%.2f", initialAnchorScrollInset)
            )
    }

    private static func loadTemplate() -> String? {
        let candidateURLs = [
            Bundle.main.url(forResource: resourceName, withExtension: "js"),
            Bundle.main.url(forResource: resourceName, withExtension: "js", subdirectory: "library"),
        ]

        for candidateURL in candidateURLs {
            guard let candidateURL else { continue }
            if let template = try? String(contentsOf: candidateURL, encoding: .utf8) {
                return template
            }
        }

        return nil
    }
}
