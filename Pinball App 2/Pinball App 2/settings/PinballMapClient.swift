import Foundation

enum PinballMapClient {
    private static let decoder = JSONDecoder()

    static func searchVenues(query: String, radiusMiles: Int) async throws -> [PinballLibraryVenueSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://pinballmap.com/api/v1/locations/closest_by_address.json")
        components?.queryItems = [
            URLQueryItem(name: "address", value: trimmed),
            URLQueryItem(name: "max_distance", value: String(radiusMiles)),
            URLQueryItem(name: "send_all_within_distance", value: "true"),
        ]
        return try await fetchVenues(components: components)
    }

    static func searchVenues(latitude: Double, longitude: Double, radiusMiles: Int) async throws -> [PinballLibraryVenueSearchResult] {
        var components = URLComponents(string: "https://pinballmap.com/api/v1/locations/closest_by_lat_lon.json")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "max_distance", value: String(radiusMiles)),
            URLQueryItem(name: "send_all_within_distance", value: "true"),
        ]
        return try await fetchVenues(components: components)
    }

    private static func fetchVenues(components: URLComponents?) async throws -> [PinballLibraryVenueSearchResult] {
        guard let url = components?.url else { return [] }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode) {
            throw PinballMapClientError.http(statusCode: httpResponse.statusCode)
        }
        let payload = try decoder.decode(VenueSearchResponse.self, from: data)
        return payload.locations.map { location in
            PinballLibraryVenueSearchResult(
                id: "venue--pm-\(location.id)",
                name: location.name,
                city: location.city,
                state: location.state,
                zip: location.zip,
                distanceMiles: location.distance,
                machineCount: location.machineCount ?? location.numMachines ?? 0
            )
        }
    }

    static func fetchVenueMachineIDs(locationID: String) async throws -> [String] {
        let trimmed = locationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let url = URL(string: "https://pinballmap.com/api/v1/locations/\(trimmed)/machine_details.json") else {
            return []
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode) {
            throw PinballMapClientError.http(statusCode: httpResponse.statusCode)
        }
        let payload = try decoder.decode(VenueMachinesResponse.self, from: data)
        return Array(
            NSOrderedSet(
                array: payload.machines.compactMap { machine in
                    let trimmed = machine.opdbID?.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let trimmed, !trimmed.isEmpty else { return nil }
                    return trimmed
                }
            )
        ).compactMap { $0 as? String }
    }
}

private enum PinballMapClientError: LocalizedError {
    case http(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .http(let statusCode):
            if statusCode == 404 {
                return "Pinball Map location not found."
            }
            return "Pinball Map request failed (\(statusCode))."
        }
    }
}

private struct VenueSearchResponse: Decodable {
    let locations: [VenueLocation]
}

private struct VenueLocation: Decodable {
    let id: Int
    let name: String
    let city: String?
    let state: String?
    let zip: String?
    let distance: Double?
    let machineCount: Int?
    let numMachines: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case city
        case state
        case zip
        case distance
        case machineCount = "machine_count"
        case numMachines = "num_machines"
    }
}

private struct VenueMachinesResponse: Decodable {
    let machines: [VenueMachine]
}

private struct VenueMachine: Decodable {
    let opdbID: String?

    enum CodingKeys: String, CodingKey {
        case opdbID = "opdb_id"
    }
}
