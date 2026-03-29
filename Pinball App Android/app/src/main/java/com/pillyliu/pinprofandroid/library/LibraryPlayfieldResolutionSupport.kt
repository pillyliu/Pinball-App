package com.pillyliu.pinprofandroid.library

internal data class PlayfieldOption(
    val label: String,
    val candidates: List<String>,
)

internal val PinballGame.localRulesheetChipLabel: String
    get() = if (usesBundledOnlyAppAssetException) "Local" else "PinProf"

internal val PinballGame.localPlayfieldChipLabel: String
    get() = if (usesBundledOnlyAppAssetException) "Local" else "PinProf"

internal fun PinballGame.libraryPlayfieldCandidate(): String? =
    libraryPlayfieldCandidates().firstOrNull()

internal val PinballGame.hasPlayfieldResource: Boolean
    get() = actualFullscreenPlayfieldCandidates.isNotEmpty()

internal fun PinballGame.resolvedPlayfieldButtonLabel(liveStatus: LivePlayfieldStatus?): String =
    when (liveStatus?.effectiveKind) {
        LivePlayfieldKind.PILLYLIU -> if (usesBundledOnlyAppAssetException) localPlayfieldChipLabel else "PinProf"
        LivePlayfieldKind.OPDB -> "OPDB"
        LivePlayfieldKind.EXTERNAL -> playfieldButtonLabel
        LivePlayfieldKind.MISSING -> if (actualFullscreenPlayfieldCandidates.isEmpty()) "Unavailable" else playfieldButtonLabel
        null -> playfieldButtonLabel
    }

internal fun PinballGame.resolvedPlayfieldOptions(liveStatus: LivePlayfieldStatus?): List<PlayfieldOption> {
    val options = mutableListOf<PlayfieldOption>()
    val usedCandidates = mutableSetOf<String>()
    if (liveStatus?.effectiveKind == LivePlayfieldKind.MISSING &&
        actualFullscreenPlayfieldCandidates.isEmpty() &&
        resolvedPlayfieldCandidates(liveStatus).isEmpty()
    ) {
        return emptyList()
    }

    fun appendOption(label: String, candidates: List<String>) {
        val filtered = candidates.filter { candidate -> usedCandidates.add(candidate) }
        if (filtered.isEmpty()) return
        options += PlayfieldOption(label = label, candidates = filtered)
    }

    val profCandidates = profPlayfieldCandidatesForOptions(liveStatus)
    if (profCandidates.isNotEmpty()) {
        appendOption(label = "PinProf", candidates = profCandidates)
    } else {
        appendOption(label = localPlayfieldChipLabel, candidates = localFallbackPlayfieldCandidatesForLabel())
    }

    appendOption(label = "OPDB", candidates = opdbPlayfieldCandidatesForOptions(liveStatus))
    return options
}

internal val PinballGame.playfieldButtonLabel: String
    get() {
        val explicitLabel = playfieldSourceLabel?.trim()?.takeIf { it.isNotEmpty() }
        if (explicitLabel != null) {
            val normalized = explicitLabel.lowercase()
            return when {
                "opdb" in normalized -> "OPDB"
                "prof" in normalized -> "PinProf"
                "local" in normalized -> localPlayfieldChipLabel
                "remote" in normalized || "external" in normalized -> "View"
                else -> explicitLabel
            }
        }
        if (profPlayfieldBaseCandidatesForLabel().isNotEmpty()) {
            return "PinProf"
        }
        if (localFallbackPlayfieldCandidatesForLabel().isNotEmpty()) {
            return localPlayfieldChipLabel
        }
        val resolved = resolveLibraryUrl(playfieldImageUrl)
        if (resolved != null) {
            return when {
                isPinProfPlayfieldUrl(resolved) -> "PinProf"
                isOpdbPlayfieldCandidateUrl(resolved) -> "OPDB"
                else -> "View"
            }
        }
        if (isOpdbPlayfieldCandidateUrl(alternatePlayfieldImageSourceUrl)) {
            return "OPDB"
        }
        return "View"
    }
