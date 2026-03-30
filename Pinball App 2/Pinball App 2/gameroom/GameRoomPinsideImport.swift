import Foundation

actor GameRoomPinsideImportService {
    private var cachedGroupMap: [String: String]?

    func fetchCollectionMachines(sourceInput: String) async throws -> (sourceURL: String, machines: [PinsideImportedMachine]) {
        let normalizedInput = sourceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedInput.isEmpty else {
            throw GameRoomPinsideImportError.invalidInput
        }

        let sourceURL = try buildCollectionURL(from: normalizedInput)
        let groupMap = try await loadGroupMap()

        do {
            let html = try await fetchHTML(url: sourceURL)
            let directMachines = try parseBasicPinsideMachines(from: html, groupMap: groupMap)
            if let enrichedMachines = try? await fetchDetailedOrBasicMachinesFromJina(sourceURL: sourceURL, groupMap: groupMap),
               !enrichedMachines.isEmpty {
                return (sourceURL.absoluteString, mergePinsideImportedMachines(primary: enrichedMachines, fallback: directMachines))
            }
            return (sourceURL.absoluteString, directMachines)
        } catch {
            guard !isFatalImportError(error) else { throw error }
            let fallbackMachines = try await fetchDetailedOrBasicMachinesFromJina(sourceURL: sourceURL, groupMap: groupMap)
            guard !fallbackMachines.isEmpty else {
                throw GameRoomPinsideImportError.noMachinesFound
            }
            return (sourceURL.absoluteString, fallbackMachines)
        }
    }

    private func loadGroupMap() async throws -> [String: String] {
        if let cachedGroupMap {
            return cachedGroupMap
        }

        let decoded = loadBundledPinsideGroupMap()
        cachedGroupMap = decoded
        return decoded
    }
}
