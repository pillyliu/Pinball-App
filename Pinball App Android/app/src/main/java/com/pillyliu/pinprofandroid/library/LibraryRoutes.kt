package com.pillyliu.pinprofandroid.library

import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.listSaver

internal sealed interface LibraryRoute {
    data object List : LibraryRoute
    data class Detail(val gameId: String) : LibraryRoute
    data class Rulesheet(
        val gameId: String,
        val sourceProvider: String?,
        val sourceUrl: String?,
    ) : LibraryRoute
    data class ExternalRulesheet(
        val gameId: String,
        val url: String,
    ) : LibraryRoute
    data class Playfield(
        val gameId: String,
        val imageUrls: kotlin.collections.List<String>,
    ) : LibraryRoute
}

internal val LibraryRouteSaver: Saver<LibraryRoute, Any> = listSaver(
    save = { route ->
        when (route) {
            LibraryRoute.List -> listOf("list")
            is LibraryRoute.Detail -> listOf("detail", route.gameId)
            is LibraryRoute.Rulesheet -> listOf("rulesheet", route.gameId, route.sourceProvider.orEmpty(), route.sourceUrl.orEmpty())
            is LibraryRoute.ExternalRulesheet -> listOf("external_rulesheet", route.gameId, route.url)
            is LibraryRoute.Playfield -> listOf("playfield", route.gameId) + route.imageUrls
        }
    },
    restore = { values ->
        when (values.firstOrNull() as? String) {
            "detail" -> (values.getOrNull(1) as? String)?.let(LibraryRoute::Detail)
            "rulesheet" -> {
                val gameId = values.getOrNull(1) as? String
                if (gameId == null) null else LibraryRoute.Rulesheet(
                    gameId = gameId,
                    sourceProvider = (values.getOrNull(2) as? String)?.ifBlank { null },
                    sourceUrl = (values.getOrNull(3) as? String)?.ifBlank { null },
                )
            }
            "external_rulesheet" -> {
                val gameId = values.getOrNull(1) as? String
                val url = values.getOrNull(2) as? String
                if (gameId == null || url.isNullOrBlank()) null else LibraryRoute.ExternalRulesheet(gameId, url)
            }
            "playfield" -> {
                val gameId = values.getOrNull(1) as? String
                if (gameId == null) null else LibraryRoute.Playfield(
                    gameId = gameId,
                    imageUrls = values.drop(2).mapNotNull { (it as? String)?.ifBlank { null } },
                )
            }
            else -> LibraryRoute.List
        }
    },
)

internal val LibraryRoute.gameId: String?
    get() = when (this) {
        LibraryRoute.List -> null
        is LibraryRoute.Detail -> gameId
        is LibraryRoute.Rulesheet -> gameId
        is LibraryRoute.ExternalRulesheet -> gameId
        is LibraryRoute.Playfield -> gameId
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
