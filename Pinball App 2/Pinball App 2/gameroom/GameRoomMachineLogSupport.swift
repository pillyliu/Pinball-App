import SwiftUI

private struct GameRoomLogRowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]

    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct GameRoomMachineLogContent: View {
    let events: [MachineEvent]
    @Binding var selectedLogEventID: UUID?
    let linkedAttachment: (MachineEvent) -> MachineAttachment?
    let onOpenAttachment: (MachineAttachment) -> Void
    let onEditEvent: (MachineEvent) -> Void
    let onDeleteEvent: (MachineEvent) -> Void

    @State private var logRowHeights: [UUID: CGFloat] = [:]

    var body: some View {
        let visibleEvents = Array(events.prefix(40))
        return VStack(alignment: .leading, spacing: 10) {
            if events.isEmpty {
                AppPanelEmptyCard(text: "No log entries yet.")
            } else {
                if let selected = selectedLogEvent(from: events) {
                    GameRoomLogDetailCard(event: selected)
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visibleEvents.enumerated()), id: \.element.id) { index, event in
                            gameRoomLogRow(event)
                            if index != visibleEvents.indices.last {
                                Divider()
                                    .overlay(Color.secondary.opacity(0.18))
                            }
                        }
                    }
                }
                .onPreferenceChange(GameRoomLogRowHeightPreferenceKey.self) { heights in
                    let visibleIDs = Set(visibleEvents.map(\.id))
                    logRowHeights = heights.filter { visibleIDs.contains($0.key) }
                }
                .frame(height: embeddedLogListHeight(for: visibleEvents))
            }
        }
        .onAppear {
            if selectedLogEventID == nil {
                selectedLogEventID = events.first?.id
            }
        }
        .onChange(of: events.map(\.id)) { _, _ in
            let visibleIDs = Set(visibleEvents.map(\.id))
            logRowHeights = logRowHeights.filter { visibleIDs.contains($0.key) }
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

    private func embeddedLogListHeight(for events: [MachineEvent]) -> CGFloat {
        let visibleEvents = Array(events.prefix(40))
        guard !visibleEvents.isEmpty else { return 60 }
        let estimatedRowHeight: CGFloat = 58
        let contentPadding: CGFloat = 4
        let measuredContentHeight = visibleEvents.reduce(CGFloat.zero) { partialResult, event in
            partialResult + (logRowHeights[event.id] ?? estimatedRowHeight)
        }
        return min(280, max(60, measuredContentHeight + contentPadding))
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

        JournalStaticEditableRow {
            content
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    if (event.type == .photoAdded || event.type == .videoAdded),
                       let attachment = linkedAttachment(event) {
                        onOpenAttachment(attachment)
                    } else {
                        selectedLogEventID = event.id
                    }
                }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onDeleteEvent(event)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)

            Button {
                onEditEvent(event)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(AppTheme.statsMeanMedian)
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: GameRoomLogRowHeightPreferenceKey.self,
                    value: [event.id: max(proxy.size.height, 1)]
                )
            }
        )
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
