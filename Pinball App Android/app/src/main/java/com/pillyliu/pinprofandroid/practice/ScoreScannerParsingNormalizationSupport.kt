package com.pillyliu.pinprofandroid.practice

import kotlin.math.abs
import kotlin.math.hypot

private data class ScoreScannerNormalizedScore(
    val score: Long,
    val digitCount: Int,
    val formatQuality: Int,
    val rawRun: String,
)

private data class ScoreScannerRescueVariant(
    val run: String,
    val qualityAdjustment: Int,
)

internal fun scoreScannerCandidateFrom(observation: ScoreOcrObservation): ScoreScannerCandidate? {
    val normalized = scoreScannerNormalizeOcrText(observation.text) ?: return null
    val centerX = observation.boundingBox.centerX()
    val centerY = observation.boundingBox.centerY()
    val distance = hypot(centerX - 0.5f, centerY - 0.5f)
    val maxDistance = hypot(0.5f, 0.5f)
    val centerBias = (1f - (distance / maxDistance)).coerceIn(0f, 1f).toDouble()

    return ScoreScannerCandidate(
        rawText = observation.text,
        normalizedScore = normalized.score,
        formattedScore = ScoreScannerParsingService.formattedScore(normalized.score),
        confidence = observation.confidence,
        boundingBox = observation.boundingBox,
        digitCount = normalized.digitCount,
        centerBias = centerBias,
        formatQuality = normalized.formatQuality,
    )
}

internal fun scoreScannerCandidateSort(
    lhs: ScoreScannerCandidate,
    rhs: ScoreScannerCandidate,
): Int {
    if (lhs.normalizedScore == rhs.normalizedScore &&
        lhs.formatQuality != rhs.formatQuality
    ) {
        return rhs.formatQuality.compareTo(lhs.formatQuality)
    }
    if (abs(lhs.digitCount - rhs.digitCount) >= 3) {
        return rhs.digitCount.compareTo(lhs.digitCount)
    }
    if (lhs.formatQuality != rhs.formatQuality) {
        return rhs.formatQuality.compareTo(lhs.formatQuality)
    }
    if (lhs.digitCount != rhs.digitCount) {
        return rhs.digitCount.compareTo(lhs.digitCount)
    }
    if (abs(lhs.centerBias - rhs.centerBias) > 0.001) {
        return rhs.centerBias.compareTo(lhs.centerBias)
    }
    return rhs.confidence.compareTo(lhs.confidence)
}

private fun scoreScannerNormalizeOcrText(raw: String): ScoreScannerNormalizedScore? {
    val strippedWhitespace = raw
        .replace(" ", "")
        .replace("\n", "")
        .trim()
    if (strippedWhitespace.isEmpty()) return null

    val mapped = scoreScannerNormalizedDigitLikeText(strippedWhitespace)
    val normalizedRuns = scoreScannerDigitLikeRuns(mapped)
        .flatMap(::scoreScannerNormalizedRunCandidates)
    return normalizedRuns.maxWithOrNull(::scoreScannerNormalizedRunSort)
}

private fun scoreScannerNormalizedDigitLikeText(raw: String): String {
    val characters = raw.toCharArray()
    return buildString(characters.size) {
        characters.indices.forEach { index ->
            val previous = characters.getOrNull(index - 1)
            val next = characters.getOrNull(index + 1)
            append(scoreScannerMappedDigit(characters[index], previous, next) ?: characters[index])
        }
    }
}

private fun scoreScannerMappedDigit(
    character: Char,
    previous: Char?,
    next: Char?,
): Char? {
    return when (character) {
        'O', 'o' -> '0'
        'I', 'l', 'L', '|', '!' -> '1'
        'S', 's' -> '5'
        'b', 'G', 'Z', 'z', 'q', 'Q' -> {
            if (!scoreScannerHasNumericContext(previous, next)) return null
            when (character) {
                'b', 'G' -> '6'
                'Z', 'z' -> '2'
                'q', 'Q' -> '9'
                else -> null
            }
        }
        else -> null
    }
}

private fun scoreScannerHasNumericContext(previous: Char?, next: Char?): Boolean {
    return scoreScannerIsDigitLikeContext(previous) || scoreScannerIsDigitLikeContext(next)
}

private fun scoreScannerIsDigitLikeContext(character: Char?): Boolean {
    return when {
        character == null -> false
        character.isDigit() -> true
        character == ',' || character == '.' || character == '\'' -> true
        scoreScannerMappedDigit(character, previous = null, next = null) != null -> true
        else -> false
    }
}

