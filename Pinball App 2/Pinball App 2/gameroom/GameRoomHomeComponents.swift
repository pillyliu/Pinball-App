import SwiftUI

enum GameRoomCollectionLayout: String, CaseIterable, Identifiable {
    case tiles
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiles: return "Cards"
        case .list: return "List"
        }
    }
}

struct GameRoomHomeView: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let onOpenSettings: () -> Void
    let onOpenMachineView: (UUID) -> Void
    @State private var selectedMachineID: UUID?
    @State private var collectionLayout: GameRoomCollectionLayout = .tiles

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(store.venueName)
                            .font(.title3.weight(.semibold))

                        Spacer()

                        Button(action: onOpenSettings) {
                            Image(systemName: "gearshape")
                        }
                        .buttonStyle(.glass)
                    }
                    .padding(.leading, 8)

                    GameRoomSelectedSummaryCard(
                        store: store,
                        selectedMachine: selectedMachine
                    )
                    GameRoomCollectionCard(
                        store: store,
                        catalogLoader: catalogLoader,
                        selectedMachineID: selectedMachineID,
                        collectionLayout: collectionLayout,
                        onChangeLayout: { collectionLayout = $0 },
                        onMachineTap: handleMachineTap
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            seedSelectionIfNeeded()
        }
        .onChange(of: store.activeMachines.map(\.id)) { _, _ in
            seedSelectionIfNeeded()
        }
    }

    private var selectedMachine: OwnedMachine? {
        guard let selectedMachineID else { return store.activeMachines.first }
        return store.activeMachines.first(where: { $0.id == selectedMachineID }) ?? store.activeMachines.first
    }

    private func seedSelectionIfNeeded() {
        guard !store.activeMachines.isEmpty else {
            selectedMachineID = nil
            return
        }
        guard let selectedMachineID,
              store.activeMachines.contains(where: { $0.id == selectedMachineID }) else {
            self.selectedMachineID = store.activeMachines.first?.id
            return
        }
    }

    private func handleMachineTap(_ machine: OwnedMachine) {
        if selectedMachineID == machine.id {
            onOpenMachineView(machine.id)
            return
        }
        selectedMachineID = machine.id
    }
}

private struct GameRoomSelectedSummaryCard: View {
    @ObservedObject var store: GameRoomStore
    let selectedMachine: OwnedMachine?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selected Machine")
                .font(.headline)

            if let selectedMachine {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(selectedMachine.displayTitle)
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 8)

