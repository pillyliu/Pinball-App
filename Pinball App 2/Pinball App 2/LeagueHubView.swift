import SwiftUI

private enum LeagueDestination: String, CaseIterable, Identifiable {
    case stats
    case standings
    case targets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stats: return "Stats"
        case .standings: return "Standings"
        case .targets: return "Targets"
        }
    }

    var subtitle: String {
        switch self {
        case .stats: return "Player trends and machine performance"
        case .standings: return "Season standings and bank breakdown"
        case .targets: return "Great game, main target, and floor goals"
        }
    }

    var previewLines: [String] {
        switch self {
        case .stats:
            return ["Filters: season, player, bank, machine", "Score distribution and top machine insights"]
        case .standings:
            return ["Ranked table by season", "Bank-by-bank points snapshot"]
        case .targets:
            return ["Great game / main target / floor columns", "Quick benchmark view by machine"]
        }
    }

    var icon: String {
        switch self {
        case .stats: return "chart.xyaxis.line"
        case .standings: return "list.number"
        case .targets: return "scope"
        }
    }
}

struct LeagueHubView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(LeagueDestination.allCases) { destination in
                            NavigationLink {
                                destinationView(for: destination)
                            } label: {
                                LeagueCard(destination: destination)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                }
            }
            .navigationTitle("League")
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
}

private struct LeagueCard: View {
    let destination: LeagueDestination

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: destination.icon)
                .font(.title3.weight(.semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(destination.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(destination.previewLines, id: \.self) { line in
                        Text("• \(line)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
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
    LeagueHubView()
}
