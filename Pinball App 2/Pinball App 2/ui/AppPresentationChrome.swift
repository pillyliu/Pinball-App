import SwiftUI

extension View {
    func appSheetChrome(
        detents: Set<PresentationDetent> = [.medium, .large],
        dismissesKeyboardOnTap: Bool = true
    ) -> some View {
        appSheetChrome(
            detents: detents,
            dismissesKeyboardOnTap: dismissesKeyboardOnTap,
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

    @ViewBuilder
    func appSheetChrome<S: ShapeStyle>(
        detents: Set<PresentationDetent> = [.medium, .large],
        dismissesKeyboardOnTap: Bool = true,
        background: S
    ) -> some View {
        let chrome = presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(AppRadii.panel)
            .presentationBackground(background)

        if dismissesKeyboardOnTap {
            chrome.dismissKeyboardOnTap()
        } else {
            chrome
        }
    }
}
