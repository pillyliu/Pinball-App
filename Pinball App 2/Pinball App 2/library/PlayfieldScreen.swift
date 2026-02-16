import SwiftUI
import UIKit
import Combine

struct FallbackAsyncImageView: View {
    let candidates: [URL]
    let emptyMessage: String?
    var contentMode: ContentMode = .fill
    @State private var index = 0
    @State private var image: UIImage?
    @State private var didFailCurrent = false

    var body: some View {
        let currentURL = candidates.indices.contains(index) ? candidates[index] : nil

        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .modifier(AppImageContentMode(contentMode: contentMode))
            } else {
                Color(uiColor: .tertiarySystemBackground)
                    .overlay {
                        if let emptyMessage, candidates.isEmpty || didFailCurrent {
                            Text(emptyMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
            }
        }
        .task(id: currentURL) {
            guard let currentURL else {
                image = nil
                didFailCurrent = true
                return
            }
            do {
                let data = try await PinballDataCache.shared.loadData(url: currentURL)
                guard let loaded = UIImage(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                image = loaded
                didFailCurrent = false
            } catch {
                image = nil
                didFailCurrent = true
                if index + 1 < candidates.count {
                    index += 1
                }
            }
        }
    }
}

private struct AppImageContentMode: ViewModifier {
    let contentMode: ContentMode

    func body(content: Content) -> some View {
        switch contentMode {
        case .fit:
            content.scaledToFit()
        case .fill:
            content.scaledToFill()
        @unknown default:
            content.scaledToFill()
        }
    }
}

struct HostedImageView: View {
    let imageCandidates: [URL]
    @StateObject private var loader = RemoteUIImageLoader()
    @StateObject private var chrome = FullscreenChromeController()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = loader.image {
                ZoomableImageScrollView(image: image)
                    .ignoresSafeArea()
            } else if loader.failed {
                VStack(spacing: 8) {
                    Text("Could not load image.")
                        .foregroundStyle(.secondary)
                    if let sourceURL = imageCandidates.first {
                        Link("Open Original URL", destination: sourceURL)
                            .font(.footnote)
                    }
                }
            } else {
                ProgressView()
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
                chrome.toggle(reduceMotion: reduceMotion)
            }
        )
        .appEdgeBackGesture(dismiss: dismiss)
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

@MainActor
private final class RemoteUIImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var failed = false

    private var didLoad = false

    func loadIfNeeded(from urls: [URL]) async {
        guard !didLoad else { return }
        didLoad = true

        for url in urls {
            do {
                let data = try await PinballDataCache.shared.loadData(url: url)
                guard let uiImage = UIImage(data: data) else {
                    continue
                }

                image = uiImage
                failed = false
                return
            } catch {
                continue
            }
        }

        failed = true
    }
}

private struct ZoomableImageScrollView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 8
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        context.coordinator.imageView?.frame = uiView.bounds
        uiView.contentSize = uiView.bounds.size
        uiView.minimumZoomScale = 1
        uiView.setZoomScale(uiView.minimumZoomScale, animated: false)
        context.coordinator.centerImage(in: uiView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        func centerImage(in scrollView: UIScrollView) {
            let boundsSize = scrollView.bounds.size
            let contentSize = scrollView.contentSize

            let horizontalInset = max(0, (boundsSize.width - contentSize.width) / 2)
            let verticalInset = max(0, (boundsSize.height - contentSize.height) / 2)

            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }
    }
}
