import SwiftUI
import UIKit
import WebKit
import CryptoKit

struct RulesheetScreen: View {
    let slug: String
    let gameName: String
    private let pathCandidates: [String]
    private let externalSource: RulesheetRemoteSource?
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

    init(
        slug: String,
        gameName: String? = nil,
        pathCandidates: [String]? = nil,
        externalSource: RulesheetRemoteSource? = nil
    ) {
        self.slug = slug
        self.gameName = gameName ?? slug.replacingOccurrences(of: "-", with: " ").capitalized
        self.pathCandidates = pathCandidates ?? ["/pinball/rulesheets/\(slug).md"]
        self.externalSource = externalSource
        _viewModel = StateObject(
            wrappedValue: RulesheetScreenModel(
                pathCandidates: pathCandidates ?? ["/pinball/rulesheets/\(slug).md"],
                externalSource: externalSource
            )
        )
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
                    if let content = viewModel.content {
                        ZStack(alignment: .topTrailing) {
                            RulesheetRenderer(
                                content: content,
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
                    } else if let fallbackURL = viewModel.webFallbackURL {
                        RulesheetWebFallbackView(url: fallbackURL)
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
    let content: RulesheetRenderContent
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
        guard context.coordinator.lastContent != content else { return }
        context.coordinator.lastContent = content
        webView.loadHTMLString(
            Self.html(for: content),
            baseURL: content.baseURL ?? URL(string: "https://pillyliu.com")
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate {
        var lastContent: RulesheetRenderContent?
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
                decisionHandler(.allow)
                return
            }

            UIApplication.shared.open(destination)
            decisionHandler(.cancel)
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

        private func isSameDocumentLink(_ destination: URL, currentURL: URL?) -> Bool {
            guard let currentURL else { return destination.fragment != nil }

            guard destination.fragment != nil else { return false }
            var lhs = URLComponents(url: destination, resolvingAgainstBaseURL: false)
            var rhs = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)
            lhs?.fragment = nil
            rhs?.fragment = nil
            return lhs?.url == rhs?.url
        }
    }
}

private struct RulesheetWebFallbackView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastURL != url else { return }
        context.coordinator.lastURL = url
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastURL: URL?
    }
}

struct ExternalRulesheetWebScreen: View {
    let title: String
    let url: URL

