import SwiftUI

struct PracticeHomeRootView: View {
    let isLoadingGames: Bool
    let greetingName: String?
    let onOpenSettings: () -> Void

    let resumeGame: PinballGame?
    let allGames: [PinballGame]
    let activeGroups: [CustomGameGroup]
    let selectedGroupID: UUID?
    let groupGames: (CustomGameGroup) -> [PinballGame]
    let gameTransition: Namespace.ID
    let onResume: () -> Void
    let onPickGame: (String) -> Void
    let onQuickEntry: (QuickEntrySheet) -> Void

    let showingNamePrompt: Bool
    @Binding var firstNamePromptValue: String
    @Binding var importLplStatsOnNameSave: Bool
    let onNotNow: () -> Void
    let onSaveName: (String, Bool) -> Void

    var body: some View {
        ZStack {
            AppBackground()

            if isLoadingGames {
                ProgressView("Loading practice data...")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(greetingName == nil ? "Welcome back" : "Welcome back, \(greetingName!)")
                                .font(.title3.weight(.semibold))
                            Spacer()
                            Button(action: onOpenSettings) {
                                Image(systemName: "gearshape")
                            }
                            .buttonStyle(.glass)
                        }
                        .padding(.leading, 8)

                        PracticeHomeCardSection(
                            resumeGame: resumeGame,
                            allGames: allGames,
                            activeGroups: activeGroups,
                            selectedGroupID: selectedGroupID,
                            groupGames: groupGames,
                            gameTransition: gameTransition,
                            onResume: onResume,
                            onPickGame: onPickGame,
                            onQuickEntry: onQuickEntry
                        )

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(PracticeHubDestination.allCases) { destination in
                                NavigationLink(value: PracticeNavRoute.destination(destination)) {
                                    PracticeHubMiniCard(destination: destination)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }

            if showingNamePrompt {
                Color.black.opacity(0.30)
                    .ignoresSafeArea()

                PracticeWelcomeOverlay(
                    firstNamePromptValue: $firstNamePromptValue,
                    importLplStatsOnSave: $importLplStatsOnNameSave,
                    onNotNow: onNotNow,
                    onSave: onSaveName
                )
                .padding(.horizontal, 20)
                .frame(maxWidth: 560)
            }
        }
    }
}
