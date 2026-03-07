import SwiftUI

struct PracticeScreen: View {
    @StateObject var store = PracticeStore()
    @EnvironmentObject var appNavigation: AppNavigationModel
    @Namespace var gameTransition

    @State var uiState = PracticeScreenState()

    @AppStorage("practice-journal-filter") var journalFilterRaw: String = JournalFilter.all.rawValue
    @AppStorage("practice-quick-game-score") var quickScoreGameID: String = ""
    @AppStorage("practice-quick-game-study") var quickStudyGameID: String = ""
    @AppStorage("practice-quick-game-practice") var quickPracticeGameID: String = ""
    @AppStorage("practice-quick-game-mechanics") var quickMechanicsGameID: String = ""
    @AppStorage("practice-last-viewed-game-id") var practiceLastViewedGameID: String = ""
    @AppStorage("practice-last-viewed-game-ts") var practiceLastViewedGameTS: Double = 0
    @AppStorage("library-last-viewed-game-ts") var libraryLastViewedGameTS: Double = 0
    @AppStorage("practice-name-prompted") var practiceNamePrompted = false

    @State var hasRunInitialPracticeLoad = false
    struct TimelineItem: Identifiable {
        let id: String
        let gameID: String
        let summary: String
        let icon: String
        let timestamp: Date
        let journalEntry: JournalEntry?
    }

    var resumeGame: PinballGame? {
        let libraryID = appNavigation.lastViewedLibraryGameID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let practiceID = practiceLastViewedGameID.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateID: String
        if libraryLastViewedGameTS >= practiceLastViewedGameTS {
            candidateID = libraryID.isEmpty ? practiceID : libraryID
        } else {
            candidateID = practiceID.isEmpty ? libraryID : practiceID
        }
        if !candidateID.isEmpty,
           let match = store.gameForAnyID(candidateID) {
            return match
        }
        return defaultPracticeGame
    }

    var defaultPracticeGame: PinballGame? {
        return orderedGamesForDropdown(store.games, collapseByPracticeIdentity: true).first
    }

    var selectedGroup: CustomGameGroup? {
        store.selectedGroup()
    }

    var greetingName: String? {
        let trimmed = uiState.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let redacted = redactPlayerNameForDisplay(trimmed)
        if redacted != trimmed {
            return redacted
        }
        let first = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        return first.isEmpty ? nil : first
    }

    var filteredJournalEntries: [JournalEntry] {
        let all = store.allJournalEntries()
        switch journalFilter {
        case .all:
            return all
        case .study:
            return all.filter { [.rulesheetRead, .tutorialWatch, .gameplayWatch, .playfieldViewed].contains($0.action) }
        case .practice:
            return all.filter { $0.action == .practiceSession }
        case .score:
            return all.filter { $0.action == .scoreLogged }
        case .notes:
            return all.filter { $0.action == .noteAdded }
        case .league:
            return all.filter { entry in
                entry.action == .scoreLogged && (entry.scoreContext == .league || (entry.note ?? "").localizedCaseInsensitiveContains("league import"))
            }
        }
    }

    var filteredLibraryActivities: [LibraryActivityEvent] {
        let all = LibraryActivityLog.events()
        switch journalFilter {
        case .all:
            return all
        case .study:
            return all.filter { [.openRulesheet, .openPlayfield, .tapVideo].contains($0.kind) }
        case .practice, .score, .notes, .league:
            return []
        }
    }

    var timelineItems: [TimelineItem] {
        let appItems = filteredJournalEntries.map { entry in
            TimelineItem(
                id: "app-\(entry.id.uuidString)",
                gameID: entry.gameID,
                summary: store.journalSummary(for: entry),
                icon: actionIcon(entry.action),
                timestamp: entry.timestamp,
                journalEntry: entry
            )
        }
        let libraryItems = filteredLibraryActivities.map { event in
            TimelineItem(
                id: "library-\(event.id.uuidString)",
                gameID: event.gameID,
                summary: libraryActivitySummary(event),
                icon: libraryActivityIcon(event.kind),
                timestamp: event.timestamp,
                journalEntry: nil
            )
        }
        return (appItems + libraryItems).sorted { $0.timestamp > $1.timestamp }
    }

    var journalSectionItems: [PracticeJournalItem] {
        timelineItems.map { item in
            PracticeJournalItem(
                id: item.id,
                gameID: item.gameID,
                summary: item.summary,
                icon: item.icon,
                timestamp: item.timestamp,
                journalEntry: item.journalEntry
            )
        }
    }

    var journalFilter: JournalFilter {
        JournalFilter(rawValue: journalFilterRaw) ?? .all
    }

    var body: some View {
        NavigationStack(path: $uiState.gameNavigationPath) {
            practiceDialogHost(practiceRootContent)
        }
    }

    var practiceHomeContext: PracticeHomeContext {
        PracticeHomeContext(
            store: store,
            greetingName: greetingName,
            hasIFPAProfileAccess: !uiState.ifpaPlayerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            resumeGame: resumeGame,
            allGames: store.games,
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
            onOpenSettings: {
                openRoute(.settings)
            },
            onOpenIFPAProfile: {
                openRoute(.ifpaProfile)
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
                guard shouldImportLplStats else { return }
                Task {
                    let normalizedInput = store.normalizeHumanName(trimmedName)
                    let players = await store.availableLeaguePlayers()
                    guard let matchedPlayer = players.first(where: {
                        store.normalizeHumanName($0) == normalizedInput
                    }) else { return }
                    uiState.leaguePlayerName = matchedPlayer
                    store.updateLeagueSettings(playerName: matchedPlayer, csvAutoFillEnabled: true)
                    _ = await store.importLeagueScoresFromCSV()
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
            items: journalSectionItems,
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
            leaguePlayerOptions: uiState.leaguePlayerOptions,
            leagueImportStatus: uiState.leagueImportStatus,
            cloudSyncEnabled: $uiState.cloudSyncEnabled,
            redactName: { name in
                formatLPLPlayerNameForDisplay(name)
            },
            onImportLeagueCSV: {
                Task {
                    store.updateLeagueSettings(playerName: uiState.leaguePlayerName, csvAutoFillEnabled: true)
                    let result = await store.importLeagueScoresFromCSV()
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
            editingGroupID: uiState.editingGroupID,
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
            onDismissGroupEditor: {
                uiState.presentedSheet = nil
                uiState.editingGroupID = nil
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
            lastViewedLibraryGameID: appNavigation.lastViewedLibraryGameID,
            journalFilterRaw: journalFilterRaw,
            presentedSheet: uiState.presentedSheet,
            onInitialLoad: {
                guard !hasRunInitialPracticeLoad else { return }
                hasRunInitialPracticeLoad = true
                await store.loadIfNeeded()
                applyDefaultsAfterLoad()
                await refreshLeaguePlayerOptions()
                await refreshHeadToHead()
                let trimmedName = uiState.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedName.isEmpty {
                    uiState.firstNamePromptValue = ""
                    uiState.importLplStatsOnNameSave = true
                    uiState.showingNamePrompt = true
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


#Preview {
    PracticeScreen()
}
