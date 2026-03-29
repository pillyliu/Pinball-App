package com.pillyliu.pinprofandroid.library

internal fun preferredMachineForSourceLookup(
    requestedMachineId: String,
    machineByOpdbId: Map<String, CatalogMachineRecord>,
    machineByPracticeIdentity: Map<String, List<CatalogMachineRecord>>,
): CatalogMachineRecord? {
    val normalizedMachineId = normalizedOptionalString(requestedMachineId)
    val preferredGroupMachine = normalizedMachineId
        ?.let { machineByPracticeIdentity[it]?.minWithOrNull(::comparePreferredMachine) }
    val exactMachine = normalizedMachineId?.let { machineByOpdbId[it] } ?: return preferredGroupMachine
    if (catalogMachineHasPrimaryImage(exactMachine)) return exactMachine
    val exactGroupMachine = machineByPracticeIdentity[exactMachine.practiceIdentity]?.minWithOrNull(::comparePreferredMachine)
    return exactGroupMachine ?: preferredGroupMachine ?: exactMachine
}

internal fun comparePreferredMachine(lhs: CatalogMachineRecord, rhs: CatalogMachineRecord): Int {
    val lhsHasPrimary = catalogMachineHasPrimaryImage(lhs)
    val rhsHasPrimary = catalogMachineHasPrimaryImage(rhs)
    if (lhsHasPrimary != rhsHasPrimary) return if (lhsHasPrimary) -1 else 1

    val lhsVariant = normalizedOptionalString(lhs.variant)
    val rhsVariant = normalizedOptionalString(rhs.variant)
    if ((lhsVariant == null) != (rhsVariant == null)) return if (lhsVariant == null) -1 else 1

    val lhsYear = lhs.year ?: Int.MAX_VALUE
    val rhsYear = rhs.year ?: Int.MAX_VALUE
    if (lhsYear != rhsYear) return lhsYear.compareTo(rhsYear)

    val lhsName = lhs.name.lowercase()
    val rhsName = rhs.name.lowercase()
    if (lhsName != rhsName) return lhsName.compareTo(rhsName)

    return (lhs.opdbMachineId ?: lhs.practiceIdentity).compareTo(rhs.opdbMachineId ?: rhs.practiceIdentity)
}

internal fun compareGroupDefaultMachine(lhs: CatalogMachineRecord, rhs: CatalogMachineRecord): Int {
    val lhsVariant = normalizedOptionalString(lhs.variant)
    val rhsVariant = normalizedOptionalString(rhs.variant)
    if ((lhsVariant == null) != (rhsVariant == null)) return if (lhsVariant == null) -1 else 1

    val lhsYear = lhs.year ?: Int.MAX_VALUE
    val rhsYear = rhs.year ?: Int.MAX_VALUE
    if (lhsYear != rhsYear) return lhsYear.compareTo(rhsYear)

    val lhsName = lhs.name.lowercase()
    val rhsName = rhs.name.lowercase()
    if (lhsName != rhsName) return lhsName.compareTo(rhsName)

    return (lhs.opdbMachineId ?: lhs.practiceIdentity).compareTo(rhs.opdbMachineId ?: rhs.practiceIdentity)
}

internal fun preferredMachineForVariant(
    candidates: List<CatalogMachineRecord>,
    requestedVariant: String?,
): CatalogMachineRecord? {
    if (candidates.isEmpty()) return null
    val normalizedRequested = normalizedOptionalString(requestedVariant)?.lowercase()
    if (normalizedRequested == null) {
        return candidates.minWithOrNull(::comparePreferredMachine)
    }
    val ranked = candidates.sortedWith { lhs, rhs ->
        val lhsScore = catalogVariantScore(lhs.variant, normalizedRequested)
        val rhsScore = catalogVariantScore(rhs.variant, normalizedRequested)
        when {
            lhsScore != rhsScore -> rhsScore.compareTo(lhsScore)
            catalogMachineHasPrimaryImage(lhs) != catalogMachineHasPrimaryImage(rhs) ->
                if (catalogMachineHasPrimaryImage(lhs)) -1 else 1
            (lhs.year ?: Int.MAX_VALUE) != (rhs.year ?: Int.MAX_VALUE) ->
                (lhs.year ?: Int.MAX_VALUE).compareTo(rhs.year ?: Int.MAX_VALUE)
            else -> (lhs.opdbMachineId ?: lhs.practiceIdentity).compareTo(rhs.opdbMachineId ?: rhs.practiceIdentity)
        }
    }
    val best = ranked.firstOrNull() ?: return null
    val bestScore = catalogVariantScore(best.variant, normalizedRequested)
    if (bestScore <= 0) return null
    return best
}

internal fun catalogMachineHasPrimaryImage(machine: CatalogMachineRecord): Boolean =
    machine.primaryImageMediumUrl != null || machine.primaryImageLargeUrl != null

internal fun catalogVariantScore(machineVariant: String?, requestedVariant: String?): Int {
    val normalizedMachineVariant = normalizedOptionalString(machineVariant)?.lowercase()
    val normalizedRequested = normalizedOptionalString(requestedVariant)?.lowercase() ?: return 0
    if (normalizedMachineVariant.isNullOrBlank()) return 0
    if (normalizedMachineVariant == normalizedRequested) return 200
    val machineTokens = normalizedMachineVariant
        .split(Regex("[^A-Za-z0-9]+"))
        .filter { it.isNotBlank() }
        .toSet()
    val requestTokens = normalizedRequested
        .split(Regex("[^A-Za-z0-9]+"))
        .filter { it.isNotBlank() }
        .toSet()
    val sharedTokens = machineTokens.intersect(requestTokens)
    if (machineTokens.isNotEmpty() && requestTokens.isNotEmpty() && sharedTokens.isNotEmpty()) {
        var score = 100 + (sharedTokens.size * 20)
        if ("anniversary" in sharedTokens) score += 200
        if (sharedTokens.any { it.endsWith("th") || it.all(Char::isDigit) }) score += 120
        if ("premium" in sharedTokens) score += 40
        if ("le" in sharedTokens) score += 40
        return score
    }
    if (!normalizedMachineVariant.isNullOrBlank() &&
        (normalizedMachineVariant.contains(normalizedRequested) || normalizedRequested.contains(normalizedMachineVariant))
    ) return 80
    return 0
}
