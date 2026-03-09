import Foundation
import Combine

struct GameRoomCatalogGame: Identifiable, Hashable {
    let id: String
    let catalogGameID: String
    let canonicalPracticeIdentity: String
    let displayTitle: String
    let displayVariant: String?
    let manufacturerID: String?
    let manufacturer: String?
    let year: Int?
    let primaryImageURL: String?
}

struct GameRoomCatalogSlugMatch: Hashable {
    let catalogGameID: String
    let canonicalPracticeIdentity: String
    let variant: String?
}

private struct GameRoomCatalogRoot: Decodable {
    let manufacturers: [CatalogManufacturer]
    let machines: [CatalogMachine]

    struct CatalogManufacturer: Decodable {
        let id: String
        let name: String
        let isModern: Bool?
        let featuredRank: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case isModern = "is_modern"
            case featuredRank = "featured_rank"
        }
    }

    struct CatalogMachine: Decodable {
        struct RemoteImageSet: Decodable {
            let mediumURL: String?
            let largeURL: String?

            enum CodingKeys: String, CodingKey {
                case mediumURL = "medium_url"
                case largeURL = "large_url"
            }
        }

        let practiceIdentity: String
        let opdbMachineID: String?
        let opdbGroupID: String?
        let slug: String
        let name: String
        let variant: String?
        let manufacturerID: String?
        let manufacturerName: String?
        let year: Int?
        let primaryImage: RemoteImageSet?

        enum CodingKeys: String, CodingKey {
            case practiceIdentity = "practice_identity"
            case opdbMachineID = "opdb_machine_id"
            case opdbGroupID = "opdb_group_id"
            case slug
            case name
            case variant
            case manufacturerID = "manufacturer_id"
            case manufacturerName = "manufacturer_name"
            case year
            case primaryImage = "primary_image"
        }
    }
}

@MainActor
final class GameRoomCatalogLoader: ObservableObject {
    @Published private(set) var games: [GameRoomCatalogGame] = []
    @Published private(set) var variantOptionsByCatalogGameID: [String: [String]] = [:]
    @Published private(set) var manufacturerOptions: [PinballCatalogManufacturerOption] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var didLoad = false
    private let opdbCatalogPath = "/pinball/data/opdb_catalog_v1.json"
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
            async let gamesTask = loadCatalogGames()
            async let manufacturersTask = loadManufacturers()

