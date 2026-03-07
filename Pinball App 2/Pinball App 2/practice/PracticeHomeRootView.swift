import SwiftUI

struct PracticeHomeRootView: View {
    let isLoadingGames: Bool
    let greetingName: String?
    let hasIFPAProfileAccess: Bool
    let onOpenSettings: () -> Void
    let onOpenIFPAProfile: () -> Void

    let resumeGame: PinballGame?
    let allGames: [PinballGame]
    let librarySources: [PinballLibrarySource]
    let selectedLibrarySourceID: String?
    let activeGroups: [CustomGameGroup]
    let selectedGroupID: UUID?
    let groupGames: (CustomGameGroup) -> [PinballGame]
    let gameTransition: Namespace.ID
    let onResume: (String) -> Void
    let onSelectLibrarySource: (String) -> Void
    let onPickGame: (String, String?) -> Void
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
                            greetingHeader
                            Spacer()
                            Button(action: onOpenSettings) {
                                Image(systemName: "gearshape")
                            }
                            .buttonStyle(.glass)
                        }
                        .padding(.leading, 8)

                        PracticeHomeSection(
                            resumeGame: resumeGame,
                            allGames: allGames,
                            librarySources: librarySources,
                            selectedLibrarySourceID: selectedLibrarySourceID,
                            activeGroups: activeGroups,
                            selectedGroupID: selectedGroupID,
                            groupGames: groupGames,
                            gameTransition: gameTransition,
                            onResume: onResume,
                            onSelectLibrarySource: onSelectLibrarySource,
                            onPickGame: onPickGame,
                            onQuickEntry: onQuickEntry
                        )

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(PracticeHubDestination.allCases) { destination in
                                NavigationLink(value: destination.route) {
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
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var greetingHeader: some View {
        if let greetingName {
            HStack(spacing: 0) {
                Text("Welcome back, ")
                Button(action: onOpenIFPAProfile) {
                    Text(greetingName)
                        .foregroundStyle(Color(red: 0.49, green: 0.77, blue: 0.98))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasIFPAProfileAccess ? "Open IFPA profile for \(greetingName)" : "Open IFPA setup for \(greetingName)")
            }
            .font(.title3.weight(.semibold))
        } else {
            Text("Welcome back")
                .font(.title3.weight(.semibold))
        }
    }
}
