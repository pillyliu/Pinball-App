package com.pillyliu.pinprofandroid.library

private enum class HostedImageCandidatePriority(val rank: Int) {
    PIN_PROF(0),
    OPDB_OR_EXTERNAL(1),
    OTHER(2),
}

internal fun prioritizeHostedImageCandidates(candidates: List<String>): List<String> =
    candidates.sortedWith(
        compareBy<String> { hostedImageCandidatePriority(it).rank }
            .thenBy { it },
    )

internal fun hostedImageLoadTimeoutMs(url: String): Long? =
    when (hostedImageCandidatePriority(url)) {
        HostedImageCandidatePriority.PIN_PROF -> 5_000L
        HostedImageCandidatePriority.OPDB_OR_EXTERNAL -> 6_000L
        HostedImageCandidatePriority.OTHER -> 6_000L
    }

private fun hostedImageCandidatePriority(url: String): HostedImageCandidatePriority {
    val lowercased = url.lowercase()
    return when {
        isPinProfPlayfieldUrl(url) -> HostedImageCandidatePriority.PIN_PROF
        "opdb.org" in lowercased || lowercased.startsWith("http://") || lowercased.startsWith("https://") ->
            HostedImageCandidatePriority.OPDB_OR_EXTERNAL
        else -> HostedImageCandidatePriority.OTHER
    }
}
