import Foundation

nonisolated private func extractYouTubeVideoID(from rawURL: String) -> String? {
    guard let components = URLComponents(string: rawURL),
          let host = components.host?.lowercased() else {
        return nil
    }
    let pathComponents = components.path.split(separator: "/").map(String.init)
    if host == "youtu.be" || host == "www.youtu.be" {
        return pathComponents.first
    }
    if host == "youtube.com" || host == "www.youtube.com" || host == "m.youtube.com" || host == "music.youtube.com" || host == "youtube-nocookie.com" || host == "www.youtube-nocookie.com" || host.hasSuffix(".youtube.com") || host.hasSuffix(".youtube-nocookie.com") {
        if pathComponents.first == "watch" {
            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }
        if let first = pathComponents.first, ["embed", "shorts", "live"].contains(first), pathComponents.count >= 2 {
            return pathComponents[1]
        }
        return components.queryItems?.first(where: { $0.name == "v" })?.value
    }
    return nil
}

nonisolated func canonicalVideoIdentity(url: String) -> String {
    if let youtubeID = extractYouTubeVideoID(from: url) {
        return "youtube:\(youtubeID)"
    }
    return "url:\(url.trimmingCharacters(in: .whitespacesAndNewlines))"
}

nonisolated func canonicalVideoMergeKey(kind: String?, url: String) -> String {
    let normalizedKind = kind?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    return "\(normalizedKind)::\(canonicalVideoIdentity(url: url))"
}
