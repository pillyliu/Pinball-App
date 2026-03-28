import Foundation
import Combine
import OSLog

private let gameRoomCatalogLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.pillyliu.Pinball-App-2",
    category: "DataIntegrity"
)

struct GameRoomCatalogGame: Identifiable, Hashable {
    let id: String
    let catalogGameID: String
    let opdbID: String
    let canonicalPracticeIdentity: String
    let displayTitle: String
    let displayVariant: String?
    let manufacturerID: String?
    let manufacturer: String?
    let year: Int?
    let primaryImageURL: String?
    let opdbType: String?
    let opdbDisplay: String?
    let opdbShortname: String?
    let opdbCommonName: String?
}

struct GameRoomCatalogSlugMatch: Hashable {
    let catalogGameID: String
    let canonicalPracticeIdentity: String
    let variant: String?
}

@MainActor
final class GameRoomCatalogLoader: ObservableObject {
    @Published private(set) var games: [GameRoomCatalogGame] = []
    @Published private(set) var variantOptionsByCatalogGameID: [String: [String]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var didLoad = false
    private var allCatalogGames: [GameRoomCatalogGame] = []
    private var gamesByCatalogGameID: [String: [GameRoomCatalogGame]] = [:]
    private var gamesByNormalizedCatalogGameID: [String: [GameRoomCatalogGame]] = [:]
    private var variantOptionsByNormalizedCatalogGameID: [String: [String]] = [:]
    private var slugMatchesByKey: [String: GameRoomCatalogSlugMatch] = [:]

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil

        do {
            games = try await loadCatalogGames()
        } catch {
            errorMessage = "Failed to load catalog data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func loadCatalogGames() async throws -> [GameRoomCatalogGame] {
        let practiceIdentityCurationsData = try await loadHostedOrCachedPinballJSONData(
            path: hostedPracticeIdentityCurationsPath,
            allowMissing: true
        )
        guard let rawData = try await loadHostedOrCachedPinballJSONData(
            path: hostedOPDBExportPath,
            allowMissing: true
        ),
        let rawMachines = try? decodeOPDBExportCatalogMachines(
            data: rawData,
            practiceIdentityCurationsData: practiceIdentityCurationsData
        ),
        !rawMachines.isEmpty else {
            throw URLError(.resourceUnavailable)
        }

        let mappedGames = rawMachines.map(Self.makeGame)
        allCatalogGames = mappedGames
        gamesByCatalogGameID = Dictionary(grouping: mappedGames, by: \.catalogGameID)
        gamesByNormalizedCatalogGameID = Dictionary(grouping: mappedGames, by: { Self.normalizedCatalogGameID($0.catalogGameID) })
        variantOptionsByCatalogGameID = Self.variantOptionsMap(from: rawMachines)
        variantOptionsByNormalizedCatalogGameID = variantOptionsByCatalogGameID.reduce(into: [:]) { partialResult, entry in
            partialResult[Self.normalizedCatalogGameID(entry.key)] = entry.value
        }
        slugMatchesByKey = Self.slugMatches(from: rawMachines)
        return Self.dedupedGames(from: mappedGames)
    }

    func variantOptions(for catalogGameID: String) -> [String] {
        variantOptionsByCatalogGameID[catalogGameID] ??
            variantOptionsByNormalizedCatalogGameID[Self.normalizedCatalogGameID(catalogGameID)] ??
            []
    }

    func games(for catalogGameID: String) -> [GameRoomCatalogGame] {
        if let grouped = gamesByCatalogGameID[catalogGameID], !grouped.isEmpty {
            return grouped.sorted(by: Self.sortGames)
        }
        if let grouped = gamesByNormalizedCatalogGameID[Self.normalizedCatalogGameID(catalogGameID)], !grouped.isEmpty {
            return grouped.sorted(by: Self.sortGames)
        }
        return []
    }

    func game(for catalogGameID: String) -> GameRoomCatalogGame? {
        if let grouped = gamesByCatalogGameID[catalogGameID], !grouped.isEmpty {
            return Self.preferredGame(in: grouped)
        }
        if let grouped = gamesByNormalizedCatalogGameID[Self.normalizedCatalogGameID(catalogGameID)], !grouped.isEmpty {
            return Self.preferredGame(in: grouped)
        }
        return games.first(where: { $0.catalogGameID.caseInsensitiveCompare(catalogGameID) == .orderedSame })
    }

    func game(for catalogGameID: String, variant: String?) -> GameRoomCatalogGame? {
        if let normalizedVariant = Self.normalizedVariant(variant) {
            let grouped = games(for: catalogGameID)
            let exactMatches = grouped.filter {
                Self.exactVariantMatchesSelection(candidate: $0.displayVariant, selected: normalizedVariant)
            }
            if !exactMatches.isEmpty {
                return Self.preferredGame(in: exactMatches)
            }
            let matches = grouped.filter {
                Self.variantMatchesSelection(candidate: $0.displayVariant, selected: variant)
            }
            if !matches.isEmpty {
                return Self.preferredGame(in: matches)
            }
        }
        return game(for: catalogGameID)
    }

    func slugMatch(for slug: String) -> GameRoomCatalogSlugMatch? {
        Self.buildSlugKeys(from: slug).first { slugMatchesByKey[$0] != nil }.flatMap { slugMatchesByKey[$0] }
    }

    func resolvedOPDBID(for machine: OwnedMachine) -> String? {
        if let existing = machine.opdbID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty,
           catalogGame(forExactOPDBID: existing) != nil {
            return existing
        }

        let resolvedTitle = catalogResolvedDisplayTitle(title: machine.displayTitle, explicitVariant: machine.displayVariant)
        let resolvedVariant = catalogResolvedVariantLabel(title: machine.displayTitle, explicitVariant: machine.displayVariant)
        let normalizedTitle = Self.normalizedCatalogIdentifier(resolvedTitle)
        let normalizedVariant = Self.normalizedVariant(resolvedVariant)
        let grouped = games(for: machine.catalogGameID)

        if let normalizedTitle, let normalizedVariant,
           let exact = grouped.first(where: {
               Self.normalizedCatalogIdentifier($0.displayTitle) == normalizedTitle &&
               Self.normalizedVariant($0.displayVariant) == normalizedVariant
           }) {
            return exact.opdbID
        }

        if let normalizedVariant,
           let exactVariantMatch = grouped.first(where: {
               Self.exactVariantMatchesSelection(candidate: $0.displayVariant, selected: normalizedVariant)
           }) {
            return exactVariantMatch.opdbID
        }

        if let normalizedVariant,
           let variantMatch = grouped.first(where: {
               Self.variantMatchesSelection(candidate: $0.displayVariant, selected: normalizedVariant)
           }) {
            return variantMatch.opdbID
        }

        if let normalizedTitle,
           let titleMatch = grouped.first(where: {
               Self.normalizedCatalogIdentifier($0.displayTitle) == normalizedTitle
           }) {
            return titleMatch.opdbID
        }

        if let identityMatch = allCatalogGames.first(where: { $0.canonicalPracticeIdentity == machine.canonicalPracticeIdentity }) {
            return identityMatch.opdbID
        }

        return grouped.first?.opdbID
    }

    func normalizedCatalogGame(for machine: OwnedMachine) -> GameRoomCatalogGame? {
        if let exact = resolvedOPDBID(for: machine) {
            return catalogGame(forExactOPDBID: exact)
        }
        return nil
    }

    func imageCandidates(for machine: OwnedMachine) -> [URL] {
        var rawCandidates: [String] = []
        let resolvedTitle = catalogResolvedDisplayTitle(title: machine.displayTitle, explicitVariant: machine.displayVariant)
        let resolvedVariant = catalogResolvedVariantLabel(title: machine.displayTitle, explicitVariant: machine.displayVariant)
        let normalizedTitle = Self.normalizedCatalogIdentifier(resolvedTitle)
        let normalizedVariant = Self.normalizedVariant(resolvedVariant)

        let normalizedExactOPDBID = Self.normalizedCatalogGameID(resolvedOPDBID(for: machine) ?? "")
        if !normalizedExactOPDBID.isEmpty {
            let exactMachineMatches = allCatalogGames.filter {
                Self.normalizedCatalogGameID($0.opdbID) == normalizedExactOPDBID
            }
            rawCandidates.append(contentsOf: exactMachineMatches.compactMap(\.primaryImageURL))
        }

        let grouped = gamesByCatalogGameID[machine.catalogGameID] ??
            gamesByNormalizedCatalogGameID[Self.normalizedCatalogGameID(machine.catalogGameID)] ??
            []

        if let normalizedTitle, let normalizedVariant {
            let exactVariantMatches = allCatalogGames.filter {
                Self.normalizedCatalogIdentifier($0.displayTitle) == normalizedTitle &&
                Self.normalizedVariant($0.displayVariant) == normalizedVariant
            }
            rawCandidates.append(contentsOf: exactVariantMatches.compactMap(\.primaryImageURL))
        }

        if let normalizedVariant {
            let exactVariantMatches = grouped.filter {
                Self.exactVariantMatchesSelection(candidate: $0.displayVariant, selected: normalizedVariant)
            }
            rawCandidates.append(contentsOf: exactVariantMatches.compactMap(\.primaryImageURL))
        }

        if let normalizedVariant {
            let variantMatches = grouped.filter {
                Self.variantMatchesSelection(candidate: $0.displayVariant, selected: normalizedVariant)
            }
            rawCandidates.append(contentsOf: variantMatches.compactMap(\.primaryImageURL))
        }

        if let exactIdentity = allCatalogGames.first(where: { $0.canonicalPracticeIdentity == machine.canonicalPracticeIdentity }) {
            rawCandidates.append(contentsOf: [exactIdentity.primaryImageURL].compactMap { $0 })
        }

        rawCandidates.append(contentsOf: grouped.compactMap(\.primaryImageURL))

        let titleMatches = allCatalogGames.filter {
            $0.displayTitle.caseInsensitiveCompare(machine.displayTitle) == .orderedSame
        }
        rawCandidates.append(contentsOf: titleMatches.compactMap(\.primaryImageURL))

        var seen = Set<String>()
        return rawCandidates.compactMap { raw in
            let key = raw.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return Self.resolveURL(pathOrURL: raw)
        }
    }

    private static func makeGame(_ machine: CatalogMachineRecord) -> GameRoomCatalogGame {
        let parsedName = parsedCatalogName(title: machine.name, explicitVariant: machine.variant)
        let opdbID = machine.opdbMachineID ?? machine.opdbGroupID ?? machine.practiceIdentity
        return GameRoomCatalogGame(
            id: opdbID,
            catalogGameID: machine.practiceIdentity,
            opdbID: opdbID,
            canonicalPracticeIdentity: machine.practiceIdentity,
            displayTitle: parsedName.title,
            displayVariant: parsedName.variant,
            manufacturerID: machine.manufacturerID,
            manufacturer: machine.manufacturerName,
            year: machine.year,
            primaryImageURL: machine.primaryImage?.mediumURL ?? machine.primaryImage?.largeURL,
            opdbType: machine.opdbType,
            opdbDisplay: machine.opdbDisplay,
            opdbShortname: machine.opdbShortname,
            opdbCommonName: machine.opdbCommonName
        )
    }

    private static func dedupedGames(from games: [GameRoomCatalogGame]) -> [GameRoomCatalogGame] {
        let grouped = Dictionary(grouping: games, by: \.catalogGameID)
        return grouped.values
            .compactMap { preferredGame(in: $0) }
            .sorted(by: sortGames)
    }

    private static func variantOptionsMap(from machines: [CatalogMachineRecord]) -> [String: [String]] {
        var buckets: [String: Set<String>] = [:]

        for machine in machines {
            let catalogGameID = machine.practiceIdentity
            guard let variant = parsedCatalogName(title: machine.name, explicitVariant: machine.variant).variant else { continue }
            buckets[catalogGameID, default: []].insert(variant)
        }

        var map: [String: [String]] = [:]
        for (key, values) in buckets {
            map[key] = sanitizedVariantOptions(Array(values)).sorted { lhs, rhs in
                let lhsRank = variantPreferenceRank(lhs)
                let rhsRank = variantPreferenceRank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
        }
        return map
    }

    private static func slugMatches(from machines: [CatalogMachineRecord]) -> [String: GameRoomCatalogSlugMatch] {
        var matches: [String: GameRoomCatalogSlugMatch] = [:]

        for machine in machines {
            let catalogGameID = machine.practiceIdentity
            let parsedName = parsedCatalogName(title: machine.name, explicitVariant: machine.variant)
            let match = GameRoomCatalogSlugMatch(
                catalogGameID: catalogGameID,
                canonicalPracticeIdentity: machine.practiceIdentity,
                variant: parsedName.variant
            )
            for key in buildSlugKeys(from: machine.slug) {
                if let existing = matches[key] {
                    gameRoomCatalogLogger.warning(
                        "Duplicate GameRoom catalog slug key \(key, privacy: .public); keeping existing catalog game \(existing.catalogGameID, privacy: .public) and ignoring \(match.catalogGameID, privacy: .public)"
                    )
                    continue
                }
                matches[key] = match
            }
        }

        return matches
    }

    private static func preferredGame(in group: [GameRoomCatalogGame]) -> GameRoomCatalogGame? {
        group.min { lhs, rhs in
            let lhsYear = lhs.year ?? Int.max
            let rhsYear = rhs.year ?? Int.max
            if lhsYear != rhsYear { return lhsYear < rhsYear }

            let lhsRank = variantPreferenceRank(lhs.displayVariant)
            let rhsRank = variantPreferenceRank(rhs.displayVariant)
            if lhsRank != rhsRank { return lhsRank < rhsRank }

            let lhsHasImage = lhs.primaryImageURL != nil
            let rhsHasImage = rhs.primaryImageURL != nil
            if lhsHasImage != rhsHasImage { return lhsHasImage && !rhsHasImage }

            return lhs.id < rhs.id
        }
    }

    private func catalogGame(forExactOPDBID opdbID: String) -> GameRoomCatalogGame? {
        let normalized = Self.normalizedCatalogGameID(opdbID)
        guard !normalized.isEmpty else { return nil }
        return allCatalogGames.first { Self.normalizedCatalogGameID($0.opdbID) == normalized }
    }

    private static func variantPreferenceRank(_ value: String?) -> Int {
        guard let normalized = normalizedVariant(value)?.localizedLowercase else {
            return 80
        }
        if normalized == "premium/le" || normalized == "premium le" || normalized == "premium-le" { return 30 }
        if normalized == "premium" || normalized.contains("premium") { return 0 }
        if normalized == "le" || normalized.contains("limited") { return 1 }
        if normalized == "pro" || normalized.contains("pro") { return 2 }
        if normalized.contains("standard") { return 10 }
        if normalized.contains("anniversary") { return 40 }
        if normalized.contains("home") { return 50 }
        return 20
    }

    private static func sanitizedVariantOptions(_ values: [String]) -> [String] {
        var normalized = Set(values.compactMap(normalizedVariant))
        guard normalized.contains("Premium/LE") else {
            return Array(normalized)
        }

        normalized.remove("Premium/LE")
        normalized.insert("Premium")
        normalized.insert("LE")
        return Array(normalized)
    }

    private static func sortGames(lhs: GameRoomCatalogGame, rhs: GameRoomCatalogGame) -> Bool {
        let lhsName = lhs.displayTitle.localizedLowercase
        let rhsName = rhs.displayTitle.localizedLowercase
        if lhsName != rhsName { return lhsName < rhsName }

        let lhsVariant = lhs.displayVariant?.localizedLowercase ?? ""
        let rhsVariant = rhs.displayVariant?.localizedLowercase ?? ""
        if lhsVariant != rhsVariant { return lhsVariant < rhsVariant }

        let lhsManufacturer = lhs.manufacturer?.localizedLowercase ?? ""
        let rhsManufacturer = rhs.manufacturer?.localizedLowercase ?? ""
        if lhsManufacturer != rhsManufacturer { return lhsManufacturer < rhsManufacturer }

        let lhsYear = lhs.year ?? Int.max
        let rhsYear = rhs.year ?? Int.max
        if lhsYear != rhsYear { return lhsYear < rhsYear }

        return lhs.id < rhs.id
    }

    private static func normalizedVariant(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.localizedLowercase
        if lowered == "null" || lowered == "none" {
            return nil
        }
        if lowered == "premium" { return "Premium" }
        if lowered == "pro" { return "Pro" }
        if lowered == "le" || lowered.contains("limited edition") { return "LE" }
        if lowered == "ce" || lowered.contains("collector") { return "CE" }
        if lowered == "se" || lowered.contains("special edition") { return "SE" }
        if lowered == "premium/le" || lowered == "premium le" || lowered == "premium-le" {
            return "Premium/LE"
        }
        if lowered.contains("anniversary") {
            return trimmed
                .split(separator: " ")
                .map { token in
                    let loweredToken = token.localizedLowercase
                    if loweredToken == "le" || loweredToken == "ce" || loweredToken == "se" {
                        return loweredToken.uppercased()
                    }
                    return token.prefix(1).uppercased() + token.dropFirst().localizedLowercase
                }
                .joined(separator: " ")
        }
        return trimmed
    }

    private static func variantMatchesSelection(candidate: String?, selected: String?) -> Bool {
        guard let candidate = normalizedVariant(candidate)?.localizedLowercase,
              let selected = normalizedVariant(selected)?.localizedLowercase else {
            return false
        }
        if candidate == selected {
            return true
        }
        if candidate == "premium/le" {
            return selected == "premium" || selected == "le"
        }
        return false
    }

    private static func exactVariantMatchesSelection(candidate: String?, selected: String?) -> Bool {
        guard let candidate = normalizedVariant(candidate)?.localizedLowercase,
              let selected = normalizedVariant(selected)?.localizedLowercase else {
            return false
        }
        return candidate == selected
    }

    private static func parsedCatalogName(title: String, explicitVariant: String?) -> (title: String, variant: String?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            catalogResolvedDisplayTitle(title: trimmedTitle, explicitVariant: explicitVariant),
            catalogResolvedVariantLabel(title: trimmedTitle, explicitVariant: explicitVariant)
        )
    }

    private static func normalizedCatalogGameID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }

