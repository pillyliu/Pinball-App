import Foundation

private enum HostedImageCandidatePriority: Int {
    case pinProf = 0
    case opdbOrExternal = 1
    case other = 2
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
    case .pinProf:
        return 5.0
    case .opdbOrExternal:
        return 6.0
    case .other:
        return 6.0
    }
}

private func hostedImageCandidatePriority(_ url: URL) -> HostedImageCandidatePriority {
    if libraryIsPinProfPlayfieldURL(url) {
        return .pinProf
    }

    let host = url.host?.lowercased() ?? ""
    if host.contains("opdb.org") || !host.isEmpty {
        return .opdbOrExternal
    }

    return .other
}
