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
        guard let url = components?.url else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
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

        let (data, _) = try await URLSession.shared.data(from: url)
        let payload = try decoder.decode(VenueMachinesResponse.self, from: data)
        return payload.machines.compactMap { machine in
            machine.opdbID?.trimmingCharacters(in: .whitespacesAndNewlines)
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