                    if let label = variantBadgeLabel(for: selectedMachine) {
                        GameRoomVariantPill(label: label, style: .standard)
                    }
                }

                Text(locationLine(for: selectedMachine))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Current Snapshot")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 2)

                GameRoomSnapshotMetricGrid(items: snapshotMetrics(for: selectedMachine))

                if let purchaseDateRawText = selectedMachine.purchaseDateRawText, !purchaseDateRawText.isEmpty {
                    Text("Purchase (raw): \(purchaseDateRawText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select a machine from the collection below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func locationLine(for machine: OwnedMachine) -> String {
        let areaName = store.area(for: machine.gameRoomAreaID)?.name ?? "No area"
        let group = machine.groupNumber.map(String.init) ?? "—"
        let position = machine.position.map(String.init) ?? "—"
        return "Location: \(areaName) • Group \(group) • Position \(position)"
    }

    private func snapshotMetrics(for machine: OwnedMachine) -> [GameRoomSnapshotMetric] {
        let snapshot = store.snapshot(for: machine.id)
        let pitchText = snapshot.currentPitchValue.map { String(format: "%.1f", $0) } ?? "—"
        return [
            GameRoomSnapshotMetric(label: "Open Issues", value: "\(snapshot.openIssueCount)"),
            GameRoomSnapshotMetric(label: "Current Plays", value: "\(snapshot.currentPlayCount)"),
            GameRoomSnapshotMetric(label: "Due Tasks", value: "\(snapshot.dueTaskCount)"),
            GameRoomSnapshotMetric(label: "Last Service", value: snapshot.lastServiceAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
            GameRoomSnapshotMetric(label: "Pitch", value: pitchText),
            GameRoomSnapshotMetric(label: "Last Level", value: snapshot.lastLeveledAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
            GameRoomSnapshotMetric(label: "Last Inspection", value: snapshot.lastGeneralInspectionAt?.formatted(date: .abbreviated, time: .omitted) ?? "None"),
            GameRoomSnapshotMetric(label: "Purchase Date", value: machine.purchaseDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
        ]
    }

    private func variantBadgeLabel(for machine: OwnedMachine) -> String? {
        gameRoomVariantBadgeLabel(variant: machine.displayVariant, title: machine.displayTitle)
    }
}

struct GameRoomSnapshotMetric: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct GameRoomSnapshotMetricGrid: View {
    let items: [GameRoomSnapshotMetric]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct GameRoomCollectionCard: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let selectedMachineID: UUID?
    let collectionLayout: GameRoomCollectionLayout
    let onChangeLayout: (GameRoomCollectionLayout) -> Void
    let onMachineTap: (OwnedMachine) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Collection")
                    .font(.headline)

                Spacer()

                Picker("Layout", selection: Binding(
                    get: { collectionLayout },
                    set: { onChangeLayout($0) }
                )) {
                    ForEach(GameRoomCollectionLayout.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .appSegmentedControlStyle()
                .frame(maxWidth: 160)
            }

            Text("Tracked active machines: \(store.activeMachines.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if store.activeMachines.isEmpty {
                AppPanelEmptyCard(text: "No active machines yet. Add one in GameRoom Settings > Edit.")
            } else if collectionLayout == .tiles {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.activeMachines) { machine in
                        GameRoomMiniCard(
                            machine: machine,
                            imageCandidates: catalogLoader.imageCandidates(for: machine),
                            snapshot: store.snapshot(for: machine.id),
                            isSelected: machine.id == selectedMachineID,
                            onTap: { onMachineTap(machine) }
                        )
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(store.activeMachines) { machine in
                        GameRoomListRow(
                            machine: machine,
                            imageCandidates: catalogLoader.imageCandidates(for: machine),
                            snapshot: store.snapshot(for: machine.id),
                            areaName: store.area(for: machine.gameRoomAreaID)?.name,
                            isSelected: machine.id == selectedMachineID,
                            onTap: { onMachineTap(machine) }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }
}

private struct GameRoomMiniCard: View {
    let machine: OwnedMachine
    let imageCandidates: [URL]
    let snapshot: OwnedMachineSnapshot
    let isSelected: Bool
    let onTap: () -> Void
    private let cornerRadius: CGFloat = 10

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
                .overlay(
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.82))

                        FallbackAsyncImageView(
                            candidates: imageCandidates,
                            emptyMessage: nil,
                            contentMode: .fill,
                            fillAlignment: .center,
                            layoutMode: .fill
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.0), location: 0.0),
                                .init(color: Color.black.opacity(0.0), location: 0.18),
                                .init(color: Color.black.opacity(0.50), location: 0.40),
                                .init(color: Color.black.opacity(0.78), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(machine.displayTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(1.0), radius: 4, x: 0, y: 3)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 4)

                        if let label = variantBadgeLabel {
                            GameRoomVariantPill(label: label, style: .mini)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(isSelected ? AppTheme.brandGold.opacity(0.88) : Color.clear, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.brandInk.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 8, height: 8)
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .frame(height: 64)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture(perform: onTap)
    }

    private var statusColor: Color {
        switch snapshot.attentionState {
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        case .gray: return .gray
        }
    }

    private var variantBadgeLabel: String? {
        gameRoomVariantBadgeLabel(variant: machine.displayVariant, title: machine.displayTitle)
    }
}

private struct GameRoomListRow: View {
    let machine: OwnedMachine
    let imageCandidates: [URL]
    let snapshot: OwnedMachineSnapshot
    let areaName: String?
    let isSelected: Bool
    let onTap: () -> Void
    private let cornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
                .overlay(
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.82))

                        FallbackAsyncImageView(
                            candidates: imageCandidates,
                            emptyMessage: nil,
                            contentMode: .fill,
                            fillAlignment: .center,
                            layoutMode: .fill
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.0), location: 0.0),
                                .init(color: Color.black.opacity(0.0), location: 0.18),
                                .init(color: Color.black.opacity(0.50), location: 0.40),
                                .init(color: Color.black.opacity(0.78), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(isSelected ? AppTheme.brandGold.opacity(0.88) : Color.clear, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(machine.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(1.0), radius: 4, x: 0, y: 3)
                        .lineLimit(1)

                    Text(metaLine)
                        .font(.footnote)
                        .foregroundStyle(Color.white.opacity(0.86))
                        .shadow(color: .black.opacity(1.0), radius: 3, x: 0, y: 2)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if let label = variantBadgeLabel {
                    GameRoomVariantPill(label: label, style: .standard)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .frame(height: 58)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture(perform: onTap)
    }

    private var statusColor: Color {
        switch snapshot.attentionState {
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        case .gray: return .gray
        }
    }

    private var metaLine: String {
        let area = areaName ?? "No area"
        let group = machine.groupNumber.map(String.init) ?? "—"
        let position = machine.position.map(String.init) ?? "—"
        return "\(area) • G\(group) • P\(position)"
    }

    private var variantBadgeLabel: String? {
        gameRoomVariantBadgeLabel(variant: machine.displayVariant, title: machine.displayTitle)
    }
}

struct GameRoomVariantPill: View {
    enum Style {
        case mini
        case standard
        case machineTitle
        case editSelector

        var font: Font {
            switch self {
            case .mini:
                return .system(size: 10, weight: .semibold)
            case .standard:
                return .caption2.weight(.semibold)
            case .machineTitle:
                return .footnote.weight(.semibold)
            case .editSelector:
                return .subheadline.weight(.semibold)
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .mini:
                return 6
            case .standard, .machineTitle, .editSelector:
                return 8
            }
        }
    }

    let label: String
    var style: Style = .standard

    var body: some View {
        Text(compactLabel)
            .font(style.font)
            .foregroundStyle(AppTheme.brandInk)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, 3)
            .background(AppTheme.brandGold.opacity(0.22), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.brandGold.opacity(0.52), lineWidth: 1)
            )
    }

    private var compactLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxAllowed = 7
        guard trimmed.count > maxAllowed else { return trimmed }
        let prefix = String(trimmed.prefix(max(0, maxAllowed - 1)))
        return prefix + "…"
    }
}

func gameRoomVariantBadgeLabel(variant: String?, title: String) -> String? {
    if let variant {
        let cleanedVariant = variant.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedVariant.isEmpty, cleanedVariant.lowercased() != "null" {
            return cleanedVariant
        }
    }

    let loweredVariant = variant?.lowercased() ?? ""
    let loweredTitle = title.lowercased()
    let source = "\(loweredVariant) \(loweredTitle)"

    if source.contains("limited edition") ||
        source.contains("(le") ||
        source.hasSuffix(" le") ||
        source.contains(" le)") {
        return "LE"
    }
    if source.contains("premium") {
        return "Premium"
    }
    if source.contains("(pro") ||
        source.hasSuffix(" pro") ||
        source.contains(" pro)") ||
        loweredVariant == "pro" {
        return "Pro"
    }
    return nil
}
