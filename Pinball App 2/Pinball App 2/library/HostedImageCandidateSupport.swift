import Foundation

private enum HostedImageCandidatePriority: Int {
    case pinProf1400 = 0
    case pinProf700 = 1
    case pinProfOriginal = 2
    case opdbOrExternal = 3
    case other = 4
}

func prioritizeHostedImageCandidates(_ candidates: [URL]) -> [URL] {
    candidates.sorted { lhs, rhs in
        let lhsPriority = hostedImageCandidatePriority(lhs)
        let rhsPriority = hostedImageCandidatePriority(rhs)
        if lhsPriority != rhsPriority {
            return lhsPriority.rawValue < rhsPriority.rawValue
        }
        return lhs.absoluteString < rhs.absoluteString
    }
}

func hostedImageLoadTimeout(for url: URL) -> TimeInterval? {
    switch hostedImageCandidatePriority(url) {
    case .pinProf1400:
        return 3.0
    case .pinProf700:
        return 2.0
    case .pinProfOriginal:
        return 5.0
    case .opdbOrExternal:
        return 6.0
    case .other:
        return 6.0
    }
}

private func hostedImageCandidatePriority(_ url: URL) -> HostedImageCandidatePriority {
    let lowercasedPath = url.path.lowercased()
    if lowercasedPath.contains("/pinball/images/playfields/") {
        if lowercasedPath.contains("_1400.") {
            return .pinProf1400
        }
        if lowercasedPath.contains("_700.") {
            return .pinProf700
        }
        return .pinProfOriginal
    }

    let host = url.host?.lowercased() ?? ""
    if host.contains("opdb.org") || !host.isEmpty {
        return .opdbOrExternal
    }

    return .other
}
