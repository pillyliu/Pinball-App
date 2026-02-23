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
    let onSetGroupArchived: (UUID, Bool) -> Void
    let onDeleteGroup: (UUID) -> Void
    let onUpdateGroupDate: (UUID, GroupEditorDateField, Date?) -> Void

    let dashboardScoreForGroup: (CustomGameGroup) -> GroupDashboardScore
    let recommendedGameForGroup: (CustomGameGroup) -> PinballGame?
    let groupProgressForGroup: (CustomGameGroup) -> [GroupProgressSnapshot]
    let onOpenGame: (String) -> Void
    let onRemoveGameFromGroup: (String, UUID) -> Void
    @State private var inlineDateEditorGroupID: UUID?
    @State private var inlineDateEditorField: GroupEditorDateField?
    @State private var showArchivedGroups = false
    @State private var revealedGroupID: UUID?

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

                    let snapshots = groupProgressForGroup(group)
                    if snapshots.isEmpty {
                        Text("No games in this group yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshots) { snapshot in
                            Button {
                                onOpenGame(snapshot.game.canonicalPracticeKey)
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
                                .matchedTransitionSource(id: snapshot.game.canonicalPracticeKey, in: gameTransition)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    onRemoveGameFromGroup(snapshot.game.canonicalPracticeKey, group.id)
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
        .simultaneousGesture(
            TapGesture().onEnded {
                revealedGroupID = nil
            }
        )
    }

    private var groupListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Groups")
                    .font(.headline)
                Picker("Group Filter", selection: $showArchivedGroups) {
                    Text("Current").tag(false)
                    Text("Archived").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                Spacer()
                Button(action: onOpenCreateGroup) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.glass)

                Button(action: onOpenEditSelectedGroup) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.glass)
                .disabled(selectedGroupID == nil || !filteredGroups().contains(where: { $0.id == selectedGroupID }))
            }

            if filteredGroups().isEmpty {
                Text(showArchivedGroups ? "No archived groups." : "No current groups.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                let filtered = filteredGroups()
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

                    ForEach(filtered) { group in
                        SwipeableGroupListRow(
                            group: group,
                            selectedGroupID: selectedGroupID,
                            revealedGroupID: $revealedGroupID,
                            onSelectGroup: onSelectGroup,
                            onTogglePriority: onTogglePriority,
                            onStartDateTap: {
                                inlineDateEditorGroupID = group.id
                                inlineDateEditorField = .start
                            },
                            onEndDateTap: {
                                inlineDateEditorGroupID = group.id
                                inlineDateEditorField = .end
                            },
                            onArchiveToggle: {
                                onSetGroupArchived(group.id, !group.isArchived)
                            },
                            onDelete: {
                                onDeleteGroup(group.id)
                            },
                            formattedDashboardDate: formattedDashboardDate
                        )
                        .popover(
                            isPresented: Binding(
                                get: { inlineDateEditorGroupID == group.id && inlineDateEditorField == .start },
                                set: { isPresented in
                                    if !isPresented {
                                        inlineDateEditorGroupID = nil
                                        inlineDateEditorField = nil
                                    }
                                }
                            ),
                            attachmentAnchor: .rect(.bounds)
                        ) {
                            popoverCalendar(for: group, field: .start)
                        }
                        .popover(
                            isPresented: Binding(
                                get: { inlineDateEditorGroupID == group.id && inlineDateEditorField == .end },
                                set: { isPresented in
                                    if !isPresented {
                                        inlineDateEditorGroupID = nil
                                        inlineDateEditorField = nil
                                    }
                                }
                            ),
                            attachmentAnchor: .rect(.bounds)
                        ) {
                            popoverCalendar(for: group, field: .end)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            revealedGroupID = nil
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    @ViewBuilder
    private func popoverCalendar(for group: CustomGameGroup, field: GroupEditorDateField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(
                field == .start ? "Start Date" : "End Date",
                selection: Binding(
                    get: {
                        switch field {
                        case .start: return group.startDate ?? Date()
                        case .end: return group.endDate ?? Date()
                        }
                    },
                    set: { onUpdateGroupDate(group.id, field, $0) }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)

            HStack {
                Button("Clear", role: .destructive) {
                    onUpdateGroupDate(group.id, field, nil)
                    inlineDateEditorGroupID = nil
                    inlineDateEditorField = nil
                }
                .buttonStyle(.glass)

                Spacer()

                Button("Done") {
                    inlineDateEditorGroupID = nil
                    inlineDateEditorField = nil
                }
                .buttonStyle(.glass)
            }
        }
        .padding(12)
        .frame(minWidth: 320)
        .presentationCompactAdaptation(.popover)
    }

    private func formattedDashboardDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return Self.shortDashboardDateFormatter.string(from: date)
    }

    private func filteredGroups() -> [CustomGameGroup] {
        allGroups.filter { showArchivedGroups ? $0.isArchived : !$0.isArchived }
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

private struct SwipeableGroupListRow: View {
    let group: CustomGameGroup
    let selectedGroupID: UUID?
    @Binding var revealedGroupID: UUID?
    let onSelectGroup: (UUID) -> Void
    let onTogglePriority: (UUID, Bool) -> Void
    let onStartDateTap: () -> Void
    let onEndDateTap: () -> Void
    let onArchiveToggle: () -> Void
    let onDelete: () -> Void
    let formattedDashboardDate: (Date?) -> String

    @State private var offsetX: CGFloat = 0
    @State private var dragStartX: CGFloat = 0
    @State private var isDragging = false
    private let actionWidth: CGFloat = 116

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Button(action: {
                    onArchiveToggle()
                    revealedGroupID = nil
                    withAnimation(.easeOut(duration: 0.18)) { offsetX = 0 }
                }) {
                    Image(systemName: group.isArchived ? "arrow.uturn.left.circle" : "archivebox")
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .background(Color.orange.opacity(0.16))

                Button(action: {
                    onDelete()
                    revealedGroupID = nil
                    withAnimation(.easeOut(duration: 0.18)) { offsetX = 0 }
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .background(Color.red.opacity(0.16))
            }
            .frame(width: actionWidth, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(max(0, min(1, Double((-offsetX / actionWidth)))))

            HStack {
                Button {
                    onSelectGroup(group.id)
                    revealedGroupID = nil
                    withAnimation(.easeOut(duration: 0.18)) { offsetX = 0 }
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

                Button(action: onStartDateTap) {
                    Text(formattedDashboardDate(group.startDate))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 78, alignment: .center)

                Button(action: onEndDateTap) {
                    Text(formattedDashboardDate(group.endDate))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 78, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .frame(height: 34)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
            )
            .offset(x: offsetX)
            .highPriorityGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .onChanged { value in
                        if !isDragging {
                            dragStartX = offsetX
                            isDragging = true
                        }
                        let proposed = dragStartX + value.translation.width
                        offsetX = min(0, max(-actionWidth, proposed))
                    }
                    .onEnded { _ in
                        isDragging = false
                        withAnimation(.easeOut(duration: 0.18)) {
                            let shouldReveal = offsetX < (-actionWidth * 0.4)
                            offsetX = shouldReveal ? -actionWidth : 0
                            revealedGroupID = shouldReveal ? group.id : nil
                        }
                    }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onChange(of: revealedGroupID) { _, newValue in
            guard newValue != group.id, offsetX != 0 else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                offsetX = 0
            }
        }
    }
}
