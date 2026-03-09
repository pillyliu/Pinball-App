import SwiftUI

extension PracticeScreen {
    var practiceHomeContent: some View {
        PracticeHomeRootView(
            isLoadingGames: practiceHomeContext.store.isLoadingGames,
            greetingName: practiceHomeContext.greetingName,
            hasIFPAProfileAccess: practiceHomeContext.hasIFPAProfileAccess,
            onOpenSettings: {
                practiceHomeContext.onOpenSettings()
            },
            onOpenIFPAProfile: {
                practiceHomeContext.onOpenIFPAProfile()
            },
            resumeGame: practiceHomeContext.resumeGame,
            allGames: practiceHomeContext.allGames,
            librarySources: practiceHomeContext.librarySources,
            selectedLibrarySourceID: practiceHomeContext.selectedLibrarySourceID,
            activeGroups: practiceHomeContext.activeGroups,
            selectedGroupID: practiceHomeContext.selectedGroupID,
            groupGames: { group in
                practiceHomeContext.groupGames(group)
            },
            gameTransition: practiceHomeContext.gameTransition,
            onResume: { sourceID in
                practiceHomeContext.onResume(sourceID)
            },
            onSelectLibrarySource: { sourceID in
                practiceHomeContext.onSelectLibrarySource(sourceID)
            },
            onPickGame: { gameID, sourceID in
                practiceHomeContext.onPickGame(gameID, sourceID)
            },
            onQuickEntry: { sheet in
                practiceHomeContext.onQuickEntry(sheet)
            },
            showingNamePrompt: practiceHomeContext.showingNamePrompt,
            firstNamePromptValue: practiceHomeContext.firstNamePromptValue,
            importLplStatsOnNameSave: practiceHomeContext.importLplStatsOnNameSave,
            onNotNow: {
                practiceHomeContext.onNotNow()
            },
            onSaveName: { trimmedName, shouldImportLplStats in
                practiceHomeContext.onSaveName(trimmedName, shouldImportLplStats)
            }
        )
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        practiceHomeContext.onViewportHeightChanged(geo.size.height)
                    }
                    .onChange(of: geo.size.height) { _, newHeight in
                        practiceHomeContext.onViewportHeightChanged(newHeight)
                    }
            }
        )
    }
}
