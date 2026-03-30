import SwiftUI

struct SettingsHomeAppearanceSection: View {
    @AppStorage(AppDisplayMode.defaultsKey) private var displayModeRawValue = AppDisplayMode.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Appearance")

            Text("Choose whether PinProf follows the system appearance or stays in light or dark mode.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(
                "Display Mode",
                selection: Binding(
                    get: { AppDisplayMode(rawValue: displayModeRawValue) ?? .system },
                    set: { displayModeRawValue = $0.rawValue }
                )
            ) {
                ForEach(AppDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .appSegmentedControlStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }
}
