import SwiftUI

struct SettingsHomeHostedDataSection: View {
    let isRefreshingHostedData: Bool
    let isClearingCache: Bool
    let hostedRefreshStatus: SettingsSectionStatusContent?
    let cacheStatus: SettingsSectionStatusContent?
    let onRefreshHostedData: () -> Void
    let onClearCache: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Pinball Data")

            Text("Refresh Pinball Data force-fetches the hosted OPDB export, CAF asset indexes, league files, and redacted players list from pillyliu.com.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: onRefreshHostedData) {
                Text(isRefreshingHostedData ? "Refreshing Pinball Data…" : "Refresh Pinball Data")
            }
            .buttonStyle(AppPrimaryActionButtonStyle())
            .disabled(isRefreshingHostedData || isClearingCache)

            if let hostedRefreshStatus {
                SettingsSectionInlineStatus(status: hostedRefreshStatus)
            }

            AppTableRowDivider()

            Text("Clear Cache removes downloaded pinball data, cached images, and cached remote rulesheets. It does not remove settings, practice history, or GameRoom data.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive, action: onClearCache) {
                Text(isClearingCache ? "Clearing Cache…" : "Clear Cache")
            }
            .buttonStyle(AppSecondaryActionButtonStyle())
            .disabled(isRefreshingHostedData || isClearingCache)

            if let cacheStatus {
                SettingsSectionInlineStatus(status: cacheStatus)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }
}
