import SwiftUI

struct AppScreen<Content: View>: View {
    let dismissesKeyboardOnTap: Bool
    @ViewBuilder let content: () -> Content

    init(
        dismissesKeyboardOnTap: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.dismissesKeyboardOnTap = dismissesKeyboardOnTap
        self.content = content
    }

    var body: some View {
        let screen = ZStack(alignment: .topLeading) {
            AppBackground()
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }

        if dismissesKeyboardOnTap {
            screen.dismissKeyboardOnTap()
        } else {
            screen
        }
    }
}

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

    @ViewBuilder
    func appCardZoomTransition<ID: Hashable>(
        sourceID: ID?,
        in namespace: Namespace.ID,
        reduceMotion: Bool
    ) -> some View {
        if reduceMotion {
            self
        } else if let sourceID {
            navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}
