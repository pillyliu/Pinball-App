import SwiftUI

extension PracticeScreen {
    @ViewBuilder
    func destinationView(for destination: PracticeHubDestination) -> some View {
        switch destination {
        case .groupDashboard:
            practiceScreen("Group Dashboard") {
                groupDashboardScreen
            }
        case .journal:
            practiceViewportScreen("Journal Timeline") {
                journalScreen
            }
        case .insights:
            practiceScreen("Insights") {
                insightsScreen
            }
        case .mechanics:
            practiceScreen("Mechanics") {
                mechanicsScreen
            }
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
        .background(AppBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    func practiceViewportScreen<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    var groupDashboardScreen: some View {
        PracticeGroupDashboardSectionView(
            selectedGroup: selectedGroup,
            allGroups: store.state.customGroups,
            selectedGroupID: selectedGroup?.id,
            gameTransition: gameTransition,
            onOpenCreateGroup: {
                openGroupEditorForCreate()
            },
            onOpenEditSelectedGroup: {
                openGroupEditorForSelection()
            },
            onSelectGroup: { groupID in
                store.setSelectedGroup(id: groupID)
            },
            onTogglePriority: { groupID, isPriority in
                store.updateGroup(id: groupID, isPriority: isPriority)
            },
            onUpdateGroupDate: { groupID, field, date in
                switch field {
                case .start:
                    store.updateGroup(id: groupID, replaceStartDate: true, startDate: date)
                case .end:
                    store.updateGroup(id: groupID, replaceEndDate: true, endDate: date)
                }
            },
            dashboardScoreForGroup: { group in
                store.groupDashboardScore(for: group)
            },
            recommendedGameForGroup: { group in
                store.recommendedGame(in: group)
            },
            groupProgressForGroup: { group in
                store.groupProgress(for: group)
            },
            onOpenGame: { gameID in
                goToGame(gameID)
            },
            onRemoveGameFromGroup: { gameID, groupID in
                store.removeGame(gameID, fromGroup: groupID)
            }
        )
    }

    var journalScreen: some View {
        PracticeJournalSectionView(
            journalFilter: Binding(
                get: { journalFilter },
                set: { journalFilterRaw = $0.rawValue }
            ),
            items: journalSectionItems,
            gameTransition: gameTransition,
            onTapItem: { gameID in goToGame(gameID) }
        )
    }

    var insightsScreen: some View {
        PracticeInsightsSectionView(
            games: store.games,
            selectedGameID: $selectedGameID,
            scoreSummaryForGame: { gameID in
                store.scoreSummary(for: gameID)
            },
            scoreTrendValuesForGame: { gameID in
                scoreTrendValues(for: gameID)
            },
            playerName: playerName,
            opponentName: $insightsOpponentName,
            opponentOptions: insightsOpponentOptions,
            isLoadingHeadToHead: isLoadingHeadToHead,
            headToHead: headToHead,
            redactName: { name in
                redactPlayerNameForDisplay(name)
            },
            onRefreshHeadToHead: {
                await refreshHeadToHead()
            },
            onRefreshOpponentOptions: {
                await refreshInsightsOpponentOptions()
            }
        )
    }

    var mechanicsScreen: some View {
        PracticeMechanicsSectionView(
            selectedMechanicSkill: $selectedMechanicSkill,
            mechanicsComfort: $mechanicsComfort,
            mechanicsNote: $mechanicsNote,
            trackedSkills: store.allTrackedMechanicsSkills(),
            detectedTags: store.detectedMechanicsTags(in: mechanicsNote),
            summaryForSkill: { skill in
                store.mechanicsSummary(for: skill)
            },
            logsForSkill: { skill in
                store.mechanicsLogs(for: skill)
            },
            gameNameForID: { gameID in
                store.gameName(for: gameID)
            },
            maxHistoryHeight: mechanicsHistoryMaxHeight(),
            onLogMechanicsSession: { skill, comfort, note in
                let targetGameID = selectedGameID.isEmpty ? (orderedGamesForDropdown(store.games).first?.id ?? "") : selectedGameID
                guard !targetGameID.isEmpty else { return }

                let prefix = skill.isEmpty ? "#mechanics" : "#\(skill.replacingOccurrences(of: " ", with: ""))"
                let fullNote = "\(prefix) competency \(comfort)/5. \(note)"
                store.addNote(gameID: targetGameID, category: .general, detail: skill, note: fullNote)
                mechanicsNote = ""
            }
        )
    }

    var settingsScreen: some View {
        PracticeSettingsSectionView(
            playerName: $playerName,
            leaguePlayerName: $leaguePlayerName,
            leaguePlayerOptions: leaguePlayerOptions,
            leagueImportStatus: leagueImportStatus,
            cloudSyncEnabled: $cloudSyncEnabled,
            redactName: { name in redactPlayerNameForDisplay(name) },
            onSaveProfile: {
                store.updatePracticeSettings(playerName: playerName)
            },
            onImportLeagueCSV: {
                Task {
                    store.updateLeagueSettings(playerName: leaguePlayerName, csvAutoFillEnabled: true)
                    let result = await store.importLeagueScoresFromCSV()
                    leagueImportStatus = result.summaryLine
                }
            },
            onCloudSyncChanged: { enabled in
                store.updateSyncSettings(cloudSyncEnabled: enabled)
            },
            onResetPracticeLog: {
                resetJournalConfirmationText = ""
                showingResetJournalPrompt = true
            }
        )
    }

    func mechanicsHistoryMaxHeight() -> CGFloat {
        let height = viewportHeight > 0 ? viewportHeight : 800
        return max(200, height - 470)
    }
}
