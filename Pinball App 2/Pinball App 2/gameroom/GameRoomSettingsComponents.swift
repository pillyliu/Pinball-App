import SwiftUI

struct GameRoomSettingsView: View {
    private struct SectionPickerBar: View {
        @Binding var selectedSection: GameRoomSettingsSection

        var body: some View {
            Picker("Mode", selection: $selectedSection) {
                ForEach(GameRoomSettingsSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .appSegmentedControlStyle()
        }
    }

    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let gameTransition: Namespace.ID
    let onOpenMachineView: (UUID, String?, String) -> Void
    @State private var selectedSection: GameRoomSettingsSection = .importFromPinside
    @State private var saveFeedbackText: String?
    @State private var saveFeedbackToken = 0

    var body: some View {
        ZStack {
            settingsScrollBody
            saveFeedbackOverlay
        }
        .navigationTitle("GameRoom Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await catalogLoader.loadIfNeeded()
        }
    }

    private var settingsScrollBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SectionPickerBar(selectedSection: $selectedSection)
                errorStatus
                GameRoomSettingsSectionCard(
                    store: store,
                    catalogLoader: catalogLoader,
                    gameTransition: gameTransition,
                    selectedSection: selectedSection,
                    onOpenMachineView: onOpenMachineView,
                    onShowSaveFeedback: showSaveFeedback
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var errorStatus: some View {
        if let lastErrorMessage = store.lastErrorMessage, !lastErrorMessage.isEmpty {
            AppInlineTaskStatus(text: lastErrorMessage, isError: true)
        }
    }

    private var saveFeedbackOverlay: some View {
        GameRoomFloatingSaveFeedbackOverlay(
            token: saveFeedbackToken,
            text: saveFeedbackText
        )
        .allowsHitTesting(false)
        .padding(.horizontal, 28)
    }

    private func showSaveFeedback(_ text: String) {
        saveFeedbackText = text
        saveFeedbackToken += 1
    }
}

struct GameRoomSettingsSectionCard: View {
    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let gameTransition: Namespace.ID
    let selectedSection: GameRoomSettingsSection
    let onOpenMachineView: (UUID, String?, String) -> Void
    let onShowSaveFeedback: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionTitle(text: sectionHeading)
            sectionContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .importFromPinside:
            GameRoomImportSettingsView(store: store, catalogLoader: catalogLoader)
        case .editMachines:
            GameRoomEditMachinesView(
                store: store,
                catalogLoader: catalogLoader,
                onShowSaveFeedback: onShowSaveFeedback
            )
        case .archive:
            GameRoomArchiveSettingsView(
                store: store,
                gameTransition: gameTransition,
                onOpenMachineView: onOpenMachineView
            )
        }
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

    private var importMatcher: ImportMatcher {
        ImportMatcher(store: store, catalogLoader: catalogLoader)
    }

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

    private struct ImportMatcher {
        let store: GameRoomStore
        let catalogLoader: GameRoomCatalogLoader

        func needsReview(_ row: ImportDraftRow) -> Bool {
            row.matchConfidence != .high || row.selectedCatalogGameID == nil || duplicateWarningMessage(for: row) != nil
        }

        func duplicateWarningMessage(for row: ImportDraftRow) -> String? {
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

        func importVariantOptions(for row: ImportDraftRow, selectedCatalogGameID: String) -> [String] {
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

        func makeDraftRow(_ machine: PinsideImportedMachine) -> ImportDraftRow {
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

        func normalizedFirstOfMonth(from raw: String?) -> Date? {
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

        func matchLabel(for game: GameRoomCatalogGame) -> String {
            if let year = game.year {
                return "\(game.displayTitle) (\(year))"
            }
            return game.displayTitle
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
    }

    private struct SourceSection: View {
        @Binding var sourceInput: String
        let isLoading: Bool
        let errorMessage: String?
        let canFetchCollection: Bool
        let onFetchCollection: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Pinside username or public collection URL", text: $sourceInput)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.go)
                    .onSubmit(onFetchCollection)

                HStack(spacing: 10) {
                    Button("Fetch Collection", action: onFetchCollection)
                        .buttonStyle(AppPrimaryActionButtonStyle())
                        .disabled(!canFetchCollection)
                }

                if isLoading {
                    AppInlineTaskStatus(text: "Fetching collection…", showsProgress: true)
                } else if let errorMessage {
                    AppInlineTaskStatus(text: errorMessage, isError: true)
                }
            }
        }
    }

    private struct ReviewSection: View {
        @Binding var draftRows: [ImportDraftRow]
        @Binding var reviewFilter: ImportReviewFilter
        let filteredRowIndexes: [Int]
        let duplicateWarningMessage: (ImportDraftRow) -> String?
        let matchLabel: (GameRoomCatalogGame) -> String
        let importVariantOptions: (ImportDraftRow, String) -> [String]
        let normalizePurchaseDate: (String?) -> Date?
        let onImport: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
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
                        ForEach(filteredRowIndexes, id: \.self) { index in
                            ReviewRowCard(
                                row: $draftRows[index],
                                duplicateWarning: duplicateWarningMessage(draftRows[index]),
                                matchLabel: matchLabel,
                                importVariantOptions: importVariantOptions,
                                normalizePurchaseDate: normalizePurchaseDate
                            )
                        }
                    }
                }
                .frame(maxHeight: 360)

                Button("Import Selected Matches", action: onImport)
                    .buttonStyle(AppPrimaryActionButtonStyle())
            }
        }
    }

