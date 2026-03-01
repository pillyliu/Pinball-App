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
            }
            Text("Game Resources")
                .font(.headline)

            if let game {
                Text(game.metaLine)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                if game.rulesheetLinks.isEmpty {
                    if game.hasRulesheetResource {
                        practiceResourceRow("Rulesheet") {
                            practiceRulesheetLinkButton(title: "Local", game: game, source: nil)
                        }
                    } else {
                        practiceResourceRow("Rulesheet") {
                            unavailableResourceButton("Unavailable")
                        }
                    }
                } else {
                    practiceResourceRow("Rulesheet") {
                        ForEach(game.rulesheetLinks) { link in
                            practiceRulesheetLinkButton(link: link, game: game, title: shortRulesheetTitle(for: link))
                        }
                    }
                }

                if game.hasPlayfieldResource {
                    practiceResourceRow("Playfield") {
                        NavigationLink(playfieldButtonTitle(for: game)) {
                            HostedImageView(imageCandidates: game.actualFullscreenPlayfieldCandidates)
                        }
                        .buttonStyle(.glass)
                    }
                } else {
                    practiceResourceRow("Playfield") {
                        unavailableResourceButton("Unavailable")
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
                        Text("No video references listed.")
                            .font(.headline)
                            .foregroundStyle(.primary)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func unavailableResourceButton(_ title: String) -> some View {
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
        .buttonStyle(.glass)
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
            .buttonStyle(.glass)
        } else if let destination = link.destinationURL {
            NavigationLink(title) {
                ExternalRulesheetWebScreen(title: game.name, url: destination)
            }
            .buttonStyle(.glass)
        }
    }

    private func shortRulesheetTitle(for link: PinballGame.ReferenceLink) -> String {
        let label = link.label.lowercased()
        if label.contains("(tf)") { return "TF" }
        if label.contains("(pp)") { return "PP" }
        if label.contains("(papa)") { return "PAPA" }
        if label.contains("(bob)") { return "Bob" }
        if label.contains("(local)") || label.contains("(source)") { return "Local" }
        if link.destinationURL == nil && link.embeddedRulesheetSource == nil { return "Local" }
        return "Local"
    }

    private func playfieldButtonTitle(for game: PinballGame) -> String {
        game.playfieldSourceLabel == "Playfield (OPDB)" ? "OPDB" : "Local"
    }

    private func practiceResourceRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
}

struct PracticeVideoLaunchPanel: View {
    let selectedVideo: PinballGame.PlayableVideo?
    let onOpenURL: OpenURLAction

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
                    onOpenURL(youtubeURL)
                }
                .buttonStyle(.glass)
                .disabled(selectedVideo?.youtubeWatchURL == nil)
            }
            .padding(16)
        }
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
            .background(
                selected
                    ? Color(uiColor: .secondarySystemFill)
                    : Color(uiColor: .tertiarySystemFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(uiColor: .separator).opacity(selected ? 0.8 : 0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct PracticeYouTubeThumbnailView: View {
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
