package com.pillyliu.pinprofandroid.library

private val curatedModernManufacturerNames = listOf(
    "stern",
    "stern pinball",
    "jersey jack pinball",
    "chicago gaming",
    "american pinball",
    "spooky pinball",
    "multimorphic",
    "barrels of fun",
    "dutch pinball",
    "pinball brothers",
    "turner pinball",
    "pinprof labs",
)

private val curatedModernManufacturerRanks = curatedModernManufacturerNames
    .mapIndexed { index, name -> name to (index + 1) }
    .toMap()

internal fun buildCatalogManufacturerRecordsFromMachines(
    machines: List<CatalogMachineRecord>,
): List<CatalogManufacturerRecord> {
    val grouped = machines
        .mapNotNull { machine ->
            val manufacturerId = normalizedOptionalString(machine.manufacturerId)
            val manufacturerName = normalizedOptionalString(machine.manufacturerName)
            if (manufacturerId == null || manufacturerName == null) null
            else Triple(manufacturerId, manufacturerName, machine)
        }
        .groupBy { it.first }

    return grouped.mapNotNull { (manufacturerId, entries) ->
        val manufacturerName = entries.firstOrNull()?.second ?: return@mapNotNull null
        val modernRank = curatedModernManufacturerRanks[manufacturerName.trim().lowercase()]
        CatalogManufacturerRecord(
            id = manufacturerId,
            name = manufacturerName,
            isModern = modernRank != null,
            featuredRank = modernRank,
            gameCount = entries.map { (_, _, machine) -> machine.practiceIdentity }.toSet().size,
        )
    }.sortedWith(
        compareBy<CatalogManufacturerRecord> { if (it.isModern == true) 0 else 1 }
            .thenBy { it.featuredRank ?: Int.MAX_VALUE }
            .thenBy { it.name.lowercase() },
    )
}

internal fun decodeCatalogManufacturerOptionsFromOPDBExport(
    raw: String,
    practiceIdentityCurationsRaw: String? = null,
): List<CatalogManufacturerOption> {
    val manufacturers = buildCatalogManufacturerRecordsFromMachines(
        decodeOPDBExportCatalogMachines(raw, practiceIdentityCurationsRaw),
    )
    return manufacturers.map { manufacturer ->
        CatalogManufacturerOption(
            id = manufacturer.id,
            name = manufacturer.name,
            gameCount = manufacturer.gameCount ?: 0,
            isModern = manufacturer.isModern == true,
            featuredRank = manufacturer.featuredRank,
            sortBucket = if (manufacturer.isModern == true) 0 else 1,
        )
    }
}
