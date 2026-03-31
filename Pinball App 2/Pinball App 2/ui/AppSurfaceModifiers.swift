import SwiftUI

struct AppBackground: View {
    var body: some View {
        let atmosphere = AppTheme.atmosphere
        ZStack {
            LinearGradient(
                colors: [AppTheme.atmosphereTop, AppTheme.bg, AppTheme.atmosphereBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [AppTheme.atmosphereGlow.opacity(atmosphere.primaryGlowOpacity), .clear],
                center: .topLeading,
                startRadius: 18,
                endRadius: 360
            )
            RadialGradient(
                colors: [AppTheme.brandChalk.opacity(atmosphere.secondaryGlowOpacity), .clear],
                center: .bottomTrailing,
                startRadius: 12,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func appReadableWidth(maxWidth: CGFloat?) -> some View {
        self
            .frame(maxWidth: maxWidth ?? .infinity)
            .frame(maxWidth: .infinity)
    }

    func appPanelStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppRadii.panel, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [AppTheme.brandChalk.opacity(0.06), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.panel)
                    .stroke(AppTheme.brandChalk.opacity(0.26), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.panel, style: .continuous))
    }

    func appEmbeddedListStyle() -> some View {
        self
            .listStyle(.plain)
            .listSectionSpacing(0)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .contentMargins(.vertical, 0, for: .scrollIndicators)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 1)
            .environment(\.defaultMinListHeaderHeight, 1)
    }

    func appControlStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                    .fill(AppTheme.controlBg)
                    .overlay(
                        LinearGradient(
                            colors: [AppTheme.brandGold.opacity(0.05), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.control)
                    .stroke(AppTheme.brandGold.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous))
    }

    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            },
            including: .gesture
        )
    }
}
