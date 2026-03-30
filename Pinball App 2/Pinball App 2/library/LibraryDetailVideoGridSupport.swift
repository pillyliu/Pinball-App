import SwiftUI

struct LibraryDetailVideoGrid: View {
    let game: PinballGame
    let videos: [PinballGame.PlayableVideo]
    @Binding var activeVideoID: String?
    let usesDesktopLandscapeLayout: Bool

    private var columns: [GridItem] {
        let count = usesDesktopLandscapeLayout ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(videos) { video in
                LibraryDetailVideoTile(
                    video: video,
                    isSelected: activeVideoID == video.id,
                    onSelect: {
                        activeVideoID = video.id
                        LibraryActivityLog.log(
                            gameID: game.practiceLinkID,
                            gameName: game.name,
                            kind: .tapVideo,
                            detail: video.label
                        )
                    }
                )
            }
        }
    }
}

private struct LibraryDetailVideoTile: View {
    let video: PinballGame.PlayableVideo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                LibraryYouTubeThumbnailView(candidates: video.thumbnailCandidates)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(video.label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .pinballVideoTileChrome(selected: isSelected)
        }
        .buttonStyle(.plain)
    }
}
