import SwiftUI

struct LeagueScreen: View {
    @StateObject private var previewModel = LeaguePreviewModel()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    AppBackground()

                    let isLandscape = geo.size.width > geo.size.height
                    ScrollView {
                        if isLandscape {
                            VStack(spacing: 12) {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12),
                                    ],
                                    spacing: 12
                                ) {
                                    destinationLinks
                                }

                                aboutFooterLink
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                        } else {
                            VStack(spacing: 12) {
                                destinationLinks
                                aboutFooterLink
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await previewModel.loadIfNeeded()
        }
    }

    @ViewBuilder
    private func destinationView(for destination: LeagueDestination) -> some View {
        switch destination {
        case .stats:
            StatsScreen(embeddedInNavigation: true)
                .navigationBarTitleDisplayMode(.inline)
        case .standings:
            StandingsScreen(embeddedInNavigation: true)
                .navigationBarTitleDisplayMode(.inline)
        case .targets:
            TargetsScreen(embeddedInNavigation: true)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var destinationLinks: some View {
        ForEach(LeagueDestination.allCases) { destination in
            NavigationLink {
                destinationView(for: destination)
            } label: {
                LeagueCard(destination: destination, previewModel: previewModel)
            }
            .buttonStyle(.plain)
        }
    }

    private var aboutFooterLink: some View {
        NavigationLink {
            LPLAboutContent()
                .navigationTitle("About Lansing Pinball League")
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            LeagueAboutFooterCard()
        }
        .buttonStyle(.plain)
    }
}

private struct LeagueAboutFooterCard: View {
    var body: some View {
        HStack(spacing: 12) {
            LPLLogoView()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("About Lansing Pinball League")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text("League info, meeting details, and links")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .appPanelStyle()
    }
}


#Preview {
    LeagueScreen()
}
