package com.pillyliu.pinprofandroid.library

private const val SYNTHETIC_PINPROF_LABS_GROUP_ID = "G900001"
private const val SYNTHETIC_PINPROF_LABS_MACHINE_ID = "G900001-1"
private const val SYNTHETIC_PINPROF_LABS_MANUFACTURER_ID = "manufacturer-9001"
private const val SYNTHETIC_PINPROF_LABS_BACKGLASS_PATH = "/pinball/images/backglasses/G900001-1-backglass.webp"
private const val SYNTHETIC_PINPROF_LABS_PLAYFIELD_MEDIUM_PATH = "/pinball/images/playfields/G900001-1-playfield_700.webp"
private const val SYNTHETIC_PINPROF_LABS_PLAYFIELD_LARGE_PATH = "/pinball/images/playfields/G900001-1-playfield_1400.webp"

private fun syntheticPinProfLabsCatalogMachineRecord(): CatalogMachineRecord =
    CatalogMachineRecord(
        practiceIdentity = SYNTHETIC_PINPROF_LABS_GROUP_ID,
        opdbMachineId = SYNTHETIC_PINPROF_LABS_MACHINE_ID,
        opdbGroupId = SYNTHETIC_PINPROF_LABS_GROUP_ID,
        slug = "pinprof",
        name = "PinProf: The Final Exam",
        variant = null,
        manufacturerId = SYNTHETIC_PINPROF_LABS_MANUFACTURER_ID,
        manufacturerName = "PinProf Labs",
        year = 1982,
        opdbName = "PinProf: The Final Exam",
        opdbCommonName = "PinProf: The Final Exam",
        opdbShortname = "PinProf",
        opdbDescription = "A long-lost pinball treasure.",
        opdbType = "ss",
        opdbDisplay = "alphanumeric",
        opdbPlayerCount = 4,
        opdbManufactureDate = "1982-09-03",
        opdbIpdbId = null,
        opdbGroupShortname = "PinProf",
        opdbGroupDescription = "A long-lost pinball treasure.",
        primaryImageMediumUrl = SYNTHETIC_PINPROF_LABS_BACKGLASS_PATH,
        primaryImageLargeUrl = SYNTHETIC_PINPROF_LABS_BACKGLASS_PATH,
        playfieldImageMediumUrl = SYNTHETIC_PINPROF_LABS_PLAYFIELD_MEDIUM_PATH,
        playfieldImageLargeUrl = SYNTHETIC_PINPROF_LABS_PLAYFIELD_LARGE_PATH,
    )

internal fun appendSyntheticPinProfLabsMachine(machines: List<CatalogMachineRecord>): List<CatalogMachineRecord> {
    val hasSynthetic = machines.any { machine ->
        machine.opdbMachineId?.trim()?.equals(SYNTHETIC_PINPROF_LABS_MACHINE_ID, ignoreCase = true) == true ||
            machine.practiceIdentity.trim().equals(SYNTHETIC_PINPROF_LABS_GROUP_ID, ignoreCase = true)
    }
    return if (hasSynthetic) machines else machines + syntheticPinProfLabsCatalogMachineRecord()
}
