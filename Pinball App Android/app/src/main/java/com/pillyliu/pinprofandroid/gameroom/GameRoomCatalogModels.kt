package com.pillyliu.pinprofandroid.gameroom

internal data class GameRoomCatalogGame(
    val catalogGameID: String,
    val opdbID: String,
    val canonicalPracticeIdentity: String,
    val displayTitle: String,
    val displayVariant: String?,
    val manufacturerID: String?,
    val manufacturer: String?,
    val year: Int?,
    val primaryImageUrl: String?,
    val opdbType: String?,
    val opdbDisplay: String?,
    val opdbShortname: String?,
    val opdbCommonName: String?,
)

internal data class GameRoomCatalogManufacturerOption(
    val id: String,
    val name: String,
    val isModern: Boolean,
    val featuredRank: Int?,
)

internal data class GameRoomCatalogArt(
    val primaryImageUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldImageUrl: String?,
    val playfieldImageLargeUrl: String?,
)

internal data class GameRoomCatalogSlugMatch(
    val catalogGameID: String,
    val canonicalPracticeIdentity: String,
    val variant: String?,
)

internal data class GameRoomCatalogMachineRecord(
    val groupID: String,
    val opdbID: String,
    val practiceIdentity: String,
    val slug: String,
    val machineName: String,
    val variant: String?,
    val manufacturer: String?,
    val year: Int?,
    val primaryImageUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldImageUrl: String?,
    val playfieldImageLargeUrl: String?,
)

internal data class ParsedCatalogName(
    val displayTitle: String,
    val displayVariant: String?,
)
