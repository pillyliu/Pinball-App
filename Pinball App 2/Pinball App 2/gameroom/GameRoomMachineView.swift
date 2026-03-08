import SwiftUI

struct GameRoomMachineView: View {
    private struct FullscreenPhotoItem: Identifiable, Hashable {
        let id = UUID()
        let url: URL
    }

    private enum MachineSubview: String, CaseIterable, Identifiable {
        case summary
        case input
        case log

        var id: String { rawValue }

        var title: String {
            switch self {
            case .summary: return "Summary"
            case .input: return "Input"
            case .log: return "Log"
            }
        }
    }

    private enum MachineInputSheet: String, Identifiable {
        case cleanGlass
        case cleanPlayfield
        case swapBalls
        case checkPitch
        case levelMachine
        case generalInspection
        case logIssue
        case resolveIssue
        case ownershipUpdate
        case installMod
        case replacePart
        case addMedia
        case logPlays

        var id: String { rawValue }
    }

    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let machineID: UUID
    @State private var selectedSubview: MachineSubview = .summary
    @State private var editingEvent: MachineEvent?
    @State private var pendingDeleteEvent: MachineEvent?
    @State private var activeInputSheet: MachineInputSheet?
    @State private var revealedLogEntryID: String?
    @State private var selectedLogEventID: UUID?
    @State private var previewAttachment: MachineAttachment?
    @State private var editingAttachment: MachineAttachment?
    @State private var pendingDeleteAttachment: MachineAttachment?
    @State private var fullscreenPhotoItem: FullscreenPhotoItem?

