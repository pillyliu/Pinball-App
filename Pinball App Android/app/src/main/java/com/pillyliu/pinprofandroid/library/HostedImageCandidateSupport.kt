package com.pillyliu.pinprofandroid.library

private enum class HostedImageCandidatePriority(val rank: Int) {
    PIN_PROF_1400(0),
    PIN_PROF_700(1),
    PIN_PROF_ORIGINAL(2),
    OPDB_OR_EXTERNAL(3),
    OTHER(4),
}

internal fun prioritizeHostedImageCandidates(candidates: List<String>): List<String> =
    candidates.sortedWith(
        compareBy<String> { hostedImageCandidatePriority(it).rank }
            .thenBy { it },
    )

internal fun hostedImageLoadTimeoutMs(url: String): Long? =
    when (hostedImageCandidatePriority(url)) {
        HostedImageCandidatePriority.PIN_PROF_1400 -> 3_000L
        HostedImageCandidatePriority.PIN_PROF_700 -> 2_000L
        HostedImageCandidatePriority.PIN_PROF_ORIGINAL -> 5_000L
        HostedImageCandidatePriority.OPDB_OR_EXTERNAL -> 6_000L
        HostedImageCandidatePriority.OTHER -> 6_000L
    }

private fun hostedImageCandidatePriority(url: String): HostedImageCandidatePriority {
    val lowercased = url.lowercase()
    return when {
        "/pinball/images/playfields/" in lowercased && "_1400." in lowercased -> HostedImageCandidatePriority.PIN_PROF_1400
        "/pinball/images/playfields/" in lowercased && "_700." in lowercased -> HostedImageCandidatePriority.PIN_PROF_700
        "/pinball/images/playfields/" in lowercased -> HostedImageCandidatePriority.PIN_PROF_ORIGINAL
        "opdb.org" in lowercased || lowercased.startsWith("http://") || lowercased.startsWith("https://") ->
            HostedImageCandidatePriority.OPDB_OR_EXTERNAL
        else -> HostedImageCandidatePriority.OTHER
    }
}
