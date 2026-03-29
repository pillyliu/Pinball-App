import SwiftUI
import UIKit

struct HostedImageView: View {
    let imageCandidates: [URL]
    @StateObject private var loader = RemoteUIImageLoader()
    @StateObject private var chrome = FullscreenChromeController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            } else if loader.failed {
                ZStack {
                    AppFullscreenStatusOverlay(
                        text: "Could not load image.",
                        foregroundColor: .white.opacity(0.9)
                    )

                    if let sourceURL = imageCandidates.first {
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
        .task {
            await loader.loadIfNeeded(from: imageCandidates)
        }
    }
}
