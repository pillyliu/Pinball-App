import SwiftUI
import WebKit

struct RulesheetScreen: View {
    let slug: String
    let gameName: String
    @StateObject private var viewModel: RulesheetScreenModel
    @State private var scrollProgress: CGFloat = 0
    @State private var savedProgress: CGFloat?
    @State private var showResumePrompt = false
    @State private var resumeTarget: CGFloat?
    @State private var resumeRequestID: Int = 0
    @State private var didEvaluateResumePrompt = false
    @State private var pulsePhase = false
    @Environment(\.dismiss) private var dismiss
    @State private var showsBackButton = false

    init(slug: String, gameName: String? = nil) {
        self.slug = slug
        self.gameName = gameName ?? slug.replacingOccurrences(of: "-", with: " ").capitalized
        _viewModel = StateObject(wrappedValue: RulesheetScreenModel(slug: slug))
    }

    var body: some View {
        GeometryReader { geo in
            let topInset = max(geo.safeAreaInsets.top, 44)

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
                        ZStack(alignment: .topTrailing) {
                            RulesheetRenderer(
                                markdown: markdownText,
                                resumeTarget: resumeTarget,
                                resumeRequestID: resumeRequestID,
                                onProgressChange: { progress in
                                    scrollProgress = progress
                                }
                            )

                            Button {
                                saveCurrentProgress()
                            } label: {
                                Text("\(currentProgressPercent)%")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(progressPillForeground)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(progressPillBackground, in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(progressPillStroke, lineWidth: 0.7)
                                    )
                                    .opacity(progressNeedsSave ? (pulsePhase ? 0.52 : 1.0) : 1.0)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, topInset + 30)
                            .padding(.trailing, 12)
                        }
                    }
                }

                LinearGradient(
                    colors: [AppTheme.bg, AppTheme.bg.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: topInset + 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

                if showsBackButton {
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
                            .accessibilityLabel("Back from \(gameName)")
                            Spacer()
                        }
                        .padding(.top, topInset + 12)
                        .padding(.horizontal, 16)
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .appEdgeBackGesture(dismiss: dismiss)
        .simultaneousGesture(
            TapGesture().onEnded {
                showsBackButton.toggle()
            }
        )
        .task {
            await viewModel.loadIfNeeded()
            if savedProgress == nil {
                savedProgress = loadSavedProgress()
            }
        }
        .onAppear {
            if savedProgress == nil {
                savedProgress = loadSavedProgress()
            }
            if progressNeedsSave {
                startPulse()
            }
        }
        .onChange(of: viewModel.status) { _, newStatus in
            guard newStatus == .loaded, !didEvaluateResumePrompt else { return }
            didEvaluateResumePrompt = true
            if let saved = savedProgress, saved > 0.001 {
                showResumePrompt = true
            }
        }
        .onChange(of: progressNeedsSave) { _, needsSave in
            if needsSave {
                startPulse()
            }
        }
        .alert(
            "Return to last saved position?",
            isPresented: $showResumePrompt
        ) {
            Button("No", role: .cancel) {}
            Button("Yes") {
                if let saved = savedProgress {
                    resumeTarget = saved
                    resumeRequestID += 1
                }
            }
        } message: {
            Text("Return to \(savedProgressPercent)%?")
        }
    }

    private var currentProgressPercent: Int {
        Int((min(max(scrollProgress, 0), 1) * 100).rounded())
    }

    private var savedProgressPercent: Int {
        Int((min(max(savedProgress ?? 0, 0), 1) * 100).rounded())
    }

    private var progressNeedsSave: Bool {
        currentProgressPercent != savedProgressPercent
    }

    private var progressPillBackground: Color {
        if !progressNeedsSave, savedProgress != nil {
            return Color.green.opacity(0.85)
        }
        return Color(uiColor: .secondarySystemBackground).opacity(0.88)
    }

    private var progressPillForeground: Color {
        if !progressNeedsSave, savedProgress != nil {
            return .white
        }
        return .primary
    }

    private var progressPillStroke: Color {
        if !progressNeedsSave, savedProgress != nil {
            return Color.green.opacity(0.9)
        }
        return Color.primary.opacity(0.16)
    }

    private var progressStorageKey: String {
        "rulesheet-last-progress-\(slug)"
    }

    private func loadSavedProgress() -> CGFloat? {
        guard let number = UserDefaults.standard.object(forKey: progressStorageKey) as? NSNumber else {
            return nil
        }
        return min(max(CGFloat(number.doubleValue), 0), 1)
    }

    private func saveCurrentProgress() {
        let clamped = min(max(scrollProgress, 0), 1)
        UserDefaults.standard.set(Double(clamped), forKey: progressStorageKey)
        savedProgress = clamped
    }

    private func startPulse() {
        pulsePhase = false
        withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
            pulsePhase = true
        }
    }
}

