import Foundation
import SwiftUI
import Combine

enum PinballLibrarySourceType: String, CaseIterable, Codable {
    case venue
    case category
    case manufacturer
    case tournament
}

struct PinballLibrarySource: Identifiable {
    let id: String
    let name: String
    let type: PinballLibrarySourceType

    var defaultSortOption: PinballLibrarySortOption {
        switch type {
        case .venue:
            return .area
        case .category:
            return .alphabetical
        case .manufacturer:
            return .year
        case .tournament:
            return .alphabetical
        }
    }
}

enum PinballLibrarySortOption: String, CaseIterable, Identifiable {
    case area
    case bank
    case alphabetical
    case year

    var id: String { rawValue }

    var menuLabel: String {
        switch self {
        case .area:
            return "Sort: Area"
        case .bank:
            return "Sort: Bank"
        case .alphabetical:
            return "Sort: A-Z"
        case .year:
            return "Sort: Year"
        }
    }
}

@MainActor
final class PinballLibraryViewModel: ObservableObject {
    @Published private(set) var games: [PinballGame] = []
    @Published private(set) var sources: [PinballLibrarySource] = []
    @Published var selectedSourceID: String = "the-avenue"
    @Published var query: String = "" {
        didSet {
            if query != oldValue {
                resetVisibleGameLimit()
            }
        }
    }
    @Published var sortOption: PinballLibrarySortOption = .area {
        didSet {
            if sortOption != oldValue {
                resetVisibleGameLimit()
            }
        }
    }
    @Published var yearSortDescending: Bool = false {
        didSet {
            if yearSortDescending != oldValue {
                resetVisibleGameLimit()
            }
        }
    }
    @Published var selectedBank: Int? {
        didSet {
            if selectedBank != oldValue {
                resetVisibleGameLimit()
            }
        }
    }
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false

    private var didLoad = false
    private let initialVisibleGameCount = 48
    private let visibleGamePageSize = 36
    @Published private(set) var visibleGameLimit = 48
    private static let libraryPath = "/pinball/data/pinball_library_v3.json"
    private static let opdbCatalogPath = "/pinball/data/opdb_catalog_v1.json"
    private static let preferredSourceDefaultsKey = "preferred-library-source-id"
    private static let avenueSourceCandidates = ["venue--the-avenue-cafe", "the-avenue"]

    var selectedSource: PinballLibrarySource? {
        sources.first(where: { $0.id == selectedSourceID }) ?? sources.first
    }

    var visibleSources: [PinballLibrarySource] {
        let state = PinballLibrarySourceStateStore.load()
        let pinned = state.pinnedSourceIDs.compactMap { id in
            sources.first(where: { $0.id == id })
        }
        var visible = pinned
        if let selectedSource, !visible.contains(where: { $0.id == selectedSource.id }) {
            visible.append(selectedSource)
        }
        if let gameRoomSource = sources.first(where: { $0.id == "venue--gameroom" }),
           !visible.contains(where: { $0.id == gameRoomSource.id }) {
            visible.append(gameRoomSource)
        }
        return visible.isEmpty ? sources : visible
    }

    var sourceScopedGames: [PinballGame] {
        guard let selectedSource else { return games }
        return games.filter { $0.sourceId == selectedSource.id }
    }

    var sortOptions: [PinballLibrarySortOption] {
        guard let selectedSource else {
            return [.area, .alphabetical]
        }
        switch selectedSource.type {
        case .category, .manufacturer, .tournament:
            return [.year, .alphabetical]
        case .venue:
            let hasBank = sourceScopedGames.contains { ($0.bank ?? 0) > 0 }
            var options: [PinballLibrarySortOption] = [.area]
            if hasBank { options.append(.bank) }
            options.append(.alphabetical)
            options.append(.year)
            return options
        }
    }

    var supportsBankFilter: Bool {
        guard let selectedSource else { return false }
        return selectedSource.type == .venue && sourceScopedGames.contains { ($0.bank ?? 0) > 0 }
    }

