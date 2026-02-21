package com.pillyliu.pinballandroid.practice

import com.pillyliu.pinballandroid.library.PinballGame
import java.util.Locale

internal fun orderedGamesForDropdown(
    games: List<PinballGame>,
    limit: Int? = null,
): List<PinballGame> {
    val ordered = games.sortedWith(
        compareBy<PinballGame> { if (it.sourceType == com.pillyliu.pinballandroid.library.LibrarySourceType.CATEGORY) 1 else 0 }
            .thenBy { it.areaOrder ?: Int.MAX_VALUE }
            .thenBy { it.group ?: Int.MAX_VALUE }
            .thenBy { it.position ?: Int.MAX_VALUE }
            .thenBy { it.year ?: Int.MAX_VALUE }
            .thenBy { it.name.lowercase(Locale.US) },
    )
    return if (limit == null) ordered else ordered.take(limit)
}
