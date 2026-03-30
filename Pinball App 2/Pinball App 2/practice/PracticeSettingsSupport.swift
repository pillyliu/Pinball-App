import SwiftUI

struct PracticeSettingsSectionView: View {
    @Binding var playerName: String
    @Binding var ifpaPlayerID: String
    @Binding var leaguePlayerName: String
    let leaguePlayerOptions: [String]
    let leagueImportStatus: String
    let importedLeagueScoreCount: Int
    let onSaveProfile: () -> Void
    let onSaveIFPAID: () -> Void
    let onImportLeagueCSV: () -> Void
    let onLeaguePlayerSelected: (String) -> Void
    let onClearImportedLeagueScores: () -> Void
    let onResetPracticeLog: () -> Void
    @AppStorage(LPLNamePrivacySettings.showFullLastNameDefaultsKey) private var showFullLPLLastNames = false
    @State private var showingResetPracticeLogPrompt = false
    @State private var resetPracticeLogConfirmationText = ""
    @State private var showingClearImportedLeagueScoresPrompt = false

    var body: some View {
        settingsCards
            .frame(maxWidth: .infinity, alignment: .leading)
            .alert("Clear Imported League Scores?", isPresented: $showingClearImportedLeagueScoresPrompt) {
                Button("Cancel", role: .cancel) {}
                Button(clearImportedLeagueScoresButtonTitle(importedLeagueScoreCount), role: .destructive) {
                    onClearImportedLeagueScores()
                }
            } message: {
                Text(clearImportedLeagueScoresAlertMessage(importedLeagueScoreCount))
            }
            .alert("Reset Practice Log?", isPresented: $showingResetPracticeLogPrompt) {
                TextField("Type reset", text: $resetPracticeLogConfirmationText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("No", role: .cancel) {}
                Button("Yes, Reset", role: .destructive) {
                    onResetPracticeLog()
                }
                .disabled(!canConfirmResetPracticeLog)
            } message: {
                Text("This resets the full local Practice JSON log state. Type \"reset\" to enable confirmation.")
            }
    }

    private var settingsCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            PracticeProfileSettingsCard(
                playerName: $playerName,
                onSaveProfile: onSaveProfile
            )
            PracticeIFPASettingsCard(
                ifpaPlayerID: $ifpaPlayerID,
                onSaveIFPAID: onSaveIFPAID
            )
            PracticeLeagueImportSettingsCard(
                leaguePlayerName: leaguePlayerName,
                leaguePlayerOptions: leaguePlayerOptions,
                leagueImportStatus: leagueImportStatus,
                onImportLeagueCSV: onImportLeagueCSV,
                onLeaguePlayerSelected: onLeaguePlayerSelected,
                displayLPLPlayerName: displayLPLPlayerName
            )
            PracticeRecoverySettingsCard(
                importedLeagueScoreCount: importedLeagueScoreCount,
                onClearImportedLeagueScoresRequested: presentClearImportedLeagueScoresPrompt,
                onResetPracticeLogRequested: presentResetPracticeLogPrompt
            )
        }
    }

    private var canConfirmResetPracticeLog: Bool {
        resetPracticeLogConfirmationText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "reset"
    }

    private func presentClearImportedLeagueScoresPrompt() {
        showingClearImportedLeagueScoresPrompt = true
    }

    private func presentResetPracticeLogPrompt() {
        resetPracticeLogConfirmationText = ""
        showingResetPracticeLogPrompt = true
    }

    private func displayLPLPlayerName(_ raw: String) -> String {
        formatLPLPlayerNameForDisplay(raw, showFullLastNames: showFullLPLLastNames)
    }
}

private struct PracticeSettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }
}

private struct PracticeProfileSettingsCard: View {
    @Binding var playerName: String
    let onSaveProfile: () -> Void

    var body: some View {
        PracticeSettingsCard {
            AppSectionTitle(text: "Practice Profile")

            TextField("Player name", text: $playerName)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            Button("Save Profile", action: onSaveProfile)
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(AppPrimaryActionButtonStyle())
        }
    }
}

private struct PracticeIFPASettingsCard: View {
    @Binding var ifpaPlayerID: String
    let onSaveIFPAID: () -> Void

    var body: some View {
        PracticeSettingsCard {
            AppSectionTitle(text: "IFPA")

            TextField("IFPA number", text: $ifpaPlayerID)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            Text("Save your IFPA player number to unlock a quick stats profile from the Practice home header.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Save IFPA ID", action: onSaveIFPAID)
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(AppPrimaryActionButtonStyle())
        }
    }
}

private struct PracticeLeagueImportSettingsCard: View {
    let leaguePlayerName: String
    let leaguePlayerOptions: [String]
    let leagueImportStatus: String
    let onImportLeagueCSV: () -> Void
    let onLeaguePlayerSelected: (String) -> Void
    let displayLPLPlayerName: (String) -> String

    var body: some View {
        PracticeSettingsCard {
            AppSectionTitle(text: "League Import")

            Menu {
                Button("Select league player") {
                    onLeaguePlayerSelected("")
                }
                if leaguePlayerOptions.isEmpty {
                    AppSelectableMenuRow(text: "No player names found", isSelected: false)
                } else {
                    ForEach(leaguePlayerOptions, id: \.self) { name in
                        Button(displayLPLPlayerName(name)) {
                            onLeaguePlayerSelected(name)
                        }
                    }
                }
            } label: {
                AppCompactDropdownLabel(text: leaguePlayerMenuLabel)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(practiceLeagueImportDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Import LPL CSV", action: onImportLeagueCSV)
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(AppPrimaryActionButtonStyle())
                .disabled(!hasSelectedLeaguePlayer)

            if !leagueImportStatus.isEmpty {
                Text(leagueImportStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var leaguePlayerMenuLabel: String {
        leaguePlayerName.isEmpty ? "Select league player" : displayLPLPlayerName(leaguePlayerName)
    }

    private var hasSelectedLeaguePlayer: Bool {
        !leaguePlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct PracticeRecoverySettingsCard: View {
    let importedLeagueScoreCount: Int
    let onClearImportedLeagueScoresRequested: () -> Void
    let onResetPracticeLogRequested: () -> Void

    var body: some View {
        PracticeSettingsCard {
            AppSectionTitle(text: "Recovery")

            Text(importedLeagueScoreSummary(importedLeagueScoreCount))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(clearImportedLeagueScoresButtonTitle(importedLeagueScoreCount), role: .destructive) {
                onClearImportedLeagueScoresRequested()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(AppDestructiveActionButtonStyle())
            .disabled(importedLeagueScoreCount == 0)

            Text("Erase the full local Practice log state.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Reset Practice Log", role: .destructive) {
                onResetPracticeLogRequested()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .buttonStyle(AppDestructiveActionButtonStyle())
        }
    }
}