    var body: some View {
        RulesheetWebFallbackView(url: url)
            .background(AppBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private extension RulesheetRenderer {
    static func html(for content: RulesheetRenderContent) -> String {
        let payloadJSON = (try? String(data: JSONEncoder().encode(content.body), encoding: .utf8)) ?? "\"\""
        let mode = content.kind.rawValue

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
            #content {
              margin: 0;
              max-width: 100%;
              overflow-x: hidden;
              overflow-wrap: anywhere;
              word-break: break-word;
            }
            #content > :first-child { margin-top: 0 !important; }
            a {
              color: var(--link);
              text-decoration: underline;
              overflow-wrap: anywhere;
              word-break: break-word;
            }
            code, pre { background: var(--code-bg); border-radius: 8px; color: var(--code-text); }
            code {
              overflow-wrap: anywhere;
              word-break: break-word;
            }
            pre { padding: 10px; overflow-x: auto; }
            .table-scroll {
              overflow-x: auto;
              -webkit-overflow-scrolling: touch;
              margin: 0 0 1rem;
            }
            table {
              border-collapse: collapse;
              width: 100%;
              table-layout: auto;
            }
            th, td {
              border: 1px solid var(--table-border);
              padding: 6px 8px;
              vertical-align: top;
              word-break: normal;
              overflow-wrap: normal;
              white-space: normal;
            }
            .primer-rulesheet table td:first-child,
            .primer-rulesheet table th:first-child {
              width: 34%;
              min-width: 7.5rem;
            }
            .primer-rulesheet table td:last-child,
            .primer-rulesheet table th:last-child {
              width: 66%;
            }
            img { max-width: 100%; height: auto; }
            hr { border: none; border-top: 1px solid var(--rule); }
            h1, h2, h3, h4, h5, h6 { line-height: 1.22; }
            ul, ol { padding-left: 1.25rem; }
            .pinball-rulesheet, .remote-rulesheet { display: block; }
            .legacy-rulesheet .bodyTitle {
              display: block;
              font-size: 1.1rem;
              font-weight: 700;
              margin: 1rem 0 0.4rem;
            }
            .legacy-rulesheet .bodySmall {
              display: block;
              font-size: 0.92rem;
              opacity: 0.88;
            }
            .legacy-rulesheet pre.rulesheet-preformatted {
              white-space: pre-wrap;
              font: inherit;
              background: transparent;
              padding: 0;
              border-radius: 0;
            }
            .rulesheet-attribution {
              display: block;
              font-size: 0.78rem;
              line-height: 1.35;
              opacity: 0.78;
              margin-bottom: 0.8rem;
            }
            .rulesheet-attribution, .rulesheet-attribution * {
              overflow-wrap: anywhere;
              word-break: break-word;
            }
          </style>
          <script src="https://cdn.jsdelivr.net/npm/markdown-it@14.1.0/dist/markdown-it.min.js"></script>
        </head>
        <body>
          <article id="content"></article>
          <script>
            const mode = \(try! String(data: JSONEncoder().encode(mode), encoding: .utf8)!);
            const payload = \(payloadJSON);
            const container = document.getElementById('content');
            if (mode === 'html') {
              container.innerHTML = payload;
            } else if (!window.markdownit) {
              container.textContent = payload;
            } else {
              const md = window.markdownit({ html: true, linkify: true, breaks: false });
              container.innerHTML = md.render(payload);
            }
            container.querySelectorAll('table').forEach((table) => {
              if (table.parentElement && table.parentElement.classList.contains('table-scroll')) return;
              const wrapper = document.createElement('div');
              wrapper.className = 'table-scroll';
              table.parentNode.insertBefore(wrapper, table);
              wrapper.appendChild(table);
            });
          </script>
        </body>
        </html>
        """
    }
}

struct RulesheetRenderContent: Equatable {
    enum Kind: String, Equatable {
        case markdown
        case html
    }

    let kind: Kind
    let body: String
    let baseURL: URL?
}

struct RulesheetRemoteSource: Identifiable, Hashable {
    enum Provider: String, Hashable {
        case tiltForums
        case pinballPrimer
        case papa
        case bob

        var sourceName: String {
            switch self {
            case .tiltForums:
                return "Tilt Forums community rulesheet"
            case .pinballPrimer:
                return "Pinball Primer"
            case .papa:
                return "PAPA / pinball.org rulesheet archive"
            case .bob:
                return "Silverball Rules (Bob Matthews source)"
            }
        }

        var originalLinkLabel: String {
            switch self {
            case .tiltForums:
                return "Original thread"
            default:
                return "Original page"
            }
        }

        var detailsText: String {
            switch self {
            case .tiltForums:
                return "License/source terms remain with Tilt Forums and the original authors."
            case .pinballPrimer, .papa, .bob:
                return "Preserve source attribution and any author/site rights notes from the original page."
            }
        }
    }

    let label: String
    let url: URL
    let provider: Provider

    var id: String { url.absoluteString }

    var webFallbackURL: URL? {
        switch provider {
        case .tiltForums:
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let currentPath = components?.path ?? url.path
            if currentPath.lowercased().hasSuffix(".json") {
                components?.path = currentPath.replacingOccurrences(of: ".json", with: "")
            }
            components?.query = nil
            return components?.url ?? url
        case .pinballPrimer, .papa, .bob:
            return url
        }
    }
}

private struct RemoteFetchedDocument {
    let text: String
    let mimeType: String?
    let finalURL: URL
}

private struct RemoteCachedDocument {
    let text: String
    let mimeType: String?
    let finalURL: String
    let fetchedAt: TimeInterval
}

private struct TiltForumsTopicResponse: Decodable {
    struct PostStream: Decodable {
        let posts: [Post]
    }

    struct Post: Decodable {
        let cooked: String?
        let topicID: Int?
        let topicSlug: String?
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case cooked
            case topicID = "topic_id"
            case topicSlug = "topic_slug"
            case updatedAt = "updated_at"
        }
    }

    let title: String?
    let postStream: PostStream?

    enum CodingKeys: String, CodingKey {
        case title
        case postStream = "post_stream"
    }
}

private struct TiltForumsPostResponse: Decodable {
    let cooked: String?
    let topicID: Int?
    let topicSlug: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case cooked
        case topicID = "topic_id"
        case topicSlug = "topic_slug"
        case updatedAt = "updated_at"
    }
}

enum RemoteRulesheetLoader {
    private static let cache = RemoteRulesheetCache()

    static func load(from source: RulesheetRemoteSource) async throws -> RulesheetRenderContent {
        switch source.provider {
        case .tiltForums:
            return try await loadTiltForums(from: source)
        case .pinballPrimer:
            return try await loadPrimer(from: source)
        case .papa, .bob:
            return try await loadLegacyHTML(from: source)
        }
    }

    private static func loadTiltForums(from source: RulesheetRemoteSource) async throws -> RulesheetRenderContent {
        let apiURL = tiltForumsAPIURL(from: source.url)
        let fetched = try await fetchCached(url: apiURL)
        let payloadData = Data(fetched.text.utf8)
        let parsed = try parseTiltForumsPayload(payloadData, fallbackURL: source.url)
        let canonicalURL = parsed.canonicalURL
        let attribution = attributionHTML(
            source: source,
            displayURL: canonicalURL,
            updatedAt: parsed.updatedAt
        )
        let body = """
        \(attribution)
        <div class="pinball-rulesheet remote-rulesheet tiltforums-rulesheet">
        \(parsed.cooked)
        </div>
        """
        return RulesheetRenderContent(kind: .html, body: body, baseURL: canonicalURL)
    }

    private static func loadPrimer(from source: RulesheetRemoteSource) async throws -> RulesheetRenderContent {
        let fetched = try await fetchCached(url: source.url)
        let fragment = cleanupPrimerHTML(fetched.text)
        let attribution = attributionHTML(source: source, displayURL: fetched.finalURL, updatedAt: nil)
        let body = """
        \(attribution)
        <div class="pinball-rulesheet remote-rulesheet primer-rulesheet">
        \(fragment)
        </div>
        """
        return RulesheetRenderContent(kind: .html, body: body, baseURL: fetched.finalURL)
    }

    private static func loadLegacyHTML(from source: RulesheetRemoteSource) async throws -> RulesheetRenderContent {
        let fetchURL = legacyFetchURL(for: source)
        let fetched = try await fetchCached(url: fetchURL)
        let fragment = cleanupLegacyHTML(fetched.text, mimeType: fetched.mimeType, source: source)
        let attribution = attributionHTML(source: source, displayURL: fetched.finalURL, updatedAt: nil)
        let body = """
        \(attribution)
        <div class="pinball-rulesheet remote-rulesheet legacy-rulesheet">
        \(fragment)
        </div>
        """
        return RulesheetRenderContent(kind: .html, body: body, baseURL: fetched.finalURL)
    }

    private static func fetch(url: URL) async throws -> RemoteFetchedDocument {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 PinballApp/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            throw URLError(.cannotDecodeRawData)
        }
        return RemoteFetchedDocument(
            text: text,
            mimeType: response.mimeType,
            finalURL: response.url ?? url
        )
    }

    private static func fetchCached(url: URL) async throws -> RemoteFetchedDocument {
        if let cached = try? await cache.loadFresh(url: url) {
            return cached
        }

        do {
            let fetched = try await fetch(url: url)
            try? await cache.save(fetched, for: url)
            return fetched
        } catch {
            if let stale = try? await cache.loadAny(url: url) {
                return stale
            }
            throw error
        }
    }

    private static func legacyFetchURL(for source: RulesheetRemoteSource) -> URL {
        guard source.provider == .bob else { return source.url }
        guard source.url.host?.lowercased().contains("silverballmania.com") == true else { return source.url }
        guard let slug = source.url.pathComponents.last, !slug.isEmpty else { return source.url }
        return URL(string: "https://rules.silverballmania.com/print/\(slug)") ?? source.url
    }

    private static func cleanupPrimerHTML(_ html: String) -> String {
        let body = extractBodyHTML(from: html) ?? html
        var cleaned = stripHTML(body, patterns: [
            #"(?is)<iframe\b[^>]*>.*?</iframe>"#,
            #"(?is)<script\b[^>]*>.*?</script>"#,
            #"(?is)<style\b[^>]*>.*?</style>"#,
            #"(?is)<!--.*?-->"#
        ])
        if let firstHeadingRange = cleaned.range(of: #"(?is)<h1\b[^>]*>"#, options: .regularExpression) {
            cleaned = String(cleaned[firstHeadingRange.lowerBound...])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanupLegacyHTML(_ html: String, mimeType: String?, source: RulesheetRemoteSource) -> String {
        if shouldTreatAsPlainText(html: html, mimeType: mimeType) {
            return "<pre class=\"rulesheet-preformatted\">\(html.htmlEscaped)</pre>"
        }

        if source.provider == .bob, let main = extractMainHTML(from: html) {
            let cleanedMain = stripHTML(main, patterns: [
                #"(?is)<script\b[^>]*>.*?</script>"#,
                #"(?is)<!--.*?-->"#,
                #"(?is)<a\b[^>]*title="Print"[^>]*>.*?</a>"#
            ])
            return cleanedMain.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let body = extractBodyHTML(from: html) ?? html
        let cleaned = stripHTML(body, patterns: [
            #"(?is)<\?.*?\?>"#,
            #"(?is)<script\b[^>]*>.*?</script>"#,
            #"(?is)<style\b[^>]*>.*?</style>"#,
            #"(?is)<iframe\b[^>]*>.*?</iframe>"#,
            #"(?is)<!--.*?-->"#,
            #"(?is)</?(html|head|body|meta|link)\b[^>]*>"#
        ])
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shouldTreatAsPlainText(html: String, mimeType: String?) -> Bool {
        if mimeType?.localizedCaseInsensitiveContains("text/plain") == true {
            return true
        }
        let tagMatch = html.range(of: #"<[a-zA-Z!/][^>]*>"#, options: .regularExpression)
        return tagMatch == nil
    }

    private static func extractMainHTML(from html: String) -> String? {
        guard let match = html.firstCapture(for: #"(?is)<main\b[^>]*>(.*?)</main>"#) else {
            return nil
        }
        return match
    }

    private static func extractBodyHTML(from html: String) -> String? {
        guard let match = html.firstCapture(for: #"(?is)<body\b[^>]*>(.*?)</body>"#) else {
            return nil
        }
        return match
    }

    private static func stripHTML(_ html: String, patterns: [String]) -> String {
        patterns.reduce(html) { partial, pattern in
            partial.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
    }

    private static func tiltForumsAPIURL(from url: URL) -> URL {
        if url.absoluteString.localizedCaseInsensitiveContains("/posts/"),
           url.path.lowercased().hasSuffix(".json") {
            return url
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if !components!.path.lowercased().hasSuffix(".json") {
            components!.path += ".json"
        }
        components!.query = nil
        return components!.url ?? url
    }

    private static func tiltForumsCanonicalURL(from post: TiltForumsTopicResponse.Post) -> URL? {
        guard let slug = post.topicSlug,
              let id = post.topicID else {
            return nil
        }
        return URL(string: "https://tiltforums.com/t/\(slug)/\(id)")
    }

    private static func tiltForumsCanonicalURL(from post: TiltForumsPostResponse) -> URL? {
        guard let slug = post.topicSlug,
              let id = post.topicID else {
            return nil
        }
        return URL(string: "https://tiltforums.com/t/\(slug)/\(id)")
    }

    private static func parseTiltForumsPayload(
        _ data: Data,
        fallbackURL: URL
    ) throws -> (cooked: String, canonicalURL: URL, updatedAt: String?) {
        if let topic = try? JSONDecoder().decode(TiltForumsTopicResponse.self, from: data),
           let post = topic.postStream?.posts.first,
           let cooked = post.cooked?.trimmingCharacters(in: .whitespacesAndNewlines),
           !cooked.isEmpty {
            return (
                cooked,
                tiltForumsCanonicalURL(from: post) ?? canonicalTopicURL(from: fallbackURL),
                post.updatedAt
            )
        }

        let post = try JSONDecoder().decode(TiltForumsPostResponse.self, from: data)
        guard let cooked = post.cooked?.trimmingCharacters(in: .whitespacesAndNewlines),
              !cooked.isEmpty else {
            throw URLError(.cannotDecodeContentData)
        }
        return (
            cooked,
            tiltForumsCanonicalURL(from: post) ?? canonicalTopicURL(from: fallbackURL),
            post.updatedAt
        )
    }

    private static func canonicalTopicURL(from url: URL) -> URL {
        if url.path.lowercased().hasSuffix(".json") {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.query = nil
            let currentPath = components?.path ?? url.path
            components?.path = currentPath.replacingOccurrences(of: ".json", with: "")
            return components?.url ?? url
        }
        return url
    }

    private static func attributionHTML(
        source: RulesheetRemoteSource,
        displayURL: URL,
        updatedAt: String?
    ) -> String {
        let updatedText: String
        if let updatedAt, !updatedAt.isEmpty {
            updatedText = " | Updated: \(updatedAt.htmlEscaped)"
        } else {
            updatedText = ""
        }

        return """
        <small class="rulesheet-attribution">Source: \(source.provider.sourceName.htmlEscaped) | \(source.provider.originalLinkLabel.htmlEscaped): <a href="\(displayURL.absoluteString.htmlEscaped)">link</a>\(updatedText) | \(source.provider.detailsText.htmlEscaped) | Reformatted for readability and mobile use.</small>
        """
    }
}

extension PinballGame.ReferenceLink {
    var embeddedRulesheetSource: RulesheetRemoteSource? {
        guard let destinationURL else { return nil }
        guard let provider = RulesheetRemoteSource.Provider(url: destinationURL, label: label) else {
            return nil
        }
        return RulesheetRemoteSource(label: label, url: destinationURL, provider: provider)
    }
}

extension PinballGame {
    var preferredExternalRulesheetSource: RulesheetRemoteSource? {
        rulesheetLinks.compactMap(\.embeddedRulesheetSource).first
    }
}

private extension RulesheetRemoteSource.Provider {
    init?(url: URL, label: String) {
        let host = url.host?.lowercased() ?? ""
        let normalizedLabel = label.lowercased()

        if host.contains("pinballnews.com") {
            return nil
        }
        if host.contains("tiltforums.com") {
            self = .tiltForums
            return
        }
        if host.contains("pinballprimer.github.io") || host.contains("pinballprimer.com") {
            self = .pinballPrimer
            return
        }
        if host.contains("pinball.org") {
            self = .papa
            return
        }
        if host.contains("flippers.be") || host.contains("bobs") || host.contains("silverballmania.com") {
            self = .bob
            return
        }
        if normalizedLabel.contains("(tf)") {
            self = .tiltForums
            return
        }
        if normalizedLabel.contains("(pp)") {
            self = .pinballPrimer
            return
        }
        if normalizedLabel.contains("(papa)") {
            self = .papa
            return
        }
        if normalizedLabel.contains("(bob)") {
            self = .bob
            return
        }
        return nil
    }
}

actor RemoteRulesheetCache {
    private let fileManager = FileManager.default
    private let freshnessInterval: TimeInterval = 12 * 60 * 60

    fileprivate func loadFresh(url: URL) throws -> RemoteFetchedDocument? {
        guard let cached = try loadRaw(url: url) else { return nil }
        guard Date().timeIntervalSince1970 - cached.fetchedAt <= freshnessInterval else { return nil }
        return makeDocument(from: cached)
    }

    fileprivate func loadAny(url: URL) throws -> RemoteFetchedDocument? {
        guard let cached = try loadRaw(url: url) else { return nil }
        return makeDocument(from: cached)
    }

    fileprivate func save(_ document: RemoteFetchedDocument, for url: URL) throws {
        let cached = RemoteCachedDocument(
            text: document.text,
            mimeType: document.mimeType,
            finalURL: document.finalURL.absoluteString,
            fetchedAt: Date().timeIntervalSince1970
        )
        let data = try serialize(cached)
        let targetURL = try cacheFileURL(for: url)
        try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: targetURL, options: .atomic)
    }

    private func loadRaw(url: URL) throws -> RemoteCachedDocument? {
        let targetURL = try cacheFileURL(for: url)
        guard fileManager.fileExists(atPath: targetURL.path) else { return nil }
        let data = try Data(contentsOf: targetURL)
        return try deserialize(data)
    }

    private func makeDocument(from cached: RemoteCachedDocument) -> RemoteFetchedDocument? {
        guard let finalURL = URL(string: cached.finalURL) else { return nil }
        return RemoteFetchedDocument(text: cached.text, mimeType: cached.mimeType, finalURL: finalURL)
    }

    private func cacheFileURL(for url: URL) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let key = Insecure.SHA1.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return base
            .appendingPathComponent("remote-rulesheet-cache-v1", isDirectory: true)
            .appendingPathComponent("\(key).json")
    }

    private func serialize(_ cached: RemoteCachedDocument) throws -> Data {
        let jsonObject: [String: Any?] = [
            "text": cached.text,
            "mime_type": cached.mimeType,
            "final_url": cached.finalURL,
            "fetched_at": cached.fetchedAt,
        ]
        let compact = jsonObject.reduce(into: [String: Any]()) { result, item in
            if let value = item.value {
                result[item.key] = value
            }
        }
        return try JSONSerialization.data(withJSONObject: compact, options: [.prettyPrinted])
    }

    private func deserialize(_ data: Data) throws -> RemoteCachedDocument {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String,
              let finalURL = json["final_url"] as? String,
              let fetchedAt = json["fetched_at"] as? Double else {
            throw URLError(.cannotDecodeRawData)
        }
        return RemoteCachedDocument(
            text: text,
            mimeType: json["mime_type"] as? String,
            finalURL: finalURL,
            fetchedAt: fetchedAt
        )
    }
}

private extension String {
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    func firstCapture(for pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: self) else {
            return nil
        }
        return String(self[captureRange])
    }
}
