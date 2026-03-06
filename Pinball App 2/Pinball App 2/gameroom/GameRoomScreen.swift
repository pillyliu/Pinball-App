import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import UIKit

enum GameRoomRoute: Hashable {
    case settings
    case machineView(UUID)
}

enum GameRoomSettingsSection: String, CaseIterable, Identifiable {
    case importFromPinside
    case editMachines
    case archive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .importFromPinside:
            return "Import"
        case .editMachines:
            return "Edit"
        case .archive:
            return "Archive"
        }
    }
}

private enum GameRoomCollectionLayout: String, CaseIterable, Identifiable {
    case tiles
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiles: return "Tiles"
        case .list: return "List"
        }
    }
}

struct GameRoomScreen: View {
    @StateObject private var store = GameRoomStore()
    @StateObject private var catalogLoader = GameRoomCatalogLoader()
    @State private var path: [GameRoomRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            GameRoomHomeView(
                store: store,
                catalogLoader: catalogLoader,
                onOpenSettings: { path.append(.settings) },
                onOpenMachineView: { machineID in path.append(.machineView(machineID)) }
            )
            .navigationDestination(for: GameRoomRoute.self) { route in
                switch route {
                case .settings:
                    GameRoomSettingsView(
                        store: store,
                        catalogLoader: catalogLoader,
                        onOpenMachineView: { machineID in
                            path.append(.machineView(machineID))
                        }
                    )
                case let .machineView(machineID):
                    GameRoomMachineView(store: store, catalogLoader: catalogLoader, machineID: machineID)
                }
            }
        }
        .task {
            store.loadIfNeeded()
            await catalogLoader.loadIfNeeded()
        }
    }
}

private struct GameRoomHomeView: View {
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
                        catalogLoader: catalogLoader,
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
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
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

                ForEach(snapshotLines(for: selectedMachine), id: \.self) { line in
                    Text(line)
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

    private func snapshotLines(for machine: OwnedMachine) -> [String] {
        let snapshot = store.snapshot(for: machine.id)
        let pitchText = snapshot.currentPitchValue.map { String(format: "%.1f", $0) } ?? "—"
        var lines = [
            "Open issues: \(snapshot.openIssueCount)",
            "Current plays: \(snapshot.currentPlayCount)",
            "Due tasks: \(snapshot.dueTaskCount)",
            "Last service: \(snapshot.lastServiceAt?.formatted(date: .abbreviated, time: .omitted) ?? "None")",
            "Pitch: \(pitchText)",
            "Last level: \(snapshot.lastLeveledAt?.formatted(date: .abbreviated, time: .omitted) ?? "None")",
            "Last inspection: \(snapshot.lastGeneralInspectionAt?.formatted(date: .abbreviated, time: .omitted) ?? "None")",
            "Purchase date: \(machine.purchaseDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")"
        ]
        if let raw = machine.purchaseDateRawText, !raw.isEmpty {
            lines.append("Purchase (raw): \(raw)")
        }
        return lines
    }

    private func variantBadgeLabel(for machine: OwnedMachine) -> String? {
        gameRoomVariantBadgeLabel(variant: machine.displayVariant, title: machine.displayTitle)
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
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
            }

            Text("Tracked active machines: \(store.activeMachines.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if store.activeMachines.isEmpty {
                Text("No active machines yet. Add one in GameRoom Settings > Edit.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                        .stroke(isSelected ? Color.accentColor.opacity(0.85) : Color.clear, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
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
    let snapshot: OwnedMachineSnapshot
    let areaName: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(machine.displayTitle)
                    .font(.subheadline.weight(.semibold))

                Text(metaLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let label = variantBadgeLabel {
                GameRoomVariantPill(label: label, style: .standard)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? AppTheme.controlBg : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.8) : AppTheme.controlBorder, lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

private struct GameRoomVariantPill: View {
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
            .foregroundStyle(.white)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.72), in: Capsule())
            .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 1)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
    }

    private var compactLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxAllowed = 7 // "Premium" length
        guard trimmed.count > maxAllowed else { return trimmed }
        let prefix = String(trimmed.prefix(max(0, maxAllowed - 1)))
        return prefix + "…"
    }
}

private func gameRoomVariantBadgeLabel(variant: String?, title: String) -> String? {
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

private struct GameRoomSettingsView: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let onOpenMachineView: (UUID) -> Void
    @State private var selectedSection: GameRoomSettingsSection = .importFromPinside

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Mode", selection: $selectedSection) {
                        ForEach(GameRoomSettingsSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    GameRoomSettingsSectionCard(
                        store: store,
                        catalogLoader: catalogLoader,
                        selectedSection: selectedSection,
                        onOpenMachineView: onOpenMachineView
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .navigationTitle("GameRoom Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await catalogLoader.loadIfNeeded()
        }
    }
}

private struct GameRoomSettingsSectionCard: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let selectedSection: GameRoomSettingsSection
    let onOpenMachineView: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sectionHeading)
                .font(.headline)

            switch selectedSection {
            case .importFromPinside:
                GameRoomImportSettingsView(store: store, catalogLoader: catalogLoader)
            case .editMachines:
                GameRoomEditMachinesView(store: store, catalogLoader: catalogLoader)
            case .archive:
                GameRoomArchiveSettingsView(store: store, onOpenMachineView: onOpenMachineView)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var sectionHeading: String {
        switch selectedSection {
        case .importFromPinside:
            return "Import from Pinside"
        case .editMachines:
            return "Edit GameRoom"
        case .archive:
            return "Machine Archive"
        }
    }
}

