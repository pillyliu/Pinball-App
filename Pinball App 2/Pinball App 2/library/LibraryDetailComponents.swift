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
