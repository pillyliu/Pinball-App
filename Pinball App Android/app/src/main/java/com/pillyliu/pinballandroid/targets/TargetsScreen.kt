package com.pillyliu.pinballandroid.targets

import android.content.res.Configuration
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.Border
import com.pillyliu.pinballandroid.ui.CardContainer
import com.pillyliu.pinballandroid.ui.CardBg
import com.pillyliu.pinballandroid.ui.SectionTitle
import org.json.JSONArray
import java.text.NumberFormat

private const val LIBRARY_URL = "https://pillyliu.com/pinball/data/pinball_library.json"

private data class LPLTarget(val game: String, val great: Long, val main: Long, val floor: Long)
private data class TargetRow(
    val target: LPLTarget,
    val bank: Int?,
    val group: Int?,
    val pos: Int?,
    val libraryOrder: Int,
    val fallbackOrder: Int,
)
private data class LibraryLookup(
    val index: Int,
    val normalizedName: String,
    val bank: Int?,
    val group: Int?,
    val pos: Int?,
)

private enum class TargetSortOption(val label: String) {
    LOCATION("Location"),
    BANK("Bank"),
    ALPHABETICAL("Alphabetical"),
}

@Composable
fun TargetsScreen(contentPadding: PaddingValues) {
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    var rows by remember {
        mutableStateOf(
            lplTargets.mapIndexed { idx, t ->
                TargetRow(t, null, null, null, Int.MAX_VALUE, idx)
            },
        )
    }
    var sortOptionName by rememberSaveable { mutableStateOf(TargetSortOption.LOCATION.name) }
    var selectedBank by rememberSaveable { mutableStateOf<Int?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val sortOption = remember(sortOptionName) { TargetSortOption.valueOf(sortOptionName) }
    val bankOptions = remember(rows) { rows.mapNotNull { it.bank }.toSet().sorted() }
    val sortedRows = remember(rows, sortOption) { sortRows(rows, sortOption) }
    val filteredRows = remember(sortedRows, selectedBank) {
        if (selectedBank == null) sortedRows else sortedRows.filter { it.bank == selectedBank }
    }

    LaunchedEffect(Unit) {
        try {
            val cached = PinballDataCache.passthroughOrCachedText(LIBRARY_URL)
            val libraryGames = JSONArray(cached.text.orEmpty())
            val normalizedLibrary = (0 until libraryGames.length()).map { index ->
                val item = libraryGames.getJSONObject(index)
                LibraryLookup(
                    index = index,
                    normalizedName = normalize(item.optString("name")),
                    bank = item.optInt("bank").takeIf { it > 0 },
                    group = item.optInt("group").takeIf { it > 0 },
                    pos = item.optInt("pos").takeIf { it > 0 },
                )
            }

            val merged = lplTargets.mapIndexed { fallbackIndex, target ->
                val normalizedTarget = normalize(target.game)
                val keys = listOf(normalizedTarget) + (aliases[normalizedTarget] ?: emptyList())

                val exact = normalizedLibrary.firstOrNull { keys.contains(it.normalizedName) }
                val loose = normalizedLibrary.firstOrNull { entry ->
                    keys.any { key -> entry.normalizedName.contains(key) || key.contains(entry.normalizedName) }
                }
                val chosen = exact ?: loose

                if (chosen != null) {
                    TargetRow(target, chosen.bank, chosen.group, chosen.pos, chosen.index, fallbackIndex)
                } else {
                    TargetRow(target, null, null, null, Int.MAX_VALUE, fallbackIndex)
                }
            }

            rows = merged
            error = null
        } catch (t: Throwable) {
            error = "Using default order (library unavailable)."
        }
    }

    AppScreen(contentPadding) {
        Column(
            modifier = Modifier.verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(CardBg, RoundedCornerShape(12.dp))
                    .border(1.dp, Border, RoundedCornerShape(12.dp))
                    .padding(start = 12.dp, top = 12.dp, end = 12.dp, bottom = 7.dp),
            ) {
                SectionTitle("LPL Score Targets")
                Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                    Row {
                        Text("2nd highest", color = Color(0xFFBAF5D1), modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text("4th highest", color = Color(0xFFC0DBFF), modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text("8th highest", color = Color(0xFFE3E7EB), modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    }
                    Row {
                        Text("\"great game\"", color = Color(0xFFBAF5D1), modifier = Modifier.weight(1f), fontSize = 11.sp)
                        Text("main target", color = Color(0xFFC0DBFF), modifier = Modifier.weight(1f), fontSize = 11.sp)
                        Text("solid floor", color = Color(0xFFE3E7EB), modifier = Modifier.weight(1f), fontSize = 11.sp)
                    }
                    BoxWithConstraints {
                        val menuWidth = (maxWidth - 8.dp) / 2
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            SortMenu(
                                selected = sortOption,
                                onSelect = { sortOptionName = it.name },
                                modifier = Modifier.width(menuWidth),
                            )
                            BankMenu(
                                selectedBank = selectedBank,
                                bankOptions = bankOptions,
                                onSelect = { selectedBank = it },
                                modifier = Modifier.width(menuWidth),
                            )
                        }
                    }
                }
            }

            error?.let { Text(it, color = Color(0xFFE39A9A)) }

            CardContainer {
                BoxWithConstraints {
                    val baseWidth = 660f
                    val scale = if (isLandscape) (maxWidth.value / baseWidth).coerceIn(1f, 1.7f) else 1f
                    val gameWidth = (210 * scale).toInt()
                    val bankWidth = (44 * scale).toInt()
                    val scoreWidth = (136 * scale).toInt()

                    Row(
                        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                        horizontalArrangement = if (isLandscape) Arrangement.Center else Arrangement.Start,
                    ) {
                        Column {
                            Header(gameWidth, bankWidth, scoreWidth)
                            filteredRows.forEachIndexed { index, row ->
                                TargetRowView(index, row, gameWidth, bankWidth, scoreWidth)
                            }
                        }
                    }
                }
            }

            Text(
                "Benchmarks are based on historical LPL league results across all seasons where each game appeared.",
                color = Color(0xFFAAAAAA),
            )
        }
    }
}

@Composable
private fun SortMenu(
    selected: TargetSortOption,
    onSelect: (TargetSortOption) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier = modifier) {
        OutlinedButton(
            onClick = { expanded = true },
            modifier = Modifier.fillMaxWidth().heightIn(min = 34.dp),
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 3.dp),
            shape = RoundedCornerShape(10.dp),
        ) {
            Text("Sort: ${selected.label}", fontSize = 12.sp, maxLines = 1)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            TargetSortOption.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text("Sort: ${option.label}", fontSize = 12.sp) },
                    onClick = {
                        expanded = false
                        onSelect(option)
                    },
                )
            }
        }
    }
}

