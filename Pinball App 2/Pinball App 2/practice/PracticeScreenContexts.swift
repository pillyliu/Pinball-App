import SwiftUI

extension PracticeScreen {
    var practiceHomeContext: PracticeHomeContext {
        PracticeHomeContext(
            store: store,
            greetingName: greetingName,
            hasIFPAProfileAccess: !uiState.ifpaPlayerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            resumeGame: resumeGame,
            allGames: store.games,
            searchGames: store.searchCatalogGames,
            librarySources: store.librarySources,
            selectedLibrarySourceID: store.defaultPracticeSourceID,
            activeGroups: store.state.customGroups.filter { $0.isActive && !$0.isArchived },
            selectedGroupID: selectedGroup?.id,
            groupGames: { group in
                store.groupGames(for: group)
            },
            gameTransition: gameTransition,
            showingNamePrompt: uiState.showingNamePrompt,
            firstNamePromptValue: $uiState.firstNamePromptValue,
            importLplStatsOnNameSave: $uiState.importLplStatsOnNameSave,
            onOpenSearch: {
                openRoute(.search)
            },
            onOpenSettings: {
                openRoute(.settings)
            },
            onOpenIFPAProfile: {
                openRoute(.ifpaProfile)
            },
            onOpenHubRoute: { route in
                openRoute(route)
            },
            onResume: { sourceID in
                resumeToPracticeGame(zoomSourceID: sourceID)
            },
            onSelectLibrarySource: { sourceID in
                let normalizedSourceID = (sourceID == "__practice_home_all_games__") ? nil : sourceID
                store.selectPracticeLibrarySource(id: normalizedSourceID)
                if store.gameForAnyID(uiState.selectedGameID) == nil || !store.games.contains(where: { $0.canonicalPracticeKey == store.canonicalPracticeGameID(uiState.selectedGameID) }) {
                    uiState.selectedGameID = orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true).first?.canonicalPracticeKey ?? ""
                }
            },
            onPickGame: { gameID, sourceID in
                goToGame(gameID, zoomSourceID: sourceID)
            },
            onQuickEntry: { sheet in
                openQuickEntry(sheet)
            },
            onNotNow: {
                practiceNamePrompted = true
                uiState.showingNamePrompt = false
            },
            onSaveName: { trimmedName, shouldImportLplStats in
                uiState.playerName = trimmedName
                store.updatePracticeSettings(playerName: trimmedName)
                practiceNamePrompted = true
                uiState.showingNamePrompt = false
                Task {
                    let identity = await store.approvedLeagueIdentityMatch(
                        for: trimmedName,
                        forceRefresh: shouldImportLplStats
                    )
                    if let ifpaPlayerID = identity?.ifpaPlayerID {
                        uiState.ifpaPlayerID = ifpaPlayerID
                        store.updatePracticeSettings(ifpaPlayerID: ifpaPlayerID)
                    }
                    guard shouldImportLplStats else { return }
                    guard let matchedPlayer = identity?.player else { return }
                    uiState.leaguePlayerName = matchedPlayer
                    store.updateLeagueSettings(playerName: matchedPlayer, csvAutoFillEnabled: true)
                    _ = await store.importLeagueScoresFromCSV(forceRefresh: true)
                }
            },
            onViewportHeightChanged: { height in
                uiState.viewportHeight = height
            }
        )
    }

    var practiceGroupDashboardContext: PracticeGroupDashboardContext {
        PracticeGroupDashboardContext(
            store: store,
            selectedGroup: selectedGroup,
            gameTransition: gameTransition,
            onOpenCreateGroup: {
                openGroupEditorForCreate()
            },
            onOpenEditSelectedGroup: {
                openGroupEditorForSelection()
            },
            onOpenGame: { gameID, sourceID in
                goToGame(gameID, zoomSourceID: sourceID)
            },
            onRemoveGameFromGroup: { gameID, groupID in
                store.removeGame(gameID, fromGroup: groupID)
            }
        )
    }

    var practiceJournalContext: PracticeJournalContext {
        PracticeJournalContext(
            journalFilter: Binding(
                get: { journalFilter },
                set: { journalFilterRaw = $0.rawValue }
            ),
            sections: journalSections,
            isEditingEntries: $uiState.isEditingJournalEntries,
            selectedItemIDs: $uiState.selectedJournalItemIDs,
            gameTransition: gameTransition,
            onToggleEditing: {
                uiState.selectedJournalItemIDs.removeAll()
                uiState.isEditingJournalEntries.toggle()
            },
            onOpenGame: { gameID, sourceID in
                goToGame(gameID, zoomSourceID: sourceID)
            },
            onEditJournalEntry: { entry in
                openJournalEntryEditor(entry)
            },
            onDeleteJournalEntries: { entries in
                deleteJournalEntries(entries)
            }
        )
    }

    var practiceMechanicsContext: PracticeMechanicsContext {
        PracticeMechanicsContext(
            selectedMechanicSkill: $uiState.selectedMechanicSkill,
            mechanicsComfort: $uiState.mechanicsComfort,
            mechanicsNote: $uiState.mechanicsNote,
            trackedSkills: store.allTrackedMechanicsSkills(),
            detectedTags: store.detectedMechanicsTags(in: uiState.mechanicsNote),
            summaryForSkill: { skill in
                store.mechanicsSummary(for: skill)
            },
            allLogs: {
                store.allMechanicsLogs()
            },
            logsForSkill: { skill in
                store.mechanicsLogs(for: skill)
            },
            gameNameForID: { gameID in
                store.gameName(for: gameID)
            },
            maxHistoryHeight: mechanicsHistoryMaxHeight(),
            onLogMechanicsSession: { skill, comfort, note in
                let prefix = skill.isEmpty ? "#mechanics" : "#\(skill.replacingOccurrences(of: " ", with: ""))"
                let fullNote = "\(prefix) competency \(comfort)/5. \(note)"
                store.addNote(gameID: "", category: .general, detail: skill, note: fullNote)
                uiState.mechanicsNote = ""
            }
        )
    }

    var practiceSettingsContext: PracticeSettingsContext {
        PracticeSettingsContext(
            store: store,
            playerName: $uiState.playerName,
            ifpaPlayerID: $uiState.ifpaPlayerID,
            leaguePlayerName: $uiState.leaguePlayerName,
            leagueCsvAutoFillEnabled: Binding(
                get: { store.state.leagueSettings.csvAutoFillEnabled },
                set: { isEnabled in
                    store.updateLeagueSettings(
                        playerName: uiState.leaguePlayerName,
                        csvAutoFillEnabled: isEnabled
                    )
                }
            ),
            leaguePlayerOptions: uiState.leaguePlayerOptions,
            leagueImportStatus: uiState.leagueImportStatus,
            cloudSyncEnabled: $uiState.cloudSyncEnabled,
            redactName: { name in
                formatLPLPlayerNameForDisplay(name)
            },
            onLeaguePlayerSelected: { selectedPlayer in
                uiState.leaguePlayerName = selectedPlayer
                store.updateLeagueSettings(
                    playerName: selectedPlayer,
                    csvAutoFillEnabled: store.state.leagueSettings.csvAutoFillEnabled
                )
                guard !selectedPlayer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task {
                    guard let identity = await store.approvedLeagueIdentityMatch(for: selectedPlayer) else { return }
                    guard let ifpaPlayerID = identity.ifpaPlayerID else { return }
                    uiState.ifpaPlayerID = ifpaPlayerID
                    store.updatePracticeSettings(ifpaPlayerID: ifpaPlayerID)
                }
            },
            onImportLeagueCSV: {
                Task {
                    store.updateLeagueSettings(
                        playerName: uiState.leaguePlayerName,
                        csvAutoFillEnabled: store.state.leagueSettings.csvAutoFillEnabled
                    )
                    let result = await store.importLeagueScoresFromCSV(forceRefresh: true)
                    uiState.leagueImportStatus = result.summaryLine
                }
            },
            onResetPracticeLog: {
                uiState.resetJournalConfirmationText = ""
                uiState.showingResetJournalPrompt = true
            }
        )
    }

    var practicePresentationContext: PracticePresentationContext {
        PracticePresentationContext(
            store: store,
            selectedGameID: $uiState.selectedGameID,
            presentedSheet: $uiState.presentedSheet,
            quickEntryKind: uiState.quickEntryKind,
            currentGroupDateEditorTitle: uiState.currentGroupDateEditorField == .start ? "Start Date" : "End Date",
            currentGroupDateEditorValue: $uiState.currentGroupDateEditorValue,
            editingJournalEntry: uiState.editingJournalEntry,
            showingResetJournalPrompt: $uiState.showingResetJournalPrompt,
            resetJournalConfirmationText: $uiState.resetJournalConfirmationText,
            onRememberQuickEntryGame: { sheet, gameID in
                rememberQuickEntryGame(sheet: sheet, gameID: gameID)
            },
            onMarkGameViewed: { gameID in
                markPracticeGameViewed(gameID)
            },
            onDismissPresentedSheet: {
                uiState.presentedSheet = nil
            },
            onClearEditedGroupDate: {
                guard let groupID = uiState.currentGroupDateEditorGroupID else {
                    uiState.presentedSheet = nil
                    return
                }
                switch uiState.currentGroupDateEditorField {
                case .start:
                    store.updateGroup(id: groupID, replaceStartDate: true, startDate: nil)
                case .end:
                    store.updateGroup(id: groupID, replaceEndDate: true, endDate: nil)
                }
                uiState.presentedSheet = nil
            },
            onSaveEditedGroupDate: {
                guard let groupID = uiState.currentGroupDateEditorGroupID else {
                    uiState.presentedSheet = nil
                    return
                }
                switch uiState.currentGroupDateEditorField {
                case .start:
                    store.updateGroup(id: groupID, replaceStartDate: true, startDate: uiState.currentGroupDateEditorValue)
                case .end:
                    store.updateGroup(id: groupID, replaceEndDate: true, endDate: uiState.currentGroupDateEditorValue)
                }
                uiState.presentedSheet = nil
            },
            onSaveEditedJournalEntry: { entry in
                saveEditedJournalEntry(entry)
            },
            onConfirmResetPracticeLog: {
                uiState.resetJournalConfirmationText = ""
                store.resetPracticeState()
                applyDefaultsAfterLoad()
                LibraryActivityLog.clearAll()
            },
            onPresentedSheetDismissed: {
                uiState.quickEntryKind = nil
                uiState.editingJournalEntry = nil
                uiState.editingGroupID = nil
            }
        )
    }

    var practiceLifecycleContext: PracticeLifecycleContext {
        PracticeLifecycleContext(
            scenePhase: scenePhase,
            lastViewedLibraryGameID: appNavigation.lastViewedLibraryGameID,
            journalFilterRaw: journalFilterRaw,
            presentedSheet: uiState.presentedSheet,
            onInitialLoad: {
                guard !hasRunInitialPracticeLoad else { return }
                hasRunInitialPracticeLoad = true
                await Task.yield()
                try? await Task.sleep(nanoseconds: 180_000_000)
                await store.loadIfNeeded()
                applyDefaultsAfterLoad()
                if let result = await store.autoImportLeagueScoresIfNeeded(forceRefresh: true) {
                    uiState.leagueImportStatus = result.summaryLine
                }
                let trimmedName = uiState.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedName.isEmpty {
                    uiState.firstNamePromptValue = ""
                    uiState.importLplStatsOnNameSave = true
                    uiState.showingNamePrompt = true
                }
            },
            onScenePhaseChanged: { phase in
                guard phase == .active else { return }
                if let result = await store.autoImportLeagueScoresIfNeeded(forceRefresh: true) {
                    uiState.leagueImportStatus = result.summaryLine
                }
            },
            onLibraryGameViewedChanged: { newValue in
                let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !trimmed.isEmpty else { return }
                libraryLastViewedGameTS = Date().timeIntervalSince1970
            },
            onJournalFilterChanged: {
                uiState.selectedJournalItemIDs.removeAll()
                uiState.isEditingJournalEntries = false
            },
            onPresentedSheetChanged: { newValue in
                guard newValue == nil else { return }
                practicePresentationContext.onPresentedSheetDismissed()
            },
            onLibrarySourcesChanged: {
                await store.loadGames()
                await store.ensureSearchCatalogGamesLoadedForStoredReferencesIfNeeded()
                applyDefaultsAfterLoad()
            }
        )
    }

    var practiceInsightsContext: PracticeInsightsContext {
        PracticeInsightsContext(
            games: store.games,
            librarySources: store.librarySources,
            selectedLibrarySourceID: store.defaultPracticeSourceID,
            onSelectLibrarySourceID: { sourceID in
                store.selectPracticeLibrarySource(id: sourceID)
                let canonical = store.canonicalPracticeGameID(uiState.selectedGameID)
                if !canonical.isEmpty,
                   store.games.contains(where: { $0.canonicalPracticeKey == canonical }) {
                    uiState.selectedGameID = canonical
                } else {
                    uiState.selectedGameID = orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true).first?.canonicalPracticeKey ?? ""
                }
            },
            selectedGameID: $uiState.selectedGameID,
            scoreSummaryForGame: { gameID in
                store.scoreSummary(for: gameID)
            },
            scoreTrendValuesForGame: { gameID in
                scoreTrendValues(for: gameID)
            },
            playerName: uiState.playerName,
            opponentName: $uiState.insightsOpponentName,
            opponentOptions: uiState.insightsOpponentOptions,
            isLoadingHeadToHead: uiState.isLoadingHeadToHead,
            headToHead: uiState.headToHead,
            redactName: { name in
                formatLPLPlayerNameForDisplay(name)
            },
            onRefreshHeadToHead: {
                await refreshHeadToHead()
            },
            onRefreshOpponentOptions: {
                await refreshInsightsOpponentOptions()
            }
        )
    }
}