    var bankOptions: [Int] {
        if !supportsBankFilter { return [] }
        return Array(Set(sourceScopedGames.compactMap(\.bank).filter { $0 > 0 })).sorted()
    }

    var selectedBankLabel: String {
        if let selectedBank {
            return "Bank \(selectedBank)"
        }
        return "All banks"
    }

    var selectedSortLabel: String {
        menuLabel(for: sortOption)
    }

    var filteredGames: [PinballGame] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let effectiveBank = supportsBankFilter ? selectedBank : nil

        return sourceScopedGames.filter { game in
            let matchesQuery: Bool
            if trimmed.isEmpty {
                matchesQuery = true
            } else {
                let haystack = "\(game.name) \(game.manufacturer ?? "") \(game.year.map(String.init) ?? "")".lowercased()
                matchesQuery = haystack.contains(trimmed)
            }

            let matchesBank = effectiveBank == nil || game.bank == effectiveBank
            return matchesQuery && matchesBank
        }
    }

    var sortedFilteredGames: [PinballGame] {
        switch sortOption {
        case .area:
            return filteredGames.sorted {
                byOptionalAscending($0.areaOrder, $1.areaOrder)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? false
            }
        case .bank:
            return filteredGames.sorted {
                byOptionalAscending($0.bank, $1.bank)
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? false
            }
        case .alphabetical:
            return filteredGames.sorted {
                byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? byOptionalAscending($0.group, $1.group)
                    ?? byOptionalAscending($0.pos, $1.pos)
                    ?? false
            }
        case .year:
            if yearSortDescending {
                return filteredGames.sorted {
                    byOptionalDescending($0.year, $1.year)
                        ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                        ?? false
                }
            } else {
                return filteredGames.sorted {
                    byOptionalAscending($0.year, $1.year)
                        ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                        ?? false
                }
            }
        }
    }

    var visibleSortedFilteredGames: [PinballGame] {
        Array(sortedFilteredGames.prefix(visibleGameLimit))
    }

    var hasMoreVisibleGames: Bool {
        visibleSortedFilteredGames.count < sortedFilteredGames.count
    }

    var showGroupedView: Bool {
        let effectiveBank = supportsBankFilter ? selectedBank : nil
        return effectiveBank == nil && (sortOption == .area || sortOption == .bank)
    }

    var sections: [PinballGroupSection] {
        var out: [PinballGroupSection] = []
        let groupingKey: (PinballGame) -> (String?, Int?) = {
            switch sortOption {
            case .area:
                return { (nil, $0.group) }
            case .bank:
                return { (nil, $0.bank) }
            case .alphabetical, .year:
                return { _ in (nil, nil) }
            }
        }()

        for game in visibleSortedFilteredGames {
            let (locationKey, groupKey) = groupingKey(game)
            if let last = out.last, last.locationKey == locationKey, last.groupKey == groupKey {
                var mutable = last
                mutable.games.append(game)
                out[out.count - 1] = mutable
            } else {
                out.append(PinballGroupSection(locationKey: locationKey, groupKey: groupKey, games: [game]))
            }
        }

        return out
    }

    private func byOptionalAscending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        switch (lhs, rhs) {
        case let (l?, r?):
            return byAscending(l, r)
        case (nil, nil):
            return nil
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
    }

    private func byAscending<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool? {
        if lhs == rhs { return nil }
        return lhs < rhs
    }

    private func byOptionalDescending<T: Comparable>(_ lhs: T?, _ rhs: T?) -> Bool? {
        switch (lhs, rhs) {
        case let (l?, r?):
            return byDescending(l, r)
        case (nil, nil):
            return nil
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
    }

    private func byDescending<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool? {
        if lhs == rhs { return nil }
        return lhs > rhs
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadGames()
    }

    func refresh() async {
        await loadGames()
    }

    func selectSource(_ sourceID: String) {
        selectedSourceID = sourceID
        resetVisibleGameLimit()
        UserDefaults.standard.set(sourceID, forKey: Self.preferredSourceDefaultsKey)
        var state = PinballLibrarySourceStateStore.load()
        state.selectedSourceID = sourceID
        PinballLibrarySourceStateStore.save(state)
        if let selectedSource {
            let options = sortOptions
            if selectedSource.type == .manufacturer {
                sortOption = .year
                yearSortDescending = true
            } else {
                sortOption = preferredDefaultSortOption(for: selectedSource, games: sourceScopedGames)
                if !options.contains(sortOption), let first = options.first {
                    sortOption = first
                }
                yearSortDescending = preferredDefaultYearSortDescending(for: selectedSource, games: sourceScopedGames)
            }
        }
        selectedBank = nil
    }

    func selectSortOption(_ option: PinballLibrarySortOption) {
        if option == .year, sortOption == .year {
            yearSortDescending.toggle()
            return
        }
        sortOption = option
        if option == .year {
            yearSortDescending = false
        }
    }

    func menuLabel(for option: PinballLibrarySortOption) -> String {
        if option == .year {
            return yearSortDescending ? "Sort: Year (New-Old)" : "Sort: Year (Old-New)"
        }
        return option.menuLabel
    }

    func loadMoreGamesIfNeeded(currentGameID: String?) {
        guard hasMoreVisibleGames else { return }
        guard let currentGameID else {
            visibleGameLimit += visibleGamePageSize
            return
        }
        let thresholdIndex = max(0, visibleSortedFilteredGames.count - 12)
        guard let currentIndex = visibleSortedFilteredGames.firstIndex(where: { $0.id == currentGameID }),
              currentIndex >= thresholdIndex else {
            return
        }
        visibleGameLimit += visibleGamePageSize
    }

    private func resetVisibleGameLimit() {
        visibleGameLimit = initialVisibleGameCount
    }

    private func loadGames() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let extraction = try await loadLibraryExtraction()
            let payload = extraction.payload
            games = payload.games
            sources = payload.sources
            resetVisibleGameLimit()
            let savedSourceID = UserDefaults.standard.string(forKey: Self.preferredSourceDefaultsKey)
            let preferredCandidates = [extraction.state.selectedSourceID, savedSourceID, selectedSourceID] + Self.avenueSourceCandidates.map(Optional.some)
            let preferredSourceID = preferredCandidates
                .compactMap { $0 }
                .first(where: { id in sources.contains(where: { $0.id == id }) })
            if let selected = sources.first(where: { $0.id == preferredSourceID }) ?? sources.first(where: { $0.id == selectedSourceID }) ?? sources.first {
                selectedSourceID = selected.id
                UserDefaults.standard.set(selected.id, forKey: Self.preferredSourceDefaultsKey)
                var state = extraction.state
                state.selectedSourceID = selected.id
                PinballLibrarySourceStateStore.save(state)
                let options = sortOptions
                sortOption = preferredDefaultSortOption(for: selected, games: sourceScopedGames)
                if !options.contains(sortOption), let first = options.first {
                    sortOption = first
                }
                yearSortDescending = preferredDefaultYearSortDescending(for: selected, games: sourceScopedGames)
                if !supportsBankFilter {
                    selectedBank = nil
                }
            }
            errorMessage = nil
        } catch {
            games = []
            sources = []
            errorMessage = "Failed to load pinball library: \(error.localizedDescription)"
        }
    }

    private func preferredDefaultSortOption(for source: PinballLibrarySource, games: [PinballGame]) -> PinballLibrarySortOption {
        switch source.type {
        case .manufacturer:
            return .year
        case .category, .tournament:
            return .alphabetical
        case .venue:
            let hasArea = games.contains {
                guard let area = $0.area?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
                return !area.isEmpty && area.lowercased() != "null"
            }
            return hasArea ? .area : .alphabetical
        }
    }

    private func preferredDefaultYearSortDescending(for source: PinballLibrarySource, games: [PinballGame]) -> Bool {
        preferredDefaultSortOption(for: source, games: games) == .year && source.type == .manufacturer
    }
}

