import Combine
import UIKit

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

enum RemoteUIImageRepository {
    static func cachedImage(for url: URL) -> UIImage? {
        RemoteUIImageMemoryCache.shared.image(for: url)
    }

    static func loadImage(url: URL) async throws -> UIImage {
        if let cachedImage = cachedImage(for: url) {
            return cachedImage
        }

        let data = try await PinballDataCache.shared.loadData(url: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        RemoteUIImageMemoryCache.shared.insert(image, for: url)
        return image
    }

    static func loadImageWithRetry(url: URL) async throws -> UIImage {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                return try await loadImage(url: url)
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

    private static func shouldRetry(error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
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
            do {
                let uiImage = try await RemoteUIImageRepository.loadImage(url: url)
                image = uiImage
                failed = false
                return
            } catch is CancellationError {
                return
            } catch {
                continue
            }
        }

        if Task.isCancelled {
            return
        }
        failed = true
    }
}
