import SwiftUI

struct SettingsHomePrivacySection: View {
    @Binding var lplFullNameAccessUnlocked: Bool
    @Binding var showFullLPLLastNames: Bool
    @Binding var lplNamePassword: String
    @Binding var lplNamePrivacyError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Privacy")

            Text("Lansing Pinball League names are shown as first name plus last initial by default.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if lplFullNameAccessUnlocked {
                Toggle(isOn: $showFullLPLLastNames) {
                    Text("Show full last names for LPL data")
                        .font(.footnote)
                }
            } else {
                SecureField("LPL full-name password", text: $lplNamePassword)
                    .textContentType(.password)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appControlStyle()

                Button("Unlock Full Names", action: unlockFullNames)
                    .buttonStyle(AppPrimaryActionButtonStyle())
                    .disabled(lplNamePassword.isEmpty)

                if let lplNamePrivacyError {
                    Text(lplNamePrivacyError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func unlockFullNames() {
        if unlockLPLFullNameAccess(with: lplNamePassword) {
            lplFullNameAccessUnlocked = true
            lplNamePassword = ""
            lplNamePrivacyError = nil
        } else {
            lplNamePrivacyError = "Incorrect password."
        }
    }
}

struct SettingsHomeAboutSection: View {
    let onToggleIntroOverlayForNextLaunch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "About")
            aboutLogo
            Text(aboutAttributionText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var aboutAttributionText: AttributedString {
        let markdown = """
        PinProf is built on [OPDB](https://opdb.org/) (Open Pinball Database) to provide machine and manufacturer data. Venue search is powered by [Pinball Map](https://www.pinballmap.com). Rulesheets are sourced from [Tiltforums](https://tiltforums.com/), [Bob's Guide](https://rules.silverballmania.com/), [Pinball Primer](https://pinballprimer.github.io/), and [PAPA](https://replayfoundation.org/papa/learning-center/player-guide/rule-sheets/). Playfield images were manually sourced or provided by OPDB. Videos are manually sourced as well as curated from [Matchplay](https://matchplay.events/).
        """
        return (try? AttributedString(markdown: markdown)) ?? AttributedString("PinProf is built on OPDB (Open Pinball Database) to provide machine and manufacturer data. Rulesheets are sourced from Tiltforums, Bob's Guide, Pinball Primer, and PAPA. Playfield images were manually sourced or provided by OPDB. Videos are manually sourced as well as curated from Matchplay.")
    }

    private var aboutLogo: some View {
        Group {
            if let image = AppIntroBundledArtProvider.image(named: AppIntroCard.welcome.bundledArtworkFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: 150, height: 150)
        .frame(maxWidth: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onToggleIntroOverlayForNextLaunch)
    }
}