struct PinballGroupSection {
    let locationKey: String?
    let groupKey: Int?
    var games: [PinballGame]
}

struct PinballGame: Identifiable, Decodable {
    struct ReferenceLink: Identifiable, Decodable {
        let label: String
        let url: String

        var id: String {
            "\(label)|\(url)"
        }

        var destinationURL: URL? {
            URL(string: url)
        }
    }

    struct PlayableVideo: Identifiable {
        let id: String
        let label: String

        var youtubeWatchURL: URL? {
            URL(string: "https://www.youtube.com/watch?v=\(id)")
        }

        var youtubeOEmbedURL: URL? {
            guard let watchURL = youtubeWatchURL else { return nil }
            var components = URLComponents(string: "https://www.youtube.com/oembed")
            components?.queryItems = [
                URLQueryItem(name: "url", value: watchURL.absoluteString),
                URLQueryItem(name: "format", value: "json")
            ]
            return components?.url
        }

        var thumbnailCandidates: [URL] {
            [
                URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"),
                URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg"),
                URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg"),
                URL(string: "https://img.youtube.com/vi/\(id)/0.jpg")
            ].compactMap { $0 }
        }
    }

    struct Video: Identifiable, Decodable {
        let kind: String?
        let label: String?
        let url: String?

        var id: String {
            [kind ?? "", label ?? "", url ?? UUID().uuidString].joined(separator: "|")
        }
    }

