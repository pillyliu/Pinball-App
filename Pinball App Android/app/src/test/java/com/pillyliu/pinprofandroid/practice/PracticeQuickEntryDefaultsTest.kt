package com.pillyliu.pinprofandroid.practice

import org.junit.Assert.assertEquals
import org.junit.Test

class PracticeQuickEntryDefaultsTest {

    @Test
    fun nonGameQuickEntry_libraryDefaultsToResumeGameSourceBeforeAvenue() {
        val initial = resolveInitialQuickEntryLibraryOption(
            origin = QuickEntryOrigin.Score,
            fromGameView = false,
            selectedGameSourceId = "",
            resumeGameSourceId = "venue--latest-spot",
            savedLibraryOption = "",
            preferredLibraryOption = "",
            avenueLibraryOption = "venue--the-avenue-cafe",
            defaultPracticeSourceId = "",
            availableLibraryOptionIds = linkedSetOf("venue--the-avenue-cafe", "venue--latest-spot"),
        )

        assertEquals("venue--latest-spot", initial)
    }

    @Test
    fun nonGameQuickEntry_prefersResumeGameOverSavedQuickGame() {
        val initial = resolveInitialQuickEntryGameSlug(
            origin = QuickEntryOrigin.Score,
            fromGameView = false,
            selectedGameSlug = "",
            resumeGameSlug = "resume-game",
            savedQuickGameSlug = "saved-game",
            fallbackGameSlug = "fallback-game",
        )

        assertEquals("resume-game", initial)
    }

    @Test
    fun gameViewQuickEntry_keepsCurrentGameSelection() {
        val initial = resolveInitialQuickEntryGameSlug(
            origin = QuickEntryOrigin.Practice,
            fromGameView = true,
            selectedGameSlug = "current-game",
            resumeGameSlug = "resume-game",
            savedQuickGameSlug = "saved-game",
            fallbackGameSlug = "fallback-game",
        )

        assertEquals("current-game", initial)
    }

    @Test
    fun mechanicsQuickEntry_startsWithoutGame() {
        val initial = resolveInitialQuickEntryGameSlug(
            origin = QuickEntryOrigin.Mechanics,
            fromGameView = false,
            selectedGameSlug = "current-game",
            resumeGameSlug = "resume-game",
            savedQuickGameSlug = "saved-game",
            fallbackGameSlug = "fallback-game",
        )

        assertEquals("", initial)
    }
}
