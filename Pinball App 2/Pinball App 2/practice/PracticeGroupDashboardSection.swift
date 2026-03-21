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

    let loadDashboardDetailForGroup: (CustomGameGroup) -> GroupDashboardDetail
    let onOpenGame: (String) -> Void
    let onRemoveGameFromGroup: (String, UUID) -> Void
    @State private var inlineDateEditorGroupID: UUID?
    @State private var inlineDateEditorField: GroupEditorDateField?
    @State private var showArchivedGroups = false
    @State private var loadedDashboardDetail: GroupDashboardDetail?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            groupListCard

            if let group = selectedGroup {
                VStack(alignment: .leading, spacing: 10) {
                    AppCardSubheading(text: group.name)

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

                    if let detail = loadedDashboardDetail {
                        let score = detail.score
                        HStack(spacing: 8) {
                            AppMetricPill(label: "Completion", value: "\(score.completionAverage)%")
                            AppMetricPill(label: "Stale", value: "\(score.staleGameCount)")
                            AppMetricPill(label: "Variance Risk", value: "\(score.weakerGameCount)")
                        }

                        if detail.snapshots.isEmpty {
                            AppPanelEmptyCard(text: "No games in this group yet.")
                        } else {
                            ForEach(detail.snapshots) { snapshot in
                                Button {
                                    onOpenGame(snapshot.selectionGameID)
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
                                    .matchedTransitionSource(id: snapshot.selectionGameID, in: gameTransition)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        onRemoveGameFromGroup(snapshot.selectionGameID, group.id)
                                    } label: {
                                        Label("Delete Game", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } else {
                        AppPanelStatusCard(
                            text: "Loading group dashboard…",
                            showsProgress: true
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .appPanelStyle()
            } else {
                AppPanelEmptyCard(text: "Create or select a group to populate the dashboard.")
            }
        }
        .task(id: selectedGroupDashboardTaskKey) {
            await loadSelectedGroupDashboardDetail()
        }
    }

    private var groupListCard: some View {
        let filtered = filteredGroups()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                AppSectionTitle(text: "Groups")
                Picker("Group Filter", selection: $showArchivedGroups) {
                    Text("Current").tag(false)
                    Text("Archived").tag(true)
                }
                .appSegmentedControlStyle()
                .frame(width: 168)
                Spacer()
                Button(action: onOpenCreateGroup) {
                    Image(systemName: "plus")
                }
                .buttonStyle(AppCompactIconActionButtonStyle())

                Button(action: onOpenEditSelectedGroup) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(AppCompactIconActionButtonStyle())
                .disabled(selectedGroupID == nil || !filtered.contains(where: { $0.id == selectedGroupID }))
            }

            if filtered.isEmpty {
                Text(showArchivedGroups ? "No archived groups." : "No current groups.")
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

                    List {
                        ForEach(filtered) { group in
                            SwipeableGroupListRow(
                                group: group,
                                selectedGroupID: selectedGroupID,
                                isStartDatePopoverPresented: Binding(
                                    get: { inlineDateEditorGroupID == group.id && inlineDateEditorField == .start },
                                    set: { isPresented in
                                        if !isPresented {
                                            inlineDateEditorGroupID = nil
                                            inlineDateEditorField = nil
                                        }
                                    }
                                ),
                                isEndDatePopoverPresented: Binding(
                                    get: { inlineDateEditorGroupID == group.id && inlineDateEditorField == .end },
                                    set: { isPresented in
                                        if !isPresented {
                                            inlineDateEditorGroupID = nil
                                            inlineDateEditorField = nil
                                        }
                                    }
                                ),
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
                                formattedDashboardDate: formattedDashboardDate,
                                startDatePopoverContent: { availableHeight in
                                    AnyView(popoverCalendar(for: group, field: .start, availableHeight: availableHeight))
                                },
                                endDatePopoverContent: { availableHeight in
                                    AnyView(popoverCalendar(for: group, field: .end, availableHeight: availableHeight))
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .frame(height: groupListHeight(for: filtered.count))
                    .scrollDisabled(true)
                    .appEmbeddedListStyle()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    @ViewBuilder
    private func popoverCalendar(
        for group: CustomGameGroup,
        field: GroupEditorDateField,
        availableHeight: CGFloat
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
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
                    .buttonStyle(AppDestructiveActionButtonStyle(fillsWidth: false))

                    Spacer()

                    Button("Done") {
                        inlineDateEditorGroupID = nil
                        inlineDateEditorField = nil
                    }
                    .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(12)
        .frame(minWidth: 320, maxHeight: availableHeight, alignment: .top)
        .presentationCompactAdaptation(.popover)
    }

    private func formattedDashboardDate(_ date: Date?) -> String {
        guard let date else { return "-" }
        return Self.shortDashboardDateFormatter.string(from: date)
    }

    private func filteredGroups() -> [CustomGameGroup] {
        allGroups.filter { showArchivedGroups ? $0.isArchived : !$0.isArchived }
    }

    private var selectedGroupDashboardTaskKey: String {
        guard let group = selectedGroup else { return "none" }
        let gameIDs = group.gameIDs.joined(separator: "|")
        let start = group.startDate?.timeIntervalSince1970 ?? -1
        let end = group.endDate?.timeIntervalSince1970 ?? -1
        return "\(group.id.uuidString)|\(gameIDs)|\(start)|\(end)"
    }

    @MainActor
    private func loadSelectedGroupDashboardDetail() async {
        guard let group = selectedGroup else {
            loadedDashboardDetail = nil
            return
        }

        loadedDashboardDetail = nil
        let groupID = group.id
        await Task.yield()
        guard !Task.isCancelled else { return }
        let detail = loadDashboardDetailForGroup(group)
        guard !Task.isCancelled, selectedGroup?.id == groupID else { return }
        loadedDashboardDetail = detail
    }

    private func groupListHeight(for count: Int) -> CGFloat {
        CGFloat(count) * 36
    }

    private static let shortDashboardDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()

    private func statusChip(_ text: String, color: Color, font: Font = .caption) -> some View {
        AppTintedStatusChip(
            text: text,
            foreground: color,
            compact: font == .caption2
        )
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
    let isStartDatePopoverPresented: Binding<Bool>
    let isEndDatePopoverPresented: Binding<Bool>
    let onSelectGroup: (UUID) -> Void
    let onTogglePriority: (UUID, Bool) -> Void
    let onStartDateTap: () -> Void
    let onEndDateTap: () -> Void
    let onArchiveToggle: () -> Void
    let onDelete: () -> Void
    let formattedDashboardDate: (Date?) -> String
    let startDatePopoverContent: (CGFloat) -> AnyView
    let endDatePopoverContent: (CGFloat) -> AnyView

    var body: some View {
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

            Button(action: onStartDateTap) {
                Text(formattedDashboardDate(group.startDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .frame(width: 78, alignment: .center)
            .contentShape(Rectangle())
            .practiceAdaptivePopover(
                isPresented: isStartDatePopoverPresented,
                preferredHeight: 420
            ) { availableHeight in
                startDatePopoverContent(availableHeight)
            }

            Button(action: onEndDateTap) {
                Text(formattedDashboardDate(group.endDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .frame(width: 78, alignment: .center)
            .contentShape(Rectangle())
            .practiceAdaptivePopover(
                isPresented: isEndDatePopoverPresented,
                preferredHeight: 420
            ) { availableHeight in
                endDatePopoverContent(availableHeight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.border.opacity(0.6), lineWidth: 1)
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)

            Button {
                onArchiveToggle()
            } label: {
                Label(group.isArchived ? "Restore" : "Archive", systemImage: group.isArchived ? "arrow.uturn.left.circle" : "archivebox")
            }
            .tint(AppTheme.brandGold)
        }
    }
}
