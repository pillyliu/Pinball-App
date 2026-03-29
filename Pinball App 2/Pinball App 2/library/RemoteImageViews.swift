import SwiftUI
import UIKit

struct FallbackAsyncImageView: View {
    let candidates: [URL]
    let emptyMessage: String?
    var contentMode: ContentMode = .fill
    var fillAlignment: Alignment = .center
    var layoutMode: AppImageLayoutMode?
    @State private var index = 0
    @State private var image: UIImage?
    @State private var loadedURL: URL?
    @State private var lastPrimaryURL: URL?
    @State private var didFailCurrent = false

    var body: some View {
        let candidateKey = candidates.map(\.absoluteString).joined(separator: "|")
        let currentURL = candidates.indices.contains(index) ? candidates[index] : nil
        let primaryURL = candidates.first

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
            defer {
                lastPrimaryURL = primaryURL
            }

            if let loadedURL,
               let preservedIndex = candidates.firstIndex(of: loadedURL),
               lastPrimaryURL == primaryURL,
               image != nil {
                index = preservedIndex
                didFailCurrent = false
                return
            }

            index = 0
            image = nil
            loadedURL = nil
            didFailCurrent = false
        }
        .task(id: currentURL) {
            guard let currentURL else {
                image = nil
                loadedURL = nil
                didFailCurrent = true
                return
            }
            do {
                let loaded = try await RemoteUIImageRepository.loadImageWithRetry(url: currentURL)
                image = loaded
                loadedURL = currentURL
                didFailCurrent = false
            } catch is CancellationError {
                return
            } catch {
                if loadedURL != currentURL {
                    image = nil
                }
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
