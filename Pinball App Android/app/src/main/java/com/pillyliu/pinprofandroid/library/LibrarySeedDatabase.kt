package com.pillyliu.pinprofandroid.library

import android.content.Context
import android.database.sqlite.SQLiteDatabase

internal data class LegacyCatalogExtraction(
    val payload: ParsedLibraryData,
    val state: LibrarySourceState,
)

internal data class CatalogManufacturerOption(
    val id: String,
    val name: String,
    val gameCount: Int,
    val isModern: Boolean,
    val featuredRank: Int?,
    val sortBucket: Int,
)

internal object LibrarySeedDatabase {
    internal const val SEED_FILE_NAME = "pinball_library_seed_v1.sqlite"
    internal const val SEED_ASSET_PATH = "starter-pack/pinball/data/$SEED_FILE_NAME"

    suspend fun loadExtraction(context: Context): LegacyCatalogExtraction {
        val db = openLibrarySeedDatabase(context)
        db.use { database ->
            val builtInSources = loadLibrarySeedBuiltInSources(database)
            val builtInGames = loadLibrarySeedBuiltInGames(database)
            val importedSources = ImportedSourcesStore.load(context)
            val importedGames = loadLibrarySeedImportedGames(database, importedSources)
            val payload = ParsedLibraryData(
                games = builtInGames + importedGames,
                sources = dedupedSources(
                    builtInSources + importedSources.map { source ->
                        LibrarySource(id = source.id, name = source.name, type = source.type)
                    },
                ),
            )
            val payloadWithGameRoom = addSeedGameRoomOverlay(context = context, basePayload = payload)
            val state = LibrarySourceStateStore.synchronize(context, payloadWithGameRoom.sources)
            return LegacyCatalogExtraction(
                payload = filterSeedLibraryPayload(payloadWithGameRoom, state),
                state = state,
            )
        }
    }

    suspend fun loadManufacturerOptions(context: Context): List<CatalogManufacturerOption> {
        val db = openLibrarySeedDatabase(context)
        db.use { database ->
            return loadLibrarySeedManufacturerOptions(database)
        }
    }
}
