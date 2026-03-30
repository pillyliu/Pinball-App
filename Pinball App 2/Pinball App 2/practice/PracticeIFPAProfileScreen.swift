import SwiftUI
import Foundation

struct PracticeIFPAProfileScreen: View {
    let playerName: String
    let ifpaPlayerID: String

    @State private var profile: IFPAPlayerProfile?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var staleSnapshot: IFPACachedProfileSnapshot?
    @State private var staleSnapshotFailureMessage: String?
    @State private var loadedPlayerID: String = ""

    private var trimmedIFPAPlayerID: String {
        ifpaPlayerID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var staleSnapshotNotice: String? {
        guard let staleSnapshot, let staleSnapshotFailureMessage else { return nil }
        let cachedAtLabel = Self.cachedSnapshotDateFormatter.string(from: staleSnapshot.cachedAt)
        return "Showing your last saved IFPA snapshot from \(cachedAtLabel). It may be outdated because the latest refresh failed. \(staleSnapshotFailureMessage)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if trimmedIFPAPlayerID.isEmpty {
                missingIDCard
            } else if isLoading && profile == nil {
                AppPanelStatusCard(
                    text: "Loading IFPA profile…",
                    showsProgress: true
                )
            } else if let profile {
                profileContent(profile)
            } else if let errorMessage {
                errorCard(errorMessage)
            }
        }
        .task(id: trimmedIFPAPlayerID) {
            await handleProfileTask()
        }
    }

    private static let cachedSnapshotDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var missingIDCard: some View {
        AppPanelEmptyCard(text: "Add your IFPA ID in Practice Settings to load your public ranking snapshot here.")
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Could not load IFPA profile")
            AppInlineTaskStatus(text: message, isError: true)
            retryButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private var retryButton: some View {
        Button("Try Again") {
            Task {
                await reloadProfile()
            }
        }
        .buttonStyle(AppPrimaryActionButtonStyle())
    }

    @ViewBuilder
    private func profileContent(_ profile: IFPAPlayerProfile) -> some View {
        if let staleSnapshotNotice {
            VStack(alignment: .leading, spacing: 8) {
                AppInlineTaskStatus(text: staleSnapshotNotice, isError: true)
                retryButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()
        }

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                AppCardTitle(text: displayName(for: profile))

                AppCardSubheading(text: "IFPA #\(profile.playerID)")

                if let location = profile.location {
                    AppCardSubheading(text: location)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let profilePhotoURL = profile.profilePhotoURL {
                FallbackAsyncImageView(
                    candidates: [profilePhotoURL],
                    emptyMessage: "No image",
                    contentMode: .fill,
                    fillAlignment: .center,
                    layoutMode: .fill
                )
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()

        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            statCard(title: "Rank", value: profile.currentRank)
            statCard(title: "WPPR", value: profile.currentWPPRPoints)
            statCard(title: "Rating", value: profile.rating)
        }

        if profile.lastEventDate != nil || profile.seriesRank != nil {
            VStack(alignment: .leading, spacing: 8) {
                AppSectionTitle(text: "At a Glance")

                if let lastEventDate = profile.lastEventDate {
                    infoRow(label: "Last event", value: lastEventDate)
                }

                if let seriesLabel = profile.seriesLabel, let seriesRank = profile.seriesRank {
                    infoRow(label: seriesLabel, value: seriesRank)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .appPanelStyle()
        }

        VStack(alignment: .leading, spacing: 8) {
            AppSectionTitle(text: "Recent Tournaments")

            if profile.recentTournaments.isEmpty {
                AppPanelEmptyCard(text: "No recent tournament results were found on the public IFPA profile.")
            } else {
                ForEach(profile.recentTournaments) { tournament in
                    VStack(alignment: .leading, spacing: 6) {
                        AppCardSubheading(text: tournament.name)
                        HStack(alignment: .top) {
                            infoColumn(label: "Date", value: tournament.dateLabel)
                            Spacer()
                            infoColumn(label: "Finish", value: tournament.finish)
                            Spacer()
                            infoColumn(label: "Points", value: tournament.pointsGained)
                        }
                    }
                    .padding(.vertical, 4)
                    if tournament.id != profile.recentTournaments.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()

        if let profileURL = URL(string: "https://www.ifpapinball.com/players/view.php?p=\(profile.playerID)") {
            Link(destination: profileURL) {
                AppExternalLinkButtonLabel(text: "Open full IFPA profile")
            }
            .buttonStyle(.plain)
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            AppCardTitle(text: value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .appPanelStyle()
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func infoColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }

    private func displayName(for profile: IFPAPlayerProfile) -> String {
        let trimmedLocalName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLocalName.isEmpty {
            return trimmedLocalName
        }
        return profile.displayName
    }

    private func handleProfileTask() async {
        guard !trimmedIFPAPlayerID.isEmpty else {
            loadedPlayerID = ""
            profile = nil
            errorMessage = nil
            staleSnapshot = nil
            staleSnapshotFailureMessage = nil
            return
        }

        if loadedPlayerID != trimmedIFPAPlayerID {
            loadedPlayerID = trimmedIFPAPlayerID
            errorMessage = nil
            staleSnapshot = nil
            staleSnapshotFailureMessage = nil
            profile = IFPAPublicProfileCacheStore.load(playerID: trimmedIFPAPlayerID)?.profile
        }

        await reloadProfile()
    }

    private func reloadProfile() async {
        guard !trimmedIFPAPlayerID.isEmpty, !isLoading else { return }
        let cachedSnapshot = IFPAPublicProfileCacheStore.load(playerID: trimmedIFPAPlayerID)
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetchedProfile = try await IFPAPublicProfileService.fetchProfile(playerID: trimmedIFPAPlayerID)
            profile = fetchedProfile
            staleSnapshot = nil
            staleSnapshotFailureMessage = nil
            IFPAPublicProfileCacheStore.save(fetchedProfile)
        } catch {
            if let cachedSnapshot {
                profile = cachedSnapshot.profile
                staleSnapshot = cachedSnapshot
                staleSnapshotFailureMessage = error.localizedDescription
                errorMessage = nil
            } else {
                profile = nil
                staleSnapshot = nil
                staleSnapshotFailureMessage = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}
