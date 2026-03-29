import Foundation

nonisolated let librarySupportedPlayfieldOriginalExtensions = ["webp", "jpg", "jpeg", "png"]
nonisolated let libraryMissingArtworkPath = "/pinball/images/playfields/fallback-image-not-available_2048.webp"
nonisolated let libraryPinProfHosts: Set<String> = [
    "pillyliu.com",
    "www.pillyliu.com",
    "pinprof.com",
    "www.pinprof.com"
]
nonisolated let libraryBundledOnlyAppGroupIDs: Set<String> = [
    "G900001"
]

enum LibraryLivePlayfieldKind: String {
    case pillyliu
    case opdb
    case external
    case missing
}

struct LibraryLivePlayfieldStatus: Equatable {
    let effectiveKind: LibraryLivePlayfieldKind
    let effectiveURL: URL?
}

actor LibraryLivePlayfieldStatusStore {
    static let shared = LibraryLivePlayfieldStatusStore()

    func status(for practiceIdentity: String?) async -> LibraryLivePlayfieldStatus? {
        guard let practiceIdentity = practiceIdentity?.trimmingCharacters(in: .whitespacesAndNewlines),
              !practiceIdentity.isEmpty else {
            return nil
        }

        var components = URLComponents(string: "https://pillyliu.com/pinprof-admin/api.php")
        components?.queryItems = [
            URLQueryItem(name: "route", value: "public/playfield-status/\(practiceIdentity)")
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rawKind = json["effectiveKind"] as? String,
                  let kind = LibraryLivePlayfieldKind(rawValue: rawKind) else {
                return nil
            }

            let effectiveURL = libraryResolveURL(pathOrURL: (json["effectiveUrl"] as? String) ?? "")
            return LibraryLivePlayfieldStatus(effectiveKind: kind, effectiveURL: effectiveURL)
        } catch {
            return nil
        }
    }
}

nonisolated func libraryResolveURL(pathOrURL: String) -> URL? {
    if let direct = URL(string: pathOrURL), direct.scheme != nil {
        return direct
    }

    if pathOrURL.hasPrefix("/") {
        return URL(string: "https://pillyliu.com\(pathOrURL)")
    }

    return URL(string: "https://pillyliu.com/\(pathOrURL)")
}

nonisolated func libraryIsPinProfHost(_ host: String?) -> Bool {
    guard let host = host?.lowercased() else { return false }
    return libraryPinProfHosts.contains(host)
}

nonisolated func libraryIsPinProfPlayfieldURL(_ url: URL?) -> Bool {
    guard let url,
          libraryIsPinProfHost(url.host) else {
        return false
    }
    return url.path.hasPrefix("/pinball/images/playfields/")
}

nonisolated func normalizeLibraryCachePath(_ pathOrURL: String?) -> String? {
    guard let raw = pathOrURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return nil
    }
    func normalizePlayfieldPublishedPath(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"(/pinball/images/playfields/.+?)(?:_(700|1400))?\.[A-Za-z0-9]+$"#,
            with: "$1.webp",
            options: .regularExpression
        )
    }
    if let url = URL(string: raw), let host = url.host?.lowercased(), host == "pillyliu.com" {
        return url.path.contains("/pinball/images/playfields/") ? normalizePlayfieldPublishedPath(url.path) : url.path
    }
    if raw.hasPrefix("/") {
        return raw.contains("/pinball/images/playfields/") ? normalizePlayfieldPublishedPath(raw) : raw
    }
    let normalized = "/" + raw
    return normalized.contains("/pinball/images/playfields/") ? normalizePlayfieldPublishedPath(normalized) : normalized
}

nonisolated func normalizeLibraryPlayfieldLocalPath(_ pathOrURL: String?) -> String? {
    guard let raw = pathOrURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return nil
    }
    if raw.localizedCaseInsensitiveContains("/pinball/images/playfields/") {
        if raw.lowercased().hasSuffix("_700.webp") { return raw }
        if raw.lowercased().hasSuffix("_1400.webp") {
            return raw.replacingOccurrences(of: "_1400.webp", with: "_700.webp", options: [.caseInsensitive])
        }
        if let dot = raw.lastIndex(of: ".") {
            return String(raw[..<dot]) + "_700.webp"
        }
    }
    return raw
}

nonisolated func libraryMissingArtworkURL() -> URL? {
    libraryResolveURL(pathOrURL: libraryMissingArtworkPath)
}
