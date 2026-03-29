import Foundation

enum LibraryRulesheetSourceKind: Int {
    case local = 0
    case tf = 1
    case prof = 2
    case bob = 3
    case papa = 4
    case pp = 5
    case opdb = 6
    case other = 7

    nonisolated var shortTitle: String {
        switch self {
        case .local:
            return "Local"
        case .prof:
            return "PinProf"
        case .bob:
            return "Bob"
        case .papa:
            return "PAPA"
        case .pp:
            return "PP"
        case .tf:
            return "TF"
        case .opdb:
            return "OPDB"
        case .other:
            return "Other"
        }
    }
}

nonisolated func libraryIsPinProfRulesheetURL(_ url: URL?) -> Bool {
    guard let url,
          libraryIsPinProfHost(url.host) else {
        return false
    }
    return url.path.hasPrefix("/pinball/rulesheets/")
}

nonisolated func normalizedRulesheetMarkdownPath(_ pathOrURL: String?) -> String? {
    guard let raw = pathOrURL?.trimmingCharacters(in: .whitespacesAndNewlines),
          !raw.isEmpty,
          let resolved = libraryResolveURL(pathOrURL: raw)?.path.lowercased(),
          !resolved.isEmpty else {
        return nil
    }
    return resolved
}

nonisolated func libraryIsLikelyPinProfMarkdownRulesheetURL(_ url: URL?) -> Bool {
    guard let raw = url?.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines),
          !raw.isEmpty else {
        return false
    }
    let normalizedRaw = raw.lowercased()
    if normalizedRaw.hasSuffix("-rulesheet.md") ||
        normalizedRaw.contains("/pinball/rulesheets/") ||
        (normalizedRaw.contains("/rules/") && normalizedRaw.contains("source=local")) {
        return true
    }
    guard let resolvedPath = normalizedRulesheetMarkdownPath(raw) else {
        return false
    }
    return resolvedPath.hasPrefix("/pinball/rulesheets/") ||
        resolvedPath.hasSuffix("-rulesheet.md") ||
        (resolvedPath.hasPrefix("/rules/") && normalizedRaw.contains("source=local"))
}

extension PinballGame.ReferenceLink {
    nonisolated var rulesheetSourceKind: LibraryRulesheetSourceKind {
        let normalizedLabel = label.lowercased()
        let resolvedURL = libraryResolveURL(pathOrURL: url)

        if libraryIsPinProfRulesheetURL(resolvedURL) || normalizedLabel.contains("(prof)") {
            return .prof
        }
        if resolvedURL?.host?.lowercased().contains("tiltforums.com") == true || normalizedLabel.contains("(tf)") {
            return .tf
        }
        if resolvedURL?.host?.lowercased().contains("pinballprimer.github.io") == true
            || resolvedURL?.host?.lowercased().contains("pinballprimer.com") == true
            || normalizedLabel.contains("(pp)") {
            return .pp
        }
        if resolvedURL?.host?.lowercased().contains("pinball.org") == true
            || resolvedURL?.host?.lowercased().contains("replayfoundation.org") == true
            || normalizedLabel.contains("(papa)") {
            return .papa
        }
        if resolvedURL?.host?.lowercased().contains("silverballmania.com") == true
            || resolvedURL?.host?.lowercased().contains("flippers.be") == true
            || normalizedLabel.contains("(bob)") {
            return .bob
        }
        if normalizedLabel.contains("(opdb)") {
            return .opdb
        }
        if normalizedLabel.contains("(local)") || normalizedLabel.contains("(source)") {
            return .local
        }
        if resolvedURL == nil && embeddedRulesheetSource == nil {
            return .local
        }
        return .other
    }

    nonisolated var shortRulesheetTitle: String {
        rulesheetSourceKind.shortTitle
    }

    nonisolated var rulesheetSortKey: (Int, String, String) {
        (
            rulesheetSourceKind.rawValue,
            label.lowercased(),
            (libraryResolveURL(pathOrURL: url)?.absoluteString ?? url).lowercased()
        )
    }
}
