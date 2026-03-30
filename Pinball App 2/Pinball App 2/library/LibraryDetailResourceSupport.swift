import SwiftUI

struct LibraryRulesheetResourcesRow: View {
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

struct LibraryPlayfieldResourcesRow: View {
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
                            LibraryActivityLog.log(gameID: game.practiceLinkID, gameName: game.name, kind: .openPlayfield)
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
                LibraryActivityLog.log(gameID: game.practiceLinkID, gameName: game.name, kind: .openRulesheet, detail: detailLabel)
            }
        )
    }
}
