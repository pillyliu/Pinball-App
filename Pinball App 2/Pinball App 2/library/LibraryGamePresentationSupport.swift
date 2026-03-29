import Foundation

extension PinballGame {
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

    var manufacturerYearCardLine: String {
        let maker = abbreviatedLibraryCardManufacturer(manufacturer) ?? "-"
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

private func abbreviatedLibraryCardManufacturer(_ manufacturer: String?) -> String? {
    guard let trimmed = manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    switch trimmed.lowercased() {
    case "jersey jack pinball":
        return "JJP"
    case "barrels of fun":
        return "BoF"
    case "chicago gaming company":
        return "CGC"
    default:
        return trimmed
    }
}
