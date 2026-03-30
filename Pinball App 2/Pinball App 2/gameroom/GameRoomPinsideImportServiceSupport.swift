import Foundation

extension GameRoomPinsideImportService {
    func buildCollectionURL(from input: String) throws -> URL {
        if input.contains("pinside.com") {
            guard let url = URL(string: input), let host = url.host?.lowercased(), host.contains("pinside.com") else {
                throw GameRoomPinsideImportError.invalidURL
            }
            return url
        }

        let username = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
        guard !username.isEmpty else {
            throw GameRoomPinsideImportError.invalidInput
        }

        guard let url = URL(string: "https://pinside.com/pinball/community/pinsiders/\(username)/collection/current") else {
            throw GameRoomPinsideImportError.invalidURL
        }
        return url
    }

    func fetchHTML(url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if http.statusCode == 404 {
                throw GameRoomPinsideImportError.userNotFound
            }
            throw GameRoomPinsideImportError.httpError(http.statusCode)
        }
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .unicode) else {
            throw URLError(.cannotDecodeRawData)
        }
        return html
    }

    func fetchHTMLFromJina(sourceURL: URL) async throws -> String {
        let normalizedTarget = sourceURL.absoluteString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        guard let proxyURL = URL(string: "https://r.jina.ai/http://\(normalizedTarget)") else {
            throw GameRoomPinsideImportError.invalidURL
        }
        return try await fetchHTML(url: proxyURL)
    }

    func fetchDetailedOrBasicMachinesFromJina(
        sourceURL: URL,
        groupMap: [String: String]
    ) async throws -> [PinsideImportedMachine] {
        let content = try await fetchHTMLFromJina(sourceURL: sourceURL)
        let detailedMachines = parseDetailedPinsideMachines(from: content)
        if !detailedMachines.isEmpty {
            return detailedMachines
        }
        return try parseBasicPinsideMachines(from: content, groupMap: groupMap)
    }

    func isFatalImportError(_ error: Error) -> Bool {
        guard let error = error as? GameRoomPinsideImportError else { return false }
        switch error {
        case .invalidInput, .invalidURL, .userNotFound, .privateOrUnavailableCollection:
            return true
        case .httpError, .parseFailed, .noMachinesFound:
            return false
        }
    }
}
