import SwiftUI
import Foundation

extension PracticeScreen {
    @ViewBuilder
    func routeView(for route: PracticeRoute) -> some View {
        switch route {
        case .search:
            PracticeGameSearchSheet(
                games: practiceHomeContext.searchGames,
                isLoadingGames: store.isLoadingSearchCatalog,
                onLoadGames: {
                    await store.ensureSearchCatalogGamesLoaded()
                },
                onSelectGame: { gameID in
                    goToGame(gameID)
                }
            )
        case .rulesheet:
            if let game = store.gameForAnyID(uiState.selectedGameID) {
                if let externalURL = uiState.selectedExternalRulesheetURL {
                    ExternalRulesheetWebScreen(title: game.name, url: externalURL)
                } else {
                    RulesheetScreen(
                        slug: game.practiceKey,
                        gameName: game.name,
                        pathCandidates: uiState.selectedRulesheetSource == nil ? game.rulesheetPathCandidates : [],
                        externalSource: uiState.selectedRulesheetSource
                    )
                }
            } else {
                practiceScreen("Rulesheet") {
                    AppPanelStatusCard(text: "Select a game to open the rulesheet.")
                }
            }
        case .playfield:
            if let game = store.gameForAnyID(uiState.selectedGameID) {
                HostedImageView(
                    imageCandidates: uiState.selectedPlayfieldImageURLs.isEmpty
                        ? game.fullscreenPlayfieldCandidates
                        : uiState.selectedPlayfieldImageURLs
                )
            } else {
                practiceScreen("Playfield") {
                    AppPanelStatusCard(text: "Select a game to open the playfield.")
                }
            }
        case .groupDashboard:
            practiceScreen("Group Dashboard") {
                groupDashboardScreen(context: practiceGroupDashboardContext)
            }
        case .groupEditor:
            practiceScreen(uiState.editingGroupID == nil ? "Create Group" : "Edit Group") {
                GroupEditorScreen(
                    store: store,
                    editingGroupID: uiState.editingGroupID,
                    onSaved: {
                        if !uiState.gameNavigationPath.isEmpty {
                            uiState.gameNavigationPath.removeLast()
                        }
                        uiState.editingGroupID = nil
                    }
                )
            }
        case .journal:
            practiceViewportScreen("Journal Timeline") {
                journalScreen(context: practiceJournalContext)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        practiceJournalContext.onToggleEditing()
                    } label: {
                        if practiceJournalContext.isEditingEntries.wrappedValue {
                            Text("Cancel")
                        } else {
                            Image(systemName: "pencil")
                        }
                    }
                }
            }
        case .insights:
            practiceScreen("Insights") {
                insightsScreen(context: practiceInsightsContext)
            }
        case .mechanics:
            practiceScreen("Mechanics") {
                mechanicsScreen(context: practiceMechanicsContext)
            }
        case .settings:
            practiceScreen("Practice Settings") {
                settingsScreen(context: practiceSettingsContext)
                    .task {
                        await refreshLeaguePlayerOptions()
                    }
            }
        case .ifpaProfile:
            practiceScreen("IFPA Profile") {
                PracticeIFPAProfileScreen(
                    playerName: practiceSettingsContext.playerName.wrappedValue,
                    ifpaPlayerID: practiceSettingsContext.ifpaPlayerID.wrappedValue
                )
            }
        case .game:
            EmptyView()
        }
    }

    func practiceScreen<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    func practiceViewportScreen<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    func groupDashboardScreen(context: PracticeGroupDashboardContext) -> some View {
        PracticeGroupDashboardSectionView(
            selectedGroup: context.selectedGroup,
            allGroups: context.store.state.customGroups,
            selectedGroupID: context.store.state.practiceSettings.selectedGroupID,
            gameTransition: context.gameTransition,
            onOpenCreateGroup: {
                context.onOpenCreateGroup()
            },
            onOpenEditSelectedGroup: {
                context.onOpenEditSelectedGroup()
            },
            onSelectGroup: { groupID in
                context.store.setSelectedGroup(id: groupID)
            },
            onTogglePriority: { groupID, isPriority in
                context.store.updateGroup(id: groupID, isPriority: isPriority)
            },
            onSetGroupArchived: { groupID, isArchived in
                context.store.updateGroup(id: groupID, isArchived: isArchived)
            },
            onDeleteGroup: { groupID in
                context.store.deleteGroup(id: groupID)
            },
            onUpdateGroupDate: { groupID, field, date in
                switch field {
                case .start:
                    context.store.updateGroup(id: groupID, replaceStartDate: true, startDate: date)
                case .end:
                    context.store.updateGroup(id: groupID, replaceEndDate: true, endDate: date)
                }
            },
            loadDashboardDetailForGroup: { group in
                context.store.groupDashboardDetail(for: group)
            },
            onOpenGame: { gameID in
                context.onOpenGame(gameID, gameID)
            },
            onRemoveGameFromGroup: { gameID, groupID in
                context.onRemoveGameFromGroup(gameID, groupID)
            }
        )
    }

    func journalScreen(context: PracticeJournalContext) -> some View {
        PracticeJournalSectionView(
            journalFilter: context.journalFilter,
            sections: context.sections,
            isEditingEntries: context.isEditingEntries,
            selectedItemIDs: context.selectedItemIDs,
            gameTransition: context.gameTransition,
            onTapItem: { gameID, sourceID in context.onOpenGame(gameID, sourceID) },
            onEditJournalEntry: { entry in context.onEditJournalEntry(entry) },
            onDeleteJournalEntries: { entries in context.onDeleteJournalEntries(entries) }
        )
    }

    func insightsScreen(context: PracticeInsightsContext) -> some View {
        PracticeInsightsSectionView(
            games: context.games,
            librarySources: context.librarySources,
            selectedLibrarySourceID: context.selectedLibrarySourceID,
            onSelectLibrarySourceID: { sourceID in
                context.onSelectLibrarySourceID(sourceID)
            },
            selectedGameID: context.selectedGameID,
            scoreSummaryForGame: { gameID in
                context.scoreSummaryForGame(gameID)
            },
            scoreTrendValuesForGame: { gameID in
                context.scoreTrendValuesForGame(gameID)
            },
            playerName: context.playerName,
            opponentName: context.opponentName,
            opponentOptions: context.opponentOptions,
            isLoadingHeadToHead: context.isLoadingHeadToHead,
            headToHead: context.headToHead,
            redactName: { name in
                context.redactName(name)
            },
            onRefreshHeadToHead: {
                await context.onRefreshHeadToHead()
            },
            onRefreshOpponentOptions: {
                await context.onRefreshOpponentOptions()
            }
        )
    }

    func mechanicsScreen(context: PracticeMechanicsContext) -> some View {
        PracticeMechanicsSectionView(
            selectedMechanicSkill: context.selectedMechanicSkill,
            mechanicsComfort: context.mechanicsComfort,
            mechanicsNote: context.mechanicsNote,
            trackedSkills: context.trackedSkills,
            detectedTags: context.detectedTags,
            summaryForSkill: { skill in
                context.summaryForSkill(skill)
            },
            allLogs: {
                context.allLogs()
            },
            logsForSkill: { skill in
                context.logsForSkill(skill)
            },
            gameNameForID: { gameID in
                context.gameNameForID(gameID)
            },
            maxHistoryHeight: context.maxHistoryHeight,
            onLogMechanicsSession: { skill, comfort, note in
                context.onLogMechanicsSession(skill, comfort, note)
            }
        )
    }

    func settingsScreen(context: PracticeSettingsContext) -> some View {
        PracticeSettingsSectionView(
            playerName: context.playerName,
            ifpaPlayerID: context.ifpaPlayerID,
            leaguePlayerName: context.leaguePlayerName,
            leaguePlayerOptions: context.leaguePlayerOptions,
            leagueImportStatus: context.leagueImportStatus,
            importedLeagueScoreCount: context.importedLeagueScoreCount,
            cloudSyncEnabled: context.cloudSyncEnabled,
            redactName: { name in context.redactName(name) },
            onSaveProfile: {
                let trimmedName = context.playerName.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                context.playerName.wrappedValue = trimmedName
                context.store.updatePracticeSettings(playerName: trimmedName)
                guard !trimmedName.isEmpty else { return }
                Task {
                    guard let identity = await context.store.approvedLeagueIdentityMatch(for: trimmedName) else { return }
                    guard let ifpaPlayerID = identity.ifpaPlayerID else { return }
                    context.ifpaPlayerID.wrappedValue = ifpaPlayerID
                    context.store.updatePracticeSettings(ifpaPlayerID: ifpaPlayerID)
                }
            },
            onSaveIFPAID: {
                let sanitized = context.ifpaPlayerID.wrappedValue.filter(\.isNumber)
                context.ifpaPlayerID.wrappedValue = sanitized
                context.store.updatePracticeSettings(ifpaPlayerID: sanitized)
            },
            onImportLeagueCSV: {
                context.onImportLeagueCSV()
            },
            onLeaguePlayerSelected: { playerName in
                context.onLeaguePlayerSelected(playerName)
            },
            onCloudSyncChanged: { enabled in
                context.store.updateSyncSettings(cloudSyncEnabled: enabled)
            },
            onClearImportedLeagueScores: {
                context.onClearImportedLeagueScores()
            },
            onResetPracticeLog: {
                context.onResetPracticeLog()
            }
        )
    }

    func mechanicsHistoryMaxHeight() -> CGFloat {
        let height = uiState.viewportHeight > 0 ? uiState.viewportHeight : 800
        return max(200, height - 470)
    }
}
