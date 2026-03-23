import SwiftUI

struct PracticeHomeRootView: View {
    let showsLoadingOverlay: Bool
    let showsInteractionShield: Bool
    let showsGenericGreeting: Bool
    let greetingName: String?
    let hasIFPAProfileAccess: Bool
    let onOpenSettings: () -> Void
    let onOpenIFPAProfile: () -> Void
    let onOpenHubRoute: (PracticeRoute) -> Void

    let resumeGame: PinballGame?
    let allGames: [PinballGame]
    let searchGames: [PinballGame]
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
    let onOpenSearch: () -> Void
    let onNotNow: () -> Void
    let onSaveName: (String, Bool) -> Void

    var body: some View {
        ZStack {
            if showsLoadingOverlay {
                AppFullscreenStatusOverlay(
                    text: "Loading practice data…",
                    showsProgress: true
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            greetingHeader
                            Spacer()
                            Button(action: onOpenSearch) {
                                Image(systemName: "magnifyingglass")
                            }
                            .buttonStyle(AppCompactIconActionButtonStyle())
                            Button(action: onOpenSettings) {
                                Image(systemName: "gearshape")
                            }
                            .buttonStyle(AppCompactIconActionButtonStyle())
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
                                Button {
                                    onOpenHubRoute(destination.route)
                                } label: {
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

            if showsInteractionShield {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()

                AppFullscreenStatusOverlay(
                    text: "Refreshing practice data…",
                    showsProgress: true
                )
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
        if showsGenericGreeting {
            Text("Welcome back")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.brandInk)
        } else if let greetingName {
            HStack(spacing: 0) {
                Text("Welcome back, ")
                AppInlineLinkAction(text: greetingName, action: onOpenIFPAProfile)
                .accessibilityLabel(hasIFPAProfileAccess ? "Open IFPA profile for \(greetingName)" : "Open IFPA setup for \(greetingName)")
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppTheme.brandInk)
        } else {
            Text("Welcome back")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.brandInk)
        }
    }
}
