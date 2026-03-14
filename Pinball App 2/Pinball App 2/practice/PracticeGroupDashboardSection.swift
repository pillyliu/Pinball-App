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

                    let score = dashboardScoreForGroup(group)
                    HStack(spacing: 8) {
                        AppMetricPill(label: "Completion", value: "\(score.completionAverage)%")
                        AppMetricPill(label: "Stale", value: "\(score.staleGameCount)")
                        AppMetricPill(label: "Variance Risk", value: "\(score.weakerGameCount)")
                    }

                    let snapshots = groupProgressForGroup(group)
                    if snapshots.isEmpty {
                        AppPanelEmptyCard(text: "No games in this group yet.")
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
                AppPanelEmptyCard(text: "Create or select a group to populate the dashboard.")
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
    @Binding var revealedGroupID: UUID?
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
                    AppSwipeRevealActionButton(
                        systemName: group.isArchived ? "arrow.uturn.left.circle" : "archivebox",
                        foreground: AppTheme.brandGold
                    )
                }
                .buttonStyle(.plain)

                Button(action: {
                    onDelete()
                    revealedGroupID = nil
                    withAnimation(.easeOut(duration: 0.18)) { offsetX = 0 }
                }) {
                    AppSwipeRevealActionButton(
                        systemName: "trash",
                        foreground: .red
                    )
                }
                .buttonStyle(.plain)
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
