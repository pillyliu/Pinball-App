import SwiftUI
import UIKit
import WebKit
import CryptoKit

struct RulesheetScreen: View {
    let slug: String
    let gameName: String
    @StateObject private var viewModel: RulesheetScreenModel
    @State private var scrollProgress: CGFloat = 0
    @State private var savedProgress: CGFloat?
    @State private var sessionSavedProgress: CGFloat?
    @State private var showResumePrompt = false
    @State private var resumeTarget: CGFloat?
    @State private var resumeRequestID: Int = 0
    @State private var didEvaluateResumePrompt = false
    @State private var pillPulsePhase = false
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
        _viewModel = StateObject(
            wrappedValue: RulesheetScreenModel(
                pathCandidates: pathCandidates ?? ["/pinball/rulesheets/\(slug).md"],
                externalSource: externalSource
            )
        )
    }

    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height >= geo.size.width
            let topInset = max(geo.safeAreaInsets.top, 44)
            let anchorScrollInset = topInset + 12
            let landscapeTopOffset: CGFloat = 17
            let backButtonTopPadding = isPortrait ? (topInset + 12) : landscapeTopOffset
            let fullscreenChromeRowHeight: CGFloat = 50
            let progressPillTopPadding = isPortrait ? backButtonTopPadding : landscapeTopOffset
            let rulesheetHorizontalPadding: CGFloat = 16
            let rulesheetMaxContentWidth: CGFloat = 44 * 16
            let availableBodyWidth = max(geo.size.width - (rulesheetHorizontalPadding * 2), 0)
            let renderedContentWidth = min(
                availableBodyWidth,
                rulesheetMaxContentWidth
            )
            let contentColumnTrailingInset =
                rulesheetHorizontalPadding + max((availableBodyWidth - renderedContentWidth) / 2, 0)

            ZStack {
                AppBackground()

                switch viewModel.status {
                case .idle, .loading:
                    AppFullscreenStatusOverlay(text: "Loading rulesheet…", showsProgress: true)
                case .missing:
                    AppFullscreenStatusOverlay(text: "Rulesheet not available.")
                case .error:
                    AppFullscreenStatusOverlay(text: "Could not load rulesheet.")
                case .loaded:
                    if let content = viewModel.content {
                        ZStack(alignment: .topTrailing) {
                            RulesheetRenderer(
                                content: content,
                                anchorScrollInset: anchorScrollInset,
                                resumeTarget: resumeTarget,
                                resumeRequestID: resumeRequestID,
                                onChromeToggle: {
                                    showsBackButton.toggle()
                                },
                                onProgressChange: { progress in
                                    scrollProgress = progress
                                }
                            )

                            Button {
                                saveCurrentProgress()
                            } label: {
                                AppReadingProgressPill(
                                    text: "\(currentProgressPercent)%",
                                    saved: isCurrentProgressSessionSaved,
                                    pulseOpacity: progressPillPulseOpacity
                                )
                                .background {
                                    Capsule()
                                        .fill(AppTheme.bg.opacity(progressPillBackdropOpacity))
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(height: isPortrait ? fullscreenChromeRowHeight : nil)
                            .padding(.top, progressPillTopPadding)
                            .padding(.trailing, contentColumnTrailingInset)
                        }
                    } else if let fallbackURL = viewModel.webFallbackURL {
                        RulesheetWebFallbackView(
                            url: fallbackURL,
                            anchorScrollInset: anchorScrollInset,
                            onChromeToggle: {
                                showsBackButton.toggle()
                            }
                        )
                    }
                }

                if isPortrait {
                    LinearGradient(
                        colors: [AppTheme.bg, AppTheme.bg.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: topInset + 44)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                }

                if showsBackButton {
                    VStack {
                        HStack {
                            AppFullscreenBackButton(
                                action: { dismiss() },
                                accessibilityLabel: "Back from \(gameName)"
                            )
                            Spacer()
                        }
                        .frame(height: isPortrait ? fullscreenChromeRowHeight : nil)
                        .padding(.top, backButtonTopPadding)
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
        .task {
            await viewModel.loadIfNeeded()
        }
        .onAppear {
            if savedProgress == nil {
                savedProgress = loadSavedProgress()
            }
            syncProgressPillPulse()
        }
        .onChange(of: viewModel.status) { _, newStatus in
            if newStatus == .loaded {
                syncProgressPillPulse()
            }
            guard newStatus == .loaded, !didEvaluateResumePrompt else { return }
            didEvaluateResumePrompt = true
            if let saved = savedProgress, saved > 0.001 {
                showResumePrompt = true
            }
        }
        .onChange(of: isCurrentProgressSessionSaved) { _, _ in
            syncProgressPillPulse()
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

    private var isCurrentProgressSessionSaved: Bool {
        guard let sessionSavedProgress else { return false }
        return abs(scrollProgress - sessionSavedProgress) <= 0.0015
    }

    private var progressPillPulseOpacity: Double {
        isCurrentProgressSessionSaved ? 1.0 : (pillPulsePhase ? 0.52 : 1.0)
    }

    private var progressPillBackdropOpacity: Double {
        isCurrentProgressSessionSaved ? 0.62 : 0.76
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
        sessionSavedProgress = clamped
    }

    private func syncProgressPillPulse() {
        if isCurrentProgressSessionSaved {
            pillPulsePhase = false
            return
        }

        pillPulsePhase = false
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pillPulsePhase = true
            }
        }
    }
}

private final class RulesheetTrackingWebView: WKWebView {
    var onLayoutSubviews: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutSubviews?()
    }
}

private struct RulesheetRenderer: UIViewRepresentable {
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
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController = WKUserContentController()
        configuration.userContentController.add(context.coordinator, name: RulesheetWebChromeBridge.chromeTapMessageName)
        configuration.userContentController.add(context.coordinator, name: RulesheetWebChromeBridge.fragmentScrollMessageName)
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: RulesheetWebChromeBridge.userScriptSource(initialAnchorScrollInset: anchorScrollInset),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )

        let webView = RulesheetTrackingWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
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
            Self.html(for: content),
            baseURL: content.baseURL ?? URL(string: "https://pillyliu.com")
        )
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: RulesheetWebChromeBridge.chromeTapMessageName)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: RulesheetWebChromeBridge.fragmentScrollMessageName)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, UIScrollViewDelegate, WKScriptMessageHandler {
        private struct ViewportLayoutSnapshot: Decodable {
            let viewWidth: Double
            let viewHeight: Double
            let contentHeight: Double
            let scrollY: Double
        }

        private struct NativeViewportLayoutSnapshot {
            let webViewSize: CGSize
            let scrollViewSize: CGSize
            let contentHeight: CGFloat
            let contentOffsetY: CGFloat
        }

        private struct CombinedViewportLayoutSnapshot {
            let dom: ViewportLayoutSnapshot
            let native: NativeViewportLayoutSnapshot
        }

        var lastContent: RulesheetRenderContent?
        weak var webView: WKWebView?
        var anchorScrollInset: CGFloat
        var onChromeToggle: () -> Void
        var onProgressChange: (CGFloat) -> Void
        private var didLoadPage = false
        private var lastHandledResumeRequestID: Int = -1
        private var pendingResumeRatio: CGFloat?
        private var pendingResumeRequestID: Int?
        private var lastKnownViewSize: CGSize = .zero
        private var lastKnownAnchorScrollInset: CGFloat?
        private var lastViewportAnchorJSON: String?
        private var frozenViewportAnchorJSON: String?
        private var isApplyingViewportAnchor = false
        private var isAwaitingViewportRestore = false
        private var pendingRestoreNeedsFreshLayout = false
        private var viewportRestoreGeneration = 0
        private var viewportRestoreRetryCount = 0
        private var stableViewportLayoutSampleCount = 0
        private var lastViewportLayoutSnapshot: CombinedViewportLayoutSnapshot?
        private var lastStableViewportLayoutSnapshot: CombinedViewportLayoutSnapshot?
        private var pendingViewportAnchorCapture: DispatchWorkItem?
        private var pendingViewportRestoreWorkItem: DispatchWorkItem?
        private var viewportRestoreBaselineLayoutSnapshot: CombinedViewportLayoutSnapshot?
        private let animatedFragmentReleaseDelay: TimeInterval = 0.4
        private let animatedFragmentCaptureDelay: TimeInterval = 0.48
        private let animatedResumeReleaseDelay: TimeInterval = 0.38
        private let animatedResumeCaptureDelay: TimeInterval = 0.46

        init(
            anchorScrollInset: CGFloat,
            onChromeToggle: @escaping () -> Void,
            onProgressChange: @escaping (CGFloat) -> Void
        ) {
            self.anchorScrollInset = anchorScrollInset
            self.onChromeToggle = onChromeToggle
            self.onProgressChange = onProgressChange
        }

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

        private func applyPendingResumeIfPossible(in webView: WKWebView) {
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

        private func canApplyRatio(in webView: WKWebView) -> Bool {
            let scrollView = webView.scrollView
            return scrollView.contentSize.height > scrollView.bounds.height + 1
        }

        private func currentScrollRatio(in webView: WKWebView) -> CGFloat {
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

        private func scrollToFragment(_ fragment: String?, in webView: WKWebView, animated: Bool = true) {
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

        private func isSameDocumentLink(_ destination: URL, currentURL: URL?) -> Bool {
            guard let currentURL else { return destination.fragment != nil }

            guard destination.fragment != nil else { return false }
            var lhs = URLComponents(url: destination, resolvingAgainstBaseURL: false)
            var rhs = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)
            lhs?.fragment = nil
            rhs?.fragment = nil
            return lhs?.url == rhs?.url
        }

        private func beginViewportRestore(in webView: WKWebView) {
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

        private func scheduleViewportAnchorCapture(in webView: WKWebView, delay: TimeInterval = 0.16) {
            guard didLoadPage else { return }
            guard !isAwaitingViewportRestore else { return }

            pendingViewportAnchorCapture?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.captureViewportLayoutSnapshot(in: webView) { [weak self, weak webView] snapshot in
                    guard let self, let webView else { return }
                    guard let snapshot, self.viewportLayoutIsCoherent(snapshot) else { return }
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

        private func captureViewportAnchor(
            in webView: WKWebView,
            completion: @escaping (String?) -> Void
        ) {
            let script = RulesheetWebChromeBridge.captureViewportAnchorScript()
            webView.evaluateJavaScript(script) { result, _ in
                completion(result as? String)
            }
        }

        private func scheduleViewportRestore(in webView: WKWebView, delay: TimeInterval = 0.12) {
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

                    guard self.viewportLayoutIsCoherent(snapshot) else {
                        self.retryViewportRestoreIfNeeded(in: webView, generation: generation)
                        return
                    }

                    let viewportStateChanged = self.viewportRestoreStateChanged(
                        baseline: baselineSnapshot,
                        current: snapshot
                    )

                    guard viewportStateChanged else {
                        guard self.viewportRestoreRetryCount < 12 else {
                            self.isAwaitingViewportRestore = false
                            self.pendingRestoreNeedsFreshLayout = false
                            self.pendingViewportRestoreWorkItem?.cancel()
                            self.pendingViewportRestoreWorkItem = nil
                            self.viewportRestoreRetryCount = 0
                            self.stableViewportLayoutSampleCount = 0
                            self.lastViewportLayoutSnapshot = nil
                            self.viewportRestoreBaselineLayoutSnapshot = nil
                            self.frozenViewportAnchorJSON = nil
                            self.releaseViewportAnchorApplication(in: webView, delay: 0.01)
                            self.scheduleViewportAnchorCapture(in: webView, delay: 0.08)
                            return
                        }
                        self.retryViewportRestoreIfNeeded(in: webView, generation: generation)
                        return
                    }

                    if let previousSnapshot = self.lastViewportLayoutSnapshot,
                       self.viewportLayoutIsStable(previous: previousSnapshot, current: snapshot) {
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
                            self.isAwaitingViewportRestore = false
                            self.pendingRestoreNeedsFreshLayout = false
                            self.pendingViewportRestoreWorkItem?.cancel()
                            self.pendingViewportRestoreWorkItem = nil
                            self.viewportRestoreRetryCount = 0
                            self.stableViewportLayoutSampleCount = 0
                            self.lastViewportLayoutSnapshot = nil
                            self.viewportRestoreBaselineLayoutSnapshot = nil
                            self.frozenViewportAnchorJSON = nil
                            self.onProgressChange(self.currentScrollRatio(in: webView))
                            self.releaseViewportAnchorApplication(in: webView, delay: 0.18)
                            self.scheduleViewportAnchorCapture(in: webView, delay: 0.24)
                        } else {
                            self.retryViewportRestoreIfNeeded(in: webView, generation: generation)
                        }
                    }
                }
            }

            pendingViewportRestoreWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        private func retryViewportRestoreIfNeeded(in webView: WKWebView?, generation: Int) {
            guard let webView else { return }
            guard isAwaitingViewportRestore else { return }
            guard viewportRestoreGeneration == generation else { return }
            guard viewportRestoreRetryCount < 12 else { return }

            viewportRestoreRetryCount += 1
            scheduleViewportRestore(in: webView)
        }

        private func captureViewportLayoutSnapshot(
            in webView: WKWebView,
            completion: @escaping (CombinedViewportLayoutSnapshot?) -> Void
        ) {
            let script = RulesheetWebChromeBridge.captureViewportLayoutSnapshotScript()
            webView.evaluateJavaScript(script) { [weak self, weak webView] result, _ in
                guard let self, let webView else {
                    completion(nil)
                    return
                }
                guard let json = result as? String,
                      let data = json.data(using: .utf8),
                      let domSnapshot = try? JSONDecoder().decode(ViewportLayoutSnapshot.self, from: data) else {
                    completion(nil)
                    return
                }

                completion(
                    CombinedViewportLayoutSnapshot(
                        dom: domSnapshot,
                        native: self.nativeViewportLayoutSnapshot(in: webView)
                    )
                )
            }
        }

        private func restoreViewportAnchorIfPossible(
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

        private func viewportLayoutIsStable(
            previous: CombinedViewportLayoutSnapshot,
            current: CombinedViewportLayoutSnapshot
        ) -> Bool {
            abs(previous.dom.viewWidth - current.dom.viewWidth) <= 1 &&
            abs(previous.dom.viewHeight - current.dom.viewHeight) <= 1 &&
            abs(previous.dom.contentHeight - current.dom.contentHeight) <= 1 &&
            abs(previous.dom.scrollY - current.dom.scrollY) <= 1 &&
            abs(previous.native.webViewSize.width - current.native.webViewSize.width) <= 1 &&
            abs(previous.native.webViewSize.height - current.native.webViewSize.height) <= 1 &&
            abs(previous.native.scrollViewSize.width - current.native.scrollViewSize.width) <= 1 &&
            abs(previous.native.scrollViewSize.height - current.native.scrollViewSize.height) <= 1 &&
            abs(previous.native.contentHeight - current.native.contentHeight) <= 1 &&
            abs(previous.native.contentOffsetY - current.native.contentOffsetY) <= 1
        }

        private func viewportLayoutIsCoherent(_ snapshot: CombinedViewportLayoutSnapshot) -> Bool {
            abs(snapshot.dom.viewWidth - snapshot.native.webViewSize.width) <= 2 &&
            abs(snapshot.dom.viewHeight - snapshot.native.webViewSize.height) <= 2 &&
            abs(snapshot.dom.viewWidth - snapshot.native.scrollViewSize.width) <= 2 &&
            abs(snapshot.dom.viewHeight - snapshot.native.scrollViewSize.height) <= 2 &&
            abs(snapshot.dom.contentHeight - snapshot.native.contentHeight) <= 24 &&
            abs(snapshot.dom.scrollY - snapshot.native.contentOffsetY) <= 24
        }

        private func viewportRestoreStateChanged(
            baseline: CombinedViewportLayoutSnapshot,
            current: CombinedViewportLayoutSnapshot
        ) -> Bool {
            abs(baseline.dom.viewWidth - current.dom.viewWidth) > 1 ||
            abs(baseline.dom.viewHeight - current.dom.viewHeight) > 1 ||
            abs(baseline.dom.contentHeight - current.dom.contentHeight) > 1 ||
            abs(baseline.dom.scrollY - current.dom.scrollY) > 24 ||
            abs(baseline.native.contentOffsetY - current.native.contentOffsetY) > 24
        }

        private func nativeViewportLayoutSnapshot(in webView: WKWebView) -> NativeViewportLayoutSnapshot {
            NativeViewportLayoutSnapshot(
                webViewSize: webView.bounds.size,
                scrollViewSize: webView.scrollView.bounds.size,
                contentHeight: webView.scrollView.contentSize.height,
                contentOffsetY: webView.scrollView.contentOffset.y
            )
        }

        private func releaseViewportAnchorApplication(in webView: WKWebView, delay: TimeInterval = 0.12) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.isApplyingViewportAnchor = false
                self.onProgressChange(self.currentScrollRatio(in: webView))
            }
        }

    }
}

private struct RulesheetWebFallbackView: UIViewRepresentable {
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
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController = WKUserContentController()
        configuration.userContentController.add(context.coordinator, name: RulesheetWebChromeBridge.chromeTapMessageName)
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: RulesheetWebChromeBridge.userScriptSource(initialAnchorScrollInset: anchorScrollInset),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
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
              --text: #162035;
              --text-muted: #556270;
              --link: #0a65cc;
              --link-soft: rgba(10, 101, 204, 0.14);
              --panel: rgba(255, 255, 255, 0.72);
              --panel-strong: rgba(255, 255, 255, 0.9);
              --code-bg: #eef2f7;
              --code-text: #162035;
              --rule: rgba(22, 32, 53, 0.14);
              --table-border: rgba(22, 32, 53, 0.14);
              --blockquote-bar: rgba(10, 101, 204, 0.42);
            }
            @media (prefers-color-scheme: dark) {
              :root {
                --text: #e7efff;
                --text-muted: #aebcd2;
                --link: #a6c8ff;
                --link-soft: rgba(166, 200, 255, 0.16);
                --panel: rgba(16, 22, 34, 0.72);
                --panel-strong: rgba(18, 25, 39, 0.9);
                --code-bg: #111824;
                --code-text: #f3f7ff;
                --rule: rgba(231, 239, 255, 0.12);
                --table-border: rgba(231, 239, 255, 0.12);
                --blockquote-bar: rgba(166, 200, 255, 0.5);
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
              line-height: 1.5;
              box-sizing: border-box;
            }
            @media (orientation: landscape) {
              body {
                padding-top: 19px;
              }
            }
            #content {
              margin: 0 auto;
              max-width: 44rem;
              overflow-x: hidden;
              overflow-wrap: anywhere;
              word-break: normal;
            }
            #content > :first-child { margin-top: 0 !important; }
            #content > :last-child { margin-bottom: 0 !important; }
            p, ul, ol, blockquote, pre, table, hr {
              margin: 0 0 0.95rem;
            }
            a {
              color: var(--link);
              text-decoration: underline;
              text-decoration-thickness: 0.08em;
              text-underline-offset: 0.14em;
              overflow-wrap: anywhere;
              word-break: break-word;
            }
            a:hover {
              background: var(--link-soft);
            }
            h1, h2, h3, h4, h5, h6 {
              color: var(--text);
              line-height: 1.2;
              margin: 1.35rem 0 0.55rem;
              scroll-margin-top: 88px;
            }
            h1 { font-size: 1.8rem; letter-spacing: -0.02em; }
            h2 {
              font-size: 1.35rem;
              letter-spacing: -0.015em;
              padding-bottom: 0.2rem;
              border-bottom: 1px solid var(--rule);
            }
            h3 { font-size: 1.08rem; }
            h4, h5, h6 { font-size: 0.98rem; }
            strong { color: var(--text); }
            small, .bodySmall, .rulesheet-attribution {
              color: var(--text-muted);
            }
            ul, ol {
              padding-left: 1.35rem;
            }
            li {
              margin: 0.18rem 0;
            }
            li > ul, li > ol {
              margin-top: 0.28rem;
              margin-bottom: 0.28rem;
            }
            blockquote {
              margin-left: 0;
              padding: 0.15rem 0 0.15rem 0.95rem;
              border-left: 3px solid var(--blockquote-bar);
              color: var(--text-muted);
              background: transparent;
            }
            code, pre {
              background: var(--code-bg);
              border-radius: 10px;
              color: var(--code-text);
            }
            code {
              padding: 0.12rem 0.34rem;
              overflow-wrap: anywhere;
              word-break: break-word;
            }
            pre {
              padding: 12px 14px;
              overflow-x: auto;
              border: 1px solid var(--rule);
            }
            pre code {
              padding: 0;
              background: transparent;
              border-radius: 0;
            }
            .table-scroll {
              overflow-x: auto;
              overflow-y: visible;
              -webkit-overflow-scrolling: touch;
              margin: 0 0 1rem;
              padding-bottom: 0.1rem;
              border: 1px solid var(--table-border);
              border-radius: 12px;
              background: var(--panel);
            }
            table {
              border-collapse: separate;
              border-spacing: 0;
              width: 100%;
              table-layout: auto;
            }
            th, td {
              border-right: 1px solid var(--table-border);
              border-bottom: 1px solid var(--table-border);
              padding: 8px 10px;
              vertical-align: top;
              word-break: normal;
              overflow-wrap: normal;
              white-space: normal;
            }
            tr > :last-child {
              border-right: none;
            }
            tbody tr:last-child td,
            table tr:last-child td {
              border-bottom: none;
            }
            th {
              background: var(--panel-strong);
              text-align: left;
            }
            thead tr:first-child th:first-child,
            table tr:first-child > *:first-child {
              border-top-left-radius: 12px;
            }
            thead tr:first-child th:last-child,
            table tr:first-child > *:last-child {
              border-top-right-radius: 12px;
            }
            tbody tr:last-child td:first-child,
            table tr:last-child td:first-child {
              border-bottom-left-radius: 12px;
            }
            tbody tr:last-child td:last-child,
            table tr:last-child td:last-child {
              border-bottom-right-radius: 12px;
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
            img {
              display: block;
              max-width: 100%;
              height: auto;
              margin: 0.5rem auto;
              border-radius: 10px;
            }
            table img,
            .table-scroll img {
              width: auto;
              max-height: min(42vh, 24rem);
              object-fit: contain;
            }
            hr { border: none; border-top: 1px solid var(--rule); }
            .pinball-rulesheet, .remote-rulesheet { display: block; }
            .legacy-rulesheet .bodyTitle {
              display: block;
              font-size: 1.08rem;
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
              opacity: 0.92;
              margin-bottom: 0.8rem;
            }
            .rulesheet-attribution, .rulesheet-attribution * {
              overflow-wrap: anywhere;
              word-break: break-word;
            }
            @media (min-width: 820px) {
              body {
                padding-left: 24px;
                padding-right: 24px;
              }
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

private enum RulesheetWebChromeBridge {
    static let chromeTapMessageName = "rulesheetChromeTap"
    static let fragmentScrollMessageName = "rulesheetFragmentScroll"

    static func userScriptSource(initialAnchorScrollInset: CGFloat) -> String {
        """
        (function() {
          function postChromeTap() {
            const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(chromeTapMessageName);
            if (handler) handler.postMessage(null);
          }

          function postFragmentScroll(hash) {
            const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(fragmentScrollMessageName);
            if (!handler) return false;
            handler.postMessage(hash);
            return true;
          }

          function setAnchorOffset(value) {
            const parsed = Number(value);
            window.__pinballAnchorScrollInset = Number.isFinite(parsed) ? parsed : 0;
          }

          function candidateFragments(raw) {
            const values = [];
            if (!raw) return values;
            values.push(raw);
            try {
              const decoded = decodeURIComponent(raw);
              if (!values.includes(decoded)) values.unshift(decoded);
            } catch (_) {}
            return values;
          }

          function resolveTarget(hash) {
            const trimmed = (hash || '').replace(/^#/, '');
            for (const candidate of candidateFragments(trimmed)) {
              const byId = document.getElementById(candidate);
              if (byId) return byId;
              const byName = document.getElementsByName(candidate);
              if (byName && byName.length > 0) return byName[0];
            }
            return null;
          }

          function scrollToHash(hash, behavior) {
            const target = resolveTarget(hash);
            if (!target) return false;
            const fragmentScrollInset = window.matchMedia('(orientation: landscape)').matches
              ? 18
              : ((window.__pinballAnchorScrollInset || 0) + 14);
            const top = Math.max(
              target.getBoundingClientRect().top + window.scrollY - fragmentScrollInset,
              0
            );
            const scrollBehavior = behavior === 'smooth' ? 'smooth' : 'auto';
            window.scrollTo({ top: top, behavior: scrollBehavior });
            if (hash && window.history && window.history.replaceState) {
              window.history.replaceState(null, '', hash);
            }
            return true;
          }

          function blockAnchor() {
            const selectors = [
              'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
              'p', 'li', 'blockquote', 'pre',
              'td', 'th', 'dt', 'dd',
              '.bodyTitle', '.bodySmall'
            ].join(', ');
            const referenceY = (window.__pinballAnchorScrollInset || 0) + 24;
            const candidates = Array.from(document.querySelectorAll(selectors));
            let target = null;
            let bestDistance = Number.POSITIVE_INFINITY;

            for (const candidate of candidates) {
              const rect = candidate.getBoundingClientRect();
              if (!rect || rect.height < 1) continue;
              const distance = rect.top <= referenceY && rect.bottom >= referenceY
                ? 0
                : Math.min(Math.abs(rect.top - referenceY), Math.abs(rect.bottom - referenceY));
              if (distance < bestDistance) {
                target = candidate;
                bestDistance = distance;
                if (distance === 0) break;
              }
            }

            if (!target) {
              target = document.getElementById('content') || document.body;
            }
            if (!target) return null;

            const rect = target.getBoundingClientRect();
            const height = Math.max(rect.height, 1);
            const path = [];
            let current = target;
            while (current && current !== document.body) {
              const parent = current.parentElement;
              if (!parent) return null;
              path.unshift(Array.prototype.indexOf.call(parent.children, current));
              current = parent;
            }

            return {
              path: path,
              offsetRatio: Math.min(Math.max((referenceY - rect.top) / height, 0), 1)
            };
          }

          function clampReferenceY() {
            return Math.min(
              Math.max((window.__pinballAnchorScrollInset || 0) + 24, 0),
              Math.max(window.innerHeight - 1, 0)
            );
          }

          function candidateReferenceXs() {
            const raw = [
              window.innerWidth * 0.5,
              window.innerWidth * 0.42,
              window.innerWidth * 0.58
            ];
            return raw.map(function(value) {
              return Math.min(Math.max(value, 1), Math.max(window.innerWidth - 1, 1));
            });
          }

          function caretRangeAtPoint(x, y) {
            if (document.caretPositionFromPoint) {
              const position = document.caretPositionFromPoint(x, y);
              if (!position || !position.offsetNode) return null;
              const range = document.createRange();
              range.setStart(position.offsetNode, position.offset || 0);
              range.collapse(true);
              return range;
            }

            if (document.caretRangeFromPoint) {
              const range = document.caretRangeFromPoint(x, y);
              if (!range) return null;
              return range.cloneRange();
            }

            return null;
          }

          function nodePath(node) {
            const path = [];
            let current = node;
            while (current && current !== document.body) {
              const parent = current.parentNode;
              if (!parent || !parent.childNodes) return null;
              path.unshift(Array.prototype.indexOf.call(parent.childNodes, current));
              current = parent;
            }
            return path;
          }

          function resolveNodePath(path) {
            if (!Array.isArray(path)) return null;
            let current = document.body;
            for (const rawIndex of path) {
              const index = Number(rawIndex);
              if (!current || !current.childNodes || !Number.isInteger(index) || index < 0 || index >= current.childNodes.length) {
                return null;
              }
              current = current.childNodes[index];
            }
            return current;
          }

          function normalizedTextSnippet(text) {
            return String(text || '').replace(/\\s+/g, ' ').trim().slice(0, 120);
          }

          function rangeContext(range) {
            if (!range) return { before: '', after: '' };
            try {
              const source = range.startContainer && range.startContainer.nodeType === Node.TEXT_NODE
                ? range.startContainer.textContent || ''
                : range.startContainer && range.startContainer.textContent
                  ? range.startContainer.textContent
                  : '';
              const offset = Math.max(Number(range.startOffset) || 0, 0);
              return {
                before: normalizedTextSnippet(source.slice(Math.max(0, offset - 24), offset)),
                after: normalizedTextSnippet(source.slice(offset, offset + 24))
              };
            } catch (_) {
              return { before: '', after: '' };
            }
          }

          function measurableRangeRect(range) {
            if (!range) return null;
            const directRect = range.getBoundingClientRect();
            if (directRect && (directRect.height > 0 || directRect.width > 0)) return directRect;

            const expanded = range.cloneRange();
            const container = expanded.startContainer;
            const offset = expanded.startOffset;

            if (container && container.nodeType === Node.TEXT_NODE) {
              const textLength = (container.textContent || '').length;
              if (offset < textLength) {
                expanded.setEnd(container, Math.min(offset + 1, textLength));
              } else if (offset > 0) {
                expanded.setStart(container, Math.max(offset - 1, 0));
              }
            } else if (container && container.childNodes && container.childNodes.length > 0) {
              const childIndex = Math.min(offset, container.childNodes.length - 1);
              const child = container.childNodes[childIndex];
              if (child) {
                expanded.selectNode(child);
              }
            }

            const fallbackRect = expanded.getBoundingClientRect();
            if (fallbackRect && (fallbackRect.height > 0 || fallbackRect.width > 0)) return fallbackRect;
            const rects = expanded.getClientRects();
            return rects && rects.length > 0 ? rects[0] : null;
          }

          function textBookmark() {
            const referenceY = clampReferenceY();
            for (const x of candidateReferenceXs()) {
              const range = caretRangeAtPoint(x, referenceY);
              if (!range) continue;

              const path = nodePath(range.startContainer);
              if (!path) continue;

              const block = blockAnchor();
              const context = rangeContext(range);
              const rect = measurableRangeRect(range);
              if (!rect) continue;
              if (Math.abs((rect.top + window.scrollY) - (window.scrollY + referenceY)) > 36) continue;
              if (Math.abs((rect.left + (rect.width / 2)) - x) > Math.max(window.innerWidth * 0.2, 64)) continue;
              const liveToken = (window.__pinballViewportBookmarkToken || 0) + 1;

              window.__pinballViewportBookmarkToken = liveToken;
              window.__pinballViewportBookmarkRange = range.cloneRange();

              return {
                kind: 'text',
                liveToken: liveToken,
                nodePath: path,
                offset: Number(range.startOffset) || 0,
                contextBefore: context.before,
                contextAfter: context.after,
                blockAnchor: block,
                referenceY: referenceY,
                measuredTop: rect.top + window.scrollY
              };
            }

            return null;
          }

          function restoreBlockAnchor(anchor) {
            if (!anchor || !Array.isArray(anchor.path)) return false;

            let target = document.body;
            for (const rawIndex of anchor.path) {
              const index = Number(rawIndex);
              if (!target || !target.children || !Number.isInteger(index) || index < 0 || index >= target.children.length) {
                return false;
              }
              target = target.children[index];
            }
            if (!target) return false;

            const rect = target.getBoundingClientRect();
            const height = Math.max(rect.height, 1);
            const offsetRatio = Math.min(Math.max(Number(anchor.offsetRatio) || 0, 0), 1);
            const referenceY = (window.__pinballAnchorScrollInset || 0) + 24;
            const top = Math.max(rect.top + window.scrollY + (offsetRatio * height) - referenceY, 0);
            window.scrollTo({ top: top, behavior: 'auto' });
            return true;
          }

          function restoreTextBookmark(payload) {
            let range = null;
            if (payload && payload.liveToken && window.__pinballViewportBookmarkToken === payload.liveToken && window.__pinballViewportBookmarkRange) {
              range = window.__pinballViewportBookmarkRange.cloneRange();
            }

            if (!range && payload && Array.isArray(payload.nodePath)) {
              const node = resolveNodePath(payload.nodePath);
              if (node) {
                const maxOffset = node.nodeType === Node.TEXT_NODE
                  ? (node.textContent || '').length
                  : (node.childNodes ? node.childNodes.length : 0);
                const offset = Math.min(Math.max(Number(payload.offset) || 0, 0), Math.max(maxOffset, 0));
                range = document.createRange();
                range.setStart(node, offset);
                range.collapse(true);
              }
            }

            if (!range) {
              return payload && payload.blockAnchor ? restoreBlockAnchor(payload.blockAnchor) : false;
            }

            const rect = measurableRangeRect(range);
            if (!rect) {
              return payload && payload.blockAnchor ? restoreBlockAnchor(payload.blockAnchor) : false;
            }

            const referenceY = (window.__pinballAnchorScrollInset || 0) + 24;
            const top = Math.max(rect.top + window.scrollY - referenceY, 0);
            window.scrollTo({ top: top, behavior: 'auto' });
            window.__pinballViewportBookmarkRange = range.cloneRange();
            return true;
          }

          function captureViewportLayoutSnapshot() {
            const selectors = [
              'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
              'p', 'li', 'blockquote', 'pre',
              'td', 'th', 'dt', 'dd',
              '.bodyTitle', '.bodySmall'
            ].join(', ');
            const referenceY = clampReferenceY();
            const referenceX = Math.min(
              Math.max(window.innerWidth / 2, 1),
              Math.max(window.innerWidth - 1, 1)
            );

            const stack = document.elementsFromPoint(referenceX, referenceY);
            let target = null;
            for (const candidate of stack) {
              if (candidate && candidate.matches && candidate.matches(selectors)) {
                target = candidate;
                break;
              }
              if (candidate && candidate.closest) {
                const ancestor = candidate.closest(selectors);
                if (ancestor) {
                  target = ancestor;
                  break;
                }
              }
            }

            if (!target) {
              const anchor = blockAnchor();
              if (anchor && Array.isArray(anchor.path)) {
                let current = document.body;
                for (const rawIndex of anchor.path) {
                  const index = Number(rawIndex);
                  if (!current || !current.children || index < 0 || index >= current.children.length) {
                    current = null;
                    break;
                  }
                  current = current.children[index];
                }
                if (current) target = current;
              }
            }

            if (!target) {
              target = document.getElementById('content') || document.body;
            }
            if (!target) return null;

            const rect = target.getBoundingClientRect();
            const height = Math.max(rect.height, 1);
            const path = [];
            let current = target;
            while (current && current !== document.body) {
              const parent = current.parentElement;
              if (!parent) break;
              path.unshift(Array.prototype.indexOf.call(parent.children, current));
              current = parent;
            }

            const text = (target.innerText || target.textContent || '')
              .replace(/\\s+/g, ' ')
              .trim()
              .slice(0, 120);

            return {
              tagName: (target.tagName || '').toLowerCase(),
              elementID: target.id || null,
              className: (target.className && String(target.className)) || null,
              textSnippet: text || null,
              domPath: path,
              viewportY: referenceY,
              documentY: window.scrollY + referenceY,
              scrollY: window.scrollY,
              viewWidth: window.innerWidth,
              viewHeight: window.innerHeight,
              contentHeight: Math.max(
                document.documentElement ? document.documentElement.scrollHeight : 0,
                document.body ? document.body.scrollHeight : 0
              ),
              maxScrollY: Math.max(
                Math.max(
                  document.documentElement ? document.documentElement.scrollHeight : 0,
                  document.body ? document.body.scrollHeight : 0
                ) - window.innerHeight,
                0
              ),
              scrollRatio: (function() {
                const contentHeight = Math.max(
                  document.documentElement ? document.documentElement.scrollHeight : 0,
                  document.body ? document.body.scrollHeight : 0
                );
                const maxScrollY = Math.max(contentHeight - window.innerHeight, 0);
                if (maxScrollY <= 0) return 0;
                return Math.min(Math.max(window.scrollY / maxScrollY, 0), 1);
              })(),
              elementTop: rect.top + window.scrollY,
              elementHeight: rect.height,
              offsetRatio: Math.min(Math.max((referenceY - rect.top) / height, 0), 1)
            };
          }

          window.__pinballSetAnchorScrollInset = setAnchorOffset;
          window.__pinballScrollToFragment = function(fragment, behavior) {
            const hash = fragment ? (String(fragment).charAt(0) === '#' ? String(fragment) : '#' + String(fragment)) : '';
            return scrollToHash(hash, behavior);
          };
          window.__pinballCaptureViewportLayoutSnapshot = captureViewportLayoutSnapshot;
          window.__pinballCaptureViewportAnchor = function() {
            const textAnchor = textBookmark();
            if (textAnchor) return JSON.stringify(textAnchor);
            const anchor = blockAnchor();
            return anchor ? JSON.stringify({ kind: 'block', blockAnchor: anchor }) : null;
          };
          window.__pinballRestoreViewportAnchor = function(anchor) {
            if (!anchor) return false;
            let payload = anchor;
            if (typeof payload === 'string') {
              try {
                payload = JSON.parse(payload);
              } catch (_) {
                return false;
              }
            }
            if (!payload) return false;
            if (payload.kind === 'text') return restoreTextBookmark(payload);
            if (payload.blockAnchor) return restoreBlockAnchor(payload.blockAnchor);
            return restoreBlockAnchor(payload);
          };
          setAnchorOffset(\(String(format: "%.2f", initialAnchorScrollInset)));

          document.addEventListener('click', function(event) {
            if (event.defaultPrevented) return;
            const target = event.target;
            const anchor = target && target.closest ? target.closest('a[href]') : null;
            if (!anchor) {
              postChromeTap();
              return;
            }

            let destination;
            let current;
            try {
              destination = new URL(anchor.href, window.location.href);
              current = new URL(window.location.href);
            } catch (_) {
              return;
            }

            const sameDocument = !!destination.hash &&
              destination.origin === current.origin &&
              destination.pathname === current.pathname &&
              destination.search === current.search;

            if (!sameDocument) return;

            event.preventDefault();
            if (postFragmentScroll(destination.hash)) return;
            scrollToHash(destination.hash, 'smooth');
          }, true);
        })();
        """
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

    static func clearCache() async throws {
        try await cache.clear()
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
    nonisolated var embeddedRulesheetSource: RulesheetRemoteSource? {
        guard let destinationURL else { return nil }
        guard let provider = RulesheetRemoteSource.Provider(url: destinationURL, label: label) else {
            return nil
        }
        return RulesheetRemoteSource(label: label, url: destinationURL, provider: provider)
    }
}

extension PinballGame {
    nonisolated var preferredExternalRulesheetSource: RulesheetRemoteSource? {
        orderedRulesheetLinks.compactMap(\.embeddedRulesheetSource).first
    }
}

private extension RulesheetRemoteSource.Provider {
    nonisolated init?(url: URL, label: String) {
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

    fileprivate func clear() throws {
        let cacheDirectoryURL = try self.cacheDirectoryURL()
        guard fileManager.fileExists(atPath: cacheDirectoryURL.path) else { return }
        try fileManager.removeItem(at: cacheDirectoryURL)
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
        let key = Insecure.SHA1.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return try cacheDirectoryURL()
            .appendingPathComponent("\(key).json")
    }

    private func cacheDirectoryURL() throws -> URL {
        try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("remote-rulesheet-cache-v1", isDirectory: true)
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
