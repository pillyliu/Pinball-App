import SwiftUI

struct PracticeJournalItem: Identifiable {
    let id: String
    let gameID: String
    let summary: String
    let icon: String
    let timestamp: Date
}

struct PracticeJournalSectionView: View {
    @Binding var journalFilter: JournalFilter
    let items: [PracticeJournalItem]
    let gameTransition: Namespace.ID
    let onTapItem: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Filter", selection: $journalFilter) {
                ForEach(JournalFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                if items.isEmpty {
                    Text("No matching journal events.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    let grouped = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.timestamp) }
                    let days = grouped.keys.sorted(by: >)

                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 8, pinnedViews: [.sectionHeaders]) {
                            ForEach(days, id: \.self) { day in
                                Section {
                                    ForEach(grouped[day] ?? []) { entry in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: entry.icon)
                                                .font(.caption)
                                                .frame(width: 14)
                                                .foregroundStyle(.secondary)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(entry.summary)
                                                    .font(.footnote)
                                                    .foregroundStyle(.primary)
                                                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            onTapItem(entry.gameID)
                                        }
                                        .matchedTransitionSource(id: "\(entry.gameID)-\(entry.id)", in: gameTransition)
                                    }
                                } header: {
                                    Text(day.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.ultraThinMaterial.opacity(0.85))
                                }
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .appPanelStyle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct PracticeSettingsSectionView: View {
    @Binding var playerName: String
    @Binding var leaguePlayerName: String
    let leaguePlayerOptions: [String]
    let leagueImportStatus: String
    @Binding var cloudSyncEnabled: Bool
    let redactName: (String) -> String
    let onSaveProfile: () -> Void
    let onImportLeagueCSV: () -> Void
    let onCloudSyncChanged: (Bool) -> Void
    let onResetPracticeLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Practice Profile")
                    .font(.headline)

                TextField("Player name", text: $playerName)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                Button("Save Profile", action: onSaveProfile)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("League Import")
                    .font(.headline)

                Menu {
                    if leaguePlayerOptions.isEmpty {
                        Text("No player names found")
                    } else {
                        ForEach(leaguePlayerOptions, id: \.self) { name in
                            Button(redactName(name)) {
                                leaguePlayerName = name
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(leaguePlayerName.isEmpty ? "Select league player" : redactName(leaguePlayerName))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()
                }

                Text("Used when you tap Import LPL CSV.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Import LPL CSV", action: onImportLeagueCSV)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buttonStyle(.glass)
                    .disabled(leaguePlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !leagueImportStatus.isEmpty {
                    Text(leagueImportStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Defaults")
                    .font(.headline)

                Toggle("Enable optional cloud sync", isOn: $cloudSyncEnabled)
                    .onChange(of: cloudSyncEnabled) { _, newValue in
                        onCloudSyncChanged(newValue)
                    }
                Text("Placeholder for Phase 2 sync to pillyliu.com. Data stays on-device today.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Reset")
                    .font(.headline)

                Text("Erase the full local Practice log state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Reset Practice Log", role: .destructive, action: onResetPracticeLog)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.red)
                    .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