    struct YouTubeMetadata: Equatable {
        let title: String
        let channelName: String?
    }

    enum CodingKeys: String, CodingKey {
        case libraryId
        case libraryIdV2 = "library_id"
        case sourceId
        case libraryName
        case libraryNameV2 = "library_name"
        case sourceName
        case libraryType
        case libraryTypeV2 = "library_type"
        case sourceType
        case venueName
        case venue
        case area
        case areaOrder
        case areaOrderV2 = "area_order"
        case location
        case group
        case position
        case bank
        case name
        case game
        case variant
        case manufacturer
        case year
        case slug
        case opdbId = "opdb_id"
        case libraryEntryId = "library_entry_id"
        case practiceIdentity = "practice_identity"
        case playfieldImageUrl
        case playfieldImageUrlV2 = "playfield_image_url"
        case primaryImageUrl = "primary_image_url"
        case primaryImageLargeUrl = "primary_image_large_url"
        case playfieldLocal
        case rulesheetUrl
        case rulesheetUrlV2 = "rulesheet_url"
        case rulesheetLinks = "rulesheet_links"
        case playfieldSourceLabel = "playfield_source_label"
        case assets
        case videos
    }

    struct Assets: Decodable {
        let playfieldLocalPractice: String?
        let rulesheetLocalPractice: String?
        let gameinfoLocalPractice: String?

        enum CodingKeys: String, CodingKey {
            case playfieldLocalPractice = "playfield_local_practice"
            case rulesheetLocalPractice = "rulesheet_local_practice"
            case gameinfoLocalPractice = "gameinfo_local_practice"
        }
    }

