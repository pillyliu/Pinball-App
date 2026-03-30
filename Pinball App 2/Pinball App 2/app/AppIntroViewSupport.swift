import SwiftUI

struct AppIntroDeckPage: View {
    let card: AppIntroCard
    let isLandscape: Bool
    let bottomAccessoryHeight: CGFloat

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if card == .welcome {
                    Spacer(minLength: 0)
                }

                AppIntroCardView(card: card, isLandscape: isLandscape)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)

                if card == .welcome {
                    Spacer(minLength: 0)
                }
            }
            .frame(
                minHeight: max(0, proxy.size.height - bottomAccessoryHeight - 8),
                maxHeight: .infinity,
                alignment: card == .welcome ? .center : .top
            )
            .padding(.bottom, bottomAccessoryHeight + 12)
        }
    }
}

struct AppIntroBackdrop: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.64)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    AppIntroTheme.tint.opacity(0.82),
                    Color.black.opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [AppIntroTheme.glow.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 340
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [AppTheme.brandGold.opacity(0.14), .clear],
                center: .bottomTrailing,
                startRadius: 24,
                endRadius: 320
            )
            .ignoresSafeArea()
        }
    }
}

struct AppIntroCardView: View {
    let card: AppIntroCard
    let isLandscape: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        Group {
            if isLandscape {
                HStack(alignment: .top, spacing: 18) {
                    AppIntroArtworkFrame(card: card)
                        .frame(width: 322)

                    AppIntroCopyColumn(card: card, isLandscape: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    AppIntroArtworkFrame(card: card)

                    AppIntroCopyColumn(card: card, isLandscape: false)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            shape
                .fill(Color.black.opacity(0.76))
                .overlay(
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppIntroTheme.tint.opacity(0.30),
                                    AppTheme.atmosphereBottom.opacity(0.12),
                                    AppTheme.brandGold.opacity(0.11)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    shape
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.1)
                )
        )
        .shadow(color: AppIntroTheme.tint.opacity(0.32), radius: 24, y: 12)
    }
}

struct AppIntroCopyColumn: View {
    let card: AppIntroCard
    let isLandscape: Bool

    var body: some View {
        VStack(alignment: isLandscape ? .leading : .center, spacing: 2) {
            if let title = card.title {
                Text(title)
                    .font(.appIntroTitle(size: isLandscape ? 24 : 26))
                    .foregroundStyle(AppTheme.brandGold)
                    .multilineTextAlignment(isLandscape ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)
            }

            if let subtitle = card.subtitle {
                Text(subtitle)
                    .font(.appIntroSubtitle(size: isLandscape ? 16 : 17))
                    .foregroundStyle(AppTheme.brandChalk)
                    .multilineTextAlignment(isLandscape ? .leading : .center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AppIntroQuoteRow(
                quote: card.quote,
                highlightedPhrase: card.highlightedQuotePhrase,
                side: card.professorSide,
                centerAligned: !isLandscape,
                showsProfessorSpotlight: card.showsProfessorSpotlight,
                quoteSize: card == .welcome ? 22 : 19
            )
            .padding(.top, card == .welcome ? 6 : 1)
        }
        .frame(maxWidth: .infinity, alignment: isLandscape ? .leading : .center)
    }
}

struct AppIntroQuoteRow: View {
    let quote: String
    let highlightedPhrase: String?
    let side: AppIntroProfessorSide
    let centerAligned: Bool
    let showsProfessorSpotlight: Bool
    let quoteSize: CGFloat

    var body: some View {
        Group {
            if !showsProfessorSpotlight {
                quoteText
            } else if side == .left {
                HStack(alignment: .center, spacing: 12) {
                    AppIntroProfessorSpotlight(side: side)
                    quoteText
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    quoteText
                    AppIntroProfessorSpotlight(side: side)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: centerAligned ? .center : .leading)
    }

    private var quoteText: some View {
        Text(styledQuoteText)
            .multilineTextAlignment(centerAligned ? .center : .leading)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var styledQuoteText: AttributedString {
        let quoteFont = Font.appIntroQuote(size: quoteSize)
        let highlightedFont = Font.appIntroQuoteHighlighted(size: quoteSize)
        let baseColor = AppIntroTheme.secondaryText

        func styledFragment(
            _ text: String,
            font: Font = quoteFont,
            color: Color = baseColor
        ) -> AttributedString {
            var fragment = AttributedString(text)
            fragment.font = font
            fragment.foregroundColor = color
            return fragment
        }

        guard
            let highlightedPhrase,
            let range = quote.range(of: highlightedPhrase)
        else {
            return styledFragment("“\(quote)”")
        }

        var attributed = styledFragment("“")
        attributed += styledFragment(String(quote[..<range.lowerBound]))

        if highlightedPhrase == "PinProf" {
            attributed += styledFragment("Pin", font: highlightedFont)
            attributed += styledFragment("Prof", font: highlightedFont, color: AppTheme.brandGold)
            attributed += styledFragment(String(quote[range.upperBound...]))
            attributed += styledFragment("”")
            return attributed
        }

        attributed += styledFragment(highlightedPhrase, font: highlightedFont)
        attributed += styledFragment(String(quote[range.upperBound...]))
        attributed += styledFragment("”")
        return attributed
    }
}

struct AppIntroPageIndicators: View {
    let count: Int
    let selectedIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == selectedIndex ? AppTheme.brandGold : Color.white.opacity(0.18))
                    .frame(width: index == selectedIndex ? 34 : 18, height: 8)
                    .animation(.easeInOut(duration: 0.18), value: selectedIndex)
            }
        }
    }
}
