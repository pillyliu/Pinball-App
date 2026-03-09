package com.pillyliu.pinprofandroid.gameroom

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.pillyliu.pinprofandroid.ui.AppTintedStatusChip
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.time.format.ResolverStyle
import java.util.Locale

internal fun makeImportDraftRow(
    machine: PinsideImportedMachine,
    catalogLoader: GameRoomCatalogLoader,
): ImportDraftRow {
    val scored = scoredCatalogSuggestions(machine, catalogLoader)
    val suggestions = scored.map { it.first.catalogGameID }
    val top = scored.firstOrNull()
    return ImportDraftRow(
        id = machine.id,
        sourceItemKey = machine.slug,
        rawTitle = machine.rawTitle,
        rawVariant = machine.rawVariant,
        matchConfidence = importMatchConfidence(top?.second ?: 0),
        suggestions = suggestions,
        fingerprint = machine.fingerprint,
        selectedCatalogGameID = top?.first?.catalogGameID,
        selectedVariant = machine.rawVariant,
        rawPurchaseDateText = machine.rawPurchaseDateText,
        normalizedPurchaseDateMs = machine.normalizedPurchaseDateMs,
    )
}

internal fun importSuggestionLabel(game: GameRoomCatalogGame): String {
    return game.year?.let { year -> "${game.displayTitle} ($year)" } ?: game.displayTitle
}

internal fun importVariantOptions(
    row: ImportDraftRow,
    catalogLoader: GameRoomCatalogLoader,
): List<String> {
    val variants = mutableListOf<String>()

    fun addVariant(raw: String?) {
        val value = raw?.trim().orEmpty()
        if (value.isBlank()) return
        if (variants.none { it.equals(value, ignoreCase = true) }) {
            variants += value
        }
    }

    addVariant(row.selectedVariant)
    addVariant(row.rawVariant)
    row.selectedCatalogGameID
        ?.let(catalogLoader::variantOptions)
        .orEmpty()
        .forEach(::addVariant)

    return variants
}

private fun scoredCatalogSuggestions(
    machine: PinsideImportedMachine,
    catalogLoader: GameRoomCatalogLoader,
): List<Pair<GameRoomCatalogGame, Int>> {
    val normalizedRawTitle = normalizeImportText(machine.rawTitle)
    val normalizedVariant = normalizeImportText(machine.rawVariant.orEmpty())
    val slugMatch = catalogLoader.slugMatch(machine.slug)
    return catalogLoader.games.map { game ->
        val normalizedGameTitle = normalizeImportText(game.displayTitle)
        var score = 0

        if (slugMatch != null && game.catalogGameID.equals(slugMatch.catalogGameID, ignoreCase = true)) {
            score += 400
        }
        if (normalizedRawTitle.isNotBlank()) {
            if (normalizedRawTitle == normalizedGameTitle) {
                score += 120
            } else if (
                normalizedGameTitle.contains(normalizedRawTitle) ||
                normalizedRawTitle.contains(normalizedGameTitle)
            ) {
                score += 80
            } else {
                score += tokenOverlapScore(normalizedRawTitle, normalizedGameTitle)
            }
        }
        if (normalizedVariant.isNotBlank()) {
            val variants = catalogLoader.variantOptions(game.catalogGameID).map(::normalizeImportText)
            if (variants.contains(normalizedVariant)) score += 20
        }
        game to score
    }.filter { (_, score) -> score > 0 }
        .sortedWith(
            compareByDescending<Pair<GameRoomCatalogGame, Int>> { it.second }
                .thenBy { it.first.displayTitle.lowercase() },
        )
        .take(3)
}

private fun importMatchConfidence(score: Int): MachineImportMatchConfidence {
    return when {
        score >= 120 -> MachineImportMatchConfidence.high
        score >= 80 -> MachineImportMatchConfidence.medium
        score > 0 -> MachineImportMatchConfidence.low
        else -> MachineImportMatchConfidence.manual
    }
}

