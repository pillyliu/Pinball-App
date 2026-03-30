import Foundation
import Combine
import OSLog

let gameRoomCatalogLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.pillyliu.Pinball-App-2",
    category: "DataIntegrity"
)

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
        gameRoomResolvedOPDBID(
            for: machine,
            allCatalogGames: allCatalogGames,
            gamesByCatalogGameID: gamesByCatalogGameID,
            gamesByNormalizedCatalogGameID: gamesByNormalizedCatalogGameID
        )
    }

    func normalizedCatalogGame(for machine: OwnedMachine) -> GameRoomCatalogGame? {
        gameRoomNormalizedCatalogGame(
            for: machine,
            allCatalogGames: allCatalogGames,
            gamesByCatalogGameID: gamesByCatalogGameID,
            gamesByNormalizedCatalogGameID: gamesByNormalizedCatalogGameID
        )
    }

    func imageCandidates(for machine: OwnedMachine) -> [URL] {
        gameRoomCatalogImageCandidates(
            for: machine,
            allCatalogGames: allCatalogGames,
            gamesByCatalogGameID: gamesByCatalogGameID,
            gamesByNormalizedCatalogGameID: gamesByNormalizedCatalogGameID
        )
    }
}
