package com.pillyliu.pinprofandroid.library

import java.net.URL

private val PinballGame.localFallbackPlayfieldCandidates: List<String>
    get() = listOfNotNull(playfieldLocalURL).distinct()

private val PinballGame.profPlayfieldBaseCandidates: List<String>
    get() = listOfNotNull(
        playfieldLocalOriginalURL?.takeIf(::isPinProfPlayfieldUrl),
        resolveLibraryUrl(playfieldImageUrl)?.takeIf(::isPinProfPlayfieldUrl),
    ).distinct().let { candidates ->
        if (usesBundledOnlyAppAssetException) emptyList() else candidates
    }

private fun PinballGame.profPlayfieldCandidates(liveStatus: LivePlayfieldStatus?): List<String> {
    if (usesBundledOnlyAppAssetException) {
        return emptyList()
    }
    val liveUrl = liveStatus?.effectiveUrl?.takeIf { liveStatus.effectiveKind == LivePlayfieldKind.PILLYLIU }
    val hasHostedCandidate = liveUrl != null || profPlayfieldBaseCandidates.isNotEmpty()
    return buildList {
        liveUrl?.let(::add)
        addAll(profPlayfieldBaseCandidates)
        if (hasHostedCandidate) {
            addAll(localFallbackPlayfieldCandidates)
        }
    }.distinct()
}

private fun PinballGame.opdbPlayfieldCandidates(liveStatus: LivePlayfieldStatus?): List<String> =
    listOfNotNull(
        liveStatus?.effectiveUrl?.takeIf { liveStatus.effectiveKind == LivePlayfieldKind.OPDB },
        resolveLibraryUrl(playfieldImageUrl)?.takeIf(::isOpdbPlayfieldUrl),
        alternatePlayfieldImageSourceUrl?.takeIf(::isOpdbPlayfieldUrl),
    ).distinct()

private fun PinballGame.artworkCandidatesOrMissingArtwork(): List<String> {
    val candidates = primaryArtworkCandidates
    if (candidates.isNotEmpty()) {
        return candidates
    }
    return listOfNotNull(missingArtworkUrl()).distinct()
}

private fun PinballGame.realPlayfieldCandidates(): List<String> =
    (preferredLocalPlayfieldCandidates + supportedSourcePlayfieldCandidates).distinct()

private fun PinballGame.realPlayfieldCandidatesOrMissingArtwork(): List<String> {
    val candidates = realPlayfieldCandidates()
    if (candidates.isNotEmpty()) {
        return candidates
    }
    return listOfNotNull(missingArtworkUrl()).distinct()
}

private fun PinballGame.fullscreenArtworkCandidatesOrMissingArtwork(): List<String> {
    if (actualFullscreenPlayfieldCandidates.isNotEmpty()) {
        return actualFullscreenPlayfieldCandidates
    }
    val candidates = realPlayfieldCandidates()
    if (candidates.isNotEmpty()) {
        return candidates
    }
    return listOfNotNull(missingArtworkUrl()).distinct()
}

internal fun PinballGame.cardArtworkCandidates(): List<String> =
    artworkCandidatesOrMissingArtwork()

internal fun PinballGame.libraryPlayfieldCandidates(): List<String> =
    realPlayfieldCandidatesOrMissingArtwork()

internal fun PinballGame.miniCardPlayfieldCandidates(): List<String> =
    realPlayfieldCandidatesOrMissingArtwork()

internal fun PinballGame.miniCardPlayfieldCandidate(): String? =
    miniCardPlayfieldCandidates().firstOrNull()

internal fun PinballGame.gameInlinePlayfieldCandidates(): List<String> =
    fullscreenArtworkCandidatesOrMissingArtwork()

internal fun PinballGame.detailArtworkCandidates(): List<String> =
    artworkCandidatesOrMissingArtwork()

internal fun PinballGame.fullscreenPlayfieldCandidates(): List<String> =
    fullscreenArtworkCandidatesOrMissingArtwork()

internal fun PinballGame.resolvedPlayfieldCandidates(liveStatus: LivePlayfieldStatus?): List<String> =
    when {
        profPlayfieldCandidates(liveStatus).isNotEmpty() -> profPlayfieldCandidates(liveStatus)
        localFallbackPlayfieldCandidates.isNotEmpty() -> localFallbackPlayfieldCandidates
        opdbPlayfieldCandidates(liveStatus).isNotEmpty() -> opdbPlayfieldCandidates(liveStatus)
        else -> emptyList()
    }

internal fun PinballGame.profPlayfieldCandidatesForOptions(liveStatus: LivePlayfieldStatus?): List<String> =
    profPlayfieldCandidates(liveStatus)

internal fun PinballGame.profPlayfieldBaseCandidatesForLabel(): List<String> =
    profPlayfieldBaseCandidates

internal fun PinballGame.localFallbackPlayfieldCandidatesForLabel(): List<String> =
    localFallbackPlayfieldCandidates

internal fun PinballGame.opdbPlayfieldCandidatesForOptions(liveStatus: LivePlayfieldStatus?): List<String> =
    opdbPlayfieldCandidates(liveStatus)

internal fun isOpdbPlayfieldCandidateUrl(url: String?): Boolean =
    isOpdbPlayfieldUrl(url)

internal fun isOpdbPlayfieldUrl(url: String?): Boolean {
    val resolved = url ?: return false
    return runCatching {
        val parsed = URL(resolved)
        parsed.host?.contains("opdb.org", ignoreCase = true) == true
    }.getOrDefault(false)
}

private fun missingArtworkUrl(): String? =
    resolveLibraryUrl(libraryMissingArtworkPath)
