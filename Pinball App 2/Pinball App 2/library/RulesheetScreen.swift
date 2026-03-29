import SwiftUI
import UIKit
import WebKit

struct RulesheetScreen: View {
    let gameID: String
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
        gameID: String,
        gameName: String? = nil,
        pathCandidates: [String]? = nil,
        externalSource: RulesheetRemoteSource? = nil
    ) {
        self.gameID = gameID
        self.gameName = gameName ?? gameID.replacingOccurrences(of: "-", with: " ").capitalized
        _viewModel = StateObject(
            wrappedValue: RulesheetScreenModel(
                pathCandidates: pathCandidates ?? ["/pinball/rulesheets/\(gameID).md"],
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

                RulesheetScreenContent(
                    status: viewModel.status,
                    content: viewModel.content,
                    fallbackURL: viewModel.webFallbackURL,
                    anchorScrollInset: anchorScrollInset,
                    resumeTarget: resumeTarget,
                    resumeRequestID: resumeRequestID,
                    currentProgressPercent: currentProgressPercent,
                    isCurrentProgressSessionSaved: isCurrentProgressSessionSaved,
                    progressPillPulseOpacity: progressPillPulseOpacity,
                    progressPillBackdropOpacity: progressPillBackdropOpacity,
                    progressPillTopPadding: progressPillTopPadding,
                    progressPillTrailingInset: contentColumnTrailingInset,
                    progressRowHeight: isPortrait ? fullscreenChromeRowHeight : nil,
                    onChromeToggle: { showsBackButton.toggle() },
                    onProgressChange: { progress in
                        scrollProgress = progress
                    },
                    onSaveProgress: saveCurrentProgress
                )

                RulesheetTopGradientOverlay(
                    isPortrait: isPortrait,
                    topInset: topInset
                )

                RulesheetBackButtonOverlay(
                    isVisible: showsBackButton,
                    isPortrait: isPortrait,
                    rowHeight: fullscreenChromeRowHeight,
                    topPadding: backButtonTopPadding,
                    gameName: gameName,
                    dismiss: dismiss.callAsFunction
                )
            }
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .appEdgeBackGesture()
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
        "rulesheet-last-progress-\(gameID)"
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

private struct RulesheetScreenContent: View {
    let status: LoadStatus
    let content: RulesheetRenderContent?
    let fallbackURL: URL?
    let anchorScrollInset: CGFloat
    let resumeTarget: CGFloat?
    let resumeRequestID: Int
    let currentProgressPercent: Int
    let isCurrentProgressSessionSaved: Bool
    let progressPillPulseOpacity: Double
    let progressPillBackdropOpacity: Double
    let progressPillTopPadding: CGFloat
    let progressPillTrailingInset: CGFloat
    let progressRowHeight: CGFloat?
    let onChromeToggle: () -> Void
    let onProgressChange: (CGFloat) -> Void
    let onSaveProgress: () -> Void

    var body: some View {
        switch status {
        case .idle, .loading:
            AppFullscreenStatusOverlay(text: "Loading rulesheet…", showsProgress: true)
        case .missing:
            AppFullscreenStatusOverlay(text: "Rulesheet not available.")
        case .error:
            AppFullscreenStatusOverlay(text: "Could not load rulesheet.")
        case .loaded:
            if let content {
                ZStack(alignment: .topTrailing) {
                    RulesheetRenderer(
                        content: content,
                        anchorScrollInset: anchorScrollInset,
                        resumeTarget: resumeTarget,
                        resumeRequestID: resumeRequestID,
                        onChromeToggle: onChromeToggle,
                        onProgressChange: onProgressChange
                    )

                    RulesheetProgressPillButton(
                        currentProgressPercent: currentProgressPercent,
                        isCurrentProgressSessionSaved: isCurrentProgressSessionSaved,
                        progressPillPulseOpacity: progressPillPulseOpacity,
                        progressPillBackdropOpacity: progressPillBackdropOpacity,
                        rowHeight: progressRowHeight,
                        topPadding: progressPillTopPadding,
                        trailingInset: progressPillTrailingInset,
                        onSaveProgress: onSaveProgress
                    )
                }
            } else if let fallbackURL {
                RulesheetWebFallbackView(
                    url: fallbackURL,
                    anchorScrollInset: anchorScrollInset,
                    onChromeToggle: onChromeToggle
                )
            }
        }
    }
}

private struct RulesheetProgressPillButton: View {
    let currentProgressPercent: Int
    let isCurrentProgressSessionSaved: Bool
    let progressPillPulseOpacity: Double
    let progressPillBackdropOpacity: Double
    let rowHeight: CGFloat?
    let topPadding: CGFloat
    let trailingInset: CGFloat
    let onSaveProgress: () -> Void

    var body: some View {
        Button(action: onSaveProgress) {
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
        .frame(height: rowHeight)
        .padding(.top, topPadding)
        .padding(.trailing, trailingInset)
    }
}

private struct RulesheetTopGradientOverlay: View {
    let isPortrait: Bool
    let topInset: CGFloat

    var body: some View {
        Group {
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
        }
    }
}

private struct RulesheetBackButtonOverlay: View {
    let isVisible: Bool
    let isPortrait: Bool
    let rowHeight: CGFloat
    let topPadding: CGFloat
    let gameName: String
    let dismiss: () -> Void

    var body: some View {
        Group {
            if isVisible {
                VStack {
                    HStack {
                        AppFullscreenBackButton(
                            action: dismiss,
                            accessibilityLabel: "Back from \(gameName)"
                        )
                        Spacer()
                    }
                    .frame(height: isPortrait ? rowHeight : nil)
                    .padding(.top, topPadding)
                    .padding(.horizontal, 16)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
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
        let configuration = makeRulesheetWebViewConfiguration(
            messageHandler: context.coordinator,
            anchorScrollInset: anchorScrollInset,
            includesFragmentScrollHandler: true
        )

        let webView = RulesheetTrackingWebView(frame: .zero, configuration: configuration)
        webView.applyRulesheetBaseAppearance()
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
            RulesheetHTMLDocumentBuilder.html(for: content),
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

        private func finishViewportRestore(
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

        private func clearViewportRestoreTrackingState() {
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
