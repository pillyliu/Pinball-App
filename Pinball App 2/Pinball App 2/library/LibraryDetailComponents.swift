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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(game.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let variant = game.variant?.trimmingCharacters(in: .whitespacesAndNewlines), !variant.isEmpty {
                    Text(variant)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(uiColor: .secondarySystemFill), in: Capsule())
                        .overlay(
                            Capsule().stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 0.8)
                        )
                }
                Spacer(minLength: 0)
            }

            Text(game.metaLine)
                .font(.subheadline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 10) {
                if game.rulesheetLinks.isEmpty {
                    if game.hasRulesheetResource {
                        PinballResourceRow("Rulesheet") {
                            libraryRulesheetLinkButton(title: "Local", game: game, source: nil)
                        }
                    } else {
                        PinballResourceRow("Rulesheet") {
                            PinballUnavailableResourceChip("Unavailable")
                        }
                    }
                } else {
                    PinballResourceRow("Rulesheet") {
                        ForEach(game.rulesheetLinks) { link in
                            libraryRulesheetLinkButton(link: link, game: game, title: PinballShortRulesheetTitle(for: link))
                        }
                    }
                }

                if game.hasPlayfieldResource {
                    PinballResourceRow("Playfield") {
                        NavigationLink(libraryPlayfieldButtonTitle(for: game)) {
                            HostedImageView(imageCandidates: game.actualFullscreenPlayfieldCandidates)
                        }
                        .buttonStyle(.glass)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                LibraryActivityLog.log(gameID: game.id, gameName: game.name, kind: .openPlayfield)
                            }
                        )
                    }
                } else {
                    PinballResourceRow("Playfield") {
                        PinballUnavailableResourceChip("Unavailable")
                    }
                }
            }
            .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Video References")

            if playableVideos.isEmpty {
                AppPanelEmptyCard(text: "No video references listed.")
            } else {
                LibraryVideoLaunchPanel(
                    selectedVideo: playableVideos.first(where: { $0.id == activeVideoID }) ?? playableVideos.first,
                    usesDesktopLandscapeLayout: usesDesktopLandscapeLayout,
                    openURL: openURL
                )

                LazyVGrid(
                    columns: usesDesktopLandscapeLayout
                        ? [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                        : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(playableVideos) { video in
                        Button {
                            activeVideoID = video.id
                            LibraryActivityLog.log(
                                gameID: game.id,
                                gameName: game.name,
                                kind: .tapVideo,
                                detail: video.label
                            )
                        } label: {
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
                            .pinballVideoTileChrome(selected: activeVideoID == video.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
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

struct LibraryDetailSourcesCard: View {
    let game: PinballGame

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionTitle(text: "Sources")

            if game.rulesheetLinks.isEmpty {
                if game.hasRulesheetResource {
                    PinballResourceRow("Rulesheet") {
                        libraryRulesheetLinkButton(title: "Local", game: game, source: nil)
                    }
                } else {
                    PinballResourceRow("Rulesheet") {
                        PinballUnavailableResourceChip("Unavailable")
                    }
                }
            } else {
                PinballResourceRow("Rulesheet") {
                    ForEach(game.rulesheetLinks) { link in
                        libraryRulesheetLinkButton(link: link, game: game, title: PinballShortRulesheetTitle(for: link))
                    }
                }
            }

            if game.hasPlayfieldResource {
                PinballResourceRow("Playfield") {
                    NavigationLink(libraryPlayfieldButtonTitle(for: game)) {
                        HostedImageView(imageCandidates: game.actualFullscreenPlayfieldCandidates)
                    }
                    .buttonStyle(.glass)
                }
            }

            if !game.hasRulesheetResource && !game.hasPlayfieldResource {
                AppPanelEmptyCard(text: "No sources available.")
            }
        }
        .font(.caption)
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

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedVideo?.label ?? "Tap a video thumbnail")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.95), radius: 4, x: 0, y: 2)

                    if let title = metadata?.title {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .shadow(color: .black.opacity(0.95), radius: 4, x: 0, y: 2)
                    }

                    if let channelName = metadata?.channelName {
                        Text(channelName)
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.84))
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.95), radius: 4, x: 0, y: 2)
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
                .buttonStyle(.glass)
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

private func libraryPlayfieldButtonTitle(for game: PinballGame) -> String {
    game.playfieldButtonLabel
}

@ViewBuilder
private func libraryRulesheetLinkButton(title: String, game: PinballGame, source: RulesheetRemoteSource?) -> some View {
    NavigationLink(title) {
        RulesheetScreen(
            slug: game.practiceKey,
            gameName: game.name,
            pathCandidates: source == nil ? game.rulesheetPathCandidates : [],
            externalSource: source
        )
    }
    .buttonStyle(.glass)
    .simultaneousGesture(
        TapGesture().onEnded {
            LibraryActivityLog.log(gameID: game.id, gameName: game.name, kind: .openRulesheet, detail: title)
        }
    )
}

@ViewBuilder
private func libraryRulesheetLinkButton(link: PinballGame.ReferenceLink, game: PinballGame, title: String) -> some View {
    if let embeddedSource = link.embeddedRulesheetSource {
        NavigationLink(title) {
            RulesheetScreen(
                slug: game.practiceKey,
                gameName: game.name,
                pathCandidates: [],
                externalSource: embeddedSource
            )
        }
        .buttonStyle(.glass)
        .simultaneousGesture(
            TapGesture().onEnded {
                LibraryActivityLog.log(gameID: game.id, gameName: game.name, kind: .openRulesheet, detail: link.label)
            }
        )
    } else if let destination = link.destinationURL {
        NavigationLink(title) {
            ExternalRulesheetWebScreen(title: game.name, url: destination)
        }
        .buttonStyle(.glass)
        .simultaneousGesture(
            TapGesture().onEnded {
                LibraryActivityLog.log(gameID: game.id, gameName: game.name, kind: .openRulesheet, detail: link.label)
            }
        )
    }
}
