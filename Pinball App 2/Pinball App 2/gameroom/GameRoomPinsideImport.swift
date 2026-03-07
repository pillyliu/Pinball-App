import Foundation

struct PinsideImportedMachine: Identifiable, Hashable {
    let id: String
    let slug: String
    let rawTitle: String
    let rawVariant: String?
    let rawPurchaseDateText: String?
    let normalizedPurchaseDate: Date?

    var fingerprint: String {
        "pinside:\(slug.lowercased())"
    }
}

enum GameRoomPinsideImportError: LocalizedError {
    case invalidInput
    case invalidURL
    case httpError(Int)
    case userNotFound
    case privateOrUnavailableCollection
    case parseFailed
    case noMachinesFound

    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Enter a Pinside username or public collection URL."
        case .invalidURL:
            return "Could not build a valid Pinside collection URL."
        case let .httpError(code):
            return "Pinside request failed (\(code))."
        case .userNotFound:
            return "Could not find that Pinside user/profile."
        case .privateOrUnavailableCollection:
            return "This Pinside collection appears private or unavailable publicly."
        case .parseFailed:
            return "Could not parse that collection page. Try a different public collection URL."
        case .noMachinesFound:
            return "No machine entries were found on that public collection page."
        }
    }
}

actor GameRoomPinsideImportService {
    private let groupMapPath = "/pinball/data/pinside_group_map.json"
    private var cachedGroupMap: [String: String]?

    func fetchCollectionMachines(sourceInput: String) async throws -> (sourceURL: String, machines: [PinsideImportedMachine]) {
        let normalizedInput = sourceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedInput.isEmpty else {
            throw GameRoomPinsideImportError.invalidInput
        }

        let sourceURL = try buildCollectionURL(from: normalizedInput)
        let html = try await fetchHTML(url: sourceURL)
        try validateCollectionPageHTML(html)
        let slugs = extractCollectionSlugs(from: html)
        guard !slugs.isEmpty else {
            throw GameRoomPinsideImportError.noMachinesFound
        }

        let groupMap = try await loadGroupMap()
        let machines = slugs.map { slug in
            let title = groupMap[slug] ?? Self.humanizedTitle(fromSlug: slug)
            let variant = Self.variantFromSlug(slug)
            return PinsideImportedMachine(
                id: slug,
                slug: slug,
                rawTitle: title,
                rawVariant: variant,
                rawPurchaseDateText: nil,
                normalizedPurchaseDate: nil
            )
        }
        return (sourceURL.absoluteString, machines)
    }

    private func buildCollectionURL(from input: String) throws -> URL {
        if input.contains("pinside.com") {
            guard let url = URL(string: input), let host = url.host?.lowercased(), host.contains("pinside.com") else {
                throw GameRoomPinsideImportError.invalidURL
            }
            return url
        }

        let username = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
        guard !username.isEmpty else {
            throw GameRoomPinsideImportError.invalidInput
        }

        guard let url = URL(string: "https://pinside.com/pinball/community/pinsiders/\(username)/collection/current") else {
            throw GameRoomPinsideImportError.invalidURL
        }
        return url
    }

    private func fetchHTML(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if http.statusCode == 404 {
                throw GameRoomPinsideImportError.userNotFound
            }
            throw GameRoomPinsideImportError.httpError(http.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            throw URLError(.cannotDecodeRawData)
        }
        return html
    }

    private func validateCollectionPageHTML(_ html: String) throws {
        let lowered = html.lowercased()
        if lowered.contains("404") && lowered.contains("page not found") {
            throw GameRoomPinsideImportError.userNotFound
        }
        if lowered.contains("this profile is private") ||
            lowered.contains("private profile") ||
            lowered.contains("collection is private") {
            throw GameRoomPinsideImportError.privateOrUnavailableCollection
        }
        if !lowered.contains("/pinball/machine/") &&
            (lowered.contains("access denied") || lowered.contains("not available")) {
            throw GameRoomPinsideImportError.privateOrUnavailableCollection
        }
        if lowered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw GameRoomPinsideImportError.parseFailed
        }
    }

    private func extractCollectionSlugs(from html: String) -> [String] {
        let pattern = #"(?:https?:\/\/pinside\.com)?\/pinball\/machine\/([a-z0-9\-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)

        var seen = Set<String>()
        var ordered: [String] = []
        for match in matches {
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html) else {
                continue
            }
            let slug = String(html[range]).lowercased()
            guard !slug.isEmpty, seen.insert(slug).inserted else { continue }
            ordered.append(slug)
        }
        return ordered
    }

    private func loadGroupMap() async throws -> [String: String] {
        if let cachedGroupMap {
            return cachedGroupMap
        }

        let data: Data
        if let bundled = try loadBundledPinballData(path: groupMapPath), !bundled.isEmpty {
            data = bundled
        } else {
            let cached = try await PinballDataCache.shared.loadText(path: groupMapPath, allowMissing: false)
            guard let text = cached.text, let encoded = text.data(using: .utf8), !encoded.isEmpty else {
                throw URLError(.cannotDecodeRawData)
            }
            data = encoded
        }

        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        cachedGroupMap = decoded
        return decoded
    }

    private static func variantFromSlug(_ slug: String) -> String? {
        let lowered = slug.lowercased()
        if let anniversary = anniversaryVariant(from: lowered) {
            return anniversary
        }
        if lowered.hasSuffix("-premium") { return "Premium" }
        if lowered.hasSuffix("-pro") { return "Pro" }
        if lowered.hasSuffix("-le") || lowered.contains("-limited-edition") { return "LE" }
        if lowered.hasSuffix("-ce") || lowered.contains("-collector") { return "CE" }
        if lowered.hasSuffix("-se") || lowered.contains("-special-edition") { return "SE" }
        return nil
    }

    private static func anniversaryVariant(from loweredSlug: String) -> String? {
        let pattern = #"(\d+)(st|nd|rd|th)-anniversary"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return loweredSlug.contains("anniversary") ? "Anniversary" : nil
        }
        let nsRange = NSRange(loweredSlug.startIndex..<loweredSlug.endIndex, in: loweredSlug)
        guard let match = regex.firstMatch(in: loweredSlug, options: [], range: nsRange) else {
            return loweredSlug.contains("anniversary") ? "Anniversary" : nil
        }
        guard
            match.numberOfRanges >= 3,
            let numberRange = Range(match.range(at: 1), in: loweredSlug),
            let suffixRange = Range(match.range(at: 2), in: loweredSlug)
        else {
            return "Anniversary"
        }
        let number = loweredSlug[numberRange]
        let suffix = loweredSlug[suffixRange].lowercased()
        return "\(number)\(suffix) Anniversary"
    }

    private static func humanizedTitle(fromSlug slug: String) -> String {
        slug
            .split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
