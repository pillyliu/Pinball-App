package com.pillyliu.pinprofandroid.library

import android.database.sqlite.SQLiteDatabase

internal fun loadEntryScopedRulesheetLinks(
    database: SQLiteDatabase,
    tableName: String,
): Map<String, List<ReferenceLink>> {
    database.rawQuery(
        "SELECT library_entry_id, label, url FROM $tableName ORDER BY library_entry_id ASC, priority ASC",
        emptyArray(),
    ).use { cursor ->
        val out = linkedMapOf<String, MutableList<ReferenceLink>>()
        while (cursor.moveToNext()) {
            val entryId = cursor.getString(0).orEmpty()
            val label = cursor.getString(1).orEmpty()
            val url = cursor.getNullableString(2) ?: continue
            out.getOrPut(entryId) { mutableListOf() }.add(ReferenceLink(label = label, url = url))
        }
        return out.mapValues { (_, links) -> dedupeRulesheetLinks(links) }
    }
}

internal fun loadEntryScopedVideos(
    database: SQLiteDatabase,
    tableName: String,
): Map<String, List<Video>> {
    database.rawQuery(
        "SELECT library_entry_id, kind, label, url FROM $tableName ORDER BY library_entry_id ASC, priority ASC",
        emptyArray(),
    ).use { cursor ->
        val out = linkedMapOf<String, MutableList<Video>>()
        while (cursor.moveToNext()) {
            val entryId = cursor.getString(0).orEmpty()
            out.getOrPut(entryId) { mutableListOf() }.add(
                Video(
                    kind = cursor.getNullableString(1),
                    label = cursor.getNullableString(2),
                    url = cursor.getNullableString(3),
                ),
            )
        }
        return out
    }
}

internal fun loadPracticeScopedRulesheetLinks(
    database: SQLiteDatabase,
    tableName: String,
): Map<String, List<ReferenceLink>> {
    database.rawQuery(
        "SELECT practice_identity, label, url FROM $tableName ORDER BY practice_identity ASC, priority ASC",
        emptyArray(),
    ).use { cursor ->
        val out = linkedMapOf<String, MutableList<ReferenceLink>>()
        while (cursor.moveToNext()) {
            val practiceIdentity = cursor.getString(0)
            val label = cursor.getString(1)
            val url = cursor.getNullableString(2) ?: continue
            out.getOrPut(practiceIdentity) { mutableListOf() }.add(ReferenceLink(label = label, url = url))
        }
        return out.mapValues { (_, links) -> dedupeRulesheetLinks(links) }
    }
}

internal fun loadPracticeScopedVideos(
    database: SQLiteDatabase,
    tableName: String,
): Map<String, List<Video>> {
    database.rawQuery(
        "SELECT practice_identity, kind, label, url FROM $tableName ORDER BY practice_identity ASC, priority ASC",
        emptyArray(),
    ).use { cursor ->
        val out = linkedMapOf<String, MutableList<Video>>()
        while (cursor.moveToNext()) {
            val practiceIdentity = cursor.getString(0)
            out.getOrPut(practiceIdentity) { mutableListOf() }.add(
                Video(
                    kind = cursor.getNullableString(1),
                    label = cursor.getNullableString(2),
                    url = cursor.getNullableString(3),
                ),
            )
        }
        return out
    }
}

internal fun loadCatalogRulesheetRecords(database: SQLiteDatabase): Map<String, List<CatalogRulesheetLinkRecord>> {
    database.rawQuery(
        "SELECT practice_identity, provider, label, url, priority FROM catalog_rulesheet_links ORDER BY practice_identity ASC, priority ASC",
        emptyArray(),
    ).use { cursor ->
        val out = linkedMapOf<String, MutableList<CatalogRulesheetLinkRecord>>()
        while (cursor.moveToNext()) {
            val practiceIdentity = cursor.getString(0)
            out.getOrPut(practiceIdentity) { mutableListOf() }.add(
                CatalogRulesheetLinkRecord(
                    practiceIdentity = practiceIdentity,
                    provider = cursor.getString(1).orEmpty(),
                    label = cursor.getNullableString(2) ?: "Rulesheet",
                    url = cursor.getNullableString(3),
                    localPath = null,
                    priority = cursor.getIntOrNull(4),
                ),
            )
        }
        return out
    }
}

internal fun loadCatalogVideoRecords(database: SQLiteDatabase): Map<String, List<CatalogVideoLinkRecord>> {
    database.rawQuery(
        "SELECT practice_identity, kind, label, url, priority FROM catalog_video_links ORDER BY practice_identity ASC, priority ASC",
        emptyArray(),
    ).use { cursor ->
        val out = linkedMapOf<String, MutableList<CatalogVideoLinkRecord>>()
        while (cursor.moveToNext()) {
            val practiceIdentity = cursor.getString(0)
            val url = cursor.getNullableString(3) ?: continue
            out.getOrPut(practiceIdentity) { mutableListOf() }.add(
                CatalogVideoLinkRecord(
                    practiceIdentity = practiceIdentity,
                    provider = "matchplay",
                    kind = cursor.getNullableString(1),
                    label = cursor.getNullableString(2) ?: "Tutorial 1",
                    url = url,
                    priority = cursor.getIntOrNull(4),
                ),
            )
        }
        return out
    }
}