private fun scoreScannerDigitLikeRuns(text: String): List<String> {
    val runs = mutableListOf<String>()
    val current = StringBuilder()
    text.forEach { character ->
        if (character.isDigit() || character == ',' || character == '.' || character == '\'') {
            current.append(character)
        } else if (current.isNotEmpty()) {
            runs += current.toString()
            current.clear()
        }
    }
    if (current.isNotEmpty()) {
        runs += current.toString()
    }
    return runs
}

private fun scoreScannerNormalizedRun(run: String): ScoreScannerNormalizedScore? {
    val digits = run.filter(Char::isDigit)
    val leadingZeroCount = digits.takeWhile { it == '0' }.count()
    if (digits.isEmpty() || digits.length > 15) return null
    val score = digits.toLongOrNull() ?: return null
    if (score <= 0) return null

    return ScoreScannerNormalizedScore(
        score = score,
        digitCount = digits.length,
        formatQuality = scoreScannerFormatQuality(run = run, leadingZeroCount = leadingZeroCount),
        rawRun = run,
    )
}

private fun scoreScannerNormalizedRunCandidates(run: String): List<ScoreScannerNormalizedScore> {
    val candidates = mutableListOf<ScoreScannerNormalizedScore>()
    scoreScannerNormalizedRun(run)?.let(candidates::add)
    val groupedVariants = scoreScannerZeroConfusionGroupedRescueVariants(run)

    scoreScannerAppendRescuedCandidates(candidates, groupedVariants)
    scoreScannerAppendRescuedCandidates(candidates, scoreScannerMissingLeadingDigitRescueVariants(run))
    scoreScannerAppendRescuedCandidates(candidates, scoreScannerLeadingDigitRescueVariants(run))

    groupedVariants.forEach { groupedVariant ->
        scoreScannerAppendRescuedCandidates(
            candidates = candidates,
            variants = scoreScannerMissingLeadingDigitRescueVariants(groupedVariant.run),
            additionalQualityAdjustment = groupedVariant.qualityAdjustment,
        )
        scoreScannerAppendRescuedCandidates(
            candidates = candidates,
            variants = scoreScannerLeadingDigitRescueVariants(groupedVariant.run),
            additionalQualityAdjustment = groupedVariant.qualityAdjustment,
        )
    }

    return candidates
}

private fun scoreScannerAppendRescuedCandidates(
    candidates: MutableList<ScoreScannerNormalizedScore>,
    variants: List<ScoreScannerRescueVariant>,
    additionalQualityAdjustment: Int = 0,
) {
    variants.forEach { variant ->
        scoreScannerNormalizedRun(variant.run)?.let { normalized ->
            candidates += normalized.copy(
                formatQuality = normalized.formatQuality +
                    variant.qualityAdjustment +
                    additionalQualityAdjustment
            )
        }
    }
}

private fun scoreScannerNormalizedRunSort(
    lhs: ScoreScannerNormalizedScore,
    rhs: ScoreScannerNormalizedScore,
): Int {
    if (lhs.digitCount != rhs.digitCount) {
        return lhs.digitCount.compareTo(rhs.digitCount)
    }
    if (lhs.formatQuality != rhs.formatQuality) {
        return lhs.formatQuality.compareTo(rhs.formatQuality)
    }
    if (lhs.rawRun.length != rhs.rawRun.length) {
        return lhs.rawRun.length.compareTo(rhs.rawRun.length)
    }
    return lhs.rawRun.compareTo(rhs.rawRun)
}

