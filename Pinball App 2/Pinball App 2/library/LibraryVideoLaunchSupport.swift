import SwiftUI

struct LibraryVideoLaunchPanel: View {
    let selectedVideo: PinballGame.PlayableVideo?
    let usesDesktopLandscapeLayout: Bool
    let openURL: OpenURLAction

    var body: some View {
        PinballVideoLaunchPanel(selectedVideo: selectedVideo, openURL: openURL)
            .frame(maxWidth: .infinity)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(minHeight: usesDesktopLandscapeLayout ? 260 : 0)
    }
}

struct PinballVideoLaunchPanel: View {
    let selectedVideo: PinballGame.PlayableVideo?
    let openURL: OpenURLAction

    @State private var metadata: PinballGame.YouTubeMetadata?

    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        ZStack {
            panelShape
                .fill(Color.black.opacity(0.82))
                .overlay {
                    if let selectedVideo {
                        LibraryYouTubeThumbnailView(candidates: selectedVideo.thumbnailCandidates)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    }
                }
                .overlay(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.24), location: 0.0),
                            .init(color: Color.black.opacity(0.48), location: 0.35),
                            .init(color: Color.black.opacity(0.82), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    panelShape
                        .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
                )
                .allowsHitTesting(false)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    AppOverlayTitle(selectedVideo?.label ?? "Tap a video thumbnail")
                        .lineLimit(1)

                    if let title = metadata?.title {
                        AppOverlaySubtitle(title)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let channelName = metadata?.channelName {
                        AppOverlaySubtitle(channelName, emphasis: 0.84)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "play.rectangle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.95), radius: 4, x: 0, y: 2)

                Button("Open in YouTube") {
                    guard let selectedVideo, let youtubeURL = selectedVideo.youtubeWatchURL else { return }
                    openURL(youtubeURL)
                }
                .buttonStyle(PinballVideoLaunchButtonStyle())
                .disabled(selectedVideo?.youtubeWatchURL == nil)
            }
            .padding(16)
        }
        .clipShape(panelShape)
        .task(id: selectedVideo?.id) {
            guard let selectedVideo else {
                metadata = nil
                return
            }
            metadata = nil
            guard let requestURL = selectedVideo.youtubeOEmbedURL else { return }
            let fetched = await YouTubeVideoMetadataService.shared.metadata(
                videoID: selectedVideo.id,
                requestURL: requestURL
            )
            guard !Task.isCancelled else { return }
            metadata = fetched
        }
    }
}

struct LibraryYouTubeThumbnailView: View {
    let candidates: [URL]

    var body: some View {
        FallbackAsyncImageView(
            candidates: candidates,
            emptyMessage: candidates.isEmpty ? "No image" : nil,
            contentMode: .fill,
            fillAlignment: .center,
            layoutMode: .fill
        )
    }
}
