package com.pillyliu.pinprofandroid.targets

import com.pillyliu.pinprofandroid.practice.parseResolvedLeagueTargets
import java.text.NumberFormat

internal fun defaultTargetRows(): List<TargetRow> {
    return lplTargets.mapIndexed { index, target ->
        TargetRow(target, null, null, null, null, null, Int.MAX_VALUE, index)
    }
}

internal fun resolveTargetRows(text: String?): List<TargetRow> {
    val resolved = if (text.isNullOrBlank()) emptyList() else parseResolvedLeagueTargets(text)
    if (resolved.isEmpty()) return defaultTargetRows()

    return resolved.mapIndexed { fallbackIndex, row ->
        TargetRow(
            target = LPLTarget(
                game = row.game,
                great = row.secondHighestAvg,
                main = row.fourthHighestAvg,
                floor = row.eighthHighestAvg,
            ),
            area = row.area,
            areaOrder = row.areaOrder,
            bank = row.bank,
            group = row.group,
            position = row.position,
            libraryOrder = row.order,
            fallbackOrder = fallbackIndex,
        )
    }
}

internal fun sortTargetRows(rows: List<TargetRow>, option: TargetSortOption): List<TargetRow> {
    return when (option) {
        TargetSortOption.LOCATION -> rows.sortedWith(
            compareBy<TargetRow> { it.areaOrder ?: Int.MAX_VALUE }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE }
                .thenBy { it.libraryOrder }
                .thenBy { it.fallbackOrder },
        )
        TargetSortOption.BANK -> rows.sortedWith(
            compareBy<TargetRow> { it.bank ?: Int.MAX_VALUE }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE }
                .thenBy { it.target.game.lowercase() }
                .thenBy { it.libraryOrder }
                .thenBy { it.fallbackOrder },
        )
        TargetSortOption.ALPHABETICAL -> rows.sortedWith(
            compareBy<TargetRow> { it.target.game.lowercase() }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE }
                .thenBy { it.libraryOrder }
                .thenBy { it.fallbackOrder },
        )
    }
}

internal fun formatTargetScore(value: Long): String = NumberFormat.getIntegerInstance().format(value)
