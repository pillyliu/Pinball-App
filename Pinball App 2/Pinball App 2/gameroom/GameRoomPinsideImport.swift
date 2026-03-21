import Foundation

nonisolated func canonicalPinsideDisplayedTitle(_ title: String, fallbackVariant: String?) -> (title: String, variant: String?) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedTitle.hasSuffix(")"),
          let openParenIndex = trimmedTitle.lastIndex(of: "(") else {
        return (trimmedTitle, fallbackVariant)
    }

    let baseTitle = String(trimmedTitle[..<openParenIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    let rawVariant = String(trimmedTitle[trimmedTitle.index(after: openParenIndex)..<trimmedTitle.index(before: trimmedTitle.endIndex)])
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !baseTitle.isEmpty else {
        return (trimmedTitle, fallbackVariant)
    }

    let normalizedVariant = normalizedPinsideVariantLabel(rawVariant)
    let resolvedVariant = preferredPinsideVariantLabel(
        parsedVariant: normalizedVariant,
        fallbackVariant: fallbackVariant
    )
    guard let resolvedVariant else {
        return (trimmedTitle, fallbackVariant)
    }
    return (baseTitle, resolvedVariant)
}

nonisolated private func preferredPinsideVariantLabel(parsedVariant: String?, fallbackVariant: String?) -> String? {
    let parsedTrimmed = parsedVariant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let normalizedParsed = parsedTrimmed.isEmpty ? nil : parsedTrimmed
    let fallbackTrimmed = fallbackVariant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let normalizedFallback = fallbackTrimmed.isEmpty ? nil : fallbackTrimmed
    guard let normalizedParsed else { return normalizedFallback }
    guard let normalizedFallback else { return normalizedParsed }

    let parsedLower = normalizedParsed.lowercased()
    let fallbackLower = normalizedFallback.lowercased()
    let bothAnniversary = parsedLower.contains("anniversary") && fallbackLower.contains("anniversary")
    if bothAnniversary {
        if parsedLower == fallbackLower {
            return normalizedFallback
        }
        if parsedLower.hasPrefix("\(fallbackLower) ") {
            return normalizedFallback
        }
    }
    return normalizedParsed
}

nonisolated private func normalizedPinsideVariantLabel(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let lowered = trimmed.lowercased()
    guard !lowered.isEmpty else { return nil }
    if lowered == "premium" || lowered == "premium edition" { return "Premium" }
    if lowered == "pro" || lowered == "pro edition" { return "Pro" }
    if lowered == "le" || lowered == "limited edition" { return "LE" }
    if lowered == "ce" || lowered.contains("collector") { return "CE" }
    if lowered == "se" || lowered.contains("special edition") { return "SE" }
    if lowered.contains("anniversary") { return trimmed }
    return nil
}

struct PinsideImportedMachine: Identifiable, Hashable {
    let id: String
    let slug: String
    let rawTitle: String
    let rawVariant: String?
    let manufacturerLabel: String?
    let manufactureYear: Int?
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
    private let groupMapPath = hostedPinsideGroupMapPath
    private var cachedGroupMap: [String: String]?

    func fetchCollectionMachines(sourceInput: String) async throws -> (sourceURL: String, machines: [PinsideImportedMachine]) {
        let normalizedInput = sourceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedInput.isEmpty else {
            throw GameRoomPinsideImportError.invalidInput
        }

        let sourceURL = try buildCollectionURL(from: normalizedInput)
        let groupMap = try await loadGroupMap()

        do {
            let html = try await fetchHTML(url: sourceURL)
            let directMachines = try parseBasicMachines(from: html, groupMap: groupMap)
            if let enrichedMachines = try? await fetchDetailedOrBasicMachinesFromJina(sourceURL: sourceURL, groupMap: groupMap),
               !enrichedMachines.isEmpty {
                return (sourceURL.absoluteString, mergeMachines(primary: enrichedMachines, fallback: directMachines))
            }
            return (sourceURL.absoluteString, directMachines)
        } catch {
            guard !isFatalImportError(error) else { throw error }
            let fallbackMachines = try await fetchDetailedOrBasicMachinesFromJina(sourceURL: sourceURL, groupMap: groupMap)
            guard !fallbackMachines.isEmpty else {
                throw GameRoomPinsideImportError.noMachinesFound
            }
            return (sourceURL.absoluteString, fallbackMachines)
        }
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

    private func fetchHTMLFromJina(sourceURL: URL) async throws -> String {
        let normalizedTarget = sourceURL.absoluteString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        guard let proxyURL = URL(string: "https://r.jina.ai/http://\(normalizedTarget)") else {
            throw GameRoomPinsideImportError.invalidURL
        }
        return try await fetchHTML(url: proxyURL)
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

    private func looksLikeCloudflareChallenge(_ html: String) -> Bool {
        let lowered = html.lowercased()
        return lowered.contains("just a moment") &&
            (lowered.contains("cf_chl_") ||
                lowered.contains("challenge-platform") ||
                lowered.contains("enable javascript and cookies to continue"))
    }

    private func parseBasicMachines(from html: String, groupMap: [String: String]) throws -> [PinsideImportedMachine] {
        try validateCollectionPageHTML(html)
        if looksLikeCloudflareChallenge(html) {
            throw GameRoomPinsideImportError.parseFailed
        }

        let slugs = extractCollectionSlugs(from: html)
        guard !slugs.isEmpty else {
            throw GameRoomPinsideImportError.noMachinesFound
        }

        return slugs.map { slug in
            let rawTitle = resolvedTitle(for: slug, groupMap: groupMap)
            return PinsideImportedMachine(
                id: slug,
                slug: slug,
                rawTitle: rawTitle,
                rawVariant: Self.variantFromSlug(slug),
                manufacturerLabel: nil,
                manufactureYear: nil,
                rawPurchaseDateText: nil,
                normalizedPurchaseDate: nil
            )
        }
    }

    private func fetchDetailedOrBasicMachinesFromJina(
        sourceURL: URL,
        groupMap: [String: String]
    ) async throws -> [PinsideImportedMachine] {
        let content = try await fetchHTMLFromJina(sourceURL: sourceURL)
        let detailedMachines = parseDetailedMachines(from: content)
        if !detailedMachines.isEmpty {
            return detailedMachines
        }
        return try parseBasicMachines(from: content, groupMap: groupMap)
    }

    private func parseDetailedMachines(from content: String) -> [PinsideImportedMachine] {
        guard
            let titleRegex = try? NSRegularExpression(
                pattern: #"^####\s+(.+?)\s+\[\]\((?:https?:\/\/)?pinside\.com\/pinball\/machine\/([a-z0-9\-]+)[^)]*\)\s*$"#,
                options: [.caseInsensitive]
            ),
            let metadataRegex = try? NSRegularExpression(
                pattern: #"^#####\s+(.+?),\s*((?:19|20)\d{2})\s*$"#,
                options: [.caseInsensitive]
            )
        else {
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        var seen = Set<String>()
        var machines: [PinsideImportedMachine] = []
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            let lineRange = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let titleMatch = titleRegex.firstMatch(in: line, options: [], range: lineRange),
                  titleMatch.numberOfRanges >= 3,
                  let titleRange = Range(titleMatch.range(at: 1), in: line),
                  let slugRange = Range(titleMatch.range(at: 2), in: line) else {
                index += 1
                continue
            }

            let slug = String(line[slugRange]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !slug.isEmpty, seen.insert(slug).inserted else {
                index += 1
                continue
            }

            let rawDisplayTitle = String(line[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            var scanIndex = index + 1
            while scanIndex < lines.count, lines[scanIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                scanIndex += 1
            }
            guard scanIndex < lines.count else { break }

            let metadataLine = lines[scanIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let metadataRange = NSRange(metadataLine.startIndex..<metadataLine.endIndex, in: metadataLine)
            guard let metadataMatch = metadataRegex.firstMatch(in: metadataLine, options: [], range: metadataRange),
                  metadataMatch.numberOfRanges >= 3,
                  let manufacturerRange = Range(metadataMatch.range(at: 1), in: metadataLine),
                  let yearRange = Range(metadataMatch.range(at: 2), in: metadataLine) else {
                index += 1
                continue
            }

            let manufacturerLabel = String(metadataLine[manufacturerRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let manufactureYear = Int(String(metadataLine[yearRange]).trimmingCharacters(in: .whitespacesAndNewlines))

            scanIndex += 1
            while scanIndex < lines.count, lines[scanIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                scanIndex += 1
            }

            var purchaseText: String?
            if scanIndex < lines.count {
                let purchaseLine = lines[scanIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if purchaseLine.lowercased().hasPrefix("purchased ") {
                    purchaseText = String(purchaseLine.dropFirst("Purchased ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    scanIndex += 1
                }
            }

            let parsedTitle = Self.parsedDisplayedTitle(rawDisplayTitle, fallbackVariant: Self.variantFromSlug(slug))
            machines.append(
                PinsideImportedMachine(
                    id: slug,
                    slug: slug,
                    rawTitle: parsedTitle.title,
                    rawVariant: parsedTitle.variant,
                    manufacturerLabel: manufacturerLabel.isEmpty ? nil : manufacturerLabel,
                    manufactureYear: manufactureYear,
                    rawPurchaseDateText: purchaseText,
                    normalizedPurchaseDate: normalizedFirstOfMonth(from: purchaseText)
                )
            )
            index = scanIndex
        }

        return machines
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
        if let cached = try loadCachedPinballData(path: groupMapPath), !cached.isEmpty {
            data = cached
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

    private func isFatalImportError(_ error: Error) -> Bool {
        guard let error = error as? GameRoomPinsideImportError else { return false }
        switch error {
        case .invalidInput, .invalidURL, .userNotFound, .privateOrUnavailableCollection:
            return true
        case .httpError, .parseFailed, .noMachinesFound:
            return false
        }
    }

    private func resolvedTitle(for slug: String, groupMap: [String: String]) -> String {
        if let mapped = groupMap[slug]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !mapped.isEmpty,
           mapped != "~" {
            return mapped
        }
        return Self.humanizedTitle(fromSlug: slug)
    }

    private func mergeMachines(
        primary: [PinsideImportedMachine],
        fallback: [PinsideImportedMachine]
    ) -> [PinsideImportedMachine] {
        var fallbackBySlug = Dictionary(uniqueKeysWithValues: fallback.map { ($0.slug.lowercased(), $0) })
        var merged: [PinsideImportedMachine] = []

        for machine in primary {
            let key = machine.slug.lowercased()
            if let fallbackMachine = fallbackBySlug.removeValue(forKey: key) {
                merged.append(
                    PinsideImportedMachine(
                        id: machine.id,
                        slug: machine.slug,
                        rawTitle: machine.rawTitle,
                        rawVariant: machine.rawVariant ?? fallbackMachine.rawVariant,
                        manufacturerLabel: machine.manufacturerLabel ?? fallbackMachine.manufacturerLabel,
                        manufactureYear: machine.manufactureYear ?? fallbackMachine.manufactureYear,
                        rawPurchaseDateText: machine.rawPurchaseDateText ?? fallbackMachine.rawPurchaseDateText,
                        normalizedPurchaseDate: machine.normalizedPurchaseDate ?? fallbackMachine.normalizedPurchaseDate
                    )
                )
            } else {
                merged.append(machine)
            }
        }

        for machine in fallback where fallbackBySlug[machine.slug.lowercased()] != nil {
            merged.append(machine)
        }

        return merged
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

    private static func parsedDisplayedTitle(_ title: String, fallbackVariant: String?) -> (title: String, variant: String?) {
        canonicalPinsideDisplayedTitle(title, fallbackVariant: fallbackVariant)
    }

    private func normalizedFirstOfMonth(from raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }

        let formats = [
            "MMMM yyyy",
            "MMM yyyy",
            "M/yyyy",
            "MM/yyyy",
            "M-yyyy",
            "MM-yyyy",
            "yyyy-MM",
            "yyyy/M"
        ]

        let calendar = Calendar(identifier: .gregorian)

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            guard let date = formatter.date(from: raw) else { continue }
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        }

        return nil
    }
}
