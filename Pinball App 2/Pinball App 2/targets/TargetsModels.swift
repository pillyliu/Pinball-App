import Foundation

struct LPLTargetRow: Identifiable {
    let target: LPLTarget
    let area: String?
    let areaOrder: Int?
    let bank: Int?
    let group: Int?
    let position: Int?
    let libraryOrder: Int
    let fallbackOrder: Int

    var id: String { target.id }
}

enum TargetsSortMode: String, CaseIterable, Identifiable {
    case location
    case bank
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location:
            return "Area"
        case .bank:
            return "Bank"
        case .alphabetical:
            return "A-Z"
        }
    }

    static var widestTitle: String {
        allCases.map(\.title).max(by: { $0.count < $1.count }) ?? "A-Z"
    }
}

struct LPLTarget: Identifiable {
    let game: String
    let great: Int64
    let main: Int64
    let floor: Int64

    var id: String { game }

    static let rows: [LPLTarget] = [
        .init(game: "Avengers: Infinity Quest", great: 173_438_323, main: 88_524_766, floor: 39_851_803),
        .init(game: "Kiss", great: 198_506_351, main: 97_959_214, floor: 36_089_540),
        .init(game: "Cactus Canyon", great: 47_757_329, main: 27_567_623, floor: 14_452_827),
        .init(game: "Uncanny X-Men", great: 225_283_763, main: 108_327_713, floor: 63_821_317),
        .init(game: "Jurassic Park (Stern 2019)", great: 319_640_285, main: 126_326_601, floor: 58_637_502),
        .init(game: "Tales of the Arabian Nights", great: 15_762_751, main: 9_345_267, floor: 5_556_107),
        .init(game: "The Munsters", great: 82_533_584, main: 34_629_771, floor: 17_369_006),
        .init(game: "Medieval Madness", great: 46_553_686, main: 29_361_166, floor: 14_409_182),
        .init(game: "AC/DC", great: 78_885_896, main: 46_469_006, floor: 19_681_744),
        .init(game: "Star Wars (2017)", great: 1_096_631_040, main: 647_340_570, floor: 319_976_625),
        .init(game: "James Bond", great: 358_874_928, main: 200_180_907, floor: 82_457_332),
        .init(game: "Indiana Jones", great: 291_687_662, main: 177_986_136, floor: 81_470_450),
        .init(game: "Metallica", great: 77_377_060, main: 43_847_284, floor: 17_158_523),
        .init(game: "Godzilla", great: 646_887_088, main: 286_268_525, floor: 123_536_572),
        .init(game: "Dungeons and Dragons", great: 418_422_050, main: 182_415_065, floor: 123_730_030),
        .init(game: "Game of Thrones", great: 949_759_118, main: 326_708_555, floor: 99_242_412),
        .init(game: "The Simpsons Pinball Party", great: 21_891_586, main: 14_562_712, floor: 6_092_065),
        .init(game: "The Getaway", great: 101_330_386, main: 59_599_913, floor: 31_934_372),
        .init(game: "Monster Bash", great: 140_207_751, main: 77_290_194, floor: 33_846_092),
        .init(game: "Venom", great: 305_244_276, main: 125_417_334, floor: 53_133_636),
        .init(game: "King Kong", great: 446_519_150, main: 105_609_360, floor: 76_835_450),
        .init(game: "Rush", great: 339_038_483, main: 95_538_978, floor: 50_832_140),
        .init(game: "Deadpool", great: 358_162_103, main: 146_074_855, floor: 69_866_975),
        .init(game: "John Wick", great: 177_005_389, main: 142_548_085, floor: 60_787_832),
        .init(game: "Attack From Mars", great: 5_521_789_989, main: 3_115_115_261, floor: 1_766_530_554),
        .init(game: "Foo Fighters", great: 437_507_022, main: 118_516_715, floor: 52_503_338),
        .init(game: "The Mandalorian", great: 246_663_781, main: 139_131_898, floor: 54_050_835),
        .init(game: "Tron", great: 32_748_236, main: 20_993_568, floor: 12_428_468),
        .init(game: "TMNT", great: 20_008_656, main: 13_337_749, floor: 7_479_849),
        .init(game: "Ghostbusters", great: 721_735_856, main: 238_692_633, floor: 85_037_818),
        .init(game: "Stranger Things", great: 269_360_318, main: 180_571_244, floor: 110_080_667),
        .init(game: "Star Trek", great: 115_837_761, main: 68_886_970, floor: 27_550_663),
        .init(game: "Pulp Fiction", great: 2_137_055, main: 1_124_280, floor: 708_345),
        .init(game: "Elvira's House of Horrors", great: 68_770_087, main: 38_590_427, floor: 18_216_957),
        .init(game: "Black Knight: Sword of Rage", great: 160_663_925, main: 62_325_610, floor: 40_949_470),
        .init(game: "The Addams Family", great: 126_854_859, main: 77_135_279, floor: 38_020_435),
        .init(game: "Scared Stiff", great: 18_537_846, main: 13_171_488, floor: 6_029_324),
        .init(game: "Fall of the Empire", great: 548_469_290, main: 308_139_210, floor: 40_719_400),
        .init(game: "Jaws", great: 523_921_050, main: 325_577_015, floor: 155_754_968)
    ]
}

extension Int64 {
    var formattedTargetScore: String {
        self.formatted(.number.grouping(.automatic))
    }
}
