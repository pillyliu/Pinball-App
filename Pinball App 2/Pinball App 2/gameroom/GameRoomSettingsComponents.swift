import SwiftUI

struct GameRoomSettingsView: View {
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
                    .appSegmentedControlStyle()

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

struct GameRoomSettingsSectionCard: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let selectedSection: GameRoomSettingsSection
    let onOpenMachineView: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionTitle(text: sectionHeading)

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

struct GameRoomImportSettingsView: View {
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
                .buttonStyle(AppPrimaryActionButtonStyle())
                .disabled(isLoading || sourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if isLoading {
                AppInlineTaskStatus(text: "Fetching collection…", showsProgress: true)
            } else if let errorMessage {
                AppInlineTaskStatus(text: errorMessage, isError: true)
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
                .appSegmentedControlStyle()

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(filteredRowIndexes.enumerated()), id: \.offset) { _, index in
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
                                                let variants = importVariantOptions(
                                                    for: draftRows[index],
                                                    selectedCatalogGameID: suggestion.catalogGameID
                                                )
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
                                    AppCompactIconMenuLabel(
                                        text: matchMenuLabel(for: draftRows[index]),
                                        systemName: "link"
                                    )
                                }
                                .buttonStyle(.plain)

                                if let selectedCatalogGameID = draftRows[index].selectedCatalogGameID {
                                    let variants = importVariantOptions(for: draftRows[index], selectedCatalogGameID: selectedCatalogGameID)
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
                                            AppCompactIconMenuLabel(
                                                text: "Variant: \(draftRows[index].selectedVariant ?? "None")",
                                                systemName: "tag"
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .appControlStyle()
                        }
                    }
                }
                .frame(maxHeight: 360)

                Button("Import Selected Matches") {
                    performImport()
                }
                .buttonStyle(AppPrimaryActionButtonStyle())
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

        return AppTintedStatusChip(
            text: confidence.rawValue.capitalized,
            foreground: color,
            compact: true
        )
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

    private func importVariantOptions(for row: ImportDraftRow, selectedCatalogGameID: String) -> [String] {
        var variants: [String] = []

        if let currentVariant = row.selectedVariant?.trimmingCharacters(in: .whitespacesAndNewlines),
           !currentVariant.isEmpty {
            variants.append(currentVariant)
        }
        if let rawVariant = row.rawVariant?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawVariant.isEmpty,
           !variants.contains(where: { $0.caseInsensitiveCompare(rawVariant) == .orderedSame }) {
            variants.append(rawVariant)
        }
        for variant in catalogLoader.variantOptions(for: selectedCatalogGameID) {
            if !variants.contains(where: { $0.caseInsensitiveCompare(variant) == .orderedSame }) {
                variants.append(variant)
            }
        }

        return variants
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
        let slugMatch = catalogLoader.slugMatch(for: machine.slug)
        let candidates = catalogLoader.games.map { game -> (GameRoomCatalogGame, Int) in
            let normalizedGameTitle = normalized(game.displayTitle)
            var score = 0

            if let slugMatch,
               slugMatch.catalogGameID.caseInsensitiveCompare(game.catalogGameID) == .orderedSame {
                score += 400
            }

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

            score += metadataScore(machine: machine, game: game)

            return (game, score)
        }

        return candidates
            .filter { $0.1 > 0 }
            .sorted(by: {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                let lhsMetadata = metadataScore(machine: machine, game: $0.0)
                let rhsMetadata = metadataScore(machine: machine, game: $1.0)
                if lhsMetadata != rhsMetadata { return lhsMetadata > rhsMetadata }
                return $0.0.displayTitle.localizedCaseInsensitiveCompare($1.0.displayTitle) == .orderedAscending
            })
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

    private func metadataScore(machine: PinsideImportedMachine, game: GameRoomCatalogGame) -> Int {
        manufacturerMatchScore(imported: machine.manufacturerLabel, catalog: game.manufacturer) +
            yearMatchScore(imported: machine.manufactureYear, catalog: game.year)
    }

    private func manufacturerMatchScore(imported: String?, catalog: String?) -> Int {
        let importedLabel = canonicalManufacturerLabel(imported)
        let catalogLabel = canonicalManufacturerLabel(catalog)
        guard !importedLabel.isEmpty, !catalogLabel.isEmpty else { return 0 }
        if importedLabel == catalogLabel { return 35 }

        let importedTokens = Set(importedLabel.split(separator: " ").map(String.init))
        let catalogTokens = Set(catalogLabel.split(separator: " ").map(String.init))
        let sharedTokens = importedTokens.intersection(catalogTokens).count
        if sharedTokens > 0 {
            return max(10, Int((Double(sharedTokens) / Double(max(importedTokens.count, catalogTokens.count))) * 24.0))
        }
        return -12
    }

    private func yearMatchScore(imported: Int?, catalog: Int?) -> Int {
        guard let imported, let catalog else { return 0 }
        let difference = abs(imported - catalog)
        switch difference {
        case 0:
            return 25
        case 1:
            return 16
        case 2:
            return 10
        case 3:
            return 4
        default:
            return -12
        }
    }

    private func canonicalManufacturerLabel(_ value: String?) -> String {
        let normalizedValue = normalized(value ?? "")
        guard !normalizedValue.isEmpty else { return "" }

        let ignoredTokens: Set<String> = [
            "co",
            "company",
            "corp",
            "corporation",
            "inc",
            "ltd",
            "limited",
            "manufacturing",
            "pinball"
        ]
        let filteredTokens = normalizedValue
            .split(separator: " ")
            .map(String.init)
            .filter { !ignoredTokens.contains($0) }
        if filteredTokens.isEmpty {
            return normalizedValue
        }
        return filteredTokens.joined(separator: " ")
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
        if let year = game.year {
            return "\(game.displayTitle) (\(year))"
        }
        return game.displayTitle
    }

    private func matchMenuLabel(for row: ImportDraftRow) -> String {
        guard let selectedCatalogGameID = row.selectedCatalogGameID,
              let selected = catalogLoader.game(for: selectedCatalogGameID) else {
            return "No Match Selected"
        }
        return "Match: \(matchLabel(for: selected))"
    }
}

struct GameRoomEditMachinesView: View {
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
                    AppCompactFilterLabel(text: selectedManufacturerLabel)
                }
                .buttonStyle(.plain)

