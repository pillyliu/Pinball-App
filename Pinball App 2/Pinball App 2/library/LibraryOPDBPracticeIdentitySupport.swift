import Foundation

private let syntheticPinProfLabsGroupID = "G900001"
private let syntheticPinProfLabsMachineID = "G900001-1"
private let syntheticPinProfLabsManufacturerID = "manufacturer-9001"
private let syntheticPinProfLabsBackglassPath = "/pinball/images/backglasses/G900001-1-backglass.webp"
private let syntheticPinProfLabsPlayfieldPath = "/pinball/images/playfields/G900001-1-playfield.webp"

private func syntheticPinProfLabsCatalogMachineRecord() -> CatalogMachineRecord {
    CatalogMachineRecord(
        practiceIdentity: syntheticPinProfLabsGroupID,
        opdbMachineID: syntheticPinProfLabsMachineID,
        opdbGroupID: syntheticPinProfLabsGroupID,
        slug: "pinprof",
        name: "PinProf: The Final Exam",
        variant: nil,
        manufacturerID: syntheticPinProfLabsManufacturerID,
        manufacturerName: "PinProf Labs",
        year: 1982,
        opdbName: "PinProf: The Final Exam",
        opdbCommonName: "PinProf: The Final Exam",
        opdbShortname: "PinProf",
        opdbDescription: "A long-lost pinball treasure.",
        opdbType: "ss",
        opdbDisplay: "alphanumeric",
        opdbPlayerCount: 4,
        opdbManufactureDate: "1982-09-03",
        opdbIpdbID: nil,
        opdbGroupShortname: "PinProf",
        opdbGroupDescription: "A long-lost pinball treasure.",
        primaryImage: CatalogMachineRecord.RemoteImageSet(
            mediumURL: syntheticPinProfLabsBackglassPath,
            largeURL: syntheticPinProfLabsBackglassPath
        ),
        playfieldImage: CatalogMachineRecord.RemoteImageSet(
            mediumURL: syntheticPinProfLabsPlayfieldPath,
            largeURL: syntheticPinProfLabsPlayfieldPath
        )
    )
}

func appendingSyntheticPinProfLabsMachine(to machines: [CatalogMachineRecord]) -> [CatalogMachineRecord] {
    let normalizedSyntheticMachineID = syntheticPinProfLabsMachineID.lowercased()
    let normalizedSyntheticGroupID = syntheticPinProfLabsGroupID.lowercased()
    guard !machines.contains(where: { machine in
        machine.opdbMachineID?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedSyntheticMachineID ||
            machine.practiceIdentity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedSyntheticGroupID
    }) else {
        return machines
    }
    return machines + [syntheticPinProfLabsCatalogMachineRecord()]
}

nonisolated func opdbGroupID(from opdbID: String?) -> String? {
    guard let trimmed = catalogNormalizedOptionalString(opdbID),
          trimmed.hasPrefix("G") else {
        return nil
    }
    guard let dashIndex = trimmed.firstIndex(of: "-") else {
        return trimmed
    }
    let group = String(trimmed[..<dashIndex])
    return group.isEmpty ? nil : group
}

private struct PracticeIdentityCurationsRoot: Decodable {
    let splits: [PracticeIdentityCurationsSplit]?
}

private struct PracticeIdentityCurationsSplit: Decodable {
    let practiceEntries: [PracticeIdentityCurationsEntry]?
}

private struct PracticeIdentityCurationsEntry: Decodable {
    let practiceIdentity: String?
    let memberOpdbIds: [String]?
}

struct PracticeIdentityCurations {
    let practiceIdentityByOpdbID: [String: String]

    static let empty = PracticeIdentityCurations(practiceIdentityByOpdbID: [:])
}

func decodePracticeIdentityCurations(data: Data?) -> PracticeIdentityCurations {
    guard let data,
          !data.isEmpty,
          let root = try? JSONDecoder().decode(PracticeIdentityCurationsRoot.self, from: data) else {
        return .empty
    }

    var resolved: [String: String] = [:]
    for split in root.splits ?? [] {
        for entry in split.practiceEntries ?? [] {
            guard let practiceIdentity = catalogNormalizedOptionalString(entry.practiceIdentity) else { continue }
            for memberID in entry.memberOpdbIds ?? [] {
                guard let opdbID = catalogNormalizedOptionalString(memberID) else { continue }
                resolved[opdbID] = practiceIdentity
            }
        }
    }
    return PracticeIdentityCurations(practiceIdentityByOpdbID: resolved)
}

func resolvePracticeIdentity(opdbID: String?, curations: PracticeIdentityCurations) -> String? {
    guard let normalized = catalogNormalizedOptionalString(opdbID) else { return nil }
    return curations.practiceIdentityByOpdbID[normalized] ?? opdbGroupID(from: normalized) ?? normalized
}
