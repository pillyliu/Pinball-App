package com.pillyliu.pinprofandroid.library

internal data class ReferenceLink(
    val label: String,
    val url: String? = null,
) {
    val embeddedRulesheetSource: RulesheetRemoteSource?
        get() {
            val destination = resolveLibraryUrl(destinationUrl) ?: return null
            val normalized = destination.lowercase()
            if (normalized.contains("pinballnews.com")) return null
            return when {
                normalized.contains("tiltforums.com") -> RulesheetRemoteSource.TiltForums(destination)
                normalized.contains("rules.silverballmania.com") ||
                    normalized.contains("silverballmania.com") ||
                    normalized.contains("flippers.be") ||
                    label.lowercase().contains("(bob)") -> RulesheetRemoteSource.BobsGuide(destination)
                normalized.contains("pinballprimer.github.io") ||
                    normalized.contains("pinballprimer.com") ||
                    label.lowercase().contains("(pp)") -> RulesheetRemoteSource.PinballPrimer(destination)
                normalized.contains("replayfoundation.org") ||
                    normalized.contains("pinball.org") ||
                    label.lowercase().contains("(papa)") -> RulesheetRemoteSource.Papa(destination)
                else -> null
            }
        }

    val destinationUrl: String?
        get() = url?.trim()?.ifBlank { null }
}

internal enum class RulesheetSourceKind(val rank: Int, val shortLabel: String) {
    LOCAL(0, "Local"),
    TF(1, "TF"),
    PROF(2, "PinProf"),
    BOB(3, "Bob"),
    PAPA(4, "PAPA"),
    PP(5, "PP"),
    OPDB(6, "OPDB"),
    OTHER(7, "Other"),
}

internal val ReferenceLink.rulesheetSourceKind: RulesheetSourceKind
    get() {
        val normalizedLabel = label.lowercase()
        val resolved = resolveLibraryUrl(destinationUrl)
        return when {
            isPinProfRulesheetUrl(resolved) || "(prof)" in normalizedLabel -> RulesheetSourceKind.PROF
            resolved?.contains("tiltforums.com", ignoreCase = true) == true || "(tf)" in normalizedLabel -> RulesheetSourceKind.TF
            resolved?.contains("pinballprimer.github.io", ignoreCase = true) == true ||
                resolved?.contains("pinballprimer.com", ignoreCase = true) == true ||
                "(pp)" in normalizedLabel -> RulesheetSourceKind.PP
            resolved?.contains("replayfoundation.org", ignoreCase = true) == true ||
                resolved?.contains("pinball.org", ignoreCase = true) == true ||
                "(papa)" in normalizedLabel -> RulesheetSourceKind.PAPA
            resolved?.contains("silverballmania.com", ignoreCase = true) == true ||
                resolved?.contains("flippers.be", ignoreCase = true) == true ||
                "(bob)" in normalizedLabel -> RulesheetSourceKind.BOB
            "(opdb)" in normalizedLabel -> RulesheetSourceKind.OPDB
            "(local)" in normalizedLabel || "(source)" in normalizedLabel -> RulesheetSourceKind.LOCAL
            resolved == null && embeddedRulesheetSource == null -> RulesheetSourceKind.LOCAL
            else -> RulesheetSourceKind.OTHER
        }
    }

internal val ReferenceLink.shortRulesheetTitle: String
    get() = rulesheetSourceKind.shortLabel

internal data class Video(val kind: String?, val label: String?, val url: String?)

internal data class PlayableVideo(val id: String, val label: String) {
    val watchUrl: String
        get() = "https://www.youtube.com/watch?v=$id"

    val thumbnailUrl: String
        get() = "https://i.ytimg.com/vi/$id/hqdefault.jpg"
}

internal data class YouTubeVideoMetadata(val title: String, val channelName: String?)

sealed interface RulesheetRemoteSource {
    val url: String
    val sourceName: String
    val originalLinkLabel: String
    val detailsText: String

    data class TiltForums(override val url: String) : RulesheetRemoteSource {
        override val sourceName: String = "Tilt Forums community rulesheet"
        override val originalLinkLabel: String = "Original thread"
        override val detailsText: String = "License/source terms remain with Tilt Forums and the original authors."
    }

    data class BobsGuide(override val url: String) : RulesheetRemoteSource {
        override val sourceName: String = "Silverball Rules (Bob Matthews source)"
        override val originalLinkLabel: String = "Original page"
        override val detailsText: String = "Preserve source attribution and any author/site rights notes from the original page."
    }

    data class PinballPrimer(override val url: String) : RulesheetRemoteSource {
        override val sourceName: String = "Pinball Primer"
        override val originalLinkLabel: String = "Original page"
        override val detailsText: String = "Preserve source attribution and any author/site rights notes from the original page."
    }

    data class Papa(override val url: String) : RulesheetRemoteSource {
        override val sourceName: String = "PAPA / pinball.org rulesheet archive"
        override val originalLinkLabel: String = "Original page"
        override val detailsText: String = "Preserve source attribution and any author/site rights notes from the original page."
    }
}