    private struct ReviewRowCard: View {
        @Binding var row: ImportDraftRow
        let duplicateWarning: String?
        let matchLabel: (GameRoomCatalogGame) -> String
        let importVariantOptions: (ImportDraftRow, String) -> [String]
        let normalizePurchaseDate: (String?) -> Date?

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.rawTitle)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    confidenceBadge(row.matchConfidence)
                }

                if let rawVariant = row.rawVariant, !rawVariant.isEmpty {
                    Text("Variant: \(rawVariant)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                TextField(
                    "Purchase date (raw import text)",
                    text: purchaseDateBinding
                )
                .textFieldStyle(.roundedBorder)

                if let normalizedPurchaseDate = row.normalizedPurchaseDate {
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
                    ForEach(row.suggestions, id: \.id) { suggestion in
                        Button(matchLabel(suggestion)) {
                            selectSuggestion(suggestion)
                        }
                    }
                    Button("Clear Match") {
                        clearMatch()
                    }
                } label: {
                    AppCompactIconMenuLabel(
                        text: matchMenuLabel,
                        systemName: "link"
                    )
                }
                .buttonStyle(.plain)

                if let selectedCatalogGameID = row.selectedCatalogGameID {
                    let variants = importVariantOptions(row, selectedCatalogGameID)
                    if !variants.isEmpty {
                        Menu {
                            Button("None") {
                                row.selectedVariant = nil
                            }
                            ForEach(variants, id: \.self) { variant in
                                Button(variant) {
                                    row.selectedVariant = variant
                                }
                            }
                        } label: {
                            AppCompactIconMenuLabel(
                                text: "Variant: \(row.selectedVariant ?? "None")",
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

        private var purchaseDateBinding: Binding<String> {
            Binding(
                get: { row.rawPurchaseDateText ?? "" },
                set: { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    row.rawPurchaseDateText = trimmed.isEmpty ? nil : trimmed
                    row.normalizedPurchaseDate = normalizePurchaseDate(row.rawPurchaseDateText)
                }
            )
        }

        private var matchMenuLabel: String {
            guard let selectedCatalogGameID = row.selectedCatalogGameID,
                  let selected = row.suggestions.first(where: { $0.catalogGameID == selectedCatalogGameID }) else {
                return "No Match Selected"
            }
            return "Match: \(matchLabel(selected))"
        }

        private func selectSuggestion(_ suggestion: GameRoomCatalogGame) {
            row.selectedCatalogGameID = suggestion.catalogGameID
            guard let current = row.selectedVariant else { return }
            let variants = importVariantOptions(row, suggestion.catalogGameID)
            if !variants.contains(where: { $0.caseInsensitiveCompare(current) == .orderedSame }) {
                row.selectedVariant = nil
            }
        }

        private func clearMatch() {
            row.selectedCatalogGameID = nil
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
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SourceSection(
                sourceInput: $sourceInput,
                isLoading: isLoading,
                errorMessage: errorMessage,
                canFetchCollection: canFetchCollection,
                onFetchCollection: fetchCollectionIfPossible
            )

            if !draftRows.isEmpty {
                ReviewSection(
                    draftRows: $draftRows,
                    reviewFilter: $reviewFilter,
                    filteredRowIndexes: filteredRowIndexes,
                    duplicateWarningMessage: importMatcher.duplicateWarningMessage(for:),
                    matchLabel: importMatcher.matchLabel(for:),
                    importVariantOptions: importMatcher.importVariantOptions(for:selectedCatalogGameID:),
                    normalizePurchaseDate: importMatcher.normalizedFirstOfMonth(from:),
                    onImport: performImport
                )
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

    private var canFetchCollection: Bool {
        !isLoading && !sourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredRowIndexes: [Int] {
        draftRows.indices.filter { index in
            switch reviewFilter {
            case .all:
                return true
            case .needsReview:
                return importMatcher.needsReview(draftRows[index])
            }
        }
    }

    private func fetchCollectionIfPossible() {
        guard canFetchCollection else { return }
        fetchCollection()
    }

    private func fetchCollection() {
        errorMessage = nil
        resultMessage = nil
        isLoading = true
        let input = sourceInput

        Task {
            do {
                let result = try await importService.fetchCollectionMachines(sourceInput: input)
                let rows = result.machines.map(importMatcher.makeDraftRow)
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

}

struct GameRoomEditMachinesView: View {
    private struct MachineMenuGroup: Identifiable {
        var id: String { key }
        let key: String
        let title: String
        let machines: [OwnedMachine]
    }

    private struct VenueNamePanel: View {
        @Binding var venueNameDraft: String
        let onSave: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                TextField("GameRoom Name", text: $venueNameDraft)
                    .textFieldStyle(.roundedBorder)

                Button("Save", action: onSave)
                    .buttonStyle(AppPrimaryActionButtonStyle())
            }
        }
    }

    private struct AreaManagementPanel: View {
        @Binding var newAreaName: String
        @Binding var newAreaOrder: Int
        let areas: [GameRoomArea]
        let onSave: () -> Void
        let onEditArea: (GameRoomArea) -> Void
        let onDeleteArea: (GameRoomArea) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    TextField("Area name", text: $newAreaName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Area order", value: $newAreaOrder, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 96)
                        .keyboardType(.numberPad)
                }

                Button("Save", action: onSave)
                    .buttonStyle(AppPrimaryActionButtonStyle())

                if areas.isEmpty {
                    AppPanelEmptyCard(text: "No areas yet. Add an area like Upstairs or Basement to keep area order consistent across machines.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(areas) { area in
                            AreaRow(
                                area: area,
                                onEditArea: onEditArea,
                                onDeleteArea: onDeleteArea
                            )
                        }
                    }
                }
            }
        }
    }

    private struct AreaRow: View {
        let area: GameRoomArea
        let onEditArea: (GameRoomArea) -> Void
        let onDeleteArea: (GameRoomArea) -> Void

        var body: some View {
            HStack {
                Button {
                    onEditArea(area)
                } label: {
                    Text("\(area.name) (\(area.areaOrder))")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(role: .destructive) {
                    onDeleteArea(area)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(AppCompactIconActionButtonStyle())
            }
        }
    }

    private struct MachineManagementPanel: View {
        let allMachines: [OwnedMachine]
        let machineMenuGroups: [MachineMenuGroup]
        let selectedMachine: OwnedMachine?
        let currentVariantLabel: String
        let variantOptions: [String]
        let areas: [GameRoomArea]
        @Binding var selectedMachineID: UUID?
        @Binding var draftAreaID: UUID?
        @Binding var draftStatus: OwnedMachineStatus
        @Binding var draftGroup: String
        @Binding var draftPosition: String
        @Binding var draftPurchaseSource: String
        @Binding var draftSerialNumber: String
        @Binding var draftOwnershipNotes: String
        let machineMenuLabel: (OwnedMachine) -> String
        let onClearVariant: () -> Void
        let onSelectVariant: (String) -> Void
        let onSaveMachine: (OwnedMachine) -> Void
        let onDeleteMachine: (OwnedMachine) -> Void
        let onArchiveMachine: (OwnedMachine) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if allMachines.isEmpty {
                    AppPanelEmptyCard(text: "No machines in the collection yet. Add a machine above to start organizing the GameRoom.")
                } else {
                    MachineSelectionRow(
                        machineMenuGroups: machineMenuGroups,
                        selectedMachineTitle: selectedMachine?.displayTitle ?? "Select Machine",
                        currentVariantLabel: currentVariantLabel,
                        variantOptions: variantOptions,
                        machineMenuLabel: machineMenuLabel,
                        onSelectMachine: { selectedMachineID = $0 },
                        onClearVariant: onClearVariant,
                        onSelectVariant: onSelectVariant
                    )

                    if let selectedMachine {
                        MachineEditorFields(
                            selectedMachine: selectedMachine,
                            areas: areas,
                            draftAreaID: $draftAreaID,
                            draftStatus: $draftStatus,
                            draftGroup: $draftGroup,
                            draftPosition: $draftPosition,
                            draftPurchaseSource: $draftPurchaseSource,
                            draftSerialNumber: $draftSerialNumber,
                            draftOwnershipNotes: $draftOwnershipNotes,
                            onSaveMachine: onSaveMachine,
                            onDeleteMachine: onDeleteMachine,
                            onArchiveMachine: onArchiveMachine
                        )
                    }
                }
            }
        }
    }

    private struct MachineSelectionRow: View {
        let machineMenuGroups: [MachineMenuGroup]
        let selectedMachineTitle: String
        let currentVariantLabel: String
        let variantOptions: [String]
        let machineMenuLabel: (OwnedMachine) -> String
        let onSelectMachine: (UUID) -> Void
        let onClearVariant: () -> Void
        let onSelectVariant: (String) -> Void

        var body: some View {
            HStack(spacing: 10) {
                Menu {
                    ForEach(machineMenuGroups) { group in
                        Section(group.title) {
                            ForEach(group.machines) { machine in
                                Button(machineMenuLabel(machine)) {
                                    onSelectMachine(machine.id)
                                }
                            }
                        }
                    }
                } label: {
                    AppCompactDropdownLabel(text: selectedMachineTitle)
                }
                .buttonStyle(.plain)

                Spacer()

                Menu {
                    Button("None") {
                        onClearVariant()
                    }

                    if !variantOptions.isEmpty {
                        Divider()
                        ForEach(variantOptions, id: \.self) { variant in
                            Button(variant) {
                                onSelectVariant(variant)
                            }
                        }
                    }
                } label: {
                    GameRoomVariantPill(label: currentVariantLabel, style: .editSelector)
                }
            }
            .padding(.bottom, 2)
        }
    }

    private struct MachineEditorFields: View {
        let selectedMachine: OwnedMachine
        let areas: [GameRoomArea]
        @Binding var draftAreaID: UUID?
        @Binding var draftStatus: OwnedMachineStatus
        @Binding var draftGroup: String
        @Binding var draftPosition: String
        @Binding var draftPurchaseSource: String
        @Binding var draftSerialNumber: String
        @Binding var draftOwnershipNotes: String
        let onSaveMachine: (OwnedMachine) -> Void
        let onDeleteMachine: (OwnedMachine) -> Void
        let onArchiveMachine: (OwnedMachine) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                areaAndStatusRow
                numericFields
                metadataFields
                actionRow
            }
        }

        private var areaAndStatusRow: some View {
            HStack(spacing: 10) {
                Menu {
                    Button("No Area") {
                        draftAreaID = nil
                    }

                    if !areas.isEmpty {
                        Divider()
                    }

                    ForEach(areas) { area in
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
        }

        private var numericFields: some View {
            HStack(spacing: 10) {
                TextField("Group", text: $draftGroup)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)

                TextField("Position", text: $draftPosition)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }
        }

        private var metadataFields: some View {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Purchase Source", text: $draftPurchaseSource)
                    .textFieldStyle(.roundedBorder)
                TextField("Serial Number", text: $draftSerialNumber)
                    .textFieldStyle(.roundedBorder)

                TextField("Ownership Notes", text: $draftOwnershipNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)
            }
        }

        private var actionRow: some View {
            HStack {
                Button("Save") {
                    onSaveMachine(selectedMachine)
                }
                .buttonStyle(AppPrimaryActionButtonStyle())

                Button(role: .destructive) {
                    onDeleteMachine(selectedMachine)
                } label: {
                    Text("Delete")
                }
                .buttonStyle(AppDestructiveActionButtonStyle())

                Spacer()

                if selectedMachine.status != .archived {
                    Button("Archive") {
                        onArchiveMachine(selectedMachine)
                    }
                    .buttonStyle(AppSecondaryActionButtonStyle())
                }
            }
        }

        private var selectedAreaLabel: String {
            guard let draftAreaID,
                  let area = areas.first(where: { $0.id == draftAreaID }) else {
                return "No Area"
            }
            return area.name
        }
    }

    private struct AddMachinePanel: View {
        @Binding var searchText: String
        @Binding var manufacturerQuery: String
        @Binding var yearQuery: String
        @Binding var selectedType: GameRoomAddMachineTypeFilter?
        @Binding var isAdvancedExpanded: Bool
        let catalogErrorMessage: String?
        let isCatalogLoading: Bool
        let hasSearchFilters: Bool
        let filteredGameCount: Int
        let filteredCatalogGames: [GameRoomCatalogGame]
        let filteredManufacturerSuggestions: [String]
        let showManufacturerSuggestions: Bool
        let pendingVariantPickerGameID: String?
        let pendingVariantPickerTitle: String
        let pendingVariantPickerOptions: [String]
        let onSelectManufacturer: (String) -> Void
        let onSelectType: (GameRoomAddMachineTypeFilter?) -> Void
        let onClearFilters: () -> Void
        let onBeginAddMachineSelection: (GameRoomCatalogGame) -> Void
        let onDismissVariantPicker: () -> Void
        let onSelectPendingVariant: (String) -> Void
        let resultMetaLine: (GameRoomCatalogGame) -> String

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if let catalogErrorMessage {
                    AppInlineTaskStatus(text: catalogErrorMessage, isError: true)
                }

                AppNativeClearTextField(
                    placeholder: "Game name",
                    text: $searchText,
                    style: .roundedBorder
                )

                AddMachineAdvancedFilters(
                    manufacturerQuery: $manufacturerQuery,
                    yearQuery: $yearQuery,
                    selectedType: $selectedType,
                    isExpanded: $isAdvancedExpanded,
                    filteredManufacturerSuggestions: filteredManufacturerSuggestions,
                    showManufacturerSuggestions: showManufacturerSuggestions,
                    hasSearchFilters: hasSearchFilters,
                    onSelectManufacturer: onSelectManufacturer,
                    onSelectType: onSelectType,
                    onClearFilters: onClearFilters
                )

                statusContent

                if hasSearchFilters {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredCatalogGames, id: \.id) { game in
                                AddMachineResultRow(
                                    game: game,
                                    metaLine: resultMetaLine(game),
                                    isVariantPickerPresented: pendingVariantPickerGameID == game.catalogGameID && !pendingVariantPickerOptions.isEmpty,
                                    pendingVariantPickerTitle: pendingVariantPickerTitle,
                                    pendingVariantPickerOptions: pendingVariantPickerOptions,
                                    onBeginAddMachineSelection: { onBeginAddMachineSelection(game) },
                                    onDismissVariantPicker: onDismissVariantPicker,
                                    onSelectPendingVariant: onSelectPendingVariant
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
        }

        @ViewBuilder
        private var statusContent: some View {
            if isCatalogLoading {
                AppInlineTaskStatus(text: "Loading catalog data…", showsProgress: true)
            } else if hasSearchFilters {
                AppInlineTaskStatus(text: "\(filteredGameCount) matches")
            } else {
                AppPanelEmptyCard(text: "Search by name or abbreviation. Open Advanced Filters for manufacturer, year, and game type.")
            }
        }
    }

    private struct AddMachineAdvancedFilters: View {
        @Binding var manufacturerQuery: String
        @Binding var yearQuery: String
        @Binding var selectedType: GameRoomAddMachineTypeFilter?
        @Binding var isExpanded: Bool
        let filteredManufacturerSuggestions: [String]
        let showManufacturerSuggestions: Bool
        let hasSearchFilters: Bool
        let onSelectManufacturer: (String) -> Void
        let onSelectType: (GameRoomAddMachineTypeFilter?) -> Void
        let onClearFilters: () -> Void

        var body: some View {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    AppNativeClearTextField(
                        placeholder: "Manufacturer",
                        text: $manufacturerQuery,
                        style: .roundedBorder
                    )

                    if showManufacturerSuggestions {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filteredManufacturerSuggestions, id: \.self) { suggestion in
                                    Button(suggestion) {
                                        onSelectManufacturer(suggestion)
                                    }
                                    .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    AppNativeClearTextField(
                        placeholder: "Year",
                        text: $yearQuery,
                        style: .roundedBorder,
                        keyboardType: .numberPad
                    )

                    Menu {
                        Button("Any type") {
                            onSelectType(nil)
                        }

                        ForEach(GameRoomAddMachineTypeFilter.allCases) { option in
                            Button(option.label) {
                                onSelectType(option)
                            }
                        }
                    } label: {
                        AppCompactFilterLabel(text: selectedType?.label ?? "Any type")
                    }
                    .buttonStyle(.plain)

                    if hasSearchFilters {
                        Button("Clear filters", action: onClearFilters)
                            .buttonStyle(AppSecondaryActionButtonStyle(fillsWidth: false))
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Advanced Filters")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private struct AddMachineResultRow: View {
        let game: GameRoomCatalogGame
        let metaLine: String
        let isVariantPickerPresented: Bool
        let pendingVariantPickerTitle: String
        let pendingVariantPickerOptions: [String]
        let onBeginAddMachineSelection: () -> Void
        let onDismissVariantPicker: () -> Void
        let onSelectPendingVariant: (String) -> Void

        var body: some View {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.displayTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(metaLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Button(action: onBeginAddMachineSelection) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(AppCompactIconActionButtonStyle())
                    .gameRoomAdaptivePopover(
                        isPresented: Binding(
                            get: { isVariantPickerPresented },
                            set: { presenting in
                                if !presenting {
                                    onDismissVariantPicker()
                                }
                            }
                        ),
                        preferredHeight: min(CGFloat(pendingVariantPickerOptions.count) * 44 + 68, 300)
                    ) { availableHeight in
                        AddMachineVariantPickerPopover(
                            title: pendingVariantPickerTitle,
                            options: pendingVariantPickerOptions,
                            availableHeight: availableHeight,
                            onSelectVariant: onSelectPendingVariant
                        )
                    }
                }
            }
            .padding(10)
            .appControlStyle()
        }
    }

    private struct AddMachineVariantPickerPopover: View {
        let title: String
        let options: [String]
        let availableHeight: CGFloat
        let onSelectVariant: (String) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Choose the machine variant")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(option) {
                                onSelectVariant(option)
                            }
                            .buttonStyle(AppSecondaryActionButtonStyle())
                        }
                    }
                }
                .frame(maxHeight: max(min(availableHeight - 44, 220), 0))
            }
            .padding(12)
            .frame(width: 220, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }

    @ObservedObject var store: GameRoomStore
    @ObservedObject var catalogLoader: GameRoomCatalogLoader
    let onShowSaveFeedback: (String) -> Void
    @State private var searchText = ""
    @State private var manufacturerQuery = ""
    @State private var yearQuery = ""
    @State private var selectedType: GameRoomAddMachineTypeFilter?
    @State private var isAdvancedExpanded = false
    @State private var selectedMachineID: UUID?
    @State private var selectedAreaID: UUID?
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
    @State private var pendingVariantPickerGameID: String?
    @State private var pendingVariantPickerTitle = ""
    @State private var pendingVariantPickerOptions: [String] = []
    @State private var indexedCatalogSearchEntries: [GameRoomCatalogSearchEntry] = []
    @State private var indexedManufacturers: [String] = []

    var body: some View {
        panelStack
        .onAppear {
            handleAppear()
        }
        .onChange(of: store.state.ownedMachines.map(\.id)) { _, _ in
            syncMachineSelectionState()
        }
        .onChange(of: selectedMachineID) { _, _ in
            syncDraftFromSelection()
        }
        .onChange(of: catalogLoader.games) { _, _ in
            rebuildCatalogSearchIndex()
        }
        .onChange(of: catalogLoader.variantOptionsByCatalogGameID) { _, _ in
            rebuildCatalogSearchIndex()
        }
    }

    private var panelStack: some View {
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
        AddMachinePanel(
            searchText: $searchText,
            manufacturerQuery: $manufacturerQuery,
            yearQuery: $yearQuery,
            selectedType: $selectedType,
            isAdvancedExpanded: $isAdvancedExpanded,
            catalogErrorMessage: catalogLoader.errorMessage,
            isCatalogLoading: catalogLoader.isLoading,
            hasSearchFilters: hasSearchFilters,
            filteredGameCount: filteredCatalogGames.count,
            filteredCatalogGames: filteredCatalogGames,
            filteredManufacturerSuggestions: filteredManufacturerSuggestions,
            showManufacturerSuggestions: shouldShowManufacturerSuggestions,
            pendingVariantPickerGameID: pendingVariantPickerGameID,
            pendingVariantPickerTitle: pendingVariantPickerTitle,
            pendingVariantPickerOptions: pendingVariantPickerOptions,
            onSelectManufacturer: { manufacturerQuery = $0 },
            onSelectType: { selectedType = $0 },
            onClearFilters: clearAddMachineFilters,
            onBeginAddMachineSelection: beginAddMachineSelection(for:),
            onDismissVariantPicker: clearPendingVariantPicker,
            onSelectPendingVariant: { option in
                completeAddMachineSelection(catalogGameID: pendingVariantPickerGameID, variant: option)
            },
            resultMetaLine: resultMetaLine(for:)
        )
    }

    private var venueNamePanel: some View {
        VenueNamePanel(
            venueNameDraft: $venueNameDraft,
            onSave: saveVenueNameDraft
        )
    }

    private var areaManagementPanel: some View {
        AreaManagementPanel(
            newAreaName: $newAreaName,
            newAreaOrder: $newAreaOrder,
            areas: store.state.areas,
            onSave: saveAreaDraftWithFeedback,
            onEditArea: editArea,
            onDeleteArea: deleteAreaWithFeedback
        )
    }

    private var machineManagementPanel: some View {
        MachineManagementPanel(
            allMachines: allMachines,
            machineMenuGroups: machineMenuGroups,
            selectedMachine: selectedMachine,
            currentVariantLabel: currentVariantLabel,
            variantOptions: selectedMachineVariantOptions,
            areas: store.state.areas,
            selectedMachineID: $selectedMachineID,
            draftAreaID: $draftAreaID,
            draftStatus: $draftStatus,
            draftGroup: $draftGroup,
            draftPosition: $draftPosition,
            draftPurchaseSource: $draftPurchaseSource,
            draftSerialNumber: $draftSerialNumber,
            draftOwnershipNotes: $draftOwnershipNotes,
            machineMenuLabel: machineMenuLabel(for:),
            onClearVariant: { draftDisplayVariant = "" },
            onSelectVariant: { draftDisplayVariant = $0 },
            onSaveMachine: persistMachineEditsWithFeedback,
            onDeleteMachine: deleteMachine,
            onArchiveMachine: archiveMachine
        )
    }

    private var selectedMachineVariantOptions: [String] {
        selectedMachine.map(variantOptions(for:)) ?? []
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

    private func handleAppear() {
        syncMachineSelectionState()
        rebuildCatalogSearchIndex()
    }

    private func areaTitle(for areaID: UUID?) -> String {
        guard let areaID, let area = store.area(for: areaID) else { return "No Area" }
        return area.name
    }

    private func saveAreaDraft() {
        store.upsertArea(id: selectedAreaID, name: newAreaName, areaOrder: max(1, newAreaOrder))
        clearAreaDraft()
    }

    private func saveAreaDraftWithFeedback() {
        saveAreaDraft()
        onShowSaveFeedback("Area saved")
    }

    private func saveVenueNameDraft() {
        store.updateVenueName(venueNameDraft)
        venueNameDraft = store.venueName
        onShowSaveFeedback("GameRoom name saved")
    }

    private func editArea(_ area: GameRoomArea) {
        selectedAreaID = area.id
        newAreaName = area.name
        newAreaOrder = area.areaOrder
    }

    private func deleteArea(_ area: GameRoomArea) {
        if draftAreaID == area.id {
            draftAreaID = nil
        }
        if selectedAreaID == area.id {
            clearAreaDraft()
        }
        store.deleteArea(id: area.id)
    }

    private func deleteAreaWithFeedback(_ area: GameRoomArea) {
        deleteArea(area)
        onShowSaveFeedback("Area deleted")
    }

    private func clearAreaDraft() {
        selectedAreaID = nil
        newAreaName = ""
        newAreaOrder = 1
    }

    private func deleteMachine(_ machine: OwnedMachine) {
        store.deleteMachine(id: machine.id)
        onShowSaveFeedback("Machine deleted")
    }

    private func persistMachineEditsWithFeedback(for machine: OwnedMachine) {
        persistMachineEdits(for: machine)
        onShowSaveFeedback("Machine details saved")
    }

    private func archiveMachine(_ machine: OwnedMachine) {
        persistMachineEdits(for: machine, status: .archived)
        draftStatus = .archived
        onShowSaveFeedback("Machine archived")
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

    private var manufacturerOptions: [String] {
        indexedManufacturers
    }

    private var filteredManufacturerSuggestions: [String] {
        gameRoomManufacturerSuggestions(options: manufacturerOptions, query: manufacturerQuery)
    }

    private var shouldShowManufacturerSuggestions: Bool {
        !filteredManufacturerSuggestions.isEmpty &&
            !filteredManufacturerSuggestions.contains(where: {
                $0.caseInsensitiveCompare(manufacturerQuery.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
            })
    }

    private var hasSearchFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !manufacturerQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !yearQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            selectedType != nil
    }

    private var currentVariantLabel: String {
        let trimmed = draftDisplayVariant.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "None" : trimmed
    }

    private var filteredCatalogGames: [GameRoomCatalogGame] {
        filteredGameRoomCatalogGames(
            entries: indexedCatalogSearchEntries,
            nameQuery: searchText,
            manufacturerQuery: manufacturerQuery,
            yearQuery: yearQuery,
            selectedType: selectedType
        )
    }

    private func clearAddMachineFilters() {
        searchText = ""
        manufacturerQuery = ""
        yearQuery = ""
        selectedType = nil
    }

    private func resultMetaLine(for game: GameRoomCatalogGame) -> String {
        var parts: [String] = []
        if let manufacturer = game.manufacturer {
            parts.append(manufacturer)
        }
        if let year = game.year {
            parts.append(String(year))
        }
        return parts.isEmpty ? "Catalog match" : parts.joined(separator: " • ")
    }

    private func syncMachineSelectionState() {
        syncVenueNameDraftIfNeeded()
        ensureSelectedMachineIsValid()
    }

    private func syncVenueNameDraftIfNeeded() {
        if venueNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            venueNameDraft = store.venueName
        }
    }

    private func ensureSelectedMachineIsValid() {
        if let selectedMachineID,
           allMachines.contains(where: { $0.id == selectedMachineID }) {
            return
        }
        selectedMachineID = allMachines.first?.id
    }

    private func syncDraftFromSelection() {
        guard let selectedMachine else {
            clearMachineDraft()
            return
        }
        draftAreaID = selectedMachine.gameRoomAreaID
        draftGroup = selectedMachine.groupNumber.map(String.init) ?? ""
        draftPosition = selectedMachine.position.map(String.init) ?? ""
        draftStatus = selectedMachine.status
        draftDisplayVariant = selectedMachine.displayVariant ?? ""
        draftPurchaseSource = selectedMachine.purchaseSource ?? ""
        draftSerialNumber = selectedMachine.serialNumber ?? ""
        draftOwnershipNotes = selectedMachine.ownershipNotes ?? ""
    }

    private func clearMachineDraft() {
        draftAreaID = nil
        draftGroup = ""
        draftPosition = ""
        draftStatus = .active
        draftDisplayVariant = ""
        draftPurchaseSource = ""
        draftSerialNumber = ""
        draftOwnershipNotes = ""
    }

    private func parsedOptionalInt(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmed)
    }

    private func parsedOptionalString(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func variantOptions(for machine: OwnedMachine) -> [String] {
        var variants = catalogLoader.variantOptions(for: machine.catalogGameID)
        if let current = parsedOptionalString(draftDisplayVariant), !variants.contains(where: { $0.caseInsensitiveCompare(current) == .orderedSame }) {
            variants.insert(current, at: 0)
        }
        return variants
    }

    private func beginAddMachineSelection(for game: GameRoomCatalogGame) {
        let variantOptions = catalogLoader.variantOptions(for: game.catalogGameID)
        let distinctVariants = Array(NSOrderedSet(array: variantOptions)) as? [String] ?? variantOptions
        if distinctVariants.count > 1 {
            pendingVariantPickerGameID = game.catalogGameID
            pendingVariantPickerTitle = game.displayTitle
            pendingVariantPickerOptions = distinctVariants
            return
        }
        completeAddMachineSelection(catalogGameID: game.catalogGameID, variant: distinctVariants.first)
    }

    private func completeAddMachineSelection(catalogGameID: String?, variant: String?) {
        guard let catalogGameID,
              let resolvedGame = catalogLoader.game(for: catalogGameID, variant: variant) else {
            clearPendingVariantPicker()
            return
        }
        let resolvedVariant = parsedOptionalString(variant) ?? resolvedGame.displayVariant
        if let existing = store.existingOwnedMachine(catalogGameID: resolvedGame.catalogGameID, displayVariant: resolvedVariant) {
            let label = existing.displayVariant.map { "\(existing.displayTitle) (\($0))" } ?? existing.displayTitle
            onShowSaveFeedback("\(label) is already in GameRoom")
            clearPendingVariantPicker()
            return
        }

        store.addOwnedMachine(from: resolvedGame, displayVariant: resolvedVariant)
        selectedMachineID = store.state.ownedMachines.last?.id
        syncDraftFromSelection()
        clearPendingVariantPicker()
    }

    private func resolvedEditedMachine(for machine: OwnedMachine) -> GameRoomCatalogGame? {
        let editedVariant = parsedOptionalString(draftDisplayVariant)
        return catalogLoader.game(for: machine.catalogGameID, variant: editedVariant)
    }

    private func persistMachineEdits(for machine: OwnedMachine, status: OwnedMachineStatus? = nil) {
        let resolvedGame = resolvedEditedMachine(for: machine)
        store.updateMachine(
            id: machine.id,
            areaID: draftAreaID,
            groupNumber: parsedOptionalInt(draftGroup),
            position: parsedOptionalInt(draftPosition),
            status: status ?? draftStatus,
            opdbID: resolvedGame?.opdbID ?? machine.opdbID,
            canonicalPracticeIdentity: resolvedGame?.canonicalPracticeIdentity,
            displayTitle: resolvedGame?.displayTitle,
            displayVariant: parsedOptionalString(draftDisplayVariant) ?? resolvedGame?.displayVariant,
            manufacturer: resolvedGame?.manufacturer,
            year: resolvedGame?.year,
            purchaseSource: draftPurchaseSource,
            serialNumber: draftSerialNumber,
            ownershipNotes: draftOwnershipNotes
        )
    }

    private func clearPendingVariantPicker() {
        pendingVariantPickerGameID = nil
        pendingVariantPickerTitle = ""
        pendingVariantPickerOptions = []
    }

    private func rebuildCatalogSearchIndex() {
        indexedCatalogSearchEntries = buildGameRoomCatalogSearchEntries(
            games: catalogLoader.games,
            variantOptions: catalogLoader.variantOptions(for:)
        )

        indexedManufacturers = Array(
            Set(indexedCatalogSearchEntries.compactMap { entry in
                let trimmed = entry.game.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines)
                return (trimmed?.isEmpty == false) ? trimmed : nil
            })
        )
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

private struct GameRoomAdaptivePopoverSourceFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let nextValue = nextValue()
        guard nextValue != .zero else { return }
        value = nextValue
    }
}

private struct GameRoomAdaptivePopoverModifier<PopoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let preferredHeight: CGFloat
    let popoverContent: (CGFloat) -> PopoverContent

    @State private var sourceFrame: CGRect = .zero
    @State private var arrowEdge: Edge = .top
    @State private var availableHeight: CGFloat

    init(
        isPresented: Binding<Bool>,
        preferredHeight: CGFloat,
        @ViewBuilder popoverContent: @escaping (CGFloat) -> PopoverContent
    ) {
        _isPresented = isPresented
        self.preferredHeight = preferredHeight
        self.popoverContent = popoverContent
        _availableHeight = State(initialValue: preferredHeight)
    }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: GameRoomAdaptivePopoverSourceFramePreferenceKey.self,
                        value: proxy.frame(in: .global)
                    )
                }
            )
            .onPreferenceChange(GameRoomAdaptivePopoverSourceFramePreferenceKey.self) { frame in
                guard frame != .zero else { return }
                sourceFrame = frame
                recalculatePlacement()
            }
            .popover(
                isPresented: $isPresented,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: arrowEdge
            ) {
                popoverContent(availableHeight)
            }
            .onAppear {
                recalculatePlacement()
            }
            .onChange(of: isPresented) { _, _ in
                recalculatePlacement()
            }
    }

    private func recalculatePlacement() {
        guard sourceFrame != .zero else {
            arrowEdge = .top
            availableHeight = preferredHeight
            return
        }

        let viewport = gameRoomPopoverViewportRect()
        let spacingBuffer: CGFloat = 16
        let availableBelow = max(viewport.maxY - sourceFrame.maxY - spacingBuffer, 0)
        let availableAbove = max(sourceFrame.minY - viewport.minY - spacingBuffer, 0)
        let opensBelow = availableBelow >= preferredHeight || availableBelow >= availableAbove

        arrowEdge = opensBelow ? .top : .bottom
        availableHeight = max(opensBelow ? availableBelow : availableAbove, 0)
    }
}

