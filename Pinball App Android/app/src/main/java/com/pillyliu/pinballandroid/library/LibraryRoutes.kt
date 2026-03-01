package com.pillyliu.pinballandroid.library

import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.listSaver

internal sealed interface LibraryRoute {
    data object List : LibraryRoute
    data class Detail(val slug: String) : LibraryRoute
    data class Rulesheet(
        val slug: String,
        val sourceProvider: String?,
        val sourceUrl: String?,
    ) : LibraryRoute
    data class ExternalRulesheet(
        val slug: String,
        val url: String,
    ) : LibraryRoute
    data class Playfield(
        val slug: String,
        val imageUrl: String?,
    ) : LibraryRoute
}

internal val LibraryRouteSaver: Saver<LibraryRoute, Any> = listSaver(
    save = { route ->
        when (route) {
            LibraryRoute.List -> listOf("list")
            is LibraryRoute.Detail -> listOf("detail", route.slug)
            is LibraryRoute.Rulesheet -> listOf("rulesheet", route.slug, route.sourceProvider.orEmpty(), route.sourceUrl.orEmpty())
            is LibraryRoute.ExternalRulesheet -> listOf("external_rulesheet", route.slug, route.url)
            is LibraryRoute.Playfield -> listOf("playfield", route.slug, route.imageUrl.orEmpty())
        }
    },
    restore = { values ->
        when (values.firstOrNull() as? String) {
            "detail" -> (values.getOrNull(1) as? String)?.let(LibraryRoute::Detail)
            "rulesheet" -> {
                val slug = values.getOrNull(1) as? String
                if (slug == null) null else LibraryRoute.Rulesheet(
                    slug = slug,
                    sourceProvider = (values.getOrNull(2) as? String)?.ifBlank { null },
                    sourceUrl = (values.getOrNull(3) as? String)?.ifBlank { null },
                )
            }
            "external_rulesheet" -> {
                val slug = values.getOrNull(1) as? String
                val url = values.getOrNull(2) as? String
                if (slug == null || url.isNullOrBlank()) null else LibraryRoute.ExternalRulesheet(slug, url)
            }
            "playfield" -> {
                val slug = values.getOrNull(1) as? String
                if (slug == null) null else LibraryRoute.Playfield(
                    slug = slug,
                    imageUrl = (values.getOrNull(2) as? String)?.ifBlank { null },
                )
            }
            else -> LibraryRoute.List
        }
    },
)

internal val LibraryRoute.slug: String?
    get() = when (this) {
        LibraryRoute.List -> null
        is LibraryRoute.Detail -> slug
        is LibraryRoute.Rulesheet -> slug
        is LibraryRoute.ExternalRulesheet -> slug
        is LibraryRoute.Playfield -> slug
    }

internal fun LibraryRoute.rulesheetSource(): RulesheetRemoteSource? = when (this) {
    is LibraryRoute.Rulesheet -> when (sourceProvider) {
        "tiltforums" -> sourceUrl?.let { RulesheetRemoteSource.TiltForums(it) }
        "primer" -> sourceUrl?.let { RulesheetRemoteSource.PinballPrimer(it) }
        "bob" -> sourceUrl?.let { RulesheetRemoteSource.BobsGuide(it) }
        "papa" -> sourceUrl?.let { RulesheetRemoteSource.Papa(it) }
        else -> null
    }
    else -> null
}
