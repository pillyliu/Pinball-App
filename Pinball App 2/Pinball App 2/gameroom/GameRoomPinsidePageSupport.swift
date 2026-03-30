import Foundation

nonisolated let bundledPinsideGroupMapResourceName = "pinside_group_map"

nonisolated func validatePinsideCollectionPageHTML(_ html: String) throws {
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

nonisolated func looksLikePinsideCloudflareChallenge(_ html: String) -> Bool {
    let lowered = html.lowercased()
    return lowered.contains("just a moment") &&
        (lowered.contains("cf_chl_") ||
            lowered.contains("challenge-platform") ||
            lowered.contains("enable javascript and cookies to continue"))
}

nonisolated func extractPinsideCollectionSlugs(from html: String) -> [String] {
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

nonisolated func loadBundledPinsideGroupMap() -> [String: String] {
    let resourceCandidates = [
        Bundle.main.url(
            forResource: bundledPinsideGroupMapResourceName,
            withExtension: "json",
            subdirectory: "SharedAppSupport"
        ),
        Bundle.main.url(
            forResource: bundledPinsideGroupMapResourceName,
            withExtension: "json"
        ),
    ]

    guard let resourceURL = resourceCandidates.compactMap({ $0 }).first,
          let data = try? Data(contentsOf: resourceURL),
          !data.isEmpty,
          let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
        return [:]
    }

    return decoded
}
