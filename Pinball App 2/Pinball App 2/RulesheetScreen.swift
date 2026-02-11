import SwiftUI
import WebKit

struct RulesheetView: View {
    let slug: String
    @StateObject private var viewModel: RulesheetViewModel
    @StateObject private var chrome = FullscreenChromeController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var suppressChromeToggle = false

    init(slug: String) {
        self.slug = slug
        _viewModel = StateObject(wrappedValue: RulesheetViewModel(slug: slug))
    }

    var body: some View {
        ZStack {
            AppBackground()

            switch viewModel.status {
            case .idle, .loading:
                Text("Loading rulesheet...")
                    .foregroundStyle(.secondary)
            case .missing:
                Text("Rulesheet not available.")
                    .foregroundStyle(.secondary)
            case .error:
                Text("Could not load rulesheet.")
                    .foregroundStyle(.secondary)
            case .loaded:
                if let markdownText = viewModel.markdownText {
                    MarkdownWebView(
                        markdown: markdownText,
                        onAnchorTap: {
                            suppressChromeToggle = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                suppressChromeToggle = false
                            }
                        }
                    )
                        .ignoresSafeArea()
                }
            }

            if chrome.isVisible {
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(14)
                                .background(.regularMaterial, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(uiColor: .separator).opacity(0.75), lineWidth: 1)
                                )
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.top, 0)
                    .padding(.horizontal, 16)
                    Spacer()
                }
                .transition(.opacity)
            }

        }
        .simultaneousGesture(
            TapGesture().onEnded {
                if suppressChromeToggle { return }
                chrome.toggle(reduceMotion: reduceMotion)
            }
        )
        .appEdgeBackGesture(dismiss: dismiss)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .tabBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .onAppear {
            chrome.resetOnAppear()
        }
        .onDisappear {
            chrome.cleanupOnDisappear()
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}

private struct MarkdownWebView: UIViewRepresentable {
    let markdown: String
    var onAnchorTap: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onAnchorTap: onAnchorTap)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "codexAnchorTap")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.navigationDelegate = context.coordinator
        guard context.coordinator.lastMarkdown != markdown else { return }

        context.coordinator.lastMarkdown = markdown
        webView.loadHTMLString(
            Self.html(for: markdown),
            baseURL: URL(string: "https://pillyliu.com")
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onAnchorTap: (() -> Void)?
        var lastMarkdown: String?
        weak var webView: WKWebView?

        init(onAnchorTap: (() -> Void)?) {
            self.onAnchorTap = onAnchorTap
            super.init()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if message.name == "codexAnchorTap" {
                    self.onAnchorTap?()
                    return
                }
            }
        }

        deinit {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "codexAnchorTap")
        }

    }
}

private extension MarkdownWebView {
    static func scriptForTopAnchor() -> String {
        """
        function __codexNotifyAnchorTapToNative() {
          try {
            if (
              window.webkit &&
              window.webkit.messageHandlers &&
              window.webkit.messageHandlers.codexAnchorTap
            ) {
              window.webkit.messageHandlers.codexAnchorTap.postMessage('anchor');
            }
          } catch (e) {}
        }
        document.addEventListener('touchstart', function(e) {
          var t = e.target;
          var a = t && t.closest ? t.closest('a[href^="#"]') : null;
          if (a) __codexNotifyAnchorTapToNative();
        }, { passive: true, capture: true });
        document.addEventListener('mousedown', function(e) {
          var t = e.target;
          var a = t && t.closest ? t.closest('a[href^="#"]') : null;
          if (a) __codexNotifyAnchorTapToNative();
        }, { capture: true });
        """
    }
}

private extension MarkdownWebView {
    static func injectedScript(markdownJSON: String) -> String {
        let renderScript = """
            const markdown = \(markdownJSON);
            const container = document.getElementById('content');
            if (!window.markdownit) {
              const fallback = document.createElement('div');
              fallback.className = 'fallback-markdown';
              fallback.textContent = markdown;
              container.appendChild(fallback);
            } else {
              const md = window.markdownit({ html: true, linkify: true, breaks: false });
              container.innerHTML = md.render(markdown);
            }
        """
        return """
        \(renderScript)

        \(scriptForTopAnchor())
        """
    }
}

private extension MarkdownWebView {
    static func html(for markdown: String) -> String {
        let markdownJSON = (try? String(data: JSONEncoder().encode(markdown), encoding: .utf8)) ?? "\"\""

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
          <style>
            :root {
              color-scheme: light dark;
              --body-text: #1f1f1f;
              --link: #0a65cc;
              --code-bg: #f1f3f5;
              --code-text: #202124;
              --rule: #d7d9de;
              --table-border: #d7d9de;
            }
            @media (prefers-color-scheme: dark) {
              :root {
                --body-text: #f3f3f3;
                --link: #a6c8ff;
                --code-bg: #111;
                --code-text: #f3f3f3;
                --rule: #2a2a2a;
                --table-border: #2a2a2a;
              }
            }
            body {
              margin: 0;
              padding: 14px 18px;
              padding-left: max(18px, calc(env(safe-area-inset-left) + 10px));
              padding-right: max(18px, calc(env(safe-area-inset-right) + 10px));
              padding-top: calc(14px + env(safe-area-inset-top));
              padding-bottom: calc(18px + env(safe-area-inset-bottom));
              font: -apple-system-body;
              -webkit-text-size-adjust: 100%;
              text-size-adjust: 100%;
              background: transparent;
              color: var(--body-text);
              line-height: 1.45;
              max-width: 980px;
              box-sizing: border-box;
            }
            article { width: 100%; }
            @media (min-width: 1000px) {
              body {
                margin-left: auto;
                margin-right: auto;
                font-size: 21px;
                line-height: 1.58;
                padding-left: max(24px, calc(env(safe-area-inset-left) + 12px));
                padding-right: max(24px, calc(env(safe-area-inset-right) + 12px));
              }
              th, td { padding: 8px 10px; }
            }
            @media (min-width: 1000px) and (orientation: landscape) {
              body {
                max-width: none;
                margin-left: 0;
                margin-right: 0;
                font-size: 22px;
                line-height: 1.6;
              }
            }
            #content > :first-child { margin-top: 0 !important; }
            :target { scroll-margin-top: calc(env(safe-area-inset-top) + 0px); }
            a { color: var(--link); text-decoration: underline; }
            code, pre { background: var(--code-bg); border-radius: 8px; color: var(--code-text); }
            pre { padding: 10px; overflow-x: auto; }
            .fallback-markdown { white-space: pre-wrap; color: var(--body-text); }
            table { border-collapse: collapse; width: 100%; overflow-x: auto; display: block; }
            th, td { border: 1px solid var(--table-border); padding: 6px 8px; }
            img { max-width: 100%; height: auto; }
            hr { border: none; border-top: 1px solid var(--rule); }
          </style>
          <script src="https://cdn.jsdelivr.net/npm/markdown-it@14.1.0/dist/markdown-it.min.js"></script>
        </head>
        <body>
          <article id="content"></article>
          <script>
        \(injectedScript(markdownJSON: markdownJSON))
          </script>
        </body>
        </html>
        """
    }
}