private struct GameRoomImportSettingsView: View {
    private enum ImportReviewFilter: String, CaseIterable, Identifiable {
        case all
        case needsReview

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .needsReview: return "Needs Review"
            }
        }
    }

    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    private let importService = GameRoomPinsideImportService()
    @State private var sourceInput = ""
    @State private var importedSourceURL = ""
    @State private var draftRows: [ImportDraftRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resultMessage: String?
    @State private var reviewFilter: ImportReviewFilter = .all

    private struct ImportDraftRow: Identifiable {
        let id: String
        let sourceItemKey: String
        let rawTitle: String
        var rawPurchaseDateText: String?
        var normalizedPurchaseDate: Date?
        let matchConfidence: MachineImportMatchConfidence
        let suggestions: [GameRoomCatalogGame]
        let fingerprint: String
        var selectedCatalogGameID: String?
        var selectedVariant: String?
        var rawVariant: String?
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Pinside username or public collection URL", text: $sourceInput)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.go)
                .onSubmit {
                    guard !isLoading, !sourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    fetchCollection()
                }

            HStack(spacing: 10) {
                Button("Fetch Collection") {
                    fetchCollection()
                }
                .buttonStyle(.glass)
                .disabled(isLoading || sourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if !draftRows.isEmpty {
                Text("Review matches (\(draftRows.count))")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)

                Picker("Review Filter", selection: $reviewFilter) {
                    ForEach(ImportReviewFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredRowIndexes, id: \.self) { index in
                            let duplicateWarning = duplicateWarningMessage(for: draftRows[index])
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(draftRows[index].rawTitle)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer(minLength: 8)
                                    confidenceBadge(draftRows[index].matchConfidence)
                                }

                                if let rawVariant = draftRows[index].rawVariant, !rawVariant.isEmpty {
                                    Text("Variant: \(rawVariant)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                TextField(
                                    "Purchase date (raw import text)",
                                    text: Binding(
                                        get: { draftRows[index].rawPurchaseDateText ?? "" },
                                        set: { newValue in
                                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                            draftRows[index].rawPurchaseDateText = trimmed.isEmpty ? nil : trimmed
                                            draftRows[index].normalizedPurchaseDate = normalizedFirstOfMonth(from: draftRows[index].rawPurchaseDateText)
                                        }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)

                                if let normalizedPurchaseDate = draftRows[index].normalizedPurchaseDate {
                                    Text("Normalized: \(normalizedPurchaseDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                if let duplicateWarning {
                                    Text(duplicateWarning)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.yellow)
                                }

                                Menu {
                                    ForEach(draftRows[index].suggestions, id: \.id) { suggestion in
                                        Button(matchLabel(for: suggestion)) {
                                            draftRows[index].selectedCatalogGameID = suggestion.catalogGameID
                                            if let current = draftRows[index].selectedVariant {
                                                let variants = catalogLoader.variantOptions(for: suggestion.catalogGameID)
                                                if !variants.contains(where: { $0.caseInsensitiveCompare(current) == .orderedSame }) {
                                                    draftRows[index].selectedVariant = nil
                                                }
                                            }
                                        }
                                    }
                                    Button("Clear Match") {
                                        draftRows[index].selectedCatalogGameID = nil
                                    }
                                } label: {
                                    Label(matchMenuLabel(for: draftRows[index]), systemImage: "link")
                                }
                                .buttonStyle(.glass)

                                if let selectedCatalogGameID = draftRows[index].selectedCatalogGameID {
                                    let variants = catalogLoader.variantOptions(for: selectedCatalogGameID)
                                    if !variants.isEmpty {
                                        Menu {
                                            Button("None") {
                                                draftRows[index].selectedVariant = nil
                                            }
                                            ForEach(variants, id: \.self) { variant in
                                                Button(variant) {
                                                    draftRows[index].selectedVariant = variant
                                                }
                                            }
                                        } label: {
                                            Label("Variant: \(draftRows[index].selectedVariant ?? "None")", systemImage: "tag")
                                        }
                                        .buttonStyle(.glass)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(AppTheme.controlBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AppTheme.controlBorder, lineWidth: 1)
                            )
                        }
                    }
                }
                .frame(maxHeight: 360)

                Button("Import Selected Matches") {
                    performImport()
                }
                .buttonStyle(.glass)
            }

            if let resultMessage {
                Text(resultMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Import records stored: \(store.state.importRecords.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var filteredRowIndexes: [Int] {
        draftRows.indices.filter { index in
            switch reviewFilter {
            case .all:
                return true
            case .needsReview:
                return needsReview(draftRows[index])
            }
        }
    }

    private func needsReview(_ row: ImportDraftRow) -> Bool {
        row.matchConfidence != .high || row.selectedCatalogGameID == nil || duplicateWarningMessage(for: row) != nil
    }

    private func confidenceBadge(_ confidence: MachineImportMatchConfidence) -> some View {
        let color: Color
        switch confidence {
        case .high:
            color = .green
        case .medium:
            color = .yellow
        case .low, .manual:
            color = .red
        }

        return Text(confidence.rawValue.capitalized)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.85), in: Capsule())
    }

    private func duplicateWarningMessage(for row: ImportDraftRow) -> String? {
        if store.hasImportFingerprint(row.fingerprint) {
            return "Already imported previously."
        }
        guard let selectedCatalogGameID = row.selectedCatalogGameID,
              let selectedGame = catalogLoader.game(for: selectedCatalogGameID) else {
            return nil
        }
        let selectedVariant = row.selectedVariant ?? row.rawVariant
        if let existing = store.existingOwnedMachine(catalogGameID: selectedGame.catalogGameID, displayVariant: selectedVariant) {
            if let variant = existing.displayVariant, !variant.isEmpty {
                return "Duplicate of existing machine: \(existing.displayTitle) (\(variant))."
            }
            return "Duplicate of existing machine: \(existing.displayTitle)."
        }
        return nil
    }

    private func fetchCollection() {
        errorMessage = nil
        resultMessage = nil
        isLoading = true
        let input = sourceInput

        Task {
            do {
                let result = try await importService.fetchCollectionMachines(sourceInput: input)
                let rows = result.machines.map(makeDraftRow)
                await MainActor.run {
                    importedSourceURL = result.sourceURL
                    draftRows = rows
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    importedSourceURL = ""
                    draftRows = []
                    isLoading = false
                }
            }
        }
    }

    private func performImport() {
        guard !draftRows.isEmpty else { return }

        var importedCount = 0
        var skippedDuplicates = 0
        var skippedUnmatched = 0

        for row in draftRows {
            guard let selectedCatalogGameID = row.selectedCatalogGameID,
                  let game = catalogLoader.game(for: selectedCatalogGameID) else {
                skippedUnmatched += 1
                continue
            }

            if store.hasImportFingerprint(row.fingerprint) ||
                store.hasOwnedMachine(catalogGameID: game.catalogGameID, displayVariant: row.selectedVariant ?? row.rawVariant) {
                skippedDuplicates += 1
                continue
            }

            _ = store.importOwnedMachine(
                game: game,
                sourceUserOrURL: importedSourceURL,
                sourceItemKey: row.sourceItemKey,
                rawTitle: row.rawTitle,
                rawVariant: row.selectedVariant ?? row.rawVariant,
                rawPurchaseDateText: row.rawPurchaseDateText,
                normalizedPurchaseDate: row.normalizedPurchaseDate,
                matchConfidence: row.matchConfidence,
                fingerprint: row.fingerprint
            )
            importedCount += 1
        }

        resultMessage = "Imported \(importedCount). Skipped \(skippedDuplicates) duplicates, \(skippedUnmatched) unmatched."
    }

    private func makeDraftRow(_ machine: PinsideImportedMachine) -> ImportDraftRow {
        let scored = scoredSuggestions(for: machine)
        let suggestions = scored.map(\.game)
        let top = scored.first

        return ImportDraftRow(
            id: machine.id,
            sourceItemKey: machine.slug,
            rawTitle: machine.rawTitle,
            rawPurchaseDateText: machine.rawPurchaseDateText,
            normalizedPurchaseDate: machine.normalizedPurchaseDate,
            matchConfidence: confidence(for: top?.score ?? 0),
            suggestions: suggestions,
            fingerprint: machine.fingerprint,
            selectedCatalogGameID: top?.game.catalogGameID,
            selectedVariant: machine.rawVariant,
            rawVariant: machine.rawVariant
        )
    }

    private func scoredSuggestions(for machine: PinsideImportedMachine) -> [(game: GameRoomCatalogGame, score: Int)] {
        let normalizedRawTitle = normalized(machine.rawTitle)
        let normalizedVariant = normalized(machine.rawVariant ?? "")
        let candidates = catalogLoader.games.map { game -> (GameRoomCatalogGame, Int) in
            let normalizedGameTitle = normalized(game.displayTitle)
            var score = 0

            if normalizedRawTitle == normalizedGameTitle {
                score += 120
            } else if normalizedGameTitle.contains(normalizedRawTitle) || normalizedRawTitle.contains(normalizedGameTitle) {
                score += 80
            } else {
                score += tokenOverlapScore(lhs: normalizedRawTitle, rhs: normalizedGameTitle)
            }

            if !normalizedVariant.isEmpty {
                let variants = catalogLoader.variantOptions(for: game.catalogGameID).map(normalized)
                if variants.contains(normalizedVariant) {
                    score += 20
                }
            }

            return (game, score)
        }

        return candidates
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                return $0.0.displayTitle.localizedCaseInsensitiveCompare($1.0.displayTitle) == .orderedAscending
            }
            .prefix(3)
            .map { $0 }
    }

    private func confidence(for score: Int) -> MachineImportMatchConfidence {
        if score >= 120 { return .high }
        if score >= 80 { return .medium }
        if score > 0 { return .low }
        return .manual
    }

    private func tokenOverlapScore(lhs: String, rhs: String) -> Int {
        let lhsSet = Set(lhs.split(separator: " ").map(String.init))
        let rhsSet = Set(rhs.split(separator: " ").map(String.init))
        guard !lhsSet.isEmpty, !rhsSet.isEmpty else { return 0 }
        let intersection = lhsSet.intersection(rhsSet).count
        if intersection == 0 { return 0 }
        return Int((Double(intersection) / Double(max(lhsSet.count, rhsSet.count))) * 70.0)
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedFirstOfMonth(from raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }

        let monthYearFormats = [
            "MMMM yyyy",
            "MMM yyyy",
            "M/yyyy",
            "MM/yyyy",
            "M-yyyy",
            "MM-yyyy",
            "yyyy-MM",
            "yyyy/M"
        ]

        let fullDateFormats = [
            "yyyy-MM-dd",
            "M/d/yyyy",
            "MM/dd/yyyy",
            "MMM d, yyyy",
            "MMMM d, yyyy"
        ]

        let calendar = Calendar(identifier: .gregorian)

        for format in monthYearFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: raw),
               let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) {
                return normalized
            }
        }

        for format in fullDateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: raw),
               let normalized = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) {
                return normalized
            }
        }

        return nil
    }

    private func matchLabel(for game: GameRoomCatalogGame) -> String {
        if let variant = game.displayVariant {
            return "\(game.displayTitle) (\(variant))"
        }
        return game.displayTitle
    }

    private func matchMenuLabel(for row: ImportDraftRow) -> String {
        guard let selectedCatalogGameID = row.selectedCatalogGameID,
              let selected = catalogLoader.game(for: selectedCatalogGameID) else {
            return "No Match Selected"
        }
        return "Match: \(selected.displayTitle)"
    }
}