extension View {
    fileprivate func gameRoomAdaptivePopover<PopoverContent: View>(
        isPresented: Binding<Bool>,
        preferredHeight: CGFloat,
        @ViewBuilder content: @escaping (CGFloat) -> PopoverContent
    ) -> some View {
        modifier(
            GameRoomAdaptivePopoverModifier(
                isPresented: isPresented,
                preferredHeight: preferredHeight,
                popoverContent: content
            )
        )
    }
}

private func gameRoomPopoverViewportRect() -> CGRect {
    let windowScenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
    let keyWindow = windowScenes
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)

    let fallbackRect = keyWindow?.windowScene?.screen.bounds
        ?? windowScenes.first(where: { $0.activationState == .foregroundActive })?.screen.bounds
        ?? windowScenes.first?.screen.bounds
        ?? CGRect(x: 0, y: 0, width: 1024, height: 1366)
    let baseRect = keyWindow?.bounds ?? fallbackRect
    let safeAreaInsets = keyWindow?.safeAreaInsets ?? .zero
    let safeAreaHeight = max(baseRect.height - safeAreaInsets.top - safeAreaInsets.bottom, 0)
    let safeAreaRect = CGRect(
        x: baseRect.minX,
        y: baseRect.minY + safeAreaInsets.top,
        width: baseRect.width,
        height: safeAreaHeight
    )
    return safeAreaRect.insetBy(dx: 0, dy: 12)
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

    private struct ArchiveFilterPicker: View {
        @Binding var selectedFilter: ArchiveFilter

        var body: some View {
            Picker("Archive Filter", selection: $selectedFilter) {
                ForEach(ArchiveFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .appSegmentedControlStyle()
        }
    }

    private struct ArchiveMachineRow: View {
        let machine: OwnedMachine
        let sourceID: String
        let metaLine: String
        let gameTransition: Namespace.ID
        let onOpenMachineView: (UUID, String?, String) -> Void

        var body: some View {
            Button(action: openMachine) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(machine.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(metaLine)
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
                .matchedTransitionSource(id: sourceID, in: gameTransition)
            }
            .buttonStyle(.plain)
        }

        private func openMachine() {
            onOpenMachineView(machine.id, sourceID, machine.displayTitle)
        }
    }

    @ObservedObject var store: GameRoomStore
    let gameTransition: Namespace.ID
    let onOpenMachineView: (UUID, String?, String) -> Void
    @State private var selectedFilter: ArchiveFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArchiveFilterPicker(selectedFilter: $selectedFilter)
            archiveListContent
            archiveSummaryFooter
        }
    }

    @ViewBuilder
    private var archiveListContent: some View {
        if filteredMachines.isEmpty {
            AppPanelEmptyCard(text: "No archived machine instances yet.")
        } else {
            ForEach(filteredMachines) { machine in
                ArchiveMachineRow(
                    machine: machine,
                    sourceID: gameRoomMachineTransitionSourceID(machineID: machine.id, surface: "archive-row"),
                    metaLine: archiveMetaLine(for: machine),
                    gameTransition: gameTransition,
                    onOpenMachineView: onOpenMachineView
                )
            }
        }
    }

    private var archiveSummaryFooter: some View {
        Text("Archived machines: \(filteredMachines.count)")
            .font(.footnote)
            .foregroundStyle(.secondary)
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

private struct GameRoomFloatingSaveFeedbackOverlay: View {
    private static let fadeInDuration = 0.14
    private static let fadeOutDuration = 0.18
    private static let totalDisplayDuration = 1.2

    let token: Int
    let text: String?

    @State private var displayedText: String?
    @State private var isVisible = false
    @State private var showTask: Task<Void, Never>?
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let displayedText {
                AppSuccessBanner(text: displayedText, prominent: true)
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.985)
                    .offset(y: isVisible ? 0 : 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onChange(of: token) { _, newValue in
            guard newValue > 0, let text, !text.isEmpty else { return }
            show(text)
        }
        .onDisappear {
            showTask?.cancel()
            hideTask?.cancel()
        }
    }

    @MainActor
    private func show(_ text: String) {
        showTask?.cancel()
        hideTask?.cancel()
        displayedText = text

        if !isVisible {
            showTask = Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: Self.fadeInDuration)) {
                    isVisible = true
                }
                showTask = nil
            }
        }

        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.totalDisplayDuration - Self.fadeOutDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: Self.fadeOutDuration)) {
                isVisible = false
            }
            try? await Task.sleep(for: .seconds(Self.fadeOutDuration))
            guard !Task.isCancelled else { return }
            if !isVisible {
                displayedText = nil
            }
            showTask = nil
            hideTask = nil
        }
    }
}
