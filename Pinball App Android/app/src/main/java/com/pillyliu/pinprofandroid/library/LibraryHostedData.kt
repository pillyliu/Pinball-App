package com.pillyliu.pinprofandroid.library

import android.content.Context
import com.pillyliu.pinprofandroid.data.PinballDataCache

internal const val HOSTED_LIBRARY_REFRESH_INTERVAL_MS = 24L * 60L * 60L * 1000L
internal const val hostedLibraryPath = "/pinball/data/pinball_library_v3.json"
internal const val hostedOPDBCatalogPath = "/pinball/data/opdb_catalog_v1.json"
internal const val hostedLibraryOverridesPath = "/pinball/data/pinball_library_seed_overrides_v1.json"
internal val HOSTED_LIBRARY_PATHS = listOf(
    hostedLibraryPath,
    hostedOPDBCatalogPath,
    hostedLibraryOverridesPath,
)

internal suspend fun loadHostedLibraryExtraction(context: Context): LegacyCatalogExtraction {
    val libraryCached = PinballDataCache.loadText(
        url = LIBRARY_URL,
        allowMissing = false,
        maxCacheAgeMs = HOSTED_LIBRARY_REFRESH_INTERVAL_MS,
    )
    val opdbCached = PinballDataCache.loadText(
        url = OPDB_CATALOG_URL,
        allowMissing = true,
        maxCacheAgeMs = HOSTED_LIBRARY_REFRESH_INTERVAL_MS,
    )
    val libraryText = libraryCached.text ?: error("Missing library payload")
    val opdbText = opdbCached.text?.takeIf { it.isNotBlank() }
    val overridesText = loadHostedLibraryOverridesText()
    return if (opdbText != null) {
        decodeMergedLibraryPayloadWithState(context, libraryText, opdbText, overridesText)
    } else {
        val bundledOpdbText = loadBundledPinballText(context, "/pinball/data/opdb_catalog_v1.json")
        if (!bundledOpdbText.isNullOrBlank()) {
            decodeMergedLibraryPayloadWithState(
                context,
                libraryText,
                bundledOpdbText,
                overridesText ?: loadBundledPinballText(context, hostedLibraryOverridesPath),
            )
        } else {
            LibrarySeedDatabase.loadExtraction(context)
        }
    }
}

internal suspend fun warmHostedLibraryOverrides() {
    loadHostedLibraryOverridesText()
}

private suspend fun loadHostedLibraryOverridesText(): String? {
    return runCatching {
        if (PinballDataCache.hasRemoteUpdate(hostedLibraryOverridesPath)) {
            PinballDataCache.forceRefreshText(
                url = hostedLibraryOverridesPath,
                allowMissing = true,
            ).text
        } else {
            PinballDataCache.loadText(
                url = hostedLibraryOverridesPath,
                allowMissing = true,
            ).text
        }
    }.recoverCatching {
        PinballDataCache.loadText(
            url = hostedLibraryOverridesPath,
            allowMissing = true,
        ).text
    }.getOrNull()?.takeIf { it.isNotBlank() }
}

internal fun loadBundledLibraryExtraction(context: Context): LegacyCatalogExtraction? {
    val libraryText = loadBundledPinballText(context, hostedLibraryPath) ?: return null
    val opdbText = loadBundledPinballText(context, hostedOPDBCatalogPath)
    val overridesText = loadBundledPinballText(context, hostedLibraryOverridesPath)
    return if (!opdbText.isNullOrBlank()) {
        decodeMergedLibraryPayloadWithState(context, libraryText, opdbText, overridesText)
    } else {
        decodeLibraryPayloadWithState(context, libraryText)
    }
}

internal fun loadBundledPinballText(context: Context, path: String): String? {
    val normalizedPath = if (path.startsWith("/")) path else "/$path"
    if (!normalizedPath.startsWith("/pinball/")) return null
    val assetPath = "starter-pack$normalizedPath"
    return runCatching {
        context.assets.open(assetPath).bufferedReader().use { it.readText() }
    }.getOrNull()
}

internal suspend fun loadHostedCatalogManufacturerOptions(context: Context): List<CatalogManufacturerOption> {
    val hostedOpdb = runCatching {
        PinballDataCache.loadText(url = OPDB_CATALOG_URL, allowMissing = true)
    }.getOrNull()
    val hostedText = hostedOpdb?.text?.takeIf { it.isNotBlank() }
    if (hostedText != null) {
        return decodeCatalogManufacturerOptions(hostedText)
    }

    return runCatching { LibrarySeedDatabase.loadManufacturerOptions(context) }
        .recoverCatching {
            val bundledText = loadBundledPinballText(context, hostedOPDBCatalogPath)
            if (!bundledText.isNullOrBlank()) {
                decodeCatalogManufacturerOptions(bundledText)
            } else {
                emptyList()
            }
        }
        .getOrElse { emptyList() }
}