private fun scoreScannerFormatQuality(
    run: String,
    leadingZeroCount: Int,
): Int {
    val separators = run.filter(::scoreScannerIsSeparator)
    val separatorKinds = separators.toSet()
    val groups = run.split(',', '.', '\'')
    val digits = run.filter(Char::isDigit)
    val zeroCount = digits.count { it == '0' }
    val hasMixedSeparators = separatorKinds.size > 1
    val hasRepeatedSeparators = scoreScannerContainsAdjacentSeparators(run)
    val hasEdgeSeparator = run.firstOrNull()?.let(::scoreScannerIsSeparator) == true ||
        run.lastOrNull()?.let(::scoreScannerIsSeparator) == true
    val usesValidThousandsGrouping =
        separators.isNotEmpty() &&
            separatorKinds.size == 1 &&
            groups.size > 1 &&
            (groups.firstOrNull()?.length ?: 0) in 1..3 &&
            groups.drop(1).all { it.length == 3 }

    var quality = 0
    if (separators.isEmpty()) {
        quality += 2
    }
    if (usesValidThousandsGrouping) {
        quality += 6
    } else if (separators.isNotEmpty()) {
        quality -= 2
    }
    if (hasMixedSeparators) {
        quality -= 5
    } else if (separators.isNotEmpty()) {
        quality += 1
    }
    if (leadingZeroCount > 0) {
        quality -= minOf(6, leadingZeroCount * 2)
    } else {
        quality += 2
    }
    if (hasRepeatedSeparators) {
        quality -= 3
    }
    if (hasEdgeSeparator) {
        quality -= 2
    }
    if (usesValidThousandsGrouping) {
        val leadingGroup = groups.firstOrNull()
        if (leadingGroup?.length == 1) {
            if (leadingGroup == "0") {
                quality -= 6
            } else if (leadingGroup == "1" && run.contains('.') && zeroCount >= 2) {
                quality -= 1
            }
        }
    }
    if (digits.length >= 7 && zeroCount >= 5) {
        quality -= 4
    } else if (digits.length >= 7 && zeroCount == 4) {
        quality -= 2
    }
    return quality
}

private fun scoreScannerMissingLeadingDigitRescueVariants(run: String): List<ScoreScannerRescueVariant> {
    if (run.firstOrNull()?.let(::scoreScannerIsSeparator) != true) return emptyList()

    val digits = run.filter(Char::isDigit)
    if (digits.length < 6) return emptyList()

    val groups = run.split(',', '.', '\'')
    if (groups.size <= 2) return emptyList()
    if ((groups.firstOrNull()?.length ?: -1) != 0) return emptyList()
    if (groups.drop(1).any { it.length != 3 }) return emptyList()

    fun prependLeadingDigit(replacement: Char, adjustment: Int): ScoreScannerRescueVariant {
        return ScoreScannerRescueVariant(run = replacement + run, qualityAdjustment = adjustment)
    }

    val preferEight = digits.count { it == '0' } >= 3
    return if (preferEight) {
        listOf(
            prependLeadingDigit(replacement = '8', adjustment = -1),
            prependLeadingDigit(replacement = '6', adjustment = -2),
            prependLeadingDigit(replacement = '7', adjustment = -3),
        )
    } else {
        listOf(
            prependLeadingDigit(replacement = '6', adjustment = -1),
            prependLeadingDigit(replacement = '8', adjustment = -2),
            prependLeadingDigit(replacement = '7', adjustment = -3),
        )
    }
}