            games = try await gamesTask
            manufacturerOptions = try await manufacturersTask
        } catch {
            errorMessage = "Failed to load catalog data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func loadCatalogGames() async throws -> [GameRoomCatalogGame] {
        let data = try await loadCatalogData()
        let root = try JSONDecoder().decode(GameRoomCatalogRoot.self, from: data)
        let mappedGames = root.machines.map(Self.makeGame)
        allCatalogGames = mappedGames
        gamesByCatalogGameID = Dictionary(grouping: mappedGames, by: \.catalogGameID)
        gamesByNormalizedCatalogGameID = Dictionary(grouping: mappedGames, by: { Self.normalizedCatalogGameID($0.catalogGameID) })
        variantOptionsByCatalogGameID = Self.variantOptionsMap(from: root.machines)
        variantOptionsByNormalizedCatalogGameID = variantOptionsByCatalogGameID.reduce(into: [:]) { partialResult, entry in
            partialResult[Self.normalizedCatalogGameID(entry.key)] = entry.value
        }
        slugMatchesByKey = Self.slugMatches(from: root.machines)
        return Self.dedupedGames(from: mappedGames)
    }

    func variantOptions(for catalogGameID: String) -> [String] {
        variantOptionsByCatalogGameID[catalogGameID] ??
            variantOptionsByNormalizedCatalogGameID[Self.normalizedCatalogGameID(catalogGameID)] ??
            []
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

    func slugMatch(for slug: String) -> GameRoomCatalogSlugMatch? {
        Self.buildSlugKeys(from: slug).first { slugMatchesByKey[$0] != nil }.flatMap { slugMatchesByKey[$0] }
    }

    func imageCandidates(for machine: OwnedMachine) -> [URL] {
        var rawCandidates: [String] = []
        let normalizedVariant = Self.normalizedVariant(machine.displayVariant)?.lowercased()
        let grouped = gamesByCatalogGameID[machine.catalogGameID] ??
            gamesByNormalizedCatalogGameID[Self.normalizedCatalogGameID(machine.catalogGameID)] ??
            []

        if let normalizedVariant {
            let variantMatches = grouped.filter {
                Self.normalizedVariant($0.displayVariant)?.lowercased() == normalizedVariant
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

    private func loadManufacturers() async throws -> [PinballCatalogManufacturerOption] {
        do {
            return try await LibrarySeedDatabase.shared.loadManufacturerOptions()
        } catch {
            let data = try await loadCatalogData()
            return try decodeCatalogManufacturerOptions(data: data)
        }
    }

    private func loadCatalogData() async throws -> Data {
        if let bundled = try loadBundledPinballData(path: opdbCatalogPath), !bundled.isEmpty {
            return bundled
        }

        let cached = try await PinballDataCache.shared.loadText(path: opdbCatalogPath, allowMissing: false)
        guard let text = cached.text, let data = text.data(using: .utf8), !data.isEmpty else {
            throw URLError(.cannotDecodeRawData)
        }
        return data
    }

    private static func makeGame(_ machine: GameRoomCatalogRoot.CatalogMachine) -> GameRoomCatalogGame {
        let parsedName = parsedCatalogName(title: machine.name, explicitVariant: machine.variant)
        return GameRoomCatalogGame(
            id: machine.opdbGroupID ?? machine.practiceIdentity,
            catalogGameID: machine.opdbGroupID ?? machine.opdbMachineID ?? machine.practiceIdentity,
            canonicalPracticeIdentity: machine.practiceIdentity,
            displayTitle: parsedName.title,
            displayVariant: parsedName.variant,
            manufacturerID: machine.manufacturerID,
            manufacturer: machine.manufacturerName,
            year: machine.year,
            primaryImageURL: machine.primaryImage?.mediumURL ?? machine.primaryImage?.largeURL
        )
    }

    private static func dedupedGames(from games: [GameRoomCatalogGame]) -> [GameRoomCatalogGame] {
        let grouped = Dictionary(grouping: games, by: \.catalogGameID)
        return grouped.values
            .compactMap { preferredGame(in: $0) }
            .sorted(by: sortGames)
    }

    private static func variantOptionsMap(from machines: [GameRoomCatalogRoot.CatalogMachine]) -> [String: [String]] {
        var buckets: [String: Set<String>] = [:]

        for machine in machines {
            let catalogGameID = machine.opdbGroupID ?? machine.opdbMachineID ?? machine.practiceIdentity
            guard let variant = parsedCatalogName(title: machine.name, explicitVariant: machine.variant).variant else { continue }
            buckets[catalogGameID, default: []].insert(variant)
        }

        var map: [String: [String]] = [:]
        for (key, values) in buckets {
            map[key] = values.sorted { lhs, rhs in
                let lhsRank = variantPreferenceRank(lhs)
                let rhsRank = variantPreferenceRank(rhs)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
        }
        return map
    }

    private static func slugMatches(from machines: [GameRoomCatalogRoot.CatalogMachine]) -> [String: GameRoomCatalogSlugMatch] {
        var matches: [String: GameRoomCatalogSlugMatch] = [:]

        for machine in machines {
            let catalogGameID = machine.opdbGroupID ?? machine.opdbMachineID ?? machine.practiceIdentity
            let parsedName = parsedCatalogName(title: machine.name, explicitVariant: machine.variant)
            let match = GameRoomCatalogSlugMatch(
                catalogGameID: catalogGameID,
                canonicalPracticeIdentity: machine.practiceIdentity,
                variant: parsedName.variant
            )
            for key in buildSlugKeys(from: machine.slug) where matches[key] == nil {
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

    private static func variantPreferenceRank(_ value: String?) -> Int {
        guard let normalized = normalizedVariant(value)?.localizedLowercase else {
            return 80
        }
        if normalized == "premium" || normalized.contains("premium") { return 0 }
        if normalized == "le" || normalized.contains("limited") { return 1 }
        if normalized == "pro" || normalized.contains("pro") { return 2 }
        if normalized.contains("standard") { return 10 }
        if normalized.contains("anniversary") { return 40 }
        if normalized.contains("home") { return 50 }
        return 20
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

    private static func parsedCatalogName(title: String, explicitVariant: String?) -> (title: String, variant: String?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExplicitVariant = normalizedVariant(explicitVariant)
        guard normalizedExplicitVariant == nil else {
            return (trimmedTitle, normalizedExplicitVariant)
        }

        guard trimmedTitle.hasSuffix(")"),
              let openParenIndex = trimmedTitle.lastIndex(of: "(") else {
            return (trimmedTitle, nil)
        }

        let baseTitle = trimmedTitle[..<openParenIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let rawVariant = trimmedTitle[
            trimmedTitle.index(after: openParenIndex)..<trimmedTitle.index(before: trimmedTitle.endIndex)
        ].trimmingCharacters(in: .whitespacesAndNewlines)

        guard !baseTitle.isEmpty, let derivedVariant = derivedVariant(fromTitleSuffix: rawVariant) else {
            return (trimmedTitle, nil)
        }
        return (baseTitle, derivedVariant)
    }

    private static func derivedVariant(fromTitleSuffix value: String) -> String? {
        let lowered = value.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !lowered.isEmpty else { return nil }
        guard lowered == "premium" ||
                lowered == "pro" ||
                lowered == "le" ||
                lowered == "ce" ||
                lowered == "se" ||
                lowered.contains("anniversary") ||
                lowered.contains("limited edition") ||
                lowered.contains("special edition") ||
                lowered.contains("collector") ||
                lowered == "premium/le" ||
                lowered == "premium le" ||
                lowered == "premium-le" ||
                lowered == "home" else {
            return nil
        }
        return normalizedVariant(value)
    }

    private static func normalizedCatalogGameID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
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
