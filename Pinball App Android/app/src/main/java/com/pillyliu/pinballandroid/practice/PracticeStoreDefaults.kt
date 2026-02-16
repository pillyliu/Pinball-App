package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.library.PinballGame

internal fun defaultPracticeGroupForGames(games: List<PinballGame>): PracticeGroup? {
    if (games.isEmpty()) return null
    val defaultGames = games.take(5).map { it.slug }
    return PracticeGroup(
        id = "group-default",
        name = "Active Rotation",
        gameSlugs = defaultGames,
        type = "custom",
        isActive = true,
        isPriority = true,
        startDateMs = null,
        endDateMs = null,
    )
}