private fun scoreScannerZeroConfusionGroupedRescueVariants(run: String): List<ScoreScannerRescueVariant> {
    val separatorKinds = run.filter(::scoreScannerIsSeparator).toSet()
    if (separatorKinds.size != 1) return emptyList()

    val groups = run.split(',', '.', '\'')
    if (groups.size <= 1) return emptyList()
    val leadingGroupLength = groups.firstOrNull()?.length ?: return emptyList()
    if (leadingGroupLength !in 0..3) return emptyList()
    if (groups.drop(1).any { it.length != 3 }) return emptyList()

    val digits = run.filter(Char::isDigit)
    if (digits.length < 7) return emptyList()
    val zeroCount = digits.count { it == '0' }
    if (zeroCount < 3) return emptyList()
    val prefersAggressiveZeroRescue = zeroCount >= 5

    val separator = separatorKinds.first()
    data class GroupOption(
        val group: String,
        val qualityAdjustment: Int,
        val changed: Boolean,
    )

    fun replacementAdjustment(
        groupIndex: Int,
        position: Int,
        replacement: Char,
        groupLength: Int,
    ): Int {
        val isLastThreeDigitGroup = groupLength == 3 && groupIndex == groups.lastIndex
        val base = when {
            groupLength == 1 -> if (prefersAggressiveZeroRescue) -1 else -2
            prefersAggressiveZeroRescue && position == 1 && isLastThreeDigitGroup && replacement == '6' -> -1
            prefersAggressiveZeroRescue && position == 1 && isLastThreeDigitGroup -> -2
            prefersAggressiveZeroRescue && position == 1 -> if (replacement == '8') -1 else -2
            prefersAggressiveZeroRescue -> -2
            position == 1 && isLastThreeDigitGroup && replacement == '6' -> -4
            position == 1 -> if (replacement == '8') -4 else -5
            else -> -5
        }
        return base
    }

    val perGroupOptions = groups.mapIndexed { groupIndex, group ->
        buildList {
            add(GroupOption(group = group, qualityAdjustment = 0, changed = false))
            if (group.isEmpty()) return@buildList

            group.indices.forEach { index ->
                if (group[index] != '0') return@forEach
                val isLeadingSingleDigitGroup = groupIndex == 0 && group.length == 1
                val isThreeDigitGroup = group.length == 3
                if (!isLeadingSingleDigitGroup && !isThreeDigitGroup) return@forEach

                listOf('8', '6').forEach { replacement ->
                    val characters = group.toCharArray()
                    characters[index] = replacement
                    add(
                        GroupOption(
                            group = String(characters),
                            qualityAdjustment = replacementAdjustment(
                                groupIndex = groupIndex,
                                position = index,
                                replacement = replacement,
                                groupLength = group.length,
                            ),
                            changed = true,
                        )
                    )
                }
            }
        }
    }

    val variants = linkedMapOf<String, Int>()
    val maximumVariantCount = 96

    fun buildVariants(
        groupIndex: Int,
        builtGroups: MutableList<String>,
        totalAdjustment: Int,
        changedGroups: Int,
    ) {
        if (variants.size >= maximumVariantCount) return
        if (groupIndex == perGroupOptions.size) {
            if (changedGroups > 0) {
                val variantRun = builtGroups.joinToString(separator.toString())
                val existing = variants[variantRun]
                if (existing == null || totalAdjustment > existing) {
                    variants[variantRun] = totalAdjustment
                }
            }
            return
        }

        perGroupOptions[groupIndex].forEach { option ->
            val nextChangedGroups = changedGroups + if (option.changed) 1 else 0
            if (nextChangedGroups > 3) return@forEach

            builtGroups += option.group
            buildVariants(
                groupIndex = groupIndex + 1,
                builtGroups = builtGroups,
                totalAdjustment = totalAdjustment + option.qualityAdjustment,
                changedGroups = nextChangedGroups,
            )
            builtGroups.removeAt(builtGroups.lastIndex)
        }
    }

    buildVariants(
        groupIndex = 0,
        builtGroups = mutableListOf(),
        totalAdjustment = 0,
        changedGroups = 0,
    )

    return variants.map { (variantRun, qualityAdjustment) ->
        ScoreScannerRescueVariant(
            run = variantRun,
            qualityAdjustment = qualityAdjustment,
        )
    }
}

private fun scoreScannerLeadingDigitRescueVariants(run: String): List<ScoreScannerRescueVariant> {
    val digits = run.filter(Char::isDigit)
    if (digits.length < 7) return emptyList()
    val groups = run.split(',', '.', '\'')
    if (groups.size <= 1) return emptyList()
    if ((groups.firstOrNull()?.length ?: 0) !in 1..3) return emptyList()
    if (groups.drop(1).any { it.length != 3 }) return emptyList()

    fun replacingLeadingDigit(replacement: Char, adjustment: Int): ScoreScannerRescueVariant {
        val characters = run.toCharArray()
        characters[0] = replacement
        return ScoreScannerRescueVariant(String(characters), adjustment)
    }

    return when (run.firstOrNull()) {
        '0' -> {
            val preferEight = digits.count { it == '0' } >= 4
            if (preferEight) {
                listOf(
                    replacingLeadingDigit(replacement = '8', adjustment = -1),
                    replacingLeadingDigit(replacement = '6', adjustment = -2),
                )
            } else {
                listOf(
                    replacingLeadingDigit(replacement = '6', adjustment = -1),
                    replacingLeadingDigit(replacement = '8', adjustment = -2),
                )
            }
        }
        '1' -> {
            if (run.contains('.') && digits.count { it == '0' } >= 2) {
                listOf(replacingLeadingDigit(replacement = '7', adjustment = -1))
            } else {
                emptyList()
            }
        }
        else -> emptyList()
    }
}

private fun scoreScannerIsSeparator(character: Char): Boolean {
    return character == ',' || character == '.' || character == '\''
}

private fun scoreScannerContainsAdjacentSeparators(run: String): Boolean {
    var previousWasSeparator = false
    run.forEach { character ->
        if (scoreScannerIsSeparator(character)) {
            if (previousWasSeparator) {
                return true
            }
            previousWasSeparator = true
        } else {
            previousWasSeparator = false
        }
    }
    return false
}