    let sourceId: String
    let sourceName: String
    let sourceType: PinballLibrarySourceType
    let area: String?
    let areaOrder: Int?
    let group: Int?
    let pos: Int?
    let bank: Int?
    let name: String
    let variant: String?
    let manufacturer: String?
    let year: Int?
    let slug: String
    let libraryEntryID: String?
    let opdbID: String?
    let practiceIdentity: String?
    let primaryImageUrl: String?
    let primaryImageLargeUrl: String?
    let playfieldImageUrl: String?
    let playfieldSourceLabel: String?
    let playfieldLocalOriginal: String?
    let playfieldLocal: String?
    let gameinfoLocal: String?
    let rulesheetLocal: String?
    let rulesheetUrl: String?
    let rulesheetLinks: [ReferenceLink]
    let videos: [Video]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let parsedType = libraryParseSourceType(
            try container.decodeIfPresent(String.self, forKey: .libraryType) ??
                (try container.decodeIfPresent(String.self, forKey: .libraryTypeV2)) ??
                (try container.decodeIfPresent(String.self, forKey: .sourceType))
        )
        sourceType = parsedType
        let sourceNameLibrary = try container.decodeIfPresent(String.self, forKey: .libraryName)
        let sourceNameLibraryV2 = try container.decodeIfPresent(String.self, forKey: .libraryNameV2)
        let sourceNameSource = try container.decodeIfPresent(String.self, forKey: .sourceName)
        let sourceNameVenueName = try container.decodeIfPresent(String.self, forKey: .venueName)
        let sourceNameVenue = try container.decodeIfPresent(String.self, forKey: .venue)
        let decodedSourceName = libraryNormalizedOptionalString(
            sourceNameLibrary ??
                sourceNameLibraryV2 ??
                sourceNameSource ??
                sourceNameVenueName ??
                sourceNameVenue
        )
        sourceName = decodedSourceName ?? "The Avenue"
        sourceId = libraryNormalizedOptionalString(
            try container.decodeIfPresent(String.self, forKey: .libraryId) ??
                (try container.decodeIfPresent(String.self, forKey: .libraryIdV2)) ??
                (try container.decodeIfPresent(String.self, forKey: .sourceId))
        ) ?? librarySlugifySourceID(sourceName)
        area = (
            try container.decodeIfPresent(String.self, forKey: .area) ??
                (try container.decodeIfPresent(String.self, forKey: .location))
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
        areaOrder = try container.decodeIfPresent(Int.self, forKey: .areaOrder)
            ?? (try container.decodeIfPresent(Int.self, forKey: .areaOrderV2))
        group = try container.decodeIfPresent(Int.self, forKey: .group)
        pos = try container.decodeIfPresent(Int.self, forKey: .position)
        bank = try container.decodeIfPresent(Int.self, forKey: .bank)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? (try container.decodeIfPresent(String.self, forKey: .game))
            ?? ""
        variant = try container.decodeIfPresent(String.self, forKey: .variant)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
            ?? (try container.decodeIfPresent(String.self, forKey: .practiceIdentity))
            ?? (try container.decodeIfPresent(String.self, forKey: .opdbId))
            ?? ""
        libraryEntryID = try container.decodeIfPresent(String.self, forKey: .libraryEntryId)
        opdbID = try container.decodeIfPresent(String.self, forKey: .opdbId)
        practiceIdentity = try container.decodeIfPresent(String.self, forKey: .practiceIdentity)
        primaryImageUrl = try container.decodeIfPresent(String.self, forKey: .primaryImageUrl)
        primaryImageLargeUrl = try container.decodeIfPresent(String.self, forKey: .primaryImageLargeUrl)
        let assets = try container.decodeIfPresent(Assets.self, forKey: .assets)
        playfieldImageUrl = try container.decodeIfPresent(String.self, forKey: .playfieldImageUrl)
            ?? (try container.decodeIfPresent(String.self, forKey: .playfieldImageUrlV2))
        let rawPlayfieldLocal = try container.decodeIfPresent(String.self, forKey: .playfieldLocal)
            ?? assets?.playfieldLocalPractice
        playfieldLocalOriginal = normalizeLibraryCachePath(rawPlayfieldLocal)
        playfieldLocal = normalizeLibraryPlayfieldLocalPath(rawPlayfieldLocal)
        gameinfoLocal = assets?.gameinfoLocalPractice
        rulesheetLocal = assets?.rulesheetLocalPractice
        rulesheetUrl = try container.decodeIfPresent(String.self, forKey: .rulesheetUrl)
            ?? (try container.decodeIfPresent(String.self, forKey: .rulesheetUrlV2))
        playfieldSourceLabel = try container.decodeIfPresent(String.self, forKey: .playfieldSourceLabel)
        let decodedRulesheetLinks = try container.decodeIfPresent([ReferenceLink].self, forKey: .rulesheetLinks)
        if let decodedRulesheetLinks {
            rulesheetLinks = decodedRulesheetLinks
        } else if let rulesheetUrl {
            rulesheetLinks = [ReferenceLink(label: "Rulesheet (source)", url: rulesheetUrl)]
        } else {
            rulesheetLinks = []
        }
        videos = try container.decodeIfPresent([Video].self, forKey: .videos) ?? []
    }

