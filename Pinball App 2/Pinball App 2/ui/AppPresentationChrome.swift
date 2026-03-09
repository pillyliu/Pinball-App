import SwiftUI

extension View {
    func appSheetChrome(
        detents: Set<PresentationDetent> = [.medium, .large]
    ) -> some View {
        appSheetChrome(
            detents: detents,
            background: LinearGradient(
                colors: [
                    AppTheme.atmosphereTop.opacity(0.88),
                    AppTheme.atmosphereBottom.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    func appSheetChrome<S: ShapeStyle>(
        detents: Set<PresentationDetent> = [.medium, .large],
        background: S
    ) -> some View {
        presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(AppRadii.panel)
            .presentationBackground(background)
            .dismissKeyboardOnTap()
    }
}
