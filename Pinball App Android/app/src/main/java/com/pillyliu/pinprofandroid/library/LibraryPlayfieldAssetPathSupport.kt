package com.pillyliu.pinprofandroid.library

private val bundledOnlyAppGroupIds = setOf("G900001")

internal val PinballGame.usesBundledOnlyAppAssetException: Boolean
    get() = listOfNotNull(practiceIdentity, opdbGroupId)
        .map { raw ->
            val trimmed = raw.trim()
            val dash = trimmed.indexOf('-')
            if (dash >= 0) trimmed.substring(0, dash) else trimmed
        }
        .any(bundledOnlyAppGroupIds::contains)

private val PinballGame.hasSplitPracticeIdentity: Boolean
    get() {
        val normalizedPracticeIdentity = practiceIdentity?.trim()?.takeIf { it.isNotEmpty() } ?: return false
        val normalizedOpdbGroupId = opdbGroupId?.trim()?.takeIf { it.isNotEmpty() } ?: return false
        return !normalizedPracticeIdentity.equals(normalizedOpdbGroupId, ignoreCase = true)
    }

internal val PinballGame.localAssetKey: String?
    get() = practiceIdentity?.ifBlank { null }

internal val PinballGame.primaryArtworkCandidates: List<String>
    get() = listOfNotNull(
        resolveLibraryUrl(primaryImageLargeUrl),
        resolveLibraryUrl(primaryImageUrl),
    ).distinct()

private val PinballGame.playfieldAssetKeys: List<String>
    get() {
        val keys = LinkedHashSet<String>()

        fun append(raw: String?) {
            val trimmed = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return
            keys += trimmed
        }

        append(opdbId)
        append(localAssetKey)
        if (!hasSplitPracticeIdentity) {
            append(opdbGroupId)
        }
        return keys.toList()
    }

internal val PinballGame.supportedSourcePlayfieldCandidates: List<String>
    get() = listOfNotNull(
        resolveLibraryUrl(playfieldImageUrl)?.takeIf {
            isPinProfPlayfieldUrl(it) || isOpdbPlayfieldUrl(it)
        },
        alternatePlayfieldImageSourceUrl?.takeIf {
            isPinProfPlayfieldUrl(it) || isOpdbPlayfieldUrl(it)
        },
    ).distinct()

internal val PinballGame.explicitLocalPlayfieldCandidates: List<String>
    get() = listOfNotNull(
        playfieldLocalOriginalURL,
        playfieldLocalURL,
    ).distinct()

internal val PinballGame.preferredLocalPlayfieldCandidates: List<String>
    get() = (
        explicitLocalPlayfieldCandidates +
            inferredHostedPlayfieldCandidates()
        ).distinct()

private fun PinballGame.inferredHostedPlayfieldCandidates(): List<String> {
    val candidates = LinkedHashSet<String>()
    playfieldAssetKeys.forEach { assetKey ->
        resolveLibraryUrl("/pinball/images/playfields/$assetKey-playfield.webp")?.let(candidates::add)
    }
    return candidates.toList()
}

internal val PinballGame.playfieldLocalURL: String?
    get() = resolveLibraryUrl(playfieldLocal ?: playfieldLocalOriginal)

internal val PinballGame.playfieldLocalOriginalURL: String?
    get() = resolveLibraryUrl(playfieldLocalOriginal ?: playfieldLocal)

internal val PinballGame.alternatePlayfieldImageSourceUrl: String?
    get() = resolveLibraryUrl(alternatePlayfieldImageUrl)

internal val PinballGame.actualFullscreenPlayfieldCandidates: List<String>
    get() = (explicitLocalPlayfieldCandidates + supportedSourcePlayfieldCandidates).distinct()
