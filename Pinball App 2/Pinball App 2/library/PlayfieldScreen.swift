import SwiftUI
import UIKit
import Combine

enum AppImageLayoutMode {
    case fill
    case fit
    case widthFillTopCropBottom
}

final class RemoteUIImageMemoryCache {
    static let shared = RemoteUIImageMemoryCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 96
        cache.totalCostLimit = 96 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func insert(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: imageCost(image))
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private func imageCost(_ image: UIImage) -> Int {
        if let cgImage = image.cgImage {
            return cgImage.bytesPerRow * cgImage.height
        }
        let scale = image.scale
        let pixels = image.size.width * image.size.height * scale * scale
        return max(Int(pixels * 4), 1)
    }
}

struct FallbackAsyncImageView: View {
    let candidates: [URL]
    let emptyMessage: String?
    var contentMode: ContentMode = .fill
    var fillAlignment: Alignment = .center
    var layoutMode: AppImageLayoutMode?
    @State private var index = 0
    @State private var image: UIImage?
    @State private var didFailCurrent = false

    var body: some View {
        let candidateKey = candidates.map(\.absoluteString).joined(separator: "|")
        let currentURL = candidates.indices.contains(index) ? candidates[index] : nil

        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .modifier(
                        AppImageContentMode(
                            contentMode: contentMode,
                            fillAlignment: fillAlignment,
                            layoutMode: layoutMode
                        )
                    )
            } else {
                PinballMediaPreviewPlaceholder(
                    message: (candidates.isEmpty || didFailCurrent) ? emptyMessage : nil,
                    showsProgress: !(candidates.isEmpty || didFailCurrent)
                )
            }
        }
        .task(id: candidateKey) {
            index = 0
            image = nil
            didFailCurrent = false
        }
        .task(id: currentURL) {
            guard let currentURL else {
                image = nil
                didFailCurrent = true
                return
            }
            if let cachedImage = RemoteUIImageMemoryCache.shared.image(for: currentURL) {
                image = cachedImage
                didFailCurrent = false
                return
            }
            do {
                let data = try await loadDataWithRetry(url: currentURL)
                guard let loaded = UIImage(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                RemoteUIImageMemoryCache.shared.insert(loaded, for: currentURL)
                image = loaded
                didFailCurrent = false
            } catch is CancellationError {
                return
            } catch {
                image = nil
                didFailCurrent = true
                if index + 1 < candidates.count {
                    index += 1
                }
            }
        }
    }

    private func loadDataWithRetry(url: URL) async throws -> Data {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                return try await PinballDataCache.shared.loadData(url: url)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if !shouldRetry(error: error) || attempt == 2 {
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(250_000_000 * (attempt + 1)))
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    private func shouldRetry(error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}

private struct AppImageContentMode: ViewModifier {
    let contentMode: ContentMode
    let fillAlignment: Alignment
    let layoutMode: AppImageLayoutMode?

    func body(content: Content) -> some View {
        Group {
            if let layoutMode {
                switch layoutMode {
                case .fill:
                    content
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: fillAlignment)
                case .fit:
                    content.scaledToFit()
                case .widthFillTopCropBottom:
                    content
                        .scaledToFit()
                        .frame(maxWidth: .infinity, alignment: fillAlignment)
                }
            } else {
                switch contentMode {
                case .fit:
                    content.scaledToFit()
                case .fill:
                    content
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: fillAlignment)
                @unknown default:
                    content
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: fillAlignment)
                }
            }
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
final class RemoteUIImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var failed = false

    private var loadedCandidateKey: String?

    func loadIfNeeded(from urls: [URL]) async {
        let candidateKey = urls.map(\.absoluteString).joined(separator: "|")
        guard loadedCandidateKey != candidateKey else { return }
        loadedCandidateKey = candidateKey
        image = nil
        failed = false

        for url in urls {
            if let cachedImage = RemoteUIImageMemoryCache.shared.image(for: url) {
                image = cachedImage
                failed = false
                return
            }
            do {
                let data = try await PinballDataCache.shared.loadData(url: url)
                guard let uiImage = UIImage(data: data) else {
                    continue
                }

                RemoteUIImageMemoryCache.shared.insert(uiImage, for: url)
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

struct ConstrainedAsyncImagePreview: View {
    let candidates: [URL]
    let emptyMessage: String?
    var maxAspectRatio: CGFloat = 4.0 / 3.0
    var imagePadding: CGFloat = 8

    @StateObject private var loader = RemoteUIImageLoader()

    private var candidateKey: String {
        candidates.map(\.absoluteString).joined(separator: "|")
    }

    private var effectiveAspectRatio: CGFloat {
        guard let image = loader.image, image.size.width > 0, image.size.height > 0 else {
            return maxAspectRatio
        }
        let imageAspectRatio = image.size.width / image.size.height
        return max(maxAspectRatio, imageAspectRatio)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.82))

            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(imagePadding)
            } else if loader.failed {
                PinballMediaPreviewPlaceholder(message: emptyMessage ?? "No image")
            } else {
                PinballMediaPreviewPlaceholder(showsProgress: true)
            }
        }
        .aspectRatio(effectiveAspectRatio, contentMode: .fit)
        .task(id: candidateKey) {
            await loader.loadIfNeeded(from: candidates)
        }
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
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.scrollView = scrollView
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
        weak var scrollView: UIScrollView?
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

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            let targetZoom = min(max(scrollView.minimumZoomScale * 2.5, 2.0), scrollView.maximumZoomScale)
            let tapPoint = recognizer.location(in: imageView)
            let zoomRect = zoomRect(for: targetZoom, center: tapPoint, in: scrollView)
            scrollView.zoom(to: zoomRect, animated: true)
        }

        private func zoomRect(for scale: CGFloat, center: CGPoint, in scrollView: UIScrollView) -> CGRect {
            let size = CGSize(
                width: scrollView.bounds.width / scale,
                height: scrollView.bounds.height / scale
            )
            let origin = CGPoint(
                x: center.x - (size.width / 2),
                y: center.y - (size.height / 2)
            )
            return CGRect(origin: origin, size: size)
        }
    }
}
