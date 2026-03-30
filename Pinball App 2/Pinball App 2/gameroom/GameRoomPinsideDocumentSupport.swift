import Foundation

nonisolated func parseDetailedPinsideMachines(from content: String) -> [PinsideImportedMachine] {
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

        let parsedTitle = parsePinsideDisplayedTitle(rawDisplayTitle, fallbackVariant: pinsideVariantFromSlug(slug))
        machines.append(
            PinsideImportedMachine(
                id: slug,
                slug: slug,
                rawTitle: parsedTitle.title,
                rawVariant: parsedTitle.variant,
                manufacturerLabel: manufacturerLabel.isEmpty ? nil : manufacturerLabel,
                manufactureYear: manufactureYear,
                rawPurchaseDateText: purchaseText,
                normalizedPurchaseDate: normalizedPinsideFirstOfMonth(from: purchaseText)
            )
        )
        index = scanIndex
    }

    return machines
}

nonisolated func mergePinsideImportedMachines(
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

nonisolated private func normalizedPinsideFirstOfMonth(from raw: String?) -> Date? {
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
