package com.pillyliu.pinprofandroid.library

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.security.MessageDigest

internal suspend fun openLibrarySeedDatabase(context: Context): SQLiteDatabase {
    val file = ensureLibrarySeedDatabaseReady(context)
    return SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)
}

internal suspend fun ensureLibrarySeedDatabaseReady(context: Context): File {
    val dir = File(context.filesDir, "pinball-seed-db")
    if (!dir.exists()) dir.mkdirs()
    val target = File(dir, LibrarySeedDatabase.SEED_FILE_NAME)
    val bytes = context.assets.open(LibrarySeedDatabase.SEED_ASSET_PATH).use { it.readBytes() }
    if (!target.exists() || target.sha256Hex() != bytes.sha256Hex()) {
        target.writeBytes(bytes)
    }
    return target
}

internal fun loadLibrarySeedManufacturerOptions(database: SQLiteDatabase): List<CatalogManufacturerOption> {
    database.rawQuery(
        """
        SELECT
            manufacturers.id,
            manufacturers.name,
            COUNT(DISTINCT COALESCE(machines.opdb_group_id, machines.practice_identity)) AS group_count,
            manufacturers.is_modern,
            manufacturers.featured_rank,
            manufacturers.sort_bucket
        FROM manufacturers
        LEFT JOIN machines ON machines.manufacturer_id = manufacturers.id
        GROUP BY manufacturers.id, manufacturers.name, manufacturers.is_modern, manufacturers.featured_rank, manufacturers.sort_bucket
        ORDER BY sort_bucket ASC, COALESCE(featured_rank, 9999) ASC, sort_name ASC
        """.trimIndent(),
        emptyArray(),
    ).use { cursor ->
        return buildList {
            while (cursor.moveToNext()) {
                add(
                    CatalogManufacturerOption(
                        id = cursor.getString(0).orEmpty(),
                        name = cursor.getString(1).orEmpty(),
                        gameCount = cursor.getInt(2),
                        isModern = cursor.getInt(3) > 0,
                        featuredRank = cursor.getIntOrNull(4),
                        sortBucket = cursor.getInt(5),
                    ),
                )
            }
        }
    }
}

internal fun loadLibrarySeedBuiltInSources(database: SQLiteDatabase): List<LibrarySource> {
    database.rawQuery(
        "SELECT id, name, type FROM built_in_sources ORDER BY sort_rank ASC",
        emptyArray(),
    ).use { cursor ->
        return buildList {
            while (cursor.moveToNext()) {
                add(
                    LibrarySource(
                        id = cursor.getString(0).orEmpty(),
                        name = cursor.getString(1).orEmpty(),
                        type = LibrarySourceType.fromRaw(cursor.getString(2)) ?: LibrarySourceType.VENUE,
                    ),
                )
            }
        }
    }
}

private fun File.sha256Hex(): String {
    if (!exists()) return ""
    return readBytes().sha256Hex()
}

private fun ByteArray.sha256Hex(): String {
    val digest = MessageDigest.getInstance("SHA-256").digest(this)
    return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
}
