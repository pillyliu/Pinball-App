import SwiftUI

struct PracticeGameResourceCard: View {
    let game: PinballGame?
    let playableVideos: [PinballGame.PlayableVideo]
    @Binding var activeVideoID: String?
    let onOpenURL: OpenURLAction
    let onOpenRulesheet: (PinballGame, RulesheetRemoteSource?) -> Void
    let onOpenExternalRulesheet: (PinballGame, URL) -> Void
    @State private var livePlayfieldStatus: LibraryLivePlayfieldStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppCardSubheading(text: "Study Resources")

            if let game {
                let playfieldOptions = game.resolvedPlayfieldOptions(liveStatus: livePlayfieldStatus)
                Text(game.metaLine)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                PinballResourceRow("Rulesheet") {
                    if game.hasLocalRulesheetResource {
                        practiceRulesheetLinkButton(title: "Local", game: game, source: nil)
                    }
                    if game.rulesheetLinks.isEmpty {
                        if !game.hasLocalRulesheetResource {
                            PinballUnavailableResourceChip("Unavailable")
                        }
                    } else {
                        ForEach(game.orderedRulesheetLinks) { link in
                            practiceRulesheetLinkButton(link: link, game: game, title: PinballShortRulesheetTitle(for: link))
                        }
                    }
                }
                if !playfieldOptions.isEmpty {
                    PinballResourceRow("Playfield") {
                        ForEach(playfieldOptions) { option in
                            NavigationLink(option.title) {
                                HostedImageView(imageCandidates: option.candidates)
                            }
                            .buttonStyle(PinballResourceChipButtonStyle())
                        }
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
        .task(id: game?.practiceIdentity) {
            livePlayfieldStatus = await LibraryLivePlayfieldStatusStore.shared.status(for: game?.practiceIdentity)
        }
    }
    @ViewBuilder
    private func practiceRulesheetLinkButton(title: String, game: PinballGame, source: RulesheetRemoteSource?) -> some View {
        Button {
            onOpenRulesheet(game, source)
        } label: {
            Text(title)
        }
        .buttonStyle(PinballResourceChipButtonStyle())
    }

    @ViewBuilder
    private func practiceRulesheetLinkButton(link: PinballGame.ReferenceLink, game: PinballGame, title: String) -> some View {
        if let embeddedSource = link.embeddedRulesheetSource {
            Button {
                onOpenRulesheet(game, embeddedSource)
            } label: {
                Text(title)
            }
            .buttonStyle(PinballResourceChipButtonStyle())
        } else if let destination = link.destinationURL {
            Button {
                onOpenExternalRulesheet(game, destination)
            } label: {
                Text(title)
            }
            .buttonStyle(PinballResourceChipButtonStyle())
        }
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
