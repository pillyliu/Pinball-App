import SwiftUI

struct LibraryDetailScreenshotSection: View {
    let game: PinballGame

    var body: some View {
        ConstrainedAsyncImagePreview(
            candidates: game.detailArtworkCandidates,
            emptyMessage: "No image",
            maxAspectRatio: 4.0 / 3.0,
            imagePadding: 0
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct LibraryDetailSummaryCard: View {
    let game: PinballGame
    @State private var livePlayfieldStatus: LibraryLivePlayfieldStatus?

    private var playfieldOptions: [LibraryPlayfieldOption] {
        game.resolvedPlayfieldOptions(liveStatus: livePlayfieldStatus)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppCardTitleWithVariant(
                text: game.name,
                variant: game.variant,
                lineLimit: 2
            )

            AppCardSubheading(text: game.metaLine)

            VStack(alignment: .leading, spacing: 10) {
                LibraryRulesheetResourcesRow(game: game)
                LibraryPlayfieldResourcesRow(
                    game: game,
                    playfieldOptions: playfieldOptions
                )
            }
            .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
        .task(id: game.practiceIdentity) {
            livePlayfieldStatus = await LibraryLivePlayfieldStatusStore.shared.status(for: game.practiceIdentity)
        }
    }
}

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

private struct LibraryDetailVideoGrid: View {
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
                            gameID: game.id,
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

struct LibraryDetailGameInfoCard: View {
    let status: LoadStatus
    let markdownText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Game Info")

            switch status {
            case .idle, .loading:
                AppInlineTaskStatus(text: "Loading…", showsProgress: true)
            case .missing:
                AppPanelEmptyCard(text: "No game info yet.")
            case .error:
                AppInlineTaskStatus(text: "Could not load game info.", isError: true)
            case .loaded:
                if let markdownText {
                    NativeMarkdownView(markdown: markdownText)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }
}

private struct LibraryVideoLaunchPanel: View {
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

private struct LibraryYouTubeThumbnailView: View {
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

private struct LibraryRulesheetResourcesRow: View {
    let game: PinballGame

    var body: some View {
        PinballResourceRow("Rulesheet") {
            if game.hasLocalRulesheetResource {
                LibraryRulesheetChip(
                    game: game,
                    title: game.localRulesheetChipTitle,
                    detailLabel: game.localRulesheetChipTitle,
                    destination: .embedded(source: nil)
                )
            }
            if game.rulesheetLinks.isEmpty {
                if !game.hasLocalRulesheetResource {
                    PinballUnavailableResourceChip("Unavailable")
                }
            } else {
                ForEach(game.displayedRulesheetLinks) { link in
                    LibraryRulesheetLinkChip(
                        game: game,
                        link: link,
                        title: PinballShortRulesheetTitle(for: link)
                    )
                }
            }
        }
    }
}

private struct LibraryPlayfieldResourcesRow: View {
    let game: PinballGame
    let playfieldOptions: [LibraryPlayfieldOption]

    var body: some View {
        PinballResourceRow("Playfield") {
            if playfieldOptions.isEmpty {
                PinballUnavailableResourceChip("Unavailable")
            } else {
                ForEach(playfieldOptions) { option in
                    NavigationLink(option.title) {
                        HostedImageView(imageCandidates: option.candidates)
                    }
                    .buttonStyle(PinballResourceChipButtonStyle())
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            LibraryActivityLog.log(gameID: game.id, gameName: game.name, kind: .openPlayfield)
                        }
                    )
                }
            }
        }
    }
}

private struct LibraryRulesheetLinkChip: View {
    let game: PinballGame
    let link: PinballGame.ReferenceLink
    let title: String

    var body: some View {
        if let embeddedSource = link.embeddedRulesheetSource {
            LibraryRulesheetChip(
                game: game,
                title: title,
                detailLabel: link.label,
                destination: .embedded(source: embeddedSource)
            )
        } else if let destination = link.destinationURL {
            LibraryRulesheetChip(
                game: game,
                title: title,
                detailLabel: link.label,
                destination: .external(url: destination)
            )
        }
    }
}

private struct LibraryRulesheetChip: View {
    enum Destination {
        case embedded(source: RulesheetRemoteSource?)
        case external(url: URL)
    }

    let game: PinballGame
    let title: String
    let detailLabel: String
    let destination: Destination

    var body: some View {
        NavigationLink(title) {
            switch destination {
            case .embedded(let source):
                RulesheetScreen(
                    gameID: game.practiceKey,
                    gameName: game.name,
                    pathCandidates: source == nil ? game.rulesheetPathCandidates : [],
                    externalSource: source
                )
            case .external(let url):
                ExternalRulesheetWebScreen(title: game.name, url: url)
            }
        }
        .buttonStyle(PinballResourceChipButtonStyle())
        .simultaneousGesture(
            TapGesture().onEnded {
                LibraryActivityLog.log(gameID: game.id, gameName: game.name, kind: .openRulesheet, detail: detailLabel)
            }
        )
    }
}
