import SwiftUI

extension View {
    func appSheetChrome(
        detents: Set<PresentationDetent> = [.medium, .large]
    ) -> some View {
        appSheetChrome(detents: detents, background: Color.clear)
    }

    func appSheetChrome<S: ShapeStyle>(
        detents: Set<PresentationDetent> = [.medium, .large],
        background: S
    ) -> some View {
        presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationBackground(background)
            .dismissKeyboardOnTap()
    }
}
