import SwiftUI
import UIKit

struct HostedImageView: View {
    let imageCandidates: [URL]
    @StateObject private var loader = RemoteUIImageLoader()
    @StateObject private var chrome = FullscreenChromeController()
    @State private var activeImageIndex = 0
    @State private var timedOutFinalCandidate = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var candidates: [URL] {
        prioritizeHostedImageCandidates(
            imageCandidates.filter { !$0.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        )
    }

    private var candidateKey: String {
        candidates.map(\.absoluteString).joined(separator: "|")
    }

    private var activeCandidate: URL? {
        guard candidates.indices.contains(activeImageIndex) else { return nil }
        return candidates[activeImageIndex]
    }

    private var hasNextCandidate: Bool {
        activeImageIndex + 1 < candidates.count
    }

    var body: some View {
        AppFullscreenStage {
            if let image = loader.image {
                ZoomableImageScrollView(
                    image: image,
                    onSingleTap: {
                        chrome.toggle(reduceMotion: reduceMotion)
                    }
                )
                .ignoresSafeArea()
            } else if candidates.isEmpty || timedOutFinalCandidate || (loader.failed && !hasNextCandidate) {
                ZStack {
                    AppFullscreenStatusOverlay(
                        text: "Could not load image.",
                        foregroundColor: .white.opacity(0.9)
                    )

                    if let sourceURL = activeCandidate ?? candidates.first {
                        VStack {
                            Spacer()
                            Link("Open Original URL", destination: sourceURL)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(.bottom, 34)
                        }
                    }
                }
            } else {
                AppFullscreenStatusOverlay(
                    text: "Loading image…",
                    showsProgress: true,
                    foregroundColor: .white.opacity(0.9)
                )
            }

            if chrome.isVisible {
                VStack {
                    HStack {
                        AppFullscreenBackButton(action: { dismiss() })
                        Spacer()
                    }
                    .padding(.top, 0)
                    .padding(.horizontal, 16)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .appEdgeBackGesture()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(true)
        .onAppear {
            chrome.resetOnAppear()
        }
        .onDisappear {
            chrome.cleanupOnDisappear()
        }
        .task(id: candidateKey) {
            activeImageIndex = 0
            timedOutFinalCandidate = false
        }
        .task(id: "\(candidateKey)|\(activeImageIndex)") {
            timedOutFinalCandidate = false
            guard let activeCandidate else { return }
            await loader.loadIfNeeded(from: [activeCandidate])
        }
        .task(id: "timeout|\(candidateKey)|\(activeImageIndex)") {
            guard let activeCandidate,
                  let timeout = hostedImageLoadTimeout(for: activeCandidate) else {
                return
            }
            let startingIndex = activeImageIndex
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled,
                  loader.image == nil,
                  !loader.failed,
                  activeImageIndex == startingIndex,
                  self.activeCandidate == activeCandidate else {
                return
            }
            if hasNextCandidate {
                activeImageIndex += 1
            } else {
                timedOutFinalCandidate = true
            }
        }
        .onChange(of: loader.failed) { _, failed in
            guard failed, hasNextCandidate else { return }
            activeImageIndex += 1
        }
    }
}
