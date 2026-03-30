import SwiftUI
import CoreLocation

struct SettingsImportStatusContent {
    let text: String
    var showsProgress = false
    var isError = false
}

struct SettingsVenueSearchControlsCard: View {
    @Binding var query: String
    @Binding var radiusMiles: Int
    @Binding var minimumGameCount: Int
    let isSearching: Bool
    let isLocating: Bool
    let status: SettingsImportStatusContent?
    let onSearch: () -> Void
    let onUseCurrentLocation: () -> Void

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSearch: Bool {
        !isSearching && !isLocating && !trimmedQuery.isEmpty
    }

    private var searchButtonTitle: String {
        isSearching ? "Searching..." : "Search Pinball Map"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsProviderCaption(prefix: "Search powered by ", linkText: "Pinball Map", urlString: "https://www.pinballmap.com")

            HStack(alignment: .center, spacing: 8) {
                AppNativeClearTextField(
                    placeholder: "City or ZIP code",
                    text: $query,
                    submitLabel: .search,
                    onSubmit: onSearch
                )
                .frame(maxWidth: .infinity)

                Button(action: onUseCurrentLocation) {
                    Group {
                        if isLocating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "scope")
                                .font(.title3)
                        }
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(AppCompactIconActionButtonStyle())
                .disabled(isSearching || isLocating)
                .accessibilityLabel("Use current location")
            }

            Menu {
                ForEach([10, 25, 50, 100], id: \.self) { miles in
                    Button {
                        radiusMiles = miles
                    } label: {
                        AppSelectableMenuRow(
                            text: "\(miles) miles",
                            isSelected: radiusMiles == miles
                        )
                    }
                }
            } label: {
                AppCompactStackedMenuLabel(
                    title: "Distance",
                    value: "\(radiusMiles) miles"
                )
            }
            .buttonStyle(.plain)

            Stepper(value: $minimumGameCount, in: 0 ... 50) {
                HStack {
                    AppCardSubheading(text: "Minimum games")
                    Spacer()
                    Text(minimumGameCount == 0 ? "Any" : "\(minimumGameCount)")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .appControlStyle()

            Button(searchButtonTitle, action: onSearch)
                .buttonStyle(AppPrimaryActionButtonStyle())
                .disabled(!canSearch)

            if let status {
                AppInlineTaskStatus(
                    text: status.text,
                    showsProgress: status.showsProgress,
                    isError: status.isError
                )
            }
        }
        .padding(12)
        .appPanelStyle()
    }
}

struct SettingsVenueSearchResultsPanel: View {
    let results: [PinballLibraryVenueSearchResult]
    let subtitle: (PinballLibraryVenueSearchResult) -> String
    let onImport: (PinballLibraryVenueSearchResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppCardSubheading(text: "Results")

            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, venue in
                    Button {
                        onImport(venue)
                    } label: {
                        SettingsImportResultRow(
                            title: venue.name,
                            subtitle: subtitle(venue),
                            accessorySystemName: "plus.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    if index < results.count - 1 {
                        AppTableRowDivider()
                    }
                }
            }
        }
        .padding(12)
        .appPanelStyle()
    }
}

enum VenueLocationError: LocalizedError {
    case servicesDisabled
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            return "Turn on Location Services to search near you."
        case .permissionDenied:
            return "Location permission is required to search near you."
        case .unavailable:
            return "Couldn't get your current location."
        }
    }
}

@MainActor
final class VenueLocationRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var isAwaitingAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestCurrentLocation() async throws -> CLLocationCoordinate2D {
        guard continuation == nil else {
            throw VenueLocationError.unavailable
        }
        guard CLLocationManager.locationServicesEnabled() else {
            throw VenueLocationError.servicesDisabled
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .notDetermined:
                isAwaitingAuthorization = true
                manager.requestWhenInUseAuthorization()
            case .restricted, .denied:
                finish(with: VenueLocationError.permissionDenied)
            @unknown default:
                finish(with: VenueLocationError.unavailable)
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isAwaitingAuthorization else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isAwaitingAuthorization = false
            manager.requestLocation()
        case .restricted, .denied:
            finish(with: VenueLocationError.permissionDenied)
        case .notDetermined:
            break
        @unknown default:
            finish(with: VenueLocationError.unavailable)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            finish(with: VenueLocationError.unavailable)
            return
        }
        finish(with: coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let locationError = error as? CLError, locationError.code == .denied {
            finish(with: VenueLocationError.permissionDenied)
        } else {
            finish(with: VenueLocationError.unavailable)
        }
    }

    private func finish(with coordinate: CLLocationCoordinate2D) {
        continuation?.resume(returning: coordinate)
        continuation = nil
        isAwaitingAuthorization = false
    }

    private func finish(with error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        isAwaitingAuthorization = false
    }
}
