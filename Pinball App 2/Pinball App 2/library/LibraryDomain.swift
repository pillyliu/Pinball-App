import Foundation
import SwiftUI
import Combine

enum MarkdownTableAlignment {
    case left
    case center
    case right
}

struct MarkdownOrderedItem {
    let number: Int
    let text: String
}

enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([MarkdownOrderedItem])
    case blockquote([String])
    case codeBlock(language: String?, code: String)
    case horizontalRule
    case table(headers: [String], alignments: [MarkdownTableAlignment], rows: [[String]])
}

enum NativeMarkdownParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var index = 0
        var blocks: [MarkdownBlock] = []

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                index += 1
                var codeLines: [String] = []
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n")))
                continue
            }

            if isHorizontalRule(trimmed) {
                blocks.append(.horizontalRule)
                index += 1
                continue
            }

            if let heading = parseHeading(trimmed) {
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if isTableHeaderLine(trimmed), index + 1 < lines.count, isTableAlignmentLine(lines[index + 1].trimmingCharacters(in: .whitespaces)) {
                let headers = parsePipeRow(trimmed)
                let alignments = parseAlignments(lines[index + 1].trimmingCharacters(in: .whitespaces))
                index += 2
                var rows: [[String]] = []
                while index < lines.count {
                    let rowLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if rowLine.isEmpty || !rowLine.contains("|") {
                        break
                    }
                    rows.append(parsePipeRow(rowLine))
                    index += 1
                }
                blocks.append(.table(headers: headers, alignments: alignments, rows: rows))
                continue
            }

            if isUnorderedListLine(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard let item = parseUnorderedListItem(candidate) else { break }
                    items.append(item)
                    index += 1
                }
                blocks.append(.unorderedList(items))
                continue
            }

            if isOrderedListLine(trimmed) {
                var items: [MarkdownOrderedItem] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard let item = parseOrderedListItem(candidate) else { break }
                    items.append(item)
                    index += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix(">") else { break }
                    let stripped = candidate.dropFirst().trimmingCharacters(in: .whitespaces)
                    quoteLines.append(stripped)
                    index += 1
                }
                blocks.append(.blockquote(quoteLines))
                continue
            }

            var paragraphLines: [String] = [trimLeadingWhitespace(line)]
            index += 1
            while index < lines.count {
                let rawCandidate = lines[index]
                let candidate = rawCandidate.trimmingCharacters(in: .whitespaces)
                if candidate.isEmpty || startsNewBlock(candidate, nextLine: index + 1 < lines.count ? lines[index + 1].trimmingCharacters(in: .whitespaces) : nil) {
                    break
                }
                paragraphLines.append(trimLeadingWhitespace(rawCandidate))
                index += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
        }

        return blocks
    }

    private static func startsNewBlock(_ line: String, nextLine: String?) -> Bool {
        if line.hasPrefix("```") || isHorizontalRule(line) || parseHeading(line) != nil || line.hasPrefix(">") {
            return true
        }
        if isUnorderedListLine(line) || isOrderedListLine(line) {
            return true
        }
        if isTableHeaderLine(line), let nextLine, isTableAlignmentLine(nextLine) {
            return true
        }
        return false
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var level = 0
        for char in line {
            if char == "#" {
                level += 1
            } else {
                break
            }
        }
        guard (1...6).contains(level) else { return nil }
        let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (level, text)
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3 else { return false }
        return compact.allSatisfy { $0 == "-" } || compact.allSatisfy { $0 == "*" } || compact.allSatisfy { $0 == "_" }
    }

    private static func isUnorderedListLine(_ line: String) -> Bool {
        parseUnorderedListItem(line) != nil
    }

    private static func parseUnorderedListItem(_ line: String) -> String? {
        guard line.count >= 2 else { return nil }
        let first = line.first
        guard first == "-" || first == "*" || first == "+" else { return nil }
        guard line.dropFirst().first == " " else { return nil }
        return String(line.dropFirst(2))
    }

    private static func isOrderedListLine(_ line: String) -> Bool {
        parseOrderedListItem(line) != nil
    }

    private static func parseOrderedListItem(_ line: String) -> MarkdownOrderedItem? {
        var numberText = ""
        var idx = line.startIndex
        while idx < line.endIndex, line[idx].isNumber {
            numberText.append(line[idx])
            idx = line.index(after: idx)
        }
        guard !numberText.isEmpty, idx < line.endIndex else { return nil }
        let sep = line[idx]
        guard sep == "." || sep == ")" else { return nil }
        idx = line.index(after: idx)
        guard idx < line.endIndex, line[idx] == " " else { return nil }
        idx = line.index(after: idx)
        let itemText = String(line[idx...])
        guard let number = Int(numberText) else { return nil }
        return MarkdownOrderedItem(number: number, text: itemText)
    }

    private static func isTableHeaderLine(_ line: String) -> Bool {
        line.contains("|")
    }

    private static func isTableAlignmentLine(_ line: String) -> Bool {
        let cells = parsePipeRow(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let compact = cell.replacingOccurrences(of: " ", with: "")
            guard compact.count >= 3 else { return false }
            return compact.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func parseAlignments(_ line: String) -> [MarkdownTableAlignment] {
        parsePipeRow(line).map { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            let left = trimmed.hasPrefix(":")
            let right = trimmed.hasSuffix(":")
            switch (left, right) {
            case (true, true): return .center
            case (false, true): return .right
            default: return .left
            }
        }
    }

    private static func parsePipeRow(_ line: String) -> [String] {
        var cleaned = line
        if cleaned.hasPrefix("|") { cleaned.removeFirst() }
        if cleaned.hasSuffix("|") { cleaned.removeLast() }
        return cleaned.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private static func trimLeadingWhitespace(_ line: String) -> String {
        guard let firstNonWhitespace = line.firstIndex(where: { !$0.isWhitespace }) else {
            return ""
        }
        return String(line[firstNonWhitespace...])
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
enum LoadStatus {
    case idle
    case loading
    case loaded
    case missing
    case error
}

enum PinballLibrarySourceType: String, CaseIterable {
    case venue
    case category
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
            return .year
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
    @Published var query: String = ""
    @Published var sortOption: PinballLibrarySortOption = .area
    @Published var selectedBank: Int?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false

    private var didLoad = false
    private static let libraryPath = "/pinball/data/pinball_library.json"

    var selectedSource: PinballLibrarySource? {
        sources.first(where: { $0.id == selectedSourceID }) ?? sources.first
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
        case .category:
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
        sortOption.menuLabel
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
            return filteredGames.sorted {
                byOptionalAscending($0.year, $1.year)
                    ?? byAscending($0.name.lowercased(), $1.name.lowercased())
                    ?? false
            }
        }
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

        for game in sortedFilteredGames {
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

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await loadGames()
    }

    func selectSource(_ sourceID: String) {
        selectedSourceID = sourceID
        if let selectedSource {
            let options = sortOptions
            if !options.contains(sortOption) {
                sortOption = selectedSource.defaultSortOption
                if !options.contains(sortOption), let first = options.first {
                    sortOption = first
                }
            }
        }
        selectedBank = nil
    }

    private func loadGames() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let cached = try await PinballDataCache.shared.loadText(path: Self.libraryPath)
            guard let text = cached.text,
                  let data = text.data(using: .utf8) else {
                throw URLError(.cannotDecodeRawData)
            }

            let payload = try decodeLibraryPayload(data: data)
            games = payload.games
            sources = payload.sources
            if let selected = sources.first(where: { $0.id == selectedSourceID }) ?? sources.first {
                selectedSourceID = selected.id
                let options = sortOptions
                if !options.contains(sortOption) {
                    sortOption = selected.defaultSortOption
                    if !options.contains(sortOption), let first = options.first {
                        sortOption = first
                    }
                }
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
}

@MainActor
final class PinballGameInfoViewModel: ObservableObject {
    @Published private(set) var status: LoadStatus = .idle
    @Published private(set) var markdownText: String?

    private let slug: String
    private var didLoad = false

    init(slug: String) {
        self.slug = slug
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await load()
    }

    private func load() async {
        status = .loading
        markdownText = nil

        do {
            let path = "/pinball/gameinfo/\(slug).md"
            let cached = try await PinballDataCache.shared.loadText(path: path, allowMissing: true)
            if cached.isMissing {
                status = .missing
                return
            }
            guard let text = cached.text, !text.isEmpty else {
                status = .missing
                return
            }

            markdownText = text
            status = .loaded
        } catch {
            status = .error
        }
    }
}

@MainActor
final class RulesheetScreenModel: ObservableObject {
    @Published private(set) var status: LoadStatus = .idle
    @Published private(set) var markdownText: String?

    private let slug: String
    private var didLoad = false

    init(slug: String) {
        self.slug = slug
    }

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await load()
    }

    private func load() async {
        status = .loading
        markdownText = nil

        do {
            let path = "/pinball/rulesheets/\(slug).md"
            let cached = try await PinballDataCache.shared.loadText(path: path, allowMissing: true)
            if cached.isMissing {
                status = .missing
                return
            }
            guard let text = cached.text, !text.isEmpty else {
                status = .missing
                return
            }

            markdownText = Self.normalizeRulesheet(text)
            status = .loaded
        } catch {
            status = .error
        }
    }

    private static func normalizeRulesheet(_ input: String) -> String {
        var text = input.replacingOccurrences(of: "\r\n", with: "\n")

        if text.hasPrefix("---\n") {
            let start = text.index(text.startIndex, offsetBy: 4)
            if let endRange = text.range(of: "\n---", range: start..<text.endIndex),
               let after = text[endRange.upperBound...].firstIndex(of: "\n") {
                text = String(text[text.index(after, offsetBy: 1)...])
            }
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Match Android behavior: add two rendered dummy lines at the end so
        // final content can scroll clear of the tab switcher.
        return text + "\n\n\u{00A0}\n\n\u{00A0}\n"
    }
}
struct PinballLibraryPayload {
    let games: [PinballGame]
    let sources: [PinballLibrarySource]
}

private struct PinballLibraryRoot: Decodable {
    let games: [PinballGame]?
    let items: [PinballGame]?
    let sources: [PinballLibrarySourcePayload]?
}

private struct PinballLibrarySourcePayload: Decodable {
    let id: String
    let name: String?
    let type: String?
}

func decodeLibraryPayload(data: Data) throws -> PinballLibraryPayload {
    let decoder = JSONDecoder()

    if let root = try? decoder.decode(PinballLibraryRoot.self, from: data) {
        let games = root.games ?? root.items ?? []
        let decodedSources = (root.sources ?? []).map {
            PinballLibrarySource(
                id: $0.id,
                name: ($0.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? $0.id,
                type: parseSourceType($0.type),
            )
        }
        let sources = decodedSources.isEmpty ? inferSources(from: games) : decodedSources
        return PinballLibraryPayload(games: games, sources: sources)
    }

    let games = try decoder.decode([PinballGame].self, from: data)
    let sources = inferSources(from: games)
    return PinballLibraryPayload(games: games, sources: sources)
}

private func inferSources(from games: [PinballGame]) -> [PinballLibrarySource] {
    var seen: [PinballLibrarySource] = []
    var ids = Set<String>()
    for game in games {
        if ids.contains(game.sourceId) { continue }
        ids.insert(game.sourceId)
        seen.append(PinballLibrarySource(id: game.sourceId, name: game.sourceName, type: game.sourceType))
    }
    if seen.isEmpty {
        seen.append(PinballLibrarySource(id: "the-avenue", name: "The Avenue", type: .venue))
    }
    return seen
}

private func parseSourceType(_ raw: String?) -> PinballLibrarySourceType {
    let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized == "category" || normalized == "manufacturer" {
        return .category
    }
    return .venue
}

private func slugifySourceID(_ value: String) -> String {
    let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if lower.isEmpty { return "the-avenue" }
    let mapped = lower
        .replacingOccurrences(of: "&", with: "and")
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return mapped.isEmpty ? "the-avenue" : mapped
}

private func normalizedOptionalString(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}

struct PinballGroupSection {
    let locationKey: String?
    let groupKey: Int?
    var games: [PinballGame]
}

struct PinballGame: Identifiable, Decodable {
    struct PlayableVideo: Identifiable {
        let id: String
        let label: String

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

    enum CodingKeys: String, CodingKey {
        case libraryId
        case sourceId
        case libraryName
        case sourceName
        case libraryType
        case sourceType
        case venueName
        case area
        case areaOrder
        case location
        case group
        case position
        case bank
        case name
        case manufacturer
        case year
        case slug
        case playfieldImageUrl
        case playfieldLocal
        case rulesheetUrl
        case videos
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
    let manufacturer: String?
    let year: Int?
    let slug: String
    let playfieldImageUrl: String?
    let playfieldLocal: String?
    let rulesheetUrl: String?
    let videos: [Video]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let parsedType = parseSourceType(
            try container.decodeIfPresent(String.self, forKey: .libraryType) ??
                container.decodeIfPresent(String.self, forKey: .sourceType)
        )
        sourceType = parsedType
        let decodedSourceName = normalizedOptionalString(
            try container.decodeIfPresent(String.self, forKey: .libraryName) ??
                container.decodeIfPresent(String.self, forKey: .sourceName) ??
                container.decodeIfPresent(String.self, forKey: .venueName)
        )
        sourceName = decodedSourceName ?? "The Avenue"
        sourceId = normalizedOptionalString(
            try container.decodeIfPresent(String.self, forKey: .libraryId) ??
                container.decodeIfPresent(String.self, forKey: .sourceId)
        ) ?? slugifySourceID(sourceName)
        area = (
            try container.decodeIfPresent(String.self, forKey: .area) ??
                container.decodeIfPresent(String.self, forKey: .location)
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
        areaOrder = try container.decodeIfPresent(Int.self, forKey: .areaOrder)
        group = try container.decodeIfPresent(Int.self, forKey: .group)
        pos = try container.decodeIfPresent(Int.self, forKey: .position)
        bank = try container.decodeIfPresent(Int.self, forKey: .bank)
        name = try container.decode(String.self, forKey: .name)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        slug = try container.decode(String.self, forKey: .slug)
        playfieldImageUrl = try container.decodeIfPresent(String.self, forKey: .playfieldImageUrl)
        playfieldLocal = try container.decodeIfPresent(String.self, forKey: .playfieldLocal)
        rulesheetUrl = try container.decodeIfPresent(String.self, forKey: .rulesheetUrl)
        videos = try container.decodeIfPresent([Video].self, forKey: .videos) ?? []
    }

    var id: String { slug }

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

    var locationBankLine: String {
        var parts: [String] = []
        if let locationText {
            parts.append(locationText)
        }
        if let bank, bank > 0 {
            parts.append("Bank \(bank)")
        }
        return parts.isEmpty ? "-" : parts.joined(separator: " • ")
    }

    var locationText: String? {
        guard let group, let pos else { return nil }
        if let area, !area.isEmpty {
            return "📍 \(area):\(group):\(pos)"
        }
        return "📍 \(group):\(pos)"
    }

    var playfieldLocalURL: URL? {
        guard let playfieldLocal else { return nil }
        return Self.resolveURL(pathOrURL: playfieldLocal)
    }

    var libraryPlayfieldCandidates: [URL] {
        [derivedPlayfieldURL(width: 700), playfieldLocalURL].compactMap { $0 }
    }

    var miniPlayfieldCandidates: [URL] {
        [derivedPlayfieldURL(width: 700), playfieldLocalURL, derivedPlayfieldURL(width: 1400)].compactMap { $0 }
    }

    var gamePlayfieldCandidates: [URL] {
        [derivedPlayfieldURL(width: 1400), playfieldLocalURL, derivedPlayfieldURL(width: 700)].compactMap { $0 }
    }

    var fullscreenPlayfieldCandidates: [URL] {
        [playfieldLocalURL, derivedPlayfieldURL(width: 1400), derivedPlayfieldURL(width: 700)].compactMap { $0 }
    }

    var playfieldImageSourceURL: URL? {
        guard let playfieldImageUrl else { return nil }
        return URL(string: playfieldImageUrl)
    }

    var rulesheetSourceURL: URL? {
        guard let rulesheetUrl else { return nil }
        return URL(string: rulesheetUrl)
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

    private func derivedPlayfieldURL(width: Int) -> URL? {
        guard let playfieldLocal else { return nil }

        let normalizedPath: String
        if let url = URL(string: playfieldLocal), url.scheme != nil {
            normalizedPath = url.path
        } else {
            normalizedPath = playfieldLocal
        }

        guard let slashIndex = normalizedPath.lastIndex(of: "/") else { return nil }
        let directory = String(normalizedPath[..<slashIndex])
        let derived = "\(directory)/\(slug)_\(width).webp"
        return Self.resolveURL(pathOrURL: derived)
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
