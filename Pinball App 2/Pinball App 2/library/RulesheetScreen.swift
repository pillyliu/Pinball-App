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

    private var progressStore: RulesheetProgressStore {
        RulesheetProgressStore(gameID: gameID)
    }

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
            let layoutMetrics = RulesheetScreenLayoutMetrics(
                size: geo.size,
                safeAreaInsets: geo.safeAreaInsets
            )

            RulesheetScreenSurface(
                layoutMetrics: layoutMetrics,
                status: viewModel.status,
                content: viewModel.content,
                fallbackURL: viewModel.webFallbackURL,
                resumeTarget: resumeTarget,
                resumeRequestID: resumeRequestID,
                currentProgressPercent: currentProgressPercent,
                isCurrentProgressSessionSaved: isCurrentProgressSessionSaved,
                progressPillPulseOpacity: progressPillPulseOpacity,
                progressPillBackdropOpacity: progressPillBackdropOpacity,
                showsBackButton: showsBackButton,
                gameName: gameName,
                onDismiss: dismiss.callAsFunction,
                onChromeToggle: toggleChromeVisibility,
                onProgressChange: updateScrollProgress,
                onSaveProgress: saveCurrentProgress
            )
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .appEdgeBackGesture()
        .task {
            await viewModel.loadIfNeeded()
        }
        .onAppear {
            handleAppear()
        }
        .onChange(of: viewModel.status) { _, newStatus in
            handleStatusChange(newStatus)
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
                resumeSavedProgress()
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

    private func saveCurrentProgress() {
        let clamped = min(max(scrollProgress, 0), 1)
        progressStore.save(clamped)
        savedProgress = clamped
        sessionSavedProgress = clamped
    }

    private func handleAppear() {
        if savedProgress == nil {
            savedProgress = progressStore.load()
        }
        syncProgressPillPulse()
    }

    private func handleStatusChange(_ newStatus: LoadStatus) {
        if newStatus == .loaded {
            syncProgressPillPulse()
        }
        guard newStatus == .loaded, !didEvaluateResumePrompt else { return }
        didEvaluateResumePrompt = true
        if let saved = savedProgress, saved > 0.001 {
            showResumePrompt = true
        }
    }

    private func resumeSavedProgress() {
        guard let saved = savedProgress else { return }
        resumeTarget = saved
        resumeRequestID += 1
    }

    private func toggleChromeVisibility() {
        showsBackButton.toggle()
    }

    private func updateScrollProgress(_ progress: CGFloat) {
        scrollProgress = progress
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