    private var machine: OwnedMachine? {
        (store.activeMachines + store.archivedMachines).first(where: { $0.id == machineID })
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ConstrainedAsyncImagePreview(
                        candidates: machine.map { catalogLoader.imageCandidates(for: $0) } ?? [],
                        emptyMessage: "No image",
                        maxAspectRatio: 4.0 / 3.0,
                        imagePadding: 0
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let machine {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .center, spacing: 8) {
                                Text(machine.displayTitle)
                                    .font(.title3.weight(.semibold))
                                if let label = gameRoomVariantBadgeLabel(variant: machine.displayVariant, title: machine.displayTitle) {
                                    GameRoomVariantPill(label: label, style: .machineTitle)
                                }
                            }

                            Text(machineHeaderLine(machine))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Picker("Subview", selection: $selectedSubview) {
                            ForEach(MachineSubview.allCases) { subview in
                                Text(subview.title).tag(subview)
                            }
                        }
                        .appSegmentedControlStyle()

                        switch selectedSubview {
                        case .summary:
                            summarySection(for: machine)
                        case .input:
                            inputSection(for: machine)
                        case .log:
                            logSection(for: machine)
                        }
                    } else {
                        Text("This machine is no longer available.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .navigationTitle("Machine View")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingEvent) { event in
            GameRoomEventEditSheet(
                event: event,
                onSave: { occurredAt, summary, notes in
                    store.updateEvent(id: event.id, occurredAt: occurredAt, summary: summary, notes: notes)
                }
            )
            .gameRoomEntrySheetStyle()
        }
        .sheet(item: $activeInputSheet) { sheet in
            if let machine {
                switch sheet {
                case .cleanGlass:
                    GameRoomServiceEntrySheet(
                        title: "Clean Glass",
                        submitLabel: "Save",
                        includesConsumableField: false,
                        includesPitchFields: false,
                        onSave: { occurredAt, notes, _, _, _ in
                            store.addEvent(
                                machineID: machine.id,
                                type: .glassCleaned,
                                category: .service,
                                occurredAt: occurredAt,
                                summary: "Clean Glass",
                                notes: notes
                            )
                        }
                    )
                    .gameRoomEntrySheetStyle()
                case .cleanPlayfield:
                    GameRoomServiceEntrySheet(
                        title: "Clean Playfield",
                        submitLabel: "Save",
                        includesConsumableField: true,
                        includesPitchFields: false,
                        onSave: { occurredAt, notes, consumable, _, _ in
                            store.addEvent(
                                machineID: machine.id,
                                type: .playfieldCleaned,
                                category: .service,
                                occurredAt: occurredAt,
                                summary: "Clean Playfield",
                                notes: notes,
                                consumablesUsed: consumable
                            )
                        }
                    )
                    .gameRoomEntrySheetStyle()
                case .swapBalls:
                    GameRoomServiceEntrySheet(
                        title: "Swap Balls",
                        submitLabel: "Save",
                        includesConsumableField: false,
                        includesPitchFields: false,
                        onSave: { occurredAt, notes, _, _, _ in
                            store.addEvent(
                                machineID: machine.id,
                                type: .ballsReplaced,
                                category: .service,
                                occurredAt: occurredAt,
                                summary: "Swap Balls",
                                notes: notes
                            )
                        }
                    )
                    .gameRoomEntrySheetStyle()
                case .checkPitch:
                    GameRoomServiceEntrySheet(
                        title: "Check Pitch",
                        submitLabel: "Save",
                        includesConsumableField: false,
                        includesPitchFields: true,
                        onSave: { occurredAt, notes, _, pitchValue, pitchPoint in
                            store.addEvent(
                                machineID: machine.id,
                                type: .pitchChecked,
                                category: .service,
                                occurredAt: occurredAt,
                                summary: "Check Pitch",
                                notes: notes,
                                pitchValue: pitchValue,
                                pitchMeasurementPoint: pitchPoint
                            )
                        }
                    )
                    .gameRoomEntrySheetStyle()
                case .levelMachine:
                    GameRoomServiceEntrySheet(
                        title: "Level Machine",
                        submitLabel: "Save",
                        includesConsumableField: false,
                        includesPitchFields: false,
                        onSave: { occurredAt, notes, _, _, _ in
                            store.addEvent(
                                machineID: machine.id,
                                type: .machineLeveled,
                                category: .service,
                                occurredAt: occurredAt,
                                summary: "Level Machine",
                                notes: notes
                            )
                        }
                    )
                    .gameRoomEntrySheetStyle()
                case .generalInspection:
                    GameRoomServiceEntrySheet(
                        title: "General Inspection",
                        submitLabel: "Save",
                        includesConsumableField: false,
                        includesPitchFields: false,
                        onSave: { occurredAt, notes, _, _, _ in
                            store.addEvent(
                                machineID: machine.id,
                                type: .generalInspection,
                                category: .service,
                                occurredAt: occurredAt,
                                summary: "General Inspection",
                                notes: notes
                            )
                        }
                    )
                    .gameRoomEntrySheetStyle()
                case .logIssue:
                    GameRoomLogIssueSheet { occurredAt, symptom, severity, subsystem, diagnosis, attachments in
                        let issueID = store.openIssue(
                            machineID: machine.id,
                            openedAt: occurredAt,
                            symptom: symptom,
                            severity: severity,
                            subsystem: subsystem,
                            diagnosis: diagnosis
                        )
                        store.addEvent(
                            machineID: machine.id,
                            type: .issueOpened,
                            category: .issue,
                            occurredAt: occurredAt,
                            summary: symptom,
                            notes: diagnosis,
                            linkedIssueID: issueID
                        )
                        for attachment in attachments {
                            store.addAttachment(
                                machineID: machine.id,
                                ownerType: .issue,
                                ownerID: issueID,
                                kind: attachment.kind,
                                uri: attachment.uri,
                                caption: attachment.caption
                            )
                            store.addEvent(
                                machineID: machine.id,
                                type: attachment.kind == .photo ? .photoAdded : .videoAdded,
                                category: .media,
                                occurredAt: occurredAt,
                                summary: attachment.kind == .photo ? "Issue photo added" : "Issue video added",
                                linkedIssueID: issueID
                            )
                        }
                    }
                    .gameRoomEntrySheetStyle()
                case .resolveIssue:
                    GameRoomResolveIssueSheet(
                        openIssues: store.state.issues
                            .filter { $0.ownedMachineID == machine.id && $0.status != .resolved }
                            .sorted { $0.openedAt > $1.openedAt },
                        onSave: { issueID, resolvedAt, resolution in
                            store.resolveIssue(id: issueID, resolvedAt: resolvedAt, resolution: resolution)
                            store.addEvent(
                                machineID: machine.id,
                                type: .issueResolved,
                                category: .issue,
                                occurredAt: resolvedAt,
                                summary: "Resolve Issue",
                                notes: resolution,
                                linkedIssueID: issueID
                            )
                        }
                    )
                    .gameRoomEntrySheetStyle()
                case .ownershipUpdate:
                    GameRoomOwnershipEntrySheet { occurredAt, eventType, summary, notes in
                        store.addEvent(
                            machineID: machine.id,
                            type: eventType,
                            category: .ownership,
                            occurredAt: occurredAt,
                            summary: summary,
                            notes: notes
                        )
                    }
                    .gameRoomEntrySheetStyle()
                case .installMod:
                    GameRoomPartOrModEntrySheet(
                        title: "Install Mod",
                        detailsLabel: "Mod",
                        detailsPrompt: "Mod Name / Details",
                        submitLabel: "Save",
                        onSave: { occurredAt, summary, details, notes in
                            store.addEvent(
                                machineID: machine.id,
                                type: .modInstalled,
                                category: .mod,
                                occurredAt: occurredAt,
                                summary: summary,
                                notes: notes,
                                partsUsed: details
                            )
                        }
                    )
                    .gameRoomEntrySheetStyle()
                case .replacePart:
                    GameRoomPartOrModEntrySheet(
                        title: "Replace Part",
                        detailsLabel: "Part",
                        detailsPrompt: "Part Replaced",
                        submitLabel: "Save",
                        onSave: { occurredAt, summary, details, notes in
                            store.addEvent(
                                machineID: machine.id,
                                type: .partReplaced,
                                category: .service,
                                occurredAt: occurredAt,
                                summary: summary,
                                notes: notes,
                                partsUsed: details
                            )
                        }
                    )
                    .gameRoomEntrySheetStyle()
                case .addMedia:
                    GameRoomMediaEntrySheet { kind, uri, caption, notes in
                        let eventType: MachineEventType = kind == .photo ? .photoAdded : .videoAdded
                        let summary = kind == .photo ? "Photo Added" : "Video Added"
                        let eventID = store.addEvent(
                            machineID: machine.id,
                            type: eventType,
                            category: .media,
                            summary: summary,
                            notes: notes
                        )
                        store.addAttachment(
                            machineID: machine.id,
                            ownerType: .event,
                            ownerID: eventID,
                            kind: kind,
                            uri: uri,
                            caption: caption
                        )
                    }
                    .gameRoomMediaSheetStyle()
                case .logPlays:
                    GameRoomPlayCountEntrySheet { occurredAt, playTotal, notes in
                        store.addEvent(
                            machineID: machine.id,
                            type: .custom,
                            category: .custom,
                            occurredAt: occurredAt,
                            playCountAtEvent: playTotal,
                            summary: "Log Plays (Total \(playTotal))",
                            notes: notes
                        )
                    }
                    .gameRoomEntrySheetStyle()
                }
            } else {
                EmptyView()
            }
        }
        .sheet(item: $previewAttachment) { attachment in
            GameRoomAttachmentPreviewSheet(attachment: attachment)
        }
        .sheet(item: $editingAttachment) { attachment in
            GameRoomMediaEditSheet(
                attachment: attachment,
                initialNotes: linkedEvent(for: attachment)?.notes,
                onSave: { caption, notes in
                    store.updateAttachment(id: attachment.id, caption: caption, notes: notes)
                }
            )
            .gameRoomEntrySheetStyle()
        }
        .navigationDestination(item: $fullscreenPhotoItem) { item in
            HostedImageView(imageCandidates: [item.url])
        }
        .alert("Delete Log Entry?", isPresented: Binding(
            get: { pendingDeleteEvent != nil },
            set: { if !$0 { pendingDeleteEvent = nil } }
        )) {
            Button("Delete", role: .destructive) {
                guard let event = pendingDeleteEvent else { return }
                store.deleteEvent(id: event.id)
                pendingDeleteEvent = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteEvent = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Delete Media?", isPresented: Binding(
            get: { pendingDeleteAttachment != nil },
            set: { if !$0 { pendingDeleteAttachment = nil } }
        )) {
            Button("Delete", role: .destructive) {
                guard let attachment = pendingDeleteAttachment else { return }
                store.deleteAttachmentAndLinkedEvent(id: attachment.id)
                pendingDeleteAttachment = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteAttachment = nil
            }
        } message: {
            Text("This removes the media and linked log event.")
        }
    }

    private func machineHeaderLine(_ machine: OwnedMachine) -> String {
        let area = store.area(for: machine.gameRoomAreaID)?.name ?? "No area"
        let group = machine.groupNumber.map(String.init) ?? "—"
        let position = machine.position.map(String.init) ?? "—"
        return "\(area) • Group \(group) • Position \(position) • \(machine.status.rawValue.capitalized)"
    }

    private func summarySection(for machine: OwnedMachine) -> some View {
        let snapshot = store.snapshot(for: machine.id)
        let recentAttachments = store.state.attachments
            .filter { $0.ownedMachineID == machine.id }
            .sorted { $0.createdAt > $1.createdAt }
        let mediaColumns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                AppCardSubheading(text: "Current Snapshot")
                GameRoomSnapshotMetricGrid(items: [
                    GameRoomSnapshotMetric(label: "Open Issues", value: "\(snapshot.openIssueCount)"),
                    GameRoomSnapshotMetric(label: "Current Plays", value: "\(snapshot.currentPlayCount)"),
                    GameRoomSnapshotMetric(label: "Due Tasks", value: "\(snapshot.dueTaskCount)"),
                    GameRoomSnapshotMetric(label: "Last Service", value: snapshot.lastServiceAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
                    GameRoomSnapshotMetric(label: "Pitch", value: snapshot.currentPitchValue.map { String(format: "%.1f", $0) } ?? "—"),
                    GameRoomSnapshotMetric(label: "Last Level", value: snapshot.lastLeveledAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
                    GameRoomSnapshotMetric(label: "Last Inspection", value: snapshot.lastGeneralInspectionAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
                    GameRoomSnapshotMetric(label: "Purchase Date", value: machine.purchaseDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                ])
                if let purchaseDateRawText = machine.purchaseDateRawText, !purchaseDateRawText.isEmpty {
                    Text("Purchase (raw): \(purchaseDateRawText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                AppCardSubheading(text: "Media")
                if recentAttachments.isEmpty {
                    AppPanelEmptyCard(text: "No media attached yet.")
                } else {
                    LazyVGrid(columns: mediaColumns, spacing: 8) {
                        ForEach(Array(recentAttachments.prefix(12))) { attachment in
                            let sourceEvent = linkedEvent(for: attachment)
                            VStack(alignment: .leading, spacing: 4) {
                                Button {
                                    openAttachment(attachment)
                                } label: {
                                    GameRoomAttachmentSquareTile(
                                        attachment: attachment,
                                        resolvedURL: urlForAttachmentURI(attachment.uri)
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Edit Media") {
                                        editingAttachment = attachment
                                    }
                                    Button("Delete Media", role: .destructive) {
                                        pendingDeleteAttachment = attachment
                                    }
                                }

                                if let sourceEvent {
                                    Button("Open Log Entry") {
                                        selectedSubview = .log
                                        selectedLogEventID = sourceEvent.id
                                    }
                                    .font(.caption2.weight(.semibold))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
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
    }

    private func inputSection(for machine: OwnedMachine) -> some View {
        let twoColumnGrid = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                AppCardSubheading(text: "Service")
                LazyVGrid(columns: twoColumnGrid, spacing: 8) {
                    ForEach(serviceInputItems, id: \.title) { item in
                        Button(action: {
                            guard machine.status == .active || machine.status == .loaned else { return }
                            activeInputSheet = item.sheet
                        }) {
                            Text(item.title)
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .appControlStyle()
                        }
                        .buttonStyle(.plain)
                        .disabled(!(machine.status == .active || machine.status == .loaned))
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                AppCardSubheading(text: "Issue")
                LazyVGrid(columns: twoColumnGrid, spacing: 8) {
                    ForEach(issueInputItems, id: \.title) { item in
                        Button(action: { activeInputSheet = item.sheet }) {
                            Text(item.title)
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .appControlStyle()
                        }
                        .buttonStyle(.plain)
                        .disabled(item.sheet == .resolveIssue && !hasOpenIssues(for: machine.id))
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                AppCardSubheading(text: "Ownership / Media")
                LazyVGrid(columns: twoColumnGrid, spacing: 8) {
                    ForEach(ownershipAndMediaInputItems, id: \.title) { item in
                        Button(action: { activeInputSheet = item.sheet }) {
                            Text(item.title)
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .appControlStyle()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var serviceInputItems: [(title: String, sheet: MachineInputSheet)] {
        [
            ("Clean Glass", .cleanGlass),
            ("Clean Playfield", .cleanPlayfield),
            ("Swap Balls", .swapBalls),
            ("Check Pitch", .checkPitch),
            ("Level Machine", .levelMachine),
            ("General Inspection", .generalInspection)
        ]
    }

    private var issueInputItems: [(title: String, sheet: MachineInputSheet)] {
        [
            ("Log Issue", .logIssue),
            ("Resolve Issue", .resolveIssue)
        ]
    }

    private var ownershipAndMediaInputItems: [(title: String, sheet: MachineInputSheet)] {
        [
            ("Ownership Update", .ownershipUpdate),
            ("Install Mod", .installMod),
            ("Replace Part", .replacePart),
            ("Log Plays", .logPlays),
            ("Add Photo/Video", .addMedia)
        ]
    }

    private func hasOpenIssues(for machineID: UUID) -> Bool {
        store.state.issues.contains(where: { $0.ownedMachineID == machineID && $0.status != .resolved })
    }

    private func linkedAttachment(for event: MachineEvent) -> MachineAttachment? {
        store.state.attachments
            .filter { $0.ownerType == .event && $0.ownerID == event.id }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private func linkedEvent(for attachment: MachineAttachment) -> MachineEvent? {
        guard attachment.ownerType == .event else { return nil }
        return store.state.events.first(where: { $0.id == attachment.ownerID })
    }

    private func openAttachment(_ attachment: MachineAttachment) {
        guard let url = urlForAttachmentURI(attachment.uri) else {
            previewAttachment = attachment
            return
        }
        if attachment.kind == .photo {
            fullscreenPhotoItem = FullscreenPhotoItem(url: url)
        } else {
            previewAttachment = attachment
        }
    }

    private func urlForAttachmentURI(_ uri: String) -> URL? {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return URL(fileURLWithPath: trimmed)
    }

    private func logSection(for machine: OwnedMachine) -> some View {
        let events = store.state.events
            .filter { $0.ownedMachineID == machine.id }
            .sorted { $0.occurredAt > $1.occurredAt }
        return VStack(alignment: .leading, spacing: 10) {
            if events.isEmpty {
                AppPanelEmptyCard(text: "No log entries yet.")
            } else {
                if let selected = selectedLogEvent(from: events) {
                    GameRoomLogDetailCard(event: selected)
                }

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(events.prefix(40))) { event in
                            gameRoomLogRow(event)
                            if event.id != events.prefix(40).last?.id {
                                Divider().overlay(.white.opacity(0.14))
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
                .scrollBounceBehavior(.basedOnSize)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if revealedLogEntryID != nil {
                            revealedLogEntryID = nil
                        }
                    }
                )
            }
        }
        .onAppear {
            if selectedLogEventID == nil {
                selectedLogEventID = events.first?.id
            }
        }
        .onChange(of: events.map(\.id)) { _, _ in
            guard let selectedLogEventID else {
                self.selectedLogEventID = events.first?.id
                return
            }
            if !events.contains(where: { $0.id == selectedLogEventID }) {
                self.selectedLogEventID = events.first?.id
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    @ViewBuilder
    private func gameRoomLogRow(_ event: MachineEvent) -> some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            styledPracticeJournalSummary(gameRoomEventSummary(event))
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        JournalSwipeRevealRow(
            id: event.id.uuidString,
            revealedID: $revealedLogEntryID,
            onEdit: {
                editingEvent = event
            },
            onDelete: {
                pendingDeleteEvent = event
            }
        ) {
            content
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    if (event.type == .photoAdded || event.type == .videoAdded),
                       let attachment = linkedAttachment(for: event) {
                        openAttachment(attachment)
                    } else {
                        selectedLogEventID = event.id
                    }
                }
        }
    }

    private func gameRoomEventSummary(_ event: MachineEvent) -> String {
        if event.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return event.type.displayTitle
        }
        return event.summary
    }

    private func selectedLogEvent(from events: [MachineEvent]) -> MachineEvent? {
        guard let selectedLogEventID else { return events.first }
        return events.first(where: { $0.id == selectedLogEventID }) ?? events.first
    }
}
