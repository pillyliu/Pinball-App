package com.pillyliu.pinprofandroid.settings

import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption

internal enum class ManufacturerBucket(val label: String) {
    MODERN("Modern"),
    CLASSIC("Classic"),
    OTHER("Other"),
}

internal fun List<CatalogManufacturerOption>.filteredForBucket(
    bucket: ManufacturerBucket,
): List<CatalogManufacturerOption> {
    val classicTopIds = filter { !it.isModern }
        .sortedWith(compareByDescending<CatalogManufacturerOption> { it.gameCount }.thenBy { it.name.lowercase() })
        .take(20)
        .map { it.id }
        .toSet()
    return when (bucket) {
        ManufacturerBucket.MODERN -> filter { it.isModern }
        ManufacturerBucket.CLASSIC -> filter { it.id in classicTopIds }
            .sortedWith(compareByDescending<CatalogManufacturerOption> { it.gameCount }.thenBy { it.name.lowercase() })
        ManufacturerBucket.OTHER -> filter { !it.isModern && it.id !in classicTopIds }
    }
}