private fun tokenOverlapScore(lhs: String, rhs: String): Int {
    val lhsSet = lhs.split(" ").filter { it.isNotBlank() }.toSet()
    val rhsSet = rhs.split(" ").filter { it.isNotBlank() }.toSet()
    if (lhsSet.isEmpty() || rhsSet.isEmpty()) return 0
    val intersection = lhsSet.intersect(rhsSet).size
    if (intersection == 0) return 0
    return ((intersection.toDouble() / maxOf(lhsSet.size, rhsSet.size)) * 70.0).toInt()
}

private fun normalizeImportText(value: String): String {
    return value
        .lowercase(Locale.US)
        .replace(Regex("[^a-z0-9 ]"), " ")
        .replace(Regex("\\s+"), " ")
        .trim()
}

internal fun normalizeFirstOfMonthMs(rawValue: String?): Long? {
    val raw = rawValue?.trim().orEmpty()
    if (raw.isBlank()) return null

    val monthYearFormatters = listOf(
        formatter("MMMM uuuu"),
        formatter("MMM uuuu"),
        formatter("M/uuuu"),
        formatter("MM/uuuu"),
        formatter("M-uuuu"),
        formatter("MM-uuuu"),
        formatter("uuuu-MM"),
        formatter("uuuu/M"),
    )
    monthYearFormatters.forEach { formatter ->
        val parsed = runCatching { YearMonth.parse(raw, formatter) }.getOrNull() ?: return@forEach
        return parsed.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    }

    val fullDateFormatters = listOf(
        formatter("uuuu-MM-dd"),
        formatter("M/d/uuuu"),
        formatter("MM/dd/uuuu"),
        formatter("MMM d, uuuu"),
        formatter("MMMM d, uuuu"),
    )
    fullDateFormatters.forEach { formatter ->
        val parsed = runCatching { LocalDate.parse(raw, formatter) }.getOrNull() ?: return@forEach
        val month = YearMonth.from(parsed)
        return month.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    }

    return null
}

private fun formatter(pattern: String): DateTimeFormatter {
    return DateTimeFormatterBuilder()
        .parseCaseInsensitive()
        .appendPattern(pattern)
        .toFormatter(Locale.US)
        .withResolverStyle(ResolverStyle.SMART)
}

internal fun duplicateWarningMessage(
    row: ImportDraftRow,
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
): String? {
    if (store.hasImportFingerprint(row.fingerprint)) {
        return "Already imported previously."
    }
    val selectedCatalogID = row.selectedCatalogGameID ?: return null
    val selectedGame = catalogLoader.game(selectedCatalogID) ?: return null
    val selectedVariant = row.selectedVariant ?: row.rawVariant
    val existing = store.existingOwnedMachine(selectedGame.catalogGameID, selectedVariant) ?: return null
    return if (!existing.displayVariant.isNullOrBlank()) {
        "Duplicate of existing machine: ${existing.displayTitle} (${existing.displayVariant})."
    } else {
        "Duplicate of existing machine: ${existing.displayTitle}."
    }
}

internal fun needsImportReview(
    row: ImportDraftRow,
    store: GameRoomStore,
    catalogLoader: GameRoomCatalogLoader,
): Boolean {
    return row.matchConfidence != MachineImportMatchConfidence.high ||
        row.selectedCatalogGameID.isNullOrBlank() ||
        duplicateWarningMessage(row, store, catalogLoader) != null
}

@Composable
internal fun MatchConfidenceBadge(confidence: MachineImportMatchConfidence) {
    val badgeColor = when (confidence) {
        MachineImportMatchConfidence.high -> Color(0xFF53A653)
        MachineImportMatchConfidence.medium -> Color(0xFFF2C14E)
        MachineImportMatchConfidence.low,
        MachineImportMatchConfidence.manual -> Color(0xFFE0524D)
    }
    AppTintedStatusChip(
        text = confidence.name.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() },
        color = badgeColor,
        compact = true,
    )
}
