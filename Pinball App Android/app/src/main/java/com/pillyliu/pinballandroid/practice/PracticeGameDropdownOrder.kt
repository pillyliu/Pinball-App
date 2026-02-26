package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.library.PinballGame
import java.util.Locale

internal fun orderedGamesForDropdown(
    games: List<PinballGame>,
    collapseByPracticeIdentity: Boolean = false,
    limit: Int? = null,
): List<PinballGame> {
    val source = if (collapseByPracticeIdentity) distinctGamesByPracticeIdentity(games) else games
    val ordered = source.sortedWith(
        compareBy<PinballGame> { it.name.lowercase(Locale.US) }
            .thenBy { it.year ?: Int.MAX_VALUE }
            .thenBy { it.practiceKey.lowercase(Locale.US) },
    )
    return if (limit == null) ordered else ordered.take(limit)
}
