import SwiftUI

struct AppIntroOverlay: View {
    static let currentVersion = 1

    let onDismiss: () -> Void

    @State private var selectedIndex = 0

    private let cards = AppIntroCard.allCases
    private var showsDismissButton: Bool { selectedIndex == cards.count - 1 }
    private var bottomAccessoryHeight: CGFloat { showsDismissButton ? 88 : 26 }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let horizontalPadding: CGFloat = isLandscape ? 28 : 22
            let verticalPadding: CGFloat = isLandscape ? 18 : 20
            let cardMaxWidth = min(proxy.size.width - (horizontalPadding * 2), isLandscape ? 960 : 460)

            ZStack {
                AppIntroBackdrop()

                TabView(selection: $selectedIndex) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        AppIntroDeckPage(
                            card: card,
                            isLandscape: isLandscape,
                            bottomAccessoryHeight: bottomAccessoryHeight
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: cardMaxWidth)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    VStack(spacing: 12) {
                        AppIntroPageIndicators(
                            count: cards.count,
                            selectedIndex: selectedIndex
                        )

                        if showsDismissButton {
                            Button("Start Exploring") {
                                withAnimation(.easeOut(duration: 0.26)) {
                                    onDismiss()
                                }
                            }
                            .buttonStyle(AppPrimaryActionButtonStyle(fillsWidth: true))
                        }
                    }
                    .frame(maxWidth: cardMaxWidth)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, isLandscape ? 8 : 14)
                }
            }
        }
        .transition(.opacity)
    }
}

#Preview("Intro Overlay") {
    ZStack {
        AppBackground()
        AppIntroOverlay(onDismiss: {})
    }
}
