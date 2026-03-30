import SwiftUI
import UniformTypeIdentifiers

struct GroupEditorSelectedGameItem: Identifiable {
    let selectionID: String
    let game: PinballGame

    var id: String { selectionID }
}

struct GroupEditorNameSection: View {
    @Binding var name: String

    var body: some View {
        GroupEditorSectionCard(title: "Name") {
            TextField("Group name", text: $name)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()
        }
    }
}

struct GroupEditorTemplatesSection: View {
    @Binding var templateSource: GroupCreationTemplateSource
    let availableBanks: [Int]
    @Binding var selectedTemplateBank: Int
    let duplicateCandidates: [CustomGameGroup]
    @Binding var selectedDuplicateGroupID: UUID?
    let onApplyBankTemplate: (Int) -> Void
    let onApplyDuplicateTemplate: (UUID?) -> Void

    var body: some View {
        GroupEditorSectionCard(title: "Templates") {
            Picker("Template", selection: $templateSource) {
                ForEach(GroupCreationTemplateSource.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)

            switch templateSource {
            case .none:
                Text("Choose a template to prefill this group.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .bank:
                if availableBanks.isEmpty {
                    AppPanelEmptyCard(text: "No LPL bank template data found.")
                } else {
                    Picker("Bank", selection: $selectedTemplateBank) {
                        ForEach(availableBanks, id: \.self) { bank in
                            Text("Bank \(bank)").tag(bank)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Apply LPL Bank Template") {
                        onApplyBankTemplate(selectedTemplateBank)
                    }
                    .buttonStyle(AppPrimaryActionButtonStyle())
                }
            case .duplicate:
                if duplicateCandidates.isEmpty {
                    AppPanelEmptyCard(text: "No existing groups to duplicate.")
                } else {
                    Picker(
                        "Group",
                        selection: Binding<UUID?>(
                            get: { selectedDuplicateGroupID ?? duplicateCandidates.first?.id },
                            set: { selectedDuplicateGroupID = $0 }
                        )
                    ) {
                        ForEach(duplicateCandidates) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Apply Duplicate Group") {
                        onApplyDuplicateTemplate(selectedDuplicateGroupID ?? duplicateCandidates.first?.id)
                    }
                    .buttonStyle(AppPrimaryActionButtonStyle())
                }
            }
        }
    }
}

struct GroupEditorTitlesSection: View {
    let selectedGameItems: [GroupEditorSelectedGameItem]
    @Binding var showingTitleSelector: Bool
    @Binding var pendingDeleteGameID: String?
    @Binding var draggingGameID: String?
    @Binding var selectedGameIDs: [String]
    let onRemovePendingGame: () -> Void

    var body: some View {
        GroupEditorSectionCard(title: "Titles") {
            Button {
                showingTitleSelector = true
            } label: {
                HStack {
                    Text(selectedGameIDs.isEmpty ? "Select games" : "\(selectedGameIDs.count) selected")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .appControlStyle()
            }
            .buttonStyle(.plain)

            if selectedGameItems.isEmpty {
                AppPanelEmptyCard(text: "No games selected.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedGameItems) { item in
                            ZStack(alignment: .topTrailing) {
                                SelectedGameMiniCard(game: item.game)

                                Button {
                                    pendingDeleteGameID = item.selectionID
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(Color.white, Color.red.opacity(0.96))
                                        .shadow(color: .black.opacity(0.26), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                                .padding(4)
                                .practiceAdaptivePopover(
                                    isPresented: Binding(
                                        get: { pendingDeleteGameID == item.selectionID },
                                        set: { isPresented in
                                            if !isPresented, pendingDeleteGameID == item.selectionID {
                                                pendingDeleteGameID = nil
                                            }
                                        }
                                    ),
                                    preferredHeight: 180
                                ) { _ in
                                    GroupEditorTitleDeletePopover(
                                        onCancel: { pendingDeleteGameID = nil },
                                        onDelete: onRemovePendingGame
                                    )
                                }
                            }
                            .onDrag {
                                draggingGameID = item.selectionID
                                return NSItemProvider(object: item.selectionID as NSString)
                            }
                            .onDrop(
                                of: [UTType.text, UTType.plainText],
                                delegate: SelectedGameReorderDropDelegate(
                                    targetGameID: item.selectionID,
                                    selectedGameIDs: $selectedGameIDs,
                                    draggingGameID: $draggingGameID
                                )
                            )
                        }
                    }
                    .onDrop(
                        of: [UTType.text, UTType.plainText],
                        delegate: SelectedGameReorderContainerDropDelegate(draggingGameID: $draggingGameID)
                    )
                }

                Text("Long-press a title card to reorder. Use the remove button to delete.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GroupEditorSettingsSection: View {
    @Binding var isActive: Bool
    @Binding var isPriority: Bool
    @Binding var type: GroupType
    let groupPosition: Int
    let canMoveGroupUp: Bool
    let canMoveGroupDown: Bool
    let onMoveGroupPosition: (Bool) -> Void
    @Binding var hasStartDate: Bool
    @Binding var startDate: Date
    @Binding var hasEndDate: Bool
    @Binding var endDate: Date
    @Binding var inlineDateEditorField: GroupEditorDateField?
    @Binding var isArchived: Bool
    let validationMessage: String?

    var body: some View {
        GroupEditorSectionCard(title: "Settings") {
            HStack {
                Text("Active")
                Spacer()
                Toggle("", isOn: $isActive)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.green)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()

            HStack {
                Text("Priority")
                Spacer()
                Toggle("", isOn: $isPriority)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()

            Picker("Type", selection: $type) {
                ForEach(GroupType.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .appSegmentedControlStyle()

            HStack {
                Text("Position")
                Spacer()
                HStack(spacing: 8) {
                    Button { onMoveGroupPosition(true) } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveGroupUp)
                    .foregroundStyle(canMoveGroupUp ? Color.primary : Color.secondary.opacity(0.4))

                    Text("\(groupPosition)")
                        .font(.footnote.monospacedDigit().weight(.semibold))
                        .frame(minWidth: 28)

                    Button { onMoveGroupPosition(false) } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveGroupDown)
                    .foregroundStyle(canMoveGroupDown ? Color.primary : Color.secondary.opacity(0.4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .appControlStyle()
            }

            GroupEditorDateToggleRow(
                title: "Start Date",
                hasDate: $hasStartDate,
                date: $startDate,
                field: .start,
                inlineDateEditorField: $inlineDateEditorField
            )
            GroupEditorDateToggleRow(
                title: "End Date",
                hasDate: $hasEndDate,
                date: $endDate,
                field: .end,
                inlineDateEditorField: $inlineDateEditorField
            )

            HStack {
                Text("Archived")
                Spacer()
                Toggle("", isOn: $isArchived)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct GroupEditorDateToggleRow: View {
    let title: String
    @Binding var hasDate: Bool
    @Binding var date: Date
    let field: GroupEditorDateField
    @Binding var inlineDateEditorField: GroupEditorDateField?

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Button {
                if !hasDate {
                    hasDate = true
                }
                inlineDateEditorField = field
            } label: {
                Text(hasDate ? formatPracticeGroupEditorDate(date) : "Select date")
                    .font(.caption2)
                    .foregroundStyle(hasDate ? .secondary : .tertiary)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppTheme.panel.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppTheme.border.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .practiceAdaptivePopover(
                isPresented: Binding(
                    get: { inlineDateEditorField == field },
                    set: { isPresented in
                        if !isPresented {
                            inlineDateEditorField = nil
                        }
                    }
                ),
                preferredHeight: 420
            ) { availableHeight in
                GroupEditorDatePopover(
                    title: title,
                    hasDate: $hasDate,
                    date: $date,
                    availableHeight: availableHeight,
                    onDone: { inlineDateEditorField = nil }
                )
            }

            if hasDate {
                Button {
                    hasDate = false
                    if inlineDateEditorField == field {
                        inlineDateEditorField = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            Toggle("", isOn: $hasDate)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .appControlStyle()
    }
}

private struct GroupEditorDatePopover: View {
    let title: String
    @Binding var hasDate: Bool
    @Binding var date: Date
    let availableHeight: CGFloat
    let onDone: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                DatePicker(title, selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)

                HStack {
                    Button("Clear", role: .destructive) {
                        hasDate = false
                        onDone()
                    }
                    .buttonStyle(AppDestructiveActionButtonStyle(fillsWidth: false))

                    Spacer()

                    Button("Done") {
                        onDone()
                    }
                    .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .padding(12)
        .frame(minWidth: 320, maxHeight: availableHeight, alignment: .top)
        .presentationCompactAdaptation(.popover)
    }
}

private struct GroupEditorTitleDeletePopover: View {
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button("Cancel") {
                onCancel()
            }
            .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))

            Button("Delete", role: .destructive) {
                onDelete()
            }
            .buttonStyle(AppDestructiveActionButtonStyle(fillsWidth: false))
        }
        .padding(12)
        .frame(minWidth: 180, alignment: .center)
        .presentationCompactAdaptation(.popover)
    }
}

private struct GroupEditorSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionTitle(text: title)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }
}
