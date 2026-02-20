import SwiftUI

extension PracticeScreen {
    var practiceRootContent: some View {
        PracticeHomeRootView(
            isLoadingGames: store.isLoadingGames,
            greetingName: greetingName,
            onOpenSettings: {
                openPracticeSettings = true
            },
            resumeGame: resumeGame,
            allGames: store.games,
            activeGroups: store.state.customGroups.filter(\.isActive),
            selectedGroupID: selectedGroup?.id,
            groupGames: { group in
                store.groupGames(for: group)
            },
            gameTransition: gameTransition,
            onResume: {
                resumeToPracticeGame()
            },
            onPickGame: { gameID in
                goToGame(gameID)
            },
            onQuickEntry: { sheet in
                openQuickEntry(sheet)
            },
            showingNamePrompt: showingNamePrompt,
            firstNamePromptValue: $firstNamePromptValue,
            importLplStatsOnNameSave: $importLplStatsOnNameSave,
            onNotNow: {
                practiceNamePrompted = true
                showingNamePrompt = false
            },
            onSaveName: { trimmedName, shouldImportLplStats in
                playerName = trimmedName
                store.updatePracticeSettings(playerName: trimmedName)
                practiceNamePrompted = true
                showingNamePrompt = false
                guard shouldImportLplStats else { return }
                Task {
                    let normalizedInput = store.normalizeHumanName(trimmedName)
                    let players = await store.availableLeaguePlayers()
                    guard let matchedPlayer = players.first(where: {
                        store.normalizeHumanName($0) == normalizedInput
                    }) else { return }
                    leaguePlayerName = matchedPlayer
                    store.updateLeagueSettings(playerName: matchedPlayer, csvAutoFillEnabled: true)
                    _ = await store.importLeagueScoresFromCSV()
                }
            }
        )
        .toolbar(.hidden, for: .navigationBar)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        viewportHeight = geo.size.height
                    }
                    .onChange(of: geo.size.height) { _, newHeight in
                        viewportHeight = newHeight
                }
            }
        )
        .sheet(item: $quickSheet) { kind in
            PracticeQuickEntrySheet(
                kind: kind,
                store: store,
                selectedGameID: $selectedGameID,
                onGameSelectionChanged: { sheet, gameID in
                    rememberQuickEntryGame(sheet: sheet, gameID: gameID)
                },
                onEntrySaved: { gameID in
                    markPracticeGameViewed(gameID)
                }
            )
            .practiceEntrySheetStyle()
        }
    }

    func practiceDialogHost<Content: View>(_ content: Content) -> some View {
        content
            .navigationDestination(for: PracticeNavRoute.self) { route in
                switch route {
                case .destination(let destination):
                    destinationView(for: destination)
                case .game(let gameID):
                    PracticeGameWorkspace(store: store, selectedGameID: $selectedGameID, onGameViewed: { viewedGameID in
                        markPracticeGameViewed(viewedGameID)
                    })
                    .onAppear { selectedGameID = gameID }
                    .navigationTransition(.zoom(sourceID: gameID, in: gameTransition))
                }
            }
            .navigationDestination(isPresented: $openPracticeSettings) {
                practiceScreen("Practice Settings") {
                    settingsScreen
                }
                .alert("Reset Practice Log?", isPresented: $showingResetJournalPrompt) {
                    TextField("Type reset", text: $resetJournalConfirmationText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("No", role: .cancel) {}
                    Button("Yes, Reset", role: .destructive) {
                        resetJournalConfirmationText = ""
                        store.resetPracticeState()
                        applyDefaultsAfterLoad()
                        LibraryActivityLog.clearAll()
                    }
                    .disabled(resetJournalConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "reset")
                } message: {
                    Text("This resets the full local Practice JSON log state. Type \"reset\" to enable confirmation.")
                }
            }
            .sheet(isPresented: $openGroupEditor) {
                NavigationStack {
                    GroupEditorScreen(
                        store: store,
                        editingGroupID: editingGroupID
                    ) {
                        openGroupEditor = false
                        editingGroupID = nil
                    }
                }
                .practiceEntrySheetStyle()
                .presentationBackground(.ultraThinMaterial)
                .presentationDetents([.large])
            }
            .sheet(isPresented: $openCurrentGroupDateEditor) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker(
                            currentGroupDateEditorField == .start ? "Start Date" : "End Date",
                            selection: $currentGroupDateEditorValue,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)

                        HStack {
                            Button("Clear", role: .destructive) {
                                guard let groupID = currentGroupDateEditorGroupID else {
                                    openCurrentGroupDateEditor = false
                                    return
                                }
                                switch currentGroupDateEditorField {
                                case .start:
                                    store.updateGroup(id: groupID, replaceStartDate: true, startDate: nil)
                                case .end:
                                    store.updateGroup(id: groupID, replaceEndDate: true, endDate: nil)
                                }
                                openCurrentGroupDateEditor = false
                            }
                            .buttonStyle(.glass)

                            Spacer()

                            Button("Save") {
                                guard let groupID = currentGroupDateEditorGroupID else {
                                    openCurrentGroupDateEditor = false
                                    return
                                }
                                switch currentGroupDateEditorField {
                                case .start:
                                    store.updateGroup(id: groupID, replaceStartDate: true, startDate: currentGroupDateEditorValue)
                                case .end:
                                    store.updateGroup(id: groupID, replaceEndDate: true, endDate: currentGroupDateEditorValue)
                                }
                                openCurrentGroupDateEditor = false
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppBackground())
                    .navigationTitle(currentGroupDateEditorField == .start ? "Set Start Date" : "Set End Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                openCurrentGroupDateEditor = false
                            }
                        }
                    }
                }
                .practiceEntrySheetStyle()
                .presentationBackground(.ultraThinMaterial)
            }
            .task {
                await store.loadIfNeeded()
                applyDefaultsAfterLoad()
                await refreshLeaguePlayerOptions()
                await refreshHeadToHead()
                let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedName.isEmpty {
                    firstNamePromptValue = ""
                    importLplStatsOnNameSave = true
                    showingNamePrompt = true
                }
            }
            .onChange(of: appNavigation.lastViewedLibraryGameID) { _, newValue in
                let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !trimmed.isEmpty else { return }
                libraryLastViewedGameTS = Date().timeIntervalSince1970
            }
    }
}
