import SwiftUI

struct LeagueDestinationView: View {
    let destination: LeagueDestination

    var body: some View {
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
        case .aboutLpl:
            LPLAboutContent()
                .navigationTitle(destination.title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
