package com.pillyliu.pinprofandroid.library

internal data class CatalogManufacturerRecord(
    val id: String,
    val name: String,
    val isModern: Boolean?,
    val featuredRank: Int?,
    val gameCount: Int?,
)

internal data class CatalogMachineRecord(
    val practiceIdentity: String,
    val opdbMachineId: String?,
    val opdbGroupId: String?,
    val slug: String,
    val name: String,
    val variant: String?,
    val manufacturerId: String?,
    val manufacturerName: String?,
    val year: Int?,
    val opdbName: String? = null,
    val opdbCommonName: String? = null,
    val opdbShortname: String? = null,
    val opdbDescription: String? = null,
    val opdbType: String? = null,
    val opdbDisplay: String? = null,
    val opdbPlayerCount: Int? = null,
    val opdbManufactureDate: String? = null,
    val opdbIpdbId: Int? = null,
    val opdbGroupShortname: String? = null,
    val opdbGroupDescription: String? = null,
    val primaryImageMediumUrl: String?,
    val primaryImageLargeUrl: String?,
    val playfieldImageMediumUrl: String?,
    val playfieldImageLargeUrl: String?,
)

internal data class CatalogRulesheetLinkRecord(
    val practiceIdentity: String,
    val provider: String,
    val label: String,
    val url: String?,
    val localPath: String?,
    val priority: Int?,
)

internal data class CatalogVideoLinkRecord(
    val practiceIdentity: String,
    val provider: String,
    val kind: String?,
    val label: String,
    val url: String?,
    val priority: Int?,
)

internal data class LegacyCuratedOverride(
    val practiceIdentity: String,
    var nameOverride: String? = null,
    var variantOverride: String? = null,
    var manufacturerOverride: String? = null,
    var yearOverride: Int? = null,
    var playfieldLocalPath: String? = null,
    var playfieldSourceUrl: String? = null,
    var gameinfoLocalPath: String? = null,
    var rulesheetLocalPath: String? = null,
    var rulesheetLinks: List<ReferenceLink> = emptyList(),
    var videos: List<Video> = emptyList(),
)