    private static func normalizedCatalogIdentifier(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed.localizedLowercase
    }

    private static func buildSlugKeys(from slug: String) -> [String] {
        let lowered = slug.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !lowered.isEmpty else { return [] }

        var keys: [String] = []

        func appendKey(_ value: String) {
            guard !value.isEmpty, !keys.contains(value) else { return }
            keys.append(value)
        }

        appendKey(lowered)
        let normalized = normalizedSlugForMatching(lowered)
        appendKey(normalized)
        let stripped = stripVariantSuffix(from: normalized)
        if !stripped.isEmpty {
            appendKey(stripped)
        }
        return keys
    }

    private static func normalizedSlugForMatching(_ slug: String) -> String {
        let prefixTokens = Set([
            "stern",
            "williams",
            "bally",
            "gottlieb",
            "spooky",
            "jersey",
            "jack",
            "american",
            "pinball",
            "chicago",
            "gaming",
            "company",
            "sega",
            "data",
            "east"
        ])

        var tokens = slug.split(separator: "-").map(String.init)
        while let first = tokens.first, prefixTokens.contains(first) {
            tokens.removeFirst()
        }

        let yearPattern = try? NSRegularExpression(pattern: #"^(19|20)\d{2}$"#)
        let filtered = tokens.filter { token in
            let range = NSRange(token.startIndex..<token.endIndex, in: token)
            return yearPattern?.firstMatch(in: token, options: [], range: range) == nil
        }
        return filtered.joined(separator: "-")
    }

    private static func stripVariantSuffix(from slug: String) -> String {
        let suffixTokens = Set([
            "premium",
            "pro",
            "le",
            "ce",
            "se",
            "limited",
            "edition",
            "collector",
            "collectors"
        ])

        var tokens = slug.split(separator: "-").map(String.init)
        while let last = tokens.last, suffixTokens.contains(last) {
            tokens.removeLast()
        }
        return tokens.joined(separator: "-")
    }

    private static func resolveURL(pathOrURL: String) -> URL? {
        if let direct = URL(string: pathOrURL), direct.scheme != nil {
            return direct
        }
        if pathOrURL.hasPrefix("/") {
            return URL(string: "https://pillyliu.com\(pathOrURL)")
        }
        return URL(string: "https://pillyliu.com/\(pathOrURL)")
    }
}
