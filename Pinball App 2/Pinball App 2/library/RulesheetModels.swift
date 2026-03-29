import Foundation

struct RulesheetRenderContent: Equatable {
    enum Kind: String, Equatable {
        case markdown
        case html
    }

    let kind: Kind
    let body: String
    let baseURL: URL?
}

nonisolated struct RulesheetRemoteSource: Identifiable, Hashable {
    nonisolated enum Provider: String, Hashable {
        case tiltForums
        case pinballPrimer
        case papa
        case bob

        var sourceName: String {
            switch self {
            case .tiltForums:
                return "Tilt Forums community rulesheet"
            case .pinballPrimer:
                return "Pinball Primer"
            case .papa:
                return "PAPA / pinball.org rulesheet archive"
            case .bob:
                return "Silverball Rules (Bob Matthews source)"
            }
        }

        var originalLinkLabel: String {
            switch self {
            case .tiltForums:
                return "Original thread"
            default:
                return "Original page"
            }
        }

        var detailsText: String {
            switch self {
            case .tiltForums:
                return "License/source terms remain with Tilt Forums and the original authors."
            case .pinballPrimer, .papa, .bob:
                return "Preserve source attribution and any author/site rights notes from the original page."
            }
        }
    }

    let label: String
    let url: URL
    let provider: Provider

    var id: String { url.absoluteString }

    var webFallbackURL: URL? {
        switch provider {
        case .tiltForums:
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let currentPath = components?.path ?? url.path
            if currentPath.lowercased().hasSuffix(".json") {
                components?.path = currentPath.replacingOccurrences(of: ".json", with: "")
            }
            components?.query = nil
            return components?.url ?? url
        case .pinballPrimer, .papa, .bob:
            return url
        }
    }
}

extension PinballGame.ReferenceLink {
    nonisolated var embeddedRulesheetSource: RulesheetRemoteSource? {
        guard let destinationURL else { return nil }
        guard let provider = RulesheetRemoteSource.Provider(url: destinationURL, label: label) else {
            return nil
        }
        return RulesheetRemoteSource(label: label, url: destinationURL, provider: provider)
    }
}

extension PinballGame {
    nonisolated var preferredExternalRulesheetSource: RulesheetRemoteSource? {
        displayedRulesheetLinks.compactMap(\.embeddedRulesheetSource).first
    }
}

extension RulesheetRemoteSource.Provider {
    nonisolated init?(url: URL, label: String) {
        let host = url.host?.lowercased() ?? ""
        let normalizedLabel = label.lowercased()

        if host.contains("pinballnews.com") {
            return nil
        }
        if host.contains("tiltforums.com") {
            self = .tiltForums
            return
        }
        if host.contains("pinballprimer.github.io") || host.contains("pinballprimer.com") {
            self = .pinballPrimer
            return
        }
        if host.contains("pinball.org") {
            self = .papa
            return
        }
        if host.contains("flippers.be") || host.contains("bobs") || host.contains("silverballmania.com") {
            self = .bob
            return
        }
        if normalizedLabel.contains("(tf)") {
            self = .tiltForums
            return
        }
        if normalizedLabel.contains("(pp)") {
            self = .pinballPrimer
            return
        }
        if normalizedLabel.contains("(papa)") {
            self = .papa
            return
        }
        if normalizedLabel.contains("(bob)") {
            self = .bob
            return
        }
        return nil
    }
}
