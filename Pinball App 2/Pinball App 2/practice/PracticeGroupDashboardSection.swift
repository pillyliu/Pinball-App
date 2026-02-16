import SwiftUI

struct PracticeGroupDashboardSectionView: View {
    let selectedGroup: CustomGameGroup?
    let allGroups: [CustomGameGroup]
    let selectedGroupID: UUID?
    let gameTransition: Namespace.ID

    let onOpenCreateGroup: () -> Void
    let onOpenEditSelectedGroup: () -> Void
    let onSelectGroup: (UUID) -> Void
    let onTogglePriority: (UUID, Bool) -> Void
    let onOpenDateEditor: (UUID, GroupEditorDateField) -> Void

    let dashboardScoreForGroup: (CustomGameGroup) -> GroupDashboardScore
    let recommendedGameForGroup: (CustomGameGroup) -> PinballGame?
    let groupProgressForGroup: (CustomGameGroup) -> [GroupProgressSnapshot]
    let onOpenGame: (String) -> Void
    let onRemoveGameFromGroup: (String, UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            groupListCard

            if let group = selectedGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.name)
                        .font(.headline)

                    HStack(spacing: 8) {
                        statusChip(group.isActive ? "Active" : "Inactive", color: group.isActive ? .green : .secondary)
                        statusChip(group.type.label, color: .secondary)
                        if group.isPriority {
                            statusChip("Priority", color: .orange)
                        }
                        if let start = group.startDate {
                            statusChip("\(formatGroupDate(start))", color: .secondary, font: .caption2)
                        }
                        if let end = group.endDate {
                            statusChip("\(formatGroupDate(end))", color: .secondary, font: .caption2)
                        }
                    }

                    let score = dashboardScoreForGroup(group)
                    HStack(spacing: 8) {
                        MetricPill(label: "Completion", value: "\(score.completionAverage)%")
                        MetricPill(label: "Stale", value: "\(score.staleGameCount)")
                        MetricPill(label: "Variance Risk", value: "\(score.weakerGameCount)")
                    }

                    if let suggested = recommendedGameForGroup(group) {
                        Button {
                            onOpenGame(suggested.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Suggested Practice Game")
                                        .font(.footnote.weight(.semibold))
                                    Text(suggested.name)
                                        .font(.subheadline)
                                    Text("Historically weaker and/or recently neglected.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .appControlStyle()
                            .matchedTransitionSource(id: suggested.id, in: gameTransition)
                        }
                        .buttonStyle(.plain)
                    }

                    let snapshots = groupProgressForGroup(group)
                    if snapshots.isEmpty {
                        Text("No games in this group yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshots) { snapshot in
                            Button {
                                onOpenGame(snapshot.game.id)
                            } label: {
                                HStack(spacing: 10) {
                                    GroupProgressWheel(taskProgress: snapshot.taskProgress)
                                        .frame(width: 46, height: 46)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(snapshot.game.name)
                                            .font(.footnote.weight(.semibold))
                                        Text(progressSummary(taskProgress: snapshot.taskProgress))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .matchedTransitionSource(id: snapshot.game.id, in: gameTransition)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onRemoveGameFromGroup(snapshot.game.id, group.id)
                                } label: {
                                    Label("Delete Game", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .appPanelStyle()
            } else {
                Text("Create or select a group to populate the dashboard.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .appPanelStyle()
            }
        }
    }

    private var groupListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current Groups")
                    .font(.headline)
                Spacer()
                Button(action: onOpenCreateGroup) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glass)

                Button(action: onOpenEditSelectedGroup) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.glass)
                .disabled(selectedGroupID == nil)
            }

            if allGroups.isEmpty {
                Text("No groups yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Priority").frame(width: 50, alignment: .center)
                        Text("Start").frame(width: 78, alignment: .center)
                        Text("End").frame(width: 78, alignment: .center)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)

                    ForEach(allGroups) { group in
                        HStack {
                            Button {
                                onSelectGroup(group.id)
                            } label: {
                                Text(group.name)
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedGroupID == group.id ? Color.white.opacity(0.18) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            Button {
                                onTogglePriority(group.id, !group.isPriority)
                            } label: {
                                Image(systemName: group.isPriority ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(group.isPriority ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 54, alignment: .center)

                            Button {
                                onOpenDateEditor(group.id, .start)
                            } label: {
                                Text(formattedDashboardDate(group.startDate))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 78, alignment: .center)

                            Button {
                                onOpenDateEditor(group.id, .end)
                            } label: {
                                Text(formattedDashboardDate(group.endDate))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 78, alignment: .center)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func formattedDashboardDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return Self.shortDashboardDateFormatter.string(from: date)
    }

    private static let shortDashboardDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()

    private func statusChip(_ text: String, color: Color, font: Font = .caption) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.12), in: Capsule())
    }

    private func formatGroupDate(_ date: Date) -> String {
        Self.groupDateFormatter.string(from: date)
    }

    private static let groupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()

    private func progressSummary(taskProgress: [StudyTaskKind: Int]) -> String {
        let ordered = StudyTaskKind.allCases.map { task in
            "\(taskShortLabel(task)): \(taskProgress[task] ?? 0)%"
        }
        return ordered.joined(separator: "  •  ")
    }

    private func taskShortLabel(_ task: StudyTaskKind) -> String {
        switch task {
        case .playfield: return "Playfield"
        case .rulesheet: return "Rules"
        case .tutorialVideo: return "Tutorial"
        case .gameplayVideo: return "Gameplay"
        case .practice: return "Practice"
        }
    }
}
