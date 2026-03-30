import SwiftUI
import AVKit
import UIKit

struct GameRoomAttachmentSquareTile: View {
    let attachment: MachineAttachment
    let resolvedURL: URL?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.82))

                if attachment.kind == .video {
                    GameRoomVideoThumbnailView(url: resolvedURL)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    Image(systemName: "play.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
                } else {
                    GameRoomImageThumbnailView(url: resolvedURL)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.controlBorder, lineWidth: 1)
        )
    }
}

private struct GameRoomImageThumbnailView: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                PinballMediaPreviewPlaceholder(showsProgress: true)
            }
        }
        .task(id: url?.absoluteString ?? "") {
            image = await loadImage(from: url)
        }
    }

    private func loadImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if let cached = RemoteUIImageMemoryCache.shared.image(for: url) {
            return cached
        }
        if url.isFileURL {
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            RemoteUIImageMemoryCache.shared.insert(image, for: url)
            return image
        }
        do {
            let data = try await PinballDataCache.shared.loadData(url: url)
            guard let image = UIImage(data: data) else { return nil }
            RemoteUIImageMemoryCache.shared.insert(image, for: url)
            return image
        } catch {
            return nil
        }
    }
}

private struct GameRoomVideoThumbnailView: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                PinballMediaPreviewPlaceholder(showsProgress: true)
            }
        }
        .task(id: url?.absoluteString ?? "") {
            image = await loadVideoThumbnail(from: url)
        }
    }

    private func loadVideoThumbnail(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        return await withCheckedContinuation { continuation in
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 600, height: 600)
            let times = [NSValue(time: .zero)]
            var resumed = false
            generator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, _, result, _ in
                guard !resumed else { return }
                switch result {
                case .succeeded:
                    resumed = true
                    if let cgImage {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } else {
                        continuation.resume(returning: nil)
                    }
                case .failed, .cancelled:
                    resumed = true
                    continuation.resume(returning: nil)
                @unknown default:
                    resumed = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