    nonisolated init(record: ResolvedCatalogRecord) {
        sourceId = record.sourceID
        sourceName = record.sourceName
        sourceType = record.sourceType
        area = record.area
        areaOrder = record.areaOrder
        group = record.groupNumber
        pos = record.position
        bank = record.bank
        name = record.name
        variant = record.variant
        manufacturer = record.manufacturer
        year = record.year
        slug = record.slug
        libraryEntryID = "\(record.sourceID)--\(record.opdbID ?? record.practiceIdentity)"
        opdbID = record.opdbID
        practiceIdentity = record.practiceIdentity
        primaryImageUrl = record.primaryImageURL
        primaryImageLargeUrl = record.primaryImageLargeURL
        playfieldImageUrl = record.playfieldImageURL
        playfieldSourceLabel = record.playfieldSourceLabel
        playfieldLocalOriginal = normalizeLibraryCachePath(record.playfieldLocalPath)
        playfieldLocal = normalizeLibraryPlayfieldLocalPath(record.playfieldLocalPath)
        gameinfoLocal = record.gameinfoLocalPath
        rulesheetLocal = record.rulesheetLocalPath
        rulesheetUrl = record.rulesheetURL
        rulesheetLinks = record.rulesheetLinks
        videos = record.videos
    }

    var id: String { libraryEntryID ?? opdbID ?? practiceIdentity ?? slug }
    var practiceKey: String { practiceIdentity ?? opdbGroupID ?? slug }

    var metaLine: String {
        var parts: [String] = []

        parts.append(manufacturer ?? "-")

        if let year {
            parts.append(String(year))
        }

        if let locationText {
            parts.append(locationText)
        }

        if let bank, bank > 0 {
            parts.append("Bank \(bank)")
        }

        return parts.joined(separator: " • ")
    }

    var manufacturerYearLine: String {
        let maker = manufacturer ?? "-"
        if let year {
            return "\(maker) • \(year)"
        }
        return maker
    }

    var normalizedVariant: String? {
        guard let variant else { return nil }
        let trimmed = variant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return nil }
        return trimmed
    }

    var locationBankLine: String {
        var parts: [String] = []
        if let locationText {
            parts.append(locationText)
        }
        if let bank, bank > 0 {
            parts.append("Bank \(bank)")
        }
        return parts.joined(separator: " • ")
    }

    var locationText: String? {
        guard let group, let pos else { return nil }
        if let area {
            let trimmed = area.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.lowercased() != "null" {
                return "📍 \(trimmed):\(group):\(pos)"
            }
        }
        return "📍 \(group):\(pos)"
    }

    var primaryImageSourceURL: URL? {
        guard let primaryImageUrl else { return nil }
        return libraryResolveURL(pathOrURL: primaryImageUrl)
    }

    var primaryImageLargeSourceURL: URL? {
        guard let primaryImageLargeUrl else { return nil }
        return libraryResolveURL(pathOrURL: primaryImageLargeUrl)
    }

    static func youtubeID(from raw: String) -> String? {
        guard let url = URL(string: raw),
              let host = url.host?.lowercased() else {
            return nil
        }

        if host.contains("youtu.be") {
            let id = url.path.replacingOccurrences(of: "/", with: "")
            guard !id.isEmpty else { return nil }
            return id
        }

        if host.contains("youtube.com"),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let id = queryItems.first(where: { $0.name == "v" })?.value,
           !id.isEmpty {
            return id
        }

        return nil
    }
}