                Spacer()

                if catalogLoader.isLoading {
                    AppInlineTaskStatus(text: "Loading catalog data…", showsProgress: true)
                } else {
                    AppInlineTaskStatus(text: "\(filteredCatalogGames.count) matches")
                }
            }

            if let errorMessage = catalogLoader.errorMessage {
                AppInlineTaskStatus(text: errorMessage, isError: true)
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
                                .buttonStyle(AppSecondaryActionButtonStyle())
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

                                    Button {
                                        store.addOwnedMachine(from: game)
                                        selectedMachineID = store.state.ownedMachines.last?.id
                                        syncDraftFromSelection()
                                    } label: {
                                        Image(systemName: "plus")
                                    }
                                    .buttonStyle(AppCompactIconActionButtonStyle())
                                }
                                .padding(10)
                                .appControlStyle()
                                .id(game.id)
                            }

                            if hasNextFilteredResults {
                                Button("Show Next 25") {
                                    loadNextResultPage()
                                }
                                .buttonStyle(AppSecondaryActionButtonStyle())
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

            Button("Save") {
                store.updateVenueName(venueNameDraft)
                venueNameDraft = store.venueName
            }
            .buttonStyle(AppPrimaryActionButtonStyle())
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

            Button("Save") {
                store.upsertArea(id: selectedAreaID, name: newAreaName, areaOrder: max(1, newAreaOrder))
                selectedAreaID = nil
                newAreaName = ""
                newAreaOrder = 1
            }
            .buttonStyle(AppPrimaryActionButtonStyle())

            if store.state.areas.isEmpty {
                AppPanelEmptyCard(text: "No areas yet. Add an area like Upstairs or Basement to keep area order consistent across machines.")
            } else {
                VStack(spacing: 8) {
                    ForEach(store.state.areas) { area in
                        HStack {
                            Button {
                                selectedAreaID = area.id
                                newAreaName = area.name
                                newAreaOrder = area.areaOrder
                            } label: {
                                Text("\(area.name) (\(area.areaOrder))")
                                    .font(.subheadline.weight(.semibold))
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
                            .buttonStyle(AppCompactIconActionButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var machineManagementPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if allMachines.isEmpty {
                AppPanelEmptyCard(text: "No machines in the collection yet. Add a machine above to start organizing the GameRoom.")
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
                        AppCompactDropdownLabel(text: selectedMachine?.displayTitle ?? "Select Machine")
                    }
                    .buttonStyle(.plain)

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
                                AppCompactIconMenuLabel(text: selectedAreaLabel, systemName: "map")
                            }
                            .buttonStyle(.plain)

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
                            .buttonStyle(AppPrimaryActionButtonStyle())

                            Button(role: .destructive) {
                                store.deleteMachine(id: selectedMachine.id)
                                selectedMachineID = allMachines.first?.id
                                syncDraftFromSelection()
                            } label: {
                                Text("Delete")
                            }
                            .buttonStyle(AppDestructiveActionButtonStyle())

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
                                .buttonStyle(AppSecondaryActionButtonStyle())
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

struct GameRoomArchiveSettingsView: View {
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
            .appSegmentedControlStyle()

            if filteredMachines.isEmpty {
                AppPanelEmptyCard(text: "No archived machine instances yet.")
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
