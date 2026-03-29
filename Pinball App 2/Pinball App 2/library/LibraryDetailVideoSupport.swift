import SwiftUI

struct LibraryDetailVideosCard: View {
    let game: PinballGame
    @Binding var activeVideoID: String?
    let usesDesktopLandscapeLayout: Bool
    let openURL: OpenURLAction

    private var playableVideos: [PinballGame.PlayableVideo] {
        game.videos.compactMap { video in
            guard let rawURL = video.url,
                  let id = PinballGame.youtubeID(from: rawURL) else {
                return nil
            }
            let fallbackLabel = video.kind?
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            let label = video.label ?? fallbackLabel ?? "Video"
            return PinballGame.PlayableVideo(id: id, label: label)
        }
    }

    private var selectedVideo: PinballGame.PlayableVideo? {
        playableVideos.first(where: { $0.id == activeVideoID }) ?? playableVideos.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Video References")

            if playableVideos.isEmpty {
                AppPanelEmptyCard(text: "No video references listed.")
            } else {
                LibraryVideoLaunchPanel(
                    selectedVideo: selectedVideo,
                    usesDesktopLandscapeLayout: usesDesktopLandscapeLayout,
                    openURL: openURL
                )

                LibraryDetailVideoGrid(
                    game: game,
                    videos: playableVideos,
                    activeVideoID: $activeVideoID,
                    usesDesktopLandscapeLayout: usesDesktopLandscapeLayout
                )
            }
        }
        .padding(12)
        .appPanelStyle()
        .onAppear {
            if activeVideoID == nil {
                activeVideoID = playableVideos.first?.id
            }
        }
    }
}
