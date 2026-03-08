import SwiftUI

@ViewBuilder
func settingsRouteDestination(
    route: SettingsRoute,
    viewModel: SettingsViewModel
) -> some View {
    switch route {
    case .addManufacturer:
        AddManufacturerScreen(viewModel: viewModel)
    case .addVenue:
        AddVenueScreen(viewModel: viewModel)
    case .addTournament:
        AddTournamentScreen(viewModel: viewModel)
    }
}
