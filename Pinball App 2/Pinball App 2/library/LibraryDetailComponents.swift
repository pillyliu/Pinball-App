import SwiftUI

struct LibraryDetailScreenshotSection: View {
    let game: PinballGame

    var body: some View {
        ConstrainedAsyncImagePreview(
            candidates: game.gamePlayfieldCandidates,
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
                        libraryResourceRow("Rulesheet") {
                            libraryRulesheetLinkButton(title: "Local", game: game, source: nil)
                        }
                    } else {
                        libraryUnavailableResourceButton("Unavailable")
                    }
                } else {
                    libraryResourceRow("Rulesheet") {
                        ForEach(game.rulesheetLinks) { link in
                            libraryRulesheetLinkButton(link: link, game: game, title: libraryShortRulesheetTitle(for: link))
                        }
                    }
                }

                if game.hasPlayfieldResource {
                    libraryResourceRow("Playfield") {
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
                    libraryResourceRow("Playfield") {
                        libraryUnavailableResourceButton("Unavailable")
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
            Text("Video References")
                .font(.headline)
                .foregroundStyle(.primary)

            if playableVideos.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
                        )
                    Text("No video references listed.")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
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
                            .background(
                                activeVideoID == video.id
                                    ? Color(uiColor: .secondarySystemFill)
                                    : Color(uiColor: .tertiarySystemFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(uiColor: .separator).opacity(activeVideoID == video.id ? 0.8 : 0.5), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            Text("Game Info")
                .font(.headline)
                .foregroundStyle(.primary)

            switch status {
            case .idle, .loading:
                Text("Loading...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .missing:
                Text("No game info yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .error:
                Text("Could not load game info.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
            Text("Sources")
                .font(.headline)
                .foregroundStyle(.primary)

            if game.rulesheetLinks.isEmpty && game.hasRulesheetResource {
                libraryResourceRow("Rulesheet") {
                    libraryRulesheetLinkButton(title: "Local", game: game, source: nil)
                }
            } else if !game.rulesheetLinks.isEmpty {
                libraryResourceRow("Rulesheet") {
                    ForEach(game.rulesheetLinks) { link in
                        libraryRulesheetLinkButton(link: link, game: game, title: libraryShortRulesheetTitle(for: link))
                    }
                }
            }

            if game.hasPlayfieldResource {
                libraryResourceRow("Playfield") {
                    if let playfieldSourceURL = game.playfieldImageSourceURL {
                        Link(libraryPlayfieldButtonTitle(for: game), destination: playfieldSourceURL)
                            .buttonStyle(.glass)
                    } else {
                        NavigationLink(libraryPlayfieldButtonTitle(for: game)) {
                            HostedImageView(imageCandidates: game.actualFullscreenPlayfieldCandidates)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }

            if !game.hasRulesheetResource && !game.hasPlayfieldResource {
                Text("No sources available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
                )

            VStack(spacing: 8) {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(selectedVideo?.label ?? "Tap a video thumbnail")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("Opens in YouTube")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open in YouTube") {
                    guard let selectedVideo, let youtubeURL = selectedVideo.youtubeWatchURL else { return }
                    openURL(youtubeURL)
                }
                .buttonStyle(.glass)
                .disabled(selectedVideo?.youtubeWatchURL == nil)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(minHeight: usesDesktopLandscapeLayout ? 260 : 0)
    }
}

private struct LibraryYouTubeThumbnailView: View {
    let candidates: [URL]
    @State private var index = 0

    var body: some View {
        let currentURL = candidates.indices.contains(index) ? candidates[index] : nil

        AsyncImage(url: currentURL) { phase in
            switch phase {
            case .empty:
                Color(uiColor: .tertiarySystemBackground)
                    .overlay { ProgressView() }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                if index + 1 < candidates.count {
                    Color(uiColor: .tertiarySystemBackground)
                        .task { index += 1 }
                } else {
                    Color(uiColor: .tertiarySystemBackground)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            @unknown default:
                Color(uiColor: .tertiarySystemBackground)
            }
        }
    }
}

private func libraryPlayfieldButtonTitle(for game: PinballGame) -> String {
    game.playfieldSourceLabel == "Playfield (OPDB)" ? "OPDB" : "Local"
}

private func libraryShortRulesheetTitle(for link: PinballGame.ReferenceLink) -> String {
    let label = link.label.lowercased()
    if label.contains("(tf)") { return "TF" }
    if label.contains("(pp)") { return "PP" }
    if label.contains("(papa)") { return "PAPA" }
    if label.contains("(bob)") { return "Bob" }
    if label.contains("(local)") || label.contains("(source)") { return "Local" }
    if link.destinationURL == nil && link.embeddedRulesheetSource == nil { return "Local" }
    return "Local"
}

private func libraryResourceRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(alignment: .center, spacing: 8) {
        Text("\(title):")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
    }
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

private func libraryUnavailableResourceButton(_ title: String) -> some View {
    Text(title)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(.secondary.opacity(0.9))
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .opacity(0.7)
        .allowsHitTesting(false)
}
