import SwiftUI

private let practiceHomeAllGamesSourceMenuID = "__practice_home_all_games__"

struct PracticeHomeSection: View {
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
    @State private var resumeControlColumnHeight: CGFloat = 0

    var body: some View {
        let orderedAllGames = orderedGamesForDropdown(allGames, collapseByPracticeIdentity: true)
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                if let game = resumeGame {
                    HStack(spacing: 8) {
                        Button {
                            onResume(resumeTransitionSourceID(for: game.canonicalPracticeKey))
                        } label: {
                            ResumeSelectedGameCard(
                                game: game,
                                targetHeight: resumeControlColumnHeight > 0 ? resumeControlColumnHeight : nil
                            )
                            .matchedTransitionSource(id: resumeTransitionSourceID(for: game.canonicalPracticeKey), in: gameTransition)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Menu {
                                Button((selectedLibrarySourceID == nil ? "✓ " : "") + "All games") {
                                    onSelectLibrarySource(practiceHomeAllGamesSourceMenuID)
                                }
                                ForEach(librarySources) { source in
                                    Button((source.id == selectedLibrarySourceID ? "✓ " : "") + source.name) {
                                        onSelectLibrarySource(source.id)
                                    }
                                }
                            } label: {
                                resumeDropdownLabel(
                                    title: "Library",
                                    value: selectedLibraryLabel(librarySources: librarySources)
                                )
                            }
                            .buttonStyle(.plain)

                            Menu {
                                ForEach(orderedAllGames) { listGame in
                                    Button(listGame.name) {
                                        onPickGame(listGame.canonicalPracticeKey, nil)
                                    }
                                }
                            } label: {
                                resumeDropdownLabel(
                                    title: "Game List",
                                    value: game.name
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: 168, alignment: .leading)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ResumeControlColumnHeightPreferenceKey.self, value: geo.size.height)
                            }
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()
            .onPreferenceChange(ResumeControlColumnHeightPreferenceKey.self) { newHeight in
                guard newHeight > 0 else { return }
                resumeControlColumnHeight = newHeight
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Entry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    quickActionButton("Score", icon: "number.circle") { onQuickEntry(.score) }
                    quickActionButton("Study", icon: "book.circle") { onQuickEntry(.study) }
                    quickActionButton("Practice", icon: "figure.run.circle") { onQuickEntry(.practice) }
                    quickActionButton("Mechanics", icon: "circle.fill") { onQuickEntry(.mechanics) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 6) {
                if activeGroups.isEmpty {
                    Text("No active groups")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(activeGroups) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(group.name)
                                        .font(.subheadline.weight(.semibold))
                                    if group.id == selectedGroupID {
                                        Text("Selected")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.14), in: Capsule())
                                    }
                                }

                                let games = groupGames(group)
                                if games.isEmpty {
                                    Text("No games in this group.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(games) { game in
                                                Button {
                                                    onPickGame(game.canonicalPracticeKey, groupTransitionSourceID(for: game.canonicalPracticeKey))
                                                } label: {
                                                    SelectedGameMiniCard(game: game)
                                                        .matchedTransitionSource(id: groupTransitionSourceID(for: game.canonicalPracticeKey), in: gameTransition)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resumeDropdownLabel(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        )
    }

    private func selectedLibraryLabel(librarySources: [PinballLibrarySource]) -> String {
        if selectedLibrarySourceID == nil { return "All Games" }
        return librarySources.first(where: { $0.id == selectedLibrarySourceID })?.name ?? "All Games"
    }

    private func quickActionButton(_ text: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                Text(text)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .appControlStyle()
        }
        .buttonStyle(.plain)
    }

    private func resumeTransitionSourceID(for gameID: String) -> String {
        "home-resume-\(gameID)"
    }

    private func groupTransitionSourceID(for gameID: String) -> String {
        "home-group-\(gameID)"
    }
}

private struct ResumeControlColumnHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct PracticeWelcomeOverlay: View {
    @Binding var firstNamePromptValue: String
    @Binding var importLplStatsOnSave: Bool
    let onNotNow: () -> Void
    let onSave: (String, Bool) -> Void

    private func submit() {
        let trimmed = firstNamePromptValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed, importLplStatsOnSave)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to Practice")
                .font(.title3.weight(.bold))

            Text("Enter your player name to get started.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Player name", text: $firstNamePromptValue)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { submit() }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()

            Toggle("Import LPL stats", isOn: $importLplStatsOnSave)
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                overlaySectionRow("Home", detail: "Return to game, quick entry, active groups")
                overlaySectionRow("Group Dashboard", detail: "View and edit groups")
                overlaySectionRow("Insights", detail: "Scores, variance, and trends")
                overlaySectionRow("Mechanics", detail: "Track pinball skills")
                overlaySectionRow("Journal Timeline", detail: "Practice and library activity history.")
                overlaySectionRow("Game View", detail: "Game resources and study log")
            }
            .padding(.top, 2)

            HStack {
                Button("Not now", action: onNotNow)
                    .buttonStyle(.glass)

                Spacer()

                Button("Save") {
                    submit()
                }
                .buttonStyle(.glass)
                .disabled(firstNamePromptValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
    }

    private func overlaySectionRow(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
