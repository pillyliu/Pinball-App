import SwiftUI

struct PracticeGameResourceCard: View {
    let game: PinballGame?
    let playableVideos: [PinballGame.PlayableVideo]
    @Binding var activeVideoID: String?
    let onOpenURL: OpenURLAction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let game {
                HStack(alignment: .center, spacing: 8) {
                    Text(game.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let variant = game.variant?.trimmingCharacters(in: .whitespacesAndNewlines), !variant.isEmpty {
                        PinballVariantBadge(variant)
                    }
                    Spacer(minLength: 0)
                }
            }
            AppCardSubheading(text: "Game Resources")

            if let game {
                Text(game.metaLine)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                if game.rulesheetLinks.isEmpty {
                    if game.hasRulesheetResource {
                        PinballResourceRow("Rulesheet") {
                            practiceRulesheetLinkButton(title: "Local", game: game, source: nil)
                        }
                    } else {
                        PinballResourceRow("Rulesheet") {
                            PinballUnavailableResourceChip("Unavailable")
                        }
                    }
                } else {
                    PinballResourceRow("Rulesheet") {
                        ForEach(game.rulesheetLinks) { link in
                            practiceRulesheetLinkButton(link: link, game: game, title: PinballShortRulesheetTitle(for: link))
                        }
                    }
                }

                if game.hasPlayfieldResource {
                    PinballResourceRow("Playfield") {
                        NavigationLink(playfieldButtonTitle(for: game)) {
                            HostedImageView(imageCandidates: game.actualFullscreenPlayfieldCandidates)
                        }
                        .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                    }
                } else {
                    PinballResourceRow("Playfield") {
                        PinballUnavailableResourceChip("Unavailable")
                    }
                }

                if playableVideos.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(uiColor: .separator).opacity(0.7), lineWidth: 1)
                            )
                        AppCardSubheading(text: "No video references listed.")
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                } else {
                    PracticeVideoLaunchPanel(
                        selectedVideo: playableVideos.first(where: { $0.id == activeVideoID }) ?? playableVideos.first,
                        onOpenURL: onOpenURL
                    )

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(playableVideos) { video in
                            PracticeVideoTile(
                                video: video,
                                selected: activeVideoID == video.id,
                                onSelect: { activeVideoID = video.id }
                            )
                        }
                    }
                }
            } else {
                Text("Select a game to load rulesheet, playfield, and video references.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }
    @ViewBuilder
    private func practiceRulesheetLinkButton(title: String, game: PinballGame, source: RulesheetRemoteSource?) -> some View {
        NavigationLink(title) {
            RulesheetScreen(
                slug: game.practiceKey,
                gameName: game.name,
                pathCandidates: source == nil ? game.rulesheetPathCandidates : [],
                externalSource: source
            )
        }
        .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
    }

    @ViewBuilder
    private func practiceRulesheetLinkButton(link: PinballGame.ReferenceLink, game: PinballGame, title: String) -> some View {
        if let embeddedSource = link.embeddedRulesheetSource {
            NavigationLink(title) {
                RulesheetScreen(
                    slug: game.practiceKey,
                    gameName: game.name,
                    pathCandidates: [],
                    externalSource: embeddedSource
                )
            }
            .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
        } else if let destination = link.destinationURL {
            NavigationLink(title) {
                ExternalRulesheetWebScreen(title: game.name, url: destination)
            }
            .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
        }
    }

    private func playfieldButtonTitle(for game: PinballGame) -> String {
        game.playfieldButtonLabel
    }
}

struct PracticeVideoLaunchPanel: View {
    let selectedVideo: PinballGame.PlayableVideo?
    let onOpenURL: OpenURLAction

    var body: some View {
        PinballVideoLaunchPanel(selectedVideo: selectedVideo, openURL: onOpenURL)
            .frame(maxWidth: .infinity)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
    }
}

struct PracticeVideoTile: View {
    let video: PinballGame.PlayableVideo
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                PracticeYouTubeThumbnailView(candidates: video.thumbnailCandidates)
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
            .pinballVideoTileChrome(selected: selected)
        }
        .buttonStyle(.plain)
    }
}

struct PracticeYouTubeThumbnailView: View {
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