private struct GameRoomEditMachinesView: View {
    private static let resultPageSize = 25
    private static let maxRenderedResults = 75

    private struct MachineMenuGroup: Identifiable {
        var id: String { key }
        let key: String
        let title: String
        let machines: [OwnedMachine]
    }

    private struct PendingScrollRestore: Equatable {
        let targetID: String
        let token: UUID
    }

    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    @State private var searchText = ""
    @State private var selectedManufacturerID: String?
    @State private var selectedMachineID: UUID?
    @State private var selectedAreaID: UUID?
    @State private var resultWindowStart = 0
    @State private var resultWindowEnd = 0
    @State private var pendingScrollRestore: PendingScrollRestore?
    @State private var draftAreaID: UUID?
    @State private var draftGroup = ""
    @State private var draftPosition = ""
    @State private var draftStatus: OwnedMachineStatus = .active
    @State private var draftDisplayVariant = ""
    @State private var draftPurchaseSource = ""
    @State private var draftSerialNumber = ""
    @State private var draftOwnershipNotes = ""
    @State private var newAreaName = ""
    @State private var newAreaOrder = 1
    @State private var venueNameDraft = ""
    @State private var isNameExpanded = false
    @State private var isAddMachineExpanded = false
    @State private var isAreasExpanded = false
    @State private var isEditMachinesExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelDisclosure(title: "Name", isExpanded: $isNameExpanded) {
                venueNamePanel
            }
            panelDisclosure(title: "Add Machine", isExpanded: $isAddMachineExpanded) {
                addMachinePanel
            }
            panelDisclosure(title: "Areas", isExpanded: $isAreasExpanded) {
                areaManagementPanel
            }
            panelDisclosure(title: editMachinesPanelTitle, isExpanded: $isEditMachinesExpanded) {
                machineManagementPanel
            }
        }
        .onAppear {
            seedSelectionIfNeeded()
            resetResultWindow()
        }
        .onChange(of: store.state.ownedMachines.map(\.id)) { _, _ in
            seedSelectionIfNeeded()
            syncDraftFromSelection()
        }
        .onChange(of: selectedMachineID) { _, _ in
            syncDraftFromSelection()
        }
        .onChange(of: searchText) { _, _ in
            resetResultWindow()
        }
        .onChange(of: selectedManufacturerID) { _, _ in
            resetResultWindow()
        }
    }

    private func panelDisclosure<Content: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            content()
                .padding(.top, 8)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .appPanelStyle()
    }

    private var addMachinePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search by title", text: $searchText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Menu {
                    Button("All Manufacturers") {
                        selectedManufacturerID = nil
                    }

                    if !modernManufacturers.isEmpty {
                        Section("Modern") {
                            ForEach(modernManufacturers) { option in
                                Button(option.name) {
                                    selectedManufacturerID = option.id
                                }
                            }
                        }
                    }

                    if !classicPopularManufacturers.isEmpty {
                        Section("Classic Popular") {
                            ForEach(classicPopularManufacturers) { option in
                                Button(option.name) {
                                    selectedManufacturerID = option.id
                                }
                            }
                        }
                    }

                    if !otherManufacturers.isEmpty {
                        Section("Other") {
                            ForEach(otherManufacturers) { option in
                                Button(option.name) {
                                    selectedManufacturerID = option.id
                                }
                            }
                        }
                    }
                } label: {
                    Label(selectedManufacturerLabel, systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.glass)

                Spacer()

                if catalogLoader.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("\(filteredCatalogGames.count) matches")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = catalogLoader.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if filteredCatalogGames.isEmpty {
                Text("No titles match the current search.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(resultWindowLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if hasPreviousFilteredResults {
                                Button("Show Previous 25") {
                                    loadPreviousResultPage()
                                }
                                .buttonStyle(.glass)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 4)
                            }

                            ForEach(displayedCatalogGames, id: \.id) { game in
                                HStack(alignment: .center, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(game.displayTitle)
                                            .font(.subheadline.weight(.semibold))
                                        Text(resultMetaLine(for: game))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Button("Add") {
                                        store.addOwnedMachine(from: game)
                                        selectedMachineID = store.state.ownedMachines.last?.id
                                        syncDraftFromSelection()
                                    }
                                    .buttonStyle(.glass)
                                }
                                .padding(.vertical, 2)
                                .id(game.id)
                            }

                            if hasNextFilteredResults {
                                Button("Show Next 25") {
                                    loadNextResultPage()
                                }
                                .buttonStyle(.glass)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                    .onChange(of: pendingScrollRestore) { _, restore in
                        guard let restore else { return }
                        DispatchQueue.main.async {
                            proxy.scrollTo(restore.targetID, anchor: .top)
                            pendingScrollRestore = nil
                        }
                    }
                }
            }
        }
    }

    private var venueNamePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("GameRoom Name", text: $venueNameDraft)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button("Save") {
                    store.updateVenueName(venueNameDraft)
                    venueNameDraft = store.venueName
                }
                .buttonStyle(.glass)

                Spacer()
            }
        }
    }

    private var areaManagementPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                TextField("Area name", text: $newAreaName)
                    .textFieldStyle(.roundedBorder)

                TextField("Area order", value: $newAreaOrder, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .keyboardType(.numberPad)
            }

            HStack(spacing: 10) {
                Button("Save") {
                    store.upsertArea(name: newAreaName, areaOrder: max(1, newAreaOrder))
                    selectedAreaID = nil
                    newAreaName = ""
                    newAreaOrder = 1
                }
                .buttonStyle(.glass)

                Button("Edit") {
                    guard let areaID = selectedAreaID else { return }
                    store.upsertArea(id: areaID, name: newAreaName, areaOrder: max(1, newAreaOrder))
                    selectedAreaID = nil
                    newAreaName = ""
                    newAreaOrder = 1
                }
                .buttonStyle(.glass)
                .disabled(selectedAreaID == nil)

                Spacer()
            }

            if store.state.areas.isEmpty {
                Text("No areas yet. Add an area like Upstairs or Basement to keep area order consistent across machines.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.state.areas) { area in
                        HStack {
                            Button {
                                selectedAreaID = area.id
                                newAreaName = area.name
                                newAreaOrder = area.areaOrder
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(area.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("Area order \(area.areaOrder)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(role: .destructive) {
                                if draftAreaID == area.id {
                                    draftAreaID = nil
                                }
                                if selectedAreaID == area.id {
                                    selectedAreaID = nil
                                    newAreaName = ""
                                    newAreaOrder = 1
                                }
                                store.deleteArea(id: area.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
    }

    private var machineManagementPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if allMachines.isEmpty {
                Text("No machines in the collection yet. Add a machine above to start organizing the GameRoom.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    Menu {
                        ForEach(machineMenuGroups) { group in
                            Section(group.title) {
                                ForEach(group.machines) { machine in
                                    Button(machineMenuLabel(for: machine)) {
                                        selectedMachineID = machine.id
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedMachine?.displayTitle ?? "Select Machine")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                    }
                    .buttonStyle(.glass)

                    Spacer()

                    Menu {
                        Button("None") {
                            draftDisplayVariant = ""
                        }

                        if let selectedMachine, !variantOptions(for: selectedMachine).isEmpty {
                            Divider()
                            ForEach(variantOptions(for: selectedMachine), id: \.self) { variant in
                                Button(variant) {
                                    draftDisplayVariant = variant
                                }
                            }
                        }
                    } label: {
                        GameRoomVariantPill(label: currentVariantLabel, style: .editSelector)
                    }
                }
                .padding(.bottom, 2)

                if let selectedMachine = selectedMachine {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Menu {
                                Button("No Area") {
                                    draftAreaID = nil
                                }

                                if !store.state.areas.isEmpty {
                                    Divider()
                                }

                                ForEach(store.state.areas) { area in
                                    Button(area.name) {
                                        draftAreaID = area.id
                                    }
                                }
                            } label: {
                                Label(selectedAreaLabel, systemImage: "map")
                            }
                            .buttonStyle(.glass)

                            Picker("Status", selection: $draftStatus) {
                                ForEach(OwnedMachineStatus.allCases) { status in
                                    Text(status.rawValue.capitalized).tag(status)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        HStack(spacing: 10) {
                            TextField("Group", text: $draftGroup)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)

                            TextField("Position", text: $draftPosition)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }

                        TextField("Purchase Source", text: $draftPurchaseSource)
                            .textFieldStyle(.roundedBorder)
                        TextField("Serial Number", text: $draftSerialNumber)
                            .textFieldStyle(.roundedBorder)

                        TextField("Ownership Notes", text: $draftOwnershipNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3, reservesSpace: true)

                        HStack {
                            Button("Save") {
                                store.updateMachine(
                                    id: selectedMachine.id,
                                    areaID: draftAreaID,
                                    groupNumber: parsedOptionalInt(draftGroup),
                                    position: parsedOptionalInt(draftPosition),
                                    status: draftStatus,
                                    displayVariant: parsedOptionalString(draftDisplayVariant),
                                    purchaseSource: draftPurchaseSource,
                                    serialNumber: draftSerialNumber,
                                    ownershipNotes: draftOwnershipNotes
                                )
                            }
                            .buttonStyle(.glass)

                            Button(role: .destructive) {
                                store.deleteMachine(id: selectedMachine.id)
                                selectedMachineID = allMachines.first?.id
                                syncDraftFromSelection()
                            } label: {
                                Text("Delete")
                            }
                            .buttonStyle(.glass)

                            Spacer()

                            if selectedMachine.status != .archived {
                                Button("Archive") {
                                    store.updateMachine(
                                        id: selectedMachine.id,
                                        areaID: draftAreaID,
                                        groupNumber: parsedOptionalInt(draftGroup),
                                        position: parsedOptionalInt(draftPosition),
                                        status: .archived,
                                        displayVariant: parsedOptionalString(draftDisplayVariant),
                                        purchaseSource: draftPurchaseSource,
                                        serialNumber: draftSerialNumber,
                                        ownershipNotes: draftOwnershipNotes
                                    )
                                    draftStatus = .archived
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }
                }
            }
        }
    }

    private var allMachines: [OwnedMachine] {
        (store.activeMachines + store.archivedMachines)
    }

    private var machineMenuGroups: [MachineMenuGroup] {
        let grouped = Dictionary(grouping: allMachines) { machine in
            machine.gameRoomAreaID?.uuidString ?? "no-area"
        }

        let sortedKeys = grouped.keys.sorted { lhs, rhs in
            let lhsArea = lhs == "no-area" ? nil : UUID(uuidString: lhs)
            let rhsArea = rhs == "no-area" ? nil : UUID(uuidString: rhs)

            let lhsOrder = store.area(for: lhsArea)?.areaOrder ?? Int.max
            let rhsOrder = store.area(for: rhsArea)?.areaOrder ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }

            let lhsName = areaTitle(for: lhsArea)
            let rhsName = areaTitle(for: rhsArea)
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }

        return sortedKeys.compactMap { key in
            guard let machines = grouped[key] else { return nil }
            let areaID = key == "no-area" ? nil : UUID(uuidString: key)
            let title = areaTitle(for: areaID)
            let sortedMachines = machines.sorted { lhs, rhs in
                if lhs.displayTitle != rhs.displayTitle {
                    return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return MachineMenuGroup(key: key, title: title, machines: sortedMachines)
        }
    }

    private var editMachinesPanelTitle: String {
        "Edit Machines (\(store.activeMachines.count))"
    }

    private func areaTitle(for areaID: UUID?) -> String {
        guard let areaID, let area = store.area(for: areaID) else { return "No Area" }
        return area.name
    }

    private func machineMenuLabel(for machine: OwnedMachine) -> String {
        let status = machine.status == .active ? nil : machine.status.rawValue.capitalized
        guard let status else { return machine.displayTitle }
        return "\(machine.displayTitle) (\(status))"
    }

    private var selectedMachine: OwnedMachine? {
        guard let selectedMachineID else { return allMachines.first }
        return allMachines.first(where: { $0.id == selectedMachineID })
    }

    private var selectedManufacturerLabel: String {
        guard let selectedManufacturerID,
              let option = catalogLoader.manufacturerOptions.first(where: { $0.id == selectedManufacturerID }) else {
            return "All Manufacturers"
        }
        return option.name
    }

    private var selectedAreaLabel: String {
        guard let draftAreaID,
              let area = store.area(for: draftAreaID) else {
            return "No Area"
        }
        return area.name
    }

    private var currentVariantLabel: String {
        let trimmed = draftDisplayVariant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "None" : trimmed
    }

    private var modernManufacturers: [PinballCatalogManufacturerOption] {
        catalogLoader.manufacturerOptions.filter(\.isModern)
    }

    private var classicPopularManufacturers: [PinballCatalogManufacturerOption] {
        catalogLoader.manufacturerOptions.filter { !$0.isModern && $0.featuredRank != nil }
    }

    private var otherManufacturers: [PinballCatalogManufacturerOption] {
        catalogLoader.manufacturerOptions.filter { !$0.isModern && $0.featuredRank == nil }
    }

    private var filteredCatalogGames: [GameRoomCatalogGame] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = trimmedSearch.localizedLowercase

        return catalogLoader.games.filter { game in
            let manufacturerMatches = selectedManufacturerID == nil || game.manufacturerID == selectedManufacturerID
            guard manufacturerMatches else { return false }
            guard !normalizedSearch.isEmpty else { return true }

            let haystack = [
                game.displayTitle,
                game.displayVariant,
                game.manufacturer,
                game.year.map(String.init)
            ]
            .compactMap { $0?.localizedLowercase }
            .joined(separator: " ")

            return haystack.contains(normalizedSearch)
        }
    }

    private var displayedCatalogGames: [GameRoomCatalogGame] {
        guard !filteredCatalogGames.isEmpty else { return [] }
        let safeStart = min(max(0, resultWindowStart), filteredCatalogGames.count)
        let safeEnd = min(max(safeStart, resultWindowEnd), filteredCatalogGames.count)
        return Array(filteredCatalogGames[safeStart..<safeEnd])
    }

    private var hasNextFilteredResults: Bool {
        resultWindowEnd < filteredCatalogGames.count
    }

    private var hasPreviousFilteredResults: Bool {
        resultWindowStart > 0
    }

    private var resultWindowLabel: String {
        guard !filteredCatalogGames.isEmpty else { return "Showing 0 results" }
        let start = min(resultWindowStart + 1, filteredCatalogGames.count)
        let end = min(resultWindowEnd, filteredCatalogGames.count)
        return "Showing \(start)-\(end) of \(filteredCatalogGames.count)"
    }

    private func resultMetaLine(for game: GameRoomCatalogGame) -> String {
        var parts: [String] = []
        if let variant = game.displayVariant {
            parts.append(variant)
        }
        if let manufacturer = game.manufacturer {
            parts.append(manufacturer)
        }
        if let year = game.year {
            parts.append(String(year))
        }
        return parts.isEmpty ? "Catalog match" : parts.joined(separator: " • ")
    }

    private func seedSelectionIfNeeded() {
        if venueNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            venueNameDraft = store.venueName
        }
        guard selectedMachineID == nil else { return }
        selectedMachineID = allMachines.first?.id
    }

    private func syncDraftFromSelection() {
        guard let selectedMachine else { return }
        draftAreaID = selectedMachine.gameRoomAreaID
        draftGroup = selectedMachine.groupNumber.map(String.init) ?? ""
        draftPosition = selectedMachine.position.map(String.init) ?? ""
        draftStatus = selectedMachine.status
        draftDisplayVariant = selectedMachine.displayVariant ?? ""
        draftPurchaseSource = selectedMachine.purchaseSource ?? ""
        draftSerialNumber = selectedMachine.serialNumber ?? ""
        draftOwnershipNotes = selectedMachine.ownershipNotes ?? ""
    }

    private func parsedOptionalInt(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmed)
    }

    private func parsedOptionalString(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func variantOptions(for machine: OwnedMachine) -> [String] {
        var variants = catalogLoader.variantOptions(for: machine.catalogGameID)
        if let current = parsedOptionalString(draftDisplayVariant), !variants.contains(where: { $0.caseInsensitiveCompare(current) == .orderedSame }) {
            variants.insert(current, at: 0)
        }
        return variants
    }

    private func resetResultWindow() {
        resultWindowStart = 0
        resultWindowEnd = min(Self.resultPageSize, filteredCatalogGames.count)
    }

    private func loadNextResultPage() {
        guard hasNextFilteredResults else { return }
        let currentTopID = displayedCatalogGames.first?.id
        let nextEnd = min(resultWindowEnd + Self.resultPageSize, filteredCatalogGames.count)
        var nextStart = resultWindowStart

        if nextEnd - nextStart > Self.maxRenderedResults {
            nextStart = min(nextStart + Self.resultPageSize, max(0, nextEnd - Self.maxRenderedResults))
        }

        resultWindowStart = nextStart
        resultWindowEnd = nextEnd

        if let currentTopID, nextStart > 0 {
            pendingScrollRestore = PendingScrollRestore(targetID: currentTopID, token: UUID())
        }
    }

    private func loadPreviousResultPage() {
        guard hasPreviousFilteredResults else { return }
        let currentTopID = displayedCatalogGames.first?.id
        let previousStart = max(0, resultWindowStart - Self.resultPageSize)
        resultWindowStart = previousStart
        if let currentTopID {
            pendingScrollRestore = PendingScrollRestore(targetID: currentTopID, token: UUID())
        }
    }
}

private struct GameRoomArchiveSettingsView: View {
    private enum ArchiveFilter: String, CaseIterable, Identifiable {
        case all
        case sold
        case traded
        case archived

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .sold: return "Sold"
            case .traded: return "Traded"
            case .archived: return "Archived"
            }
        }
    }

    @ObservedObject var store: GameRoomStore
    let onOpenMachineView: (UUID) -> Void
    @State private var selectedFilter: ArchiveFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Archive Filter", selection: $selectedFilter) {
                ForEach(ArchiveFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if filteredMachines.isEmpty {
                Text("No archived machine instances yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredMachines) { machine in
                    Button(action: { onOpenMachineView(machine.id) }) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(machine.displayTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(archiveMetaLine(for: machine))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Archived machines: \(filteredMachines.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var filteredMachines: [OwnedMachine] {
        switch selectedFilter {
        case .all:
            return store.archivedMachines
        case .sold:
            return store.archivedMachines.filter { $0.status == .sold }
        case .traded:
            return store.archivedMachines.filter { $0.status == .traded }
        case .archived:
            return store.archivedMachines.filter { $0.status == .archived }
        }
    }

    private func archiveMetaLine(for machine: OwnedMachine) -> String {
        var parts: [String] = [machine.status.rawValue.capitalized]
        if let area = store.area(for: machine.gameRoomAreaID)?.name {
            parts.append(area)
        }
        if let soldOrTradedDate = machine.soldOrTradedDate {
            parts.append(soldOrTradedDate.formatted(date: .abbreviated, time: .omitted))
        }
        return parts.joined(separator: " • ")
    }
}

private struct GameRoomMachineView: View {
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
                        .pickerStyle(.segmented)

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
                    GameRoomLogIssueSheet { occurredAt, symptom, severity, subsystem, diagnosis in
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
                Text("Current Snapshot")
                    .font(.headline)
                Text("Open issues: \(snapshot.openIssueCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Current plays: \(snapshot.currentPlayCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Due tasks: \(snapshot.dueTaskCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Last service: \(snapshot.lastServiceAt?.formatted(date: .abbreviated, time: .omitted) ?? "None")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Pitch: \(snapshot.currentPitchValue.map { String(format: "%.1f", $0) } ?? "—")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Last level: \(snapshot.lastLeveledAt?.formatted(date: .abbreviated, time: .omitted) ?? "None")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Last inspection: \(snapshot.lastGeneralInspectionAt?.formatted(date: .abbreviated, time: .omitted) ?? "None")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Purchase date: \(machine.purchaseDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                Text("Media")
                    .font(.headline)
                if recentAttachments.isEmpty {
                    Text("No media attached yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                Text("Service")
                    .font(.footnote.weight(.semibold))
                LazyVGrid(columns: twoColumnGrid, spacing: 8) {
                    ForEach(serviceInputItems, id: \.title) { item in
                        Button(action: {
                            guard machine.status == .active || machine.status == .loaned else { return }
                            activeInputSheet = item.sheet
                        }) {
                            Text(item.title)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .disabled(!(machine.status == .active || machine.status == .loaned))
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Issue")
                    .font(.footnote.weight(.semibold))
                LazyVGrid(columns: twoColumnGrid, spacing: 8) {
                    ForEach(issueInputItems, id: \.title) { item in
                        Button(action: { activeInputSheet = item.sheet }) {
                            Text(item.title)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .disabled(item.sheet == .resolveIssue && !hasOpenIssues(for: machine.id))
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Ownership / Media")
                    .font(.footnote.weight(.semibold))
                LazyVGrid(columns: twoColumnGrid, spacing: 8) {
                    ForEach(ownershipAndMediaInputItems, id: \.title) { item in
                        Button(action: { activeInputSheet = item.sheet }) {
                            Text(item.title)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
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
                Text("No history yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

private struct GameRoomServiceEntrySheet: View {
    let title: String
    let submitLabel: String
    let includesConsumableField: Bool
    let includesPitchFields: Bool
    let onSave: (Date, String?, String?, Double?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var notes = ""
    @State private var consumable = ""
    @State private var pitchValueText = ""
    @State private var pitchMeasurementPoint = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)

                if includesConsumableField {
                    TextField("Cleaner / Consumable", text: $consumable)
                }

                if includesPitchFields {
                    TextField("Pitch Value", text: $pitchValueText)
                        .keyboardType(.decimalPad)
                    TextField("Measurement Point", text: $pitchMeasurementPoint)
                }

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitLabel) {
                        onSave(
                            occurredAt,
                            normalizedOptional(notes),
                            normalizedOptional(consumable),
                            parsedPitchValue,
                            normalizedOptional(pitchMeasurementPoint)
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var parsedPitchValue: Double? {
        Double(pitchValueText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct GameRoomPlayCountEntrySheet: View {
    let onSave: (Date, Int, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var playTotalText = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                TextField("Total Plays", text: $playTotalText)
                    .keyboardType(.numberPad)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Log Plays")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let playTotal = parsedPlayTotal else { return }
                        onSave(occurredAt, playTotal, normalizedOptional(notes))
                        dismiss()
                    }
                    .disabled(parsedPlayTotal == nil)
                }
            }
        }
    }

    private var parsedPlayTotal: Int? {
        guard let value = Int(playTotalText.trimmingCharacters(in: .whitespacesAndNewlines)), value >= 0 else {
            return nil
        }
        return value
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct GameRoomLogIssueSheet: View {
    let onSave: (Date, String, MachineIssueSeverity, MachineIssueSubsystem, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var openedAt = Date()
    @State private var symptom = ""
    @State private var severity: MachineIssueSeverity = .medium
    @State private var subsystem: MachineIssueSubsystem = .other
    @State private var diagnosis = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Opened", selection: $openedAt)
                TextField("Symptom", text: $symptom)

                Picker("Severity", selection: $severity) {
                    ForEach(MachineIssueSeverity.allCases) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }
                .pickerStyle(.menu)

                Picker("Subsystem", selection: $subsystem) {
                    ForEach(MachineIssueSubsystem.allCases) { value in
                        Text(value.displayTitle).tag(value)
                    }
                }
                .pickerStyle(.menu)

                TextField("Diagnosis / Notes", text: $diagnosis, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Log Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedSymptom = symptom.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedSymptom.isEmpty else { return }
                        onSave(openedAt, trimmedSymptom, severity, subsystem, normalizedOptional(diagnosis))
                        dismiss()
                    }
                    .disabled(symptom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct GameRoomResolveIssueSheet: View {
    let openIssues: [MachineIssue]
    let onSave: (UUID, Date, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIssueID: UUID?
    @State private var resolvedAt = Date()
    @State private var resolution = ""

    var body: some View {
        NavigationStack {
            Form {
                if openIssues.isEmpty {
                    Text("No open issues.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Issue", selection: $selectedIssueID) {
                        ForEach(openIssues) { issue in
                            Text(issue.symptom).tag(Optional(issue.id))
                        }
                    }
                    .pickerStyle(.menu)

                    DatePicker("Resolved", selection: $resolvedAt)

                    TextField("Resolution Notes", text: $resolution, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle("Resolve Issue")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedIssueID == nil {
                    selectedIssueID = openIssues.first?.id
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let selectedIssueID else { return }
                        onSave(selectedIssueID, resolvedAt, normalizedOptional(resolution))
                        dismiss()
                    }
                    .disabled(selectedIssueID == nil)
                }
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct GameRoomOwnershipEntrySheet: View {
    private let ownershipTypes: [MachineEventType] = [
        .purchased,
        .moved,
        .loanedOut,
        .returned,
        .listedForSale,
        .sold,
        .traded,
        .reacquired
    ]

    let onSave: (Date, MachineEventType, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var eventType: MachineEventType = .moved
    @State private var summary = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                Picker("Event", selection: $eventType) {
                    ForEach(ownershipTypes) { type in
                        Text(type.displayTitle).tag(type)
                    }
                }
                .pickerStyle(.menu)

                TextField("Summary", text: $summary)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Ownership Update")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    summary = eventType.displayTitle
                }
            }
            .onChange(of: eventType) { _, next in
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ownershipTypes.contains(where: { $0.displayTitle == summary }) {
                    summary = next.displayTitle
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedSummary.isEmpty else { return }
                        onSave(occurredAt, eventType, trimmedSummary, normalizedOptional(notes))
                        dismiss()
                    }
                    .disabled(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct GameRoomMediaEntrySheet: View {
    private enum MediaField: Hashable {
        case uri
        case caption
        case notes
    }

    let onSave: (MachineAttachmentKind, String, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: MachineAttachmentKind = .photo
    @State private var selectedMediaItem: PhotosPickerItem?
    @State private var pickerKind: MachineAttachmentKind = .photo
    @State private var showMediaPicker = false
    @State private var isImportingAsset = false
    @State private var importErrorMessage: String?
    @State private var uri = ""
    @State private var caption = ""
    @State private var notes = ""
    @FocusState private var focusedField: MediaField?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Photo").tag(MachineAttachmentKind.photo)
                    Text("Video").tag(MachineAttachmentKind.video)
                }
                .pickerStyle(.segmented)

                if kind == .photo {
                    Button {
                        focusedField = nil
                        pickerKind = .photo
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            showMediaPicker = true
                        }
                    } label: {
                        Label("Pick Photo", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderless)
                    .contentShape(Rectangle())
                } else {
                    Button {
                        focusedField = nil
                        pickerKind = .video
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            showMediaPicker = true
                        }
                    } label: {
                        Label("Pick Video", systemImage: "video")
                    }
                    .buttonStyle(.borderless)
                    .contentShape(Rectangle())
                }

                if isImportingAsset {
                    ProgressView("Importing media…")
                        .font(.footnote)
                }

                if let importErrorMessage {
                    Text(importErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if kind == .photo, let previewURL = resolvedMediaURL {
                    ConstrainedAsyncImagePreview(
                        candidates: [previewURL],
                        emptyMessage: "No image",
                        maxAspectRatio: 4.0 / 3.0,
                        imagePadding: 0
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                TextField("Media URL / URI", text: $uri)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .uri)
                TextField("Caption", text: $caption)
                    .focused($focusedField, equals: .caption)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .focused($focusedField, equals: .notes)
            }
            .navigationTitle("Add Photo/Video")
            .navigationBarTitleDisplayMode(.inline)
            .photosPicker(
                isPresented: $showMediaPicker,
                selection: $selectedMediaItem,
                matching: pickerKind == .photo ? .images : .videos,
                photoLibrary: .shared()
            )
            .onChange(of: selectedMediaItem) { _, item in
                guard let item else { return }
                if pickerKind == .photo {
                    importPhoto(item)
                } else {
                    importVideo(item)
                }
                selectedMediaItem = nil
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedURI = uri.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedURI.isEmpty else { return }
                        onSave(kind, trimmedURI, normalizedOptional(caption), normalizedOptional(notes))
                        dismiss()
                    }
                    .disabled(uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        importErrorMessage = nil
        isImportingAsset = true
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw URLError(.cannotDecodeRawData)
                }
                let url = try saveImportedMedia(data: data, preferredExtension: "jpg")
                await MainActor.run {
                    uri = url.path
                    isImportingAsset = false
                }
            } catch {
                await MainActor.run {
                    importErrorMessage = "Could not import selected photo."
                    isImportingAsset = false
                }
            }
        }
    }

    private func importVideo(_ item: PhotosPickerItem) {
        importErrorMessage = nil
        isImportingAsset = true
        Task {
            do {
                guard let movie = try await item.loadTransferable(type: MovieTransferable.self) else {
                    throw URLError(.cannotDecodeRawData)
                }
                let copiedURL = try copyImportedMediaFile(from: movie.url)
                await MainActor.run {
                    uri = copiedURL.path
                    isImportingAsset = false
                }
            } catch {
                await MainActor.run {
                    importErrorMessage = "Could not import selected video."
                    isImportingAsset = false
                }
            }
        }
    }

    private func saveImportedMedia(data: Data, preferredExtension: String) throws -> URL {
        let directory = try mediaStorageDirectory()
        let targetURL = directory.appendingPathComponent("\(UUID().uuidString).\(preferredExtension)")
        try data.write(to: targetURL, options: [.atomic])
        return targetURL
    }

    private func copyImportedMediaFile(from sourceURL: URL) throws -> URL {
        let directory = try mediaStorageDirectory()
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let targetURL = directory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)
        return targetURL
    }

    private func mediaStorageDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("GameRoomMedia", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private var resolvedMediaURL: URL? {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return URL(fileURLWithPath: trimmed)
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct MovieTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            Self(url: received.file)
        }
    }
}

private struct GameRoomAttachmentSquareTile: View {
    let attachment: MachineAttachment
    let resolvedURL: URL?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.82))

                if attachment.kind == .video {
                    GameRoomVideoThumbnailView(url: resolvedURL)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    Image(systemName: "play.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1)
                } else {
                    GameRoomImageThumbnailView(url: resolvedURL)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.controlBorder, lineWidth: 1)
        )
    }
}

private struct GameRoomImageThumbnailView: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .task(id: url?.absoluteString ?? "") {
            image = await loadImage(from: url)
        }
    }

    private func loadImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        if url.isFileURL {
            return UIImage(contentsOfFile: url.path)
        }
        do {
            let data = try await PinballDataCache.shared.loadData(url: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

private struct GameRoomVideoThumbnailView: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .task(id: url?.absoluteString ?? "") {
            image = await loadVideoThumbnail(from: url)
        }
    }

    private func loadVideoThumbnail(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        return await withCheckedContinuation { continuation in
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 600, height: 600)
            let times = [NSValue(time: .zero)]
            var resumed = false
            generator.generateCGImagesAsynchronously(forTimes: times) { _, cgImage, _, result, _ in
                guard !resumed else { return }
                switch result {
                case .succeeded:
                    resumed = true
                    if let cgImage {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } else {
                        continuation.resume(returning: nil)
                    }
                case .failed, .cancelled:
                    resumed = true
                    continuation.resume(returning: nil)
                @unknown default:
                    resumed = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

private struct GameRoomAttachmentPreviewSheet: View {
    let attachment: MachineAttachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if attachment.kind == .photo, let url = resolvedURL {
                    HostedImageView(imageCandidates: [url])
                } else if attachment.kind == .video, let url = resolvedURL {
                    VideoPlayer(player: AVPlayer(url: url))
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                } else {
                    Text("Media unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .navigationTitle(attachment.kind == .photo ? "Photo" : "Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var resolvedURL: URL? {
        let trimmed = attachment.uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return URL(fileURLWithPath: trimmed)
    }
}

private struct GameRoomMediaEditSheet: View {
    let attachment: MachineAttachment
    let initialNotes: String?
    let onSave: (String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var caption = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Caption", text: $caption)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Edit Media")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                caption = attachment.caption ?? ""
                notes = initialNotes ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(normalizedOptional(caption), normalizedOptional(notes))
                        dismiss()
                    }
                }
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct GameRoomPartOrModEntrySheet: View {
    let title: String
    let detailsLabel: String
    let detailsPrompt: String
    let submitLabel: String
    let onSave: (Date, String, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt = Date()
    @State private var summary = ""
    @State private var details = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                TextField("Summary", text: $summary)
                TextField(detailsLabel, text: $details, prompt: Text(detailsPrompt))
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    summary = title
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitLabel) {
                        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedSummary.isEmpty else { return }
                        onSave(
                            occurredAt,
                            trimmedSummary,
                            normalizedOptional(details),
                            normalizedOptional(notes)
                        )
                        dismiss()
                    }
                    .disabled(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct GameRoomLogDetailCard: View {
    let event: MachineEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected Log Entry")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.summary)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Type: \(event.type.displayTitle) • Category: \(event.category.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let notes = normalized(event.notes) {
                        detailLine("Notes", notes)
                    }
                    if let playTotal = event.playCountAtEvent, playTotal >= 0 {
                        detailLine("Total Plays", "\(playTotal)")
                    }
                    if let consumables = normalized(event.consumablesUsed) {
                        detailLine("Consumables", consumables)
                    }
                    if let parts = normalized(event.partsUsed) {
                        detailLine("Parts / Mod", parts)
                    }
                    if event.pitchValue != nil || normalized(event.pitchMeasurementPoint) != nil {
                        let pitchValue = event.pitchValue.map { String(format: "%.1f", $0) } ?? "—"
                        let pitchPoint = normalized(event.pitchMeasurementPoint) ?? "—"
                        detailLine("Pitch", "\(pitchValue) @ \(pitchPoint)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: 164)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.controlBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.controlBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func detailLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension MachineIssueSubsystem {
    var displayTitle: String {
        switch self {
        case .popBumper: return "Pop Bumper"
        case .shooterLane: return "Shooter Lane"
        case .switchMatrix: return "Switch Matrix"
        case .toyMech: return "Toy Mech"
        default:
            return rawValue
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
        }
    }
}

private extension MachineEventType {
    var displayTitle: String {
        switch self {
        case .loanedOut: return "Loaned Out"
        case .listedForSale: return "Listed For Sale"
        default:
            return rawValue
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
        }
    }
}

private extension View {
    func gameRoomEntrySheetStyle() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .dismissKeyboardOnTap()
    }

    func gameRoomMediaSheetStyle() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .dismissKeyboardOnTap()
    }
}

private struct GameRoomEventEditSheet: View {
    let event: MachineEvent
    let onSave: (Date, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var occurredAt: Date
    @State private var summary: String
    @State private var notes: String

    init(event: MachineEvent, onSave: @escaping (Date, String, String?) -> Void) {
        self.event = event
        self.onSave = onSave
        _occurredAt = State(initialValue: event.occurredAt)
        _summary = State(initialValue: event.summary)
        _notes = State(initialValue: event.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $occurredAt)
                TextField("Summary", text: $summary)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            .navigationTitle("Edit Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(occurredAt, summary, notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes)
                        dismiss()
                    }
                    .disabled(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    GameRoomScreen()
}
