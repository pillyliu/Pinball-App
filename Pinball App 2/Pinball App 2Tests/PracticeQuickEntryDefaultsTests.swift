import XCTest
@testable import PinProf

final class PracticeQuickEntryDefaultsTests: XCTestCase {
    func testInitialLibraryFilterPrefersSelectedGameSourceBeforeAvenueFallback() {
        let initial = resolveInitialQuickEntryLibraryFilterID(
            kind: .score,
            currentSelectedGameSourceID: "venue--latest-spot",
            preferredLibrarySourceID: "",
            avenueLibrarySourceID: "venue--pm-8760",
            defaultPracticeSourceID: "",
            availableLibrarySourceIDs: ["venue--pm-8760", "venue--latest-spot"]
        )

        XCTAssertEqual(initial, "venue--latest-spot")
    }

    func testMechanicsInitialLibraryFilterUsesAllGames() {
        let initial = resolveInitialQuickEntryLibraryFilterID(
            kind: .mechanics,
            currentSelectedGameSourceID: "venue--latest-spot",
            preferredLibrarySourceID: "venue--preferred",
            avenueLibrarySourceID: "venue--pm-8760",
            defaultPracticeSourceID: "venue--default",
            availableLibrarySourceIDs: ["venue--pm-8760", "venue--latest-spot"]
        )

        XCTAssertEqual(initial, quickEntryAllGamesLibraryID)
    }

    func testVideoEntryDefaultsToPercentInput() {
        XCTAssertEqual(defaultPracticeVideoInputKind, .percent)
    }

    func testVideoInputModesShowPercentBeforeClock() {
        XCTAssertEqual(practiceVideoInputKindOptions, [.percent, .clock])
    }

    func testExternalRulesheetFallbackUsesOtherTitle() {
        let link = PinballGame.ReferenceLink(
            label: "Pinball News",
            url: "https://www.pinballnews.com/games/tron/index.html"
        )

        XCTAssertEqual(PinballShortRulesheetTitle(for: link), "Other")
    }

    func testLocalRulesheetTitleStaysLocal() {
        let link = PinballGame.ReferenceLink(
            label: "Rulesheet (source)",
            url: ""
        )

        XCTAssertEqual(PinballShortRulesheetTitle(for: link), "Local")
    }

    func testResolveVideoLinksOrdersByKindThenNaturalLabel() {
        let resolved = resolveVideoLinks(videoLinks: [
            CatalogVideoLinkRecord(
                practiceIdentity: "tron",
                provider: "matchplay",
                kind: "tutorial",
                label: "Tutorial 10",
                url: "https://www.youtube.com/watch?v=t10",
                priority: 0
            ),
            CatalogVideoLinkRecord(
                practiceIdentity: "tron",
                provider: "local",
                kind: "competition",
                label: "Competition 1",
                url: "https://www.youtube.com/watch?v=c1",
                priority: 0
            ),
            CatalogVideoLinkRecord(
                practiceIdentity: "tron",
                provider: "local",
                kind: "gameplay",
                label: "Gameplay 2",
                url: "https://www.youtube.com/watch?v=g2",
                priority: 0
            ),
            CatalogVideoLinkRecord(
                practiceIdentity: "tron",
                provider: "local",
                kind: "tutorial",
                label: "Tutorial 2",
                url: "https://www.youtube.com/watch?v=t2",
                priority: 0
            ),
            CatalogVideoLinkRecord(
                practiceIdentity: "tron",
                provider: "matchplay",
                kind: "gameplay",
                label: "Gameplay 10",
                url: "https://www.youtube.com/watch?v=g10",
                priority: 0
            ),
            CatalogVideoLinkRecord(
                practiceIdentity: "tron",
                provider: "local",
                kind: "tutorial",
                label: "Tutorial 1",
                url: "https://www.youtube.com/watch?v=t1",
                priority: 0
            )
        ])

        XCTAssertEqual(
            resolved.map { $0.label ?? "" },
            ["Tutorial 1", "Tutorial 2", "Tutorial 10", "Gameplay 2", "Gameplay 10", "Competition 1"]
        )
    }

    func testMergeResolvedVideosReordersCuratedAndCatalogVideosByDisplaySequence() {
        let merged = mergeResolvedVideos(
            primary: [
                PinballGame.Video(kind: "competition", label: "Competition 2", url: "https://www.youtube.com/watch?v=c2"),
                PinballGame.Video(kind: "tutorial", label: "Tutorial 2", url: "https://www.youtube.com/watch?v=t2")
            ],
            secondary: [
                PinballGame.Video(kind: "gameplay", label: "Gameplay 3", url: "https://www.youtube.com/watch?v=g3"),
                PinballGame.Video(kind: "tutorial", label: "Tutorial 1", url: "https://www.youtube.com/watch?v=t1"),
                PinballGame.Video(kind: "competition", label: "Competition 1", url: "https://www.youtube.com/watch?v=c1")
            ]
        )

        XCTAssertEqual(
            merged.map { $0.label ?? "" },
            ["Tutorial 1", "Tutorial 2", "Gameplay 3", "Competition 1", "Competition 2"]
        )
    }
}

final class PracticeResumeGameTests: XCTestCase {
    func testMostRecentTimelineGameIDPrefersNewestLibraryActivity() {
        let now = Date()
        let journalEntries = [
            JournalEntry(
                gameID: "practice-game",
                action: .scoreLogged,
                score: 12_345,
                timestamp: now.addingTimeInterval(-120)
            )
        ]
        let libraryEvents = [
            LibraryActivityEvent(
                gameID: "library-game",
                gameName: "Library Game",
                kind: .browseGame,
                timestamp: now
            )
        ]

        XCTAssertEqual(
            mostRecentPracticeTimelineGameID(
                journalEntries: journalEntries,
                libraryEvents: libraryEvents
            ),
            "library-game"
        )
    }

    func testMostRecentTimelineGameIDPrefersNewestPracticeJournalEntry() {
        let now = Date()
        let journalEntries = [
            JournalEntry(
                gameID: "practice-game",
                action: .practiceSession,
                progressPercent: 80,
                timestamp: now
            )
        ]
        let libraryEvents = [
            LibraryActivityEvent(
                gameID: "library-game",
                gameName: "Library Game",
                kind: .browseGame,
                timestamp: now.addingTimeInterval(-90)
            )
        ]

        XCTAssertEqual(
            mostRecentPracticeTimelineGameID(
                journalEntries: journalEntries,
                libraryEvents: libraryEvents
            ),
            "practice-game"
        )
    }

    func testMostRecentTimelineGameIDReturnsNilWhenTimelineIsEmpty() {
        XCTAssertNil(
            mostRecentPracticeTimelineGameID(
                journalEntries: [],
                libraryEvents: []
            )
        )
    }
}