private struct RulesheetRenderer: UIViewRepresentable {
    let markdown: String
    let resumeTarget: CGFloat?
    let resumeRequestID: Int
    let onProgressChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onProgressChange: onProgressChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onProgressChange = onProgressChange
        context.coordinator.handleResumeRequest(ratio: resumeTarget, requestID: resumeRequestID, in: webView)
        guard context.coordinator.lastMarkdown != markdown else { return }
        context.coordinator.lastMarkdown = markdown
        webView.loadHTMLString(Self.html(for: markdown), baseURL: URL(string: "https://pillyliu.com"))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var lastMarkdown: String?
        weak var webView: WKWebView?
        var onProgressChange: (CGFloat) -> Void
        private var didLoadPage = false
        private var lastHandledResumeRequestID: Int = -1
        private var pendingResumeRatio: CGFloat?
        private var pendingResumeRequestID: Int?

        init(onProgressChange: @escaping (CGFloat) -> Void) {
            self.onProgressChange = onProgressChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didLoadPage = true
            applyPendingResumeIfPossible(in: webView)
            onProgressChange(currentScrollRatio(in: webView))
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let webView else { return }
            let ratio = currentScrollRatio(in: webView)
            onProgressChange(ratio)
        }

        func handleResumeRequest(ratio: CGFloat?, requestID: Int, in webView: WKWebView) {
            guard let ratio else { return }
            guard requestID != lastHandledResumeRequestID else { return }

            let clamped = min(max(ratio, 0), 1)
            if didLoadPage, canApplyRatio(in: webView) {
                applyRatio(clamped, in: webView)
                lastHandledResumeRequestID = requestID
                pendingResumeRatio = nil
                pendingResumeRequestID = nil
            } else {
                pendingResumeRatio = clamped
                pendingResumeRequestID = requestID
            }
        }

        private func applyPendingResumeIfPossible(in webView: WKWebView) {
            guard let pending = pendingResumeRatio else { return }
            guard let queuedRequestID = pendingResumeRequestID else { return }
            guard queuedRequestID != lastHandledResumeRequestID else { return }
            guard canApplyRatio(in: webView) else { return }
            applyRatio(pending, in: webView)
            lastHandledResumeRequestID = queuedRequestID
            pendingResumeRatio = nil
            pendingResumeRequestID = nil
        }

        func applyRatio(_ ratio: CGFloat, in webView: WKWebView) {
            let scrollView = webView.scrollView
            let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            guard maxY > 0 else { return }
            let clamped = min(max(ratio, 0), 1)
            let targetY = clamped * maxY
            guard abs(scrollView.contentOffset.y - targetY) > 1 else { return }

            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: targetY), animated: false)
            onProgressChange(clamped)
        }

        private func canApplyRatio(in webView: WKWebView) -> Bool {
            let scrollView = webView.scrollView
            return scrollView.contentSize.height > scrollView.bounds.height + 1
        }

        private func currentScrollRatio(in webView: WKWebView) -> CGFloat {
            let scrollView = webView.scrollView
            let maxY = max(1, scrollView.contentSize.height - scrollView.bounds.height)
            return min(max(scrollView.contentOffset.y / maxY, 0), 1)
        }
    }
}

private extension RulesheetRenderer {
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
              --text: #1f1f1f;
              --link: #0a65cc;
              --code-bg: #f1f3f5;
              --code-text: #202124;
              --rule: #d7d9de;
              --table-border: #d7d9de;
            }
            @media (prefers-color-scheme: dark) {
              :root {
                --text: #f3f3f3;
                --link: #a6c8ff;
                --code-bg: #111;
                --code-text: #f3f3f3;
                --rule: #2a2a2a;
                --table-border: #2a2a2a;
              }
            }
            html, body {
              margin: 0;
              padding: 0;
              background: transparent;
            }
            body {
              padding: 76px 16px calc(env(safe-area-inset-bottom) + 28px);
              font: -apple-system-body;
              -webkit-text-size-adjust: 100%;
              text-size-adjust: 100%;
              color: var(--text);
              line-height: 1.45;
              box-sizing: border-box;
            }
            #content { margin: 0; }
            #content > :first-child { margin-top: 0 !important; }
            a { color: var(--link); text-decoration: underline; }
            code, pre { background: var(--code-bg); border-radius: 8px; color: var(--code-text); }
            pre { padding: 10px; overflow-x: auto; }
            table { border-collapse: collapse; width: 100%; overflow-x: auto; display: block; }
            th, td { border: 1px solid var(--table-border); padding: 6px 8px; }
            img { max-width: 100%; height: auto; }
            hr { border: none; border-top: 1px solid var(--rule); }
            .rulesheet-attribution {
              display: block;
              font-size: 0.78rem;
              line-height: 1.35;
              opacity: 0.78;
              margin-bottom: 0.8rem;
            }
          </style>
          <script src="https://cdn.jsdelivr.net/npm/markdown-it@14.1.0/dist/markdown-it.min.js"></script>
        </head>
        <body>
          <article id="content"></article>
          <script>
            const markdown = \(markdownJSON);
            const container = document.getElementById('content');
            if (!window.markdownit) {
              container.textContent = markdown;
            } else {
              const md = window.markdownit({ html: true, linkify: true, breaks: false });
              container.innerHTML = md.render(markdown);
            }
          </script>
        </body>
        </html>
        """
    }
}