@Composable
private fun BankMenu(
    selectedBank: Int?,
    bankOptions: List<Int>,
    onSelect: (Int?) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier = modifier) {
        OutlinedButton(
            onClick = { expanded = true },
            modifier = Modifier.fillMaxWidth().heightIn(min = 34.dp),
            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 3.dp),
            shape = RoundedCornerShape(10.dp),
        ) {
            Text(selectedBank?.let { "Bank $it" } ?: "All banks", fontSize = 12.sp, maxLines = 1)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            DropdownMenuItem(
                text = { Text("All banks", fontSize = 12.sp) },
                onClick = {
                    expanded = false
                    onSelect(null)
                },
            )
            bankOptions.forEach { bank ->
                DropdownMenuItem(
                    text = { Text("Bank $bank", fontSize = 12.sp) },
                    onClick = {
                        expanded = false
                        onSelect(bank)
                    },
                )
            }
        }
    }
}

private fun sortRows(rows: List<TargetRow>, option: TargetSortOption): List<TargetRow> {
    return when (option) {
        TargetSortOption.LOCATION -> rows.sortedWith(
            compareBy<TargetRow> { it.group ?: Int.MAX_VALUE }
                .thenBy { it.pos ?: Int.MAX_VALUE }
                .thenBy { it.libraryOrder }
                .thenBy { it.fallbackOrder },
        )
        TargetSortOption.BANK -> rows.sortedWith(
            compareBy<TargetRow> { it.bank ?: Int.MAX_VALUE }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.pos ?: Int.MAX_VALUE }
                .thenBy { it.target.game.lowercase() }
                .thenBy { it.libraryOrder }
                .thenBy { it.fallbackOrder },
        )
        TargetSortOption.ALPHABETICAL -> rows.sortedWith(
            compareBy<TargetRow> { it.target.game.lowercase() }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.pos ?: Int.MAX_VALUE }
                .thenBy { it.libraryOrder }
                .thenBy { it.fallbackOrder },
        )
    }
}

@Composable
private fun Header(gameWidth: Int, bankWidth: Int, scoreWidth: Int) {
    Row {
        Cell("Game", gameWidth, bold = true)
        Cell("B", bankWidth, bold = true)
        Cell("2nd", scoreWidth, bold = true)
        Cell("4th", scoreWidth, bold = true)
        Cell("8th", scoreWidth, bold = true)
    }
}

@Composable
private fun TargetRowView(index: Int, row: TargetRow, gameWidth: Int, bankWidth: Int, scoreWidth: Int) {
    Row(
        modifier = Modifier
            .background(if (index % 2 == 0) Color(0xFF121212) else Color(0xFF222222))
            .padding(vertical = 2.dp),
    ) {
        Cell(row.target.game, gameWidth, maxLines = 1)
        Cell(row.bank?.toString() ?: "-", bankWidth)
        Cell(fmt(row.target.great), scoreWidth, color = Color(0xFFBAF5D1))
        Cell(fmt(row.target.main), scoreWidth, color = Color(0xFFC0DBFF))
        Cell(fmt(row.target.floor), scoreWidth, color = Color(0xFFE3E7EB))
    }
}

@Composable
private fun Cell(
    text: String,
    width: Int,
    bold: Boolean = false,
    color: Color = Color.White,
    maxLines: Int = Int.MAX_VALUE,
) {
    Text(
        text = text,
        modifier = Modifier.width(width.dp).padding(horizontal = 5.dp),
        color = color,
        fontWeight = if (bold) FontWeight.SemiBold else FontWeight.Normal,
        fontSize = 13.sp,
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
    )
}

private fun fmt(value: Long): String = NumberFormat.getIntegerInstance().format(value)

private fun normalize(name: String): String {
    val lowered = name.lowercase().replace("&", " and ")
    return lowered.filter { it.isLetterOrDigit() }
}

private val aliases = mapOf(
    "tmnt" to listOf("teenagemutantninjaturtles"),
    "thegetaway" to listOf("thegetawayhighspeedii"),
    "starwars2017" to listOf("starwars"),
    "jurassicparkstern2019" to listOf("jurassicpark", "jurassicpark2019"),
    "attackfrommars" to listOf("attackfrommarsremake"),
    "dungeonsanddragons" to listOf("dungeonsdragons"),
)

private val lplTargets = listOf(
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
