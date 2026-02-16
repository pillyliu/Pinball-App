import SwiftUI

struct LeagueHubView: View {
    @StateObject private var previewModel = LeagueHubPreviewModel()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    AppBackground()

                    let isLandscape = geo.size.width > geo.size.height
                    ScrollView {
                        if isLandscape {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12),
                                ],
                                spacing: 12
                            ) {
                                destinationCards
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                        } else {
                            VStack(spacing: 12) {
                                destinationCards
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
            StatsView(embeddedInNavigation: true)
                .navigationBarTitleDisplayMode(.inline)
        case .standings:
            StandingsView(embeddedInNavigation: true)
                .navigationBarTitleDisplayMode(.inline)
        case .targets:
            LPLTargetsView(embeddedInNavigation: true)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var destinationCards: some View {
        ForEach(LeagueDestination.allCases) { destination in
            NavigationLink {
                destinationView(for: destination)
            } label: {
                LeagueCard(destination: destination, previewModel: previewModel)
            }
            .buttonStyle(.plain)
        }
    }
}


#Preview {
    LeagueHubView()
}
