package com.pillyliu.pinprofandroid.targets

internal data class LPLTarget(val game: String, val great: Long, val main: Long, val floor: Long)

internal data class TargetRow(
    val target: LPLTarget,
    val area: String?,
    val areaOrder: Int?,
    val bank: Int?,
    val group: Int?,
    val position: Int?,
    val libraryOrder: Int,
    val fallbackOrder: Int,
)

internal enum class TargetSortOption(val label: String) {
    LOCATION("Area"),
    BANK("Bank"),
    ALPHABETICAL("A-Z"),
}

internal enum class TargetColorRole { Great, Main, Floor }

internal val lplTargets = listOf(
    LPLTarget("Avengers: Infinity Quest", 173_438_323, 88_524_766, 39_851_803),
    LPLTarget("Kiss", 198_506_351, 97_959_214, 36_089_540),
    LPLTarget("Cactus Canyon", 47_757_329, 27_567_623, 14_452_827),
    LPLTarget("Uncanny X-Men", 225_283_763, 108_327_713, 63_821_317),
    LPLTarget("Jurassic Park (Stern 2019)", 319_640_285, 126_326_601, 58_637_502),
    LPLTarget("Tales of the Arabian Nights", 15_762_751, 9_345_267, 5_556_107),
    LPLTarget("The Munsters", 82_533_584, 34_629_771, 17_369_006),
    LPLTarget("Medieval Madness", 46_553_686, 29_361_166, 14_409_182),
    LPLTarget("AC/DC", 78_885_896, 46_469_006, 19_681_744),
    LPLTarget("Star Wars (2017)", 1_096_631_040, 647_340_570, 319_976_625),
    LPLTarget("James Bond", 358_874_928, 200_180_907, 82_457_332),
    LPLTarget("Indiana Jones", 291_687_662, 177_986_136, 81_470_450),
    LPLTarget("Metallica", 77_377_060, 43_847_284, 17_158_523),
    LPLTarget("Godzilla", 646_887_088, 286_268_525, 123_536_572),
    LPLTarget("Dungeons and Dragons", 418_422_050, 182_415_065, 123_730_030),
    LPLTarget("Game of Thrones", 949_759_118, 326_708_555, 99_242_412),
    LPLTarget("The Simpsons Pinball Party", 21_891_586, 14_562_712, 6_092_065),
    LPLTarget("The Getaway", 101_330_386, 59_599_913, 31_934_372),
    LPLTarget("Monster Bash", 140_207_751, 77_290_194, 33_846_092),
    LPLTarget("Venom", 305_244_276, 125_417_334, 53_133_636),
    LPLTarget("King Kong", 446_519_150, 105_609_360, 76_835_450),
    LPLTarget("Rush", 339_038_483, 95_538_978, 50_832_140),
    LPLTarget("Deadpool", 358_162_103, 146_074_855, 69_866_975),
    LPLTarget("John Wick", 177_005_389, 142_548_085, 60_787_832),
    LPLTarget("Attack From Mars", 5_521_789_989, 3_115_115_261, 1_766_530_554),
    LPLTarget("Foo Fighters", 437_507_022, 118_516_715, 52_503_338),
    LPLTarget("The Mandalorian", 246_663_781, 139_131_898, 54_050_835),
    LPLTarget("Tron", 32_748_236, 20_993_568, 12_428_468),
    LPLTarget("TMNT", 20_008_656, 13_337_749, 7_479_849),
    LPLTarget("Ghostbusters", 721_735_856, 238_692_633, 85_037_818),
    LPLTarget("Stranger Things", 269_360_318, 180_571_244, 110_080_667),
    LPLTarget("Star Trek", 115_837_761, 68_886_970, 27_550_663),
    LPLTarget("Pulp Fiction", 2_137_055, 1_124_280, 708_345),
    LPLTarget("Elvira's House of Horrors", 68_770_087, 38_590_427, 18_216_957),
    LPLTarget("Black Knight: Sword of Rage", 160_663_925, 62_325_610, 40_949_470),
    LPLTarget("The Addams Family", 126_854_859, 77_135_279, 38_020_435),
    LPLTarget("Scared Stiff", 18_537_846, 13_171_488, 6_029_324),
    LPLTarget("Fall of the Empire", 548_469_290, 308_139_210, 40_719_400),
    LPLTarget("Jaws", 523_921_050, 325_577_015, 155_754_968),
)
