package com.pillyliu.pinballandroid.targets

import android.content.res.Configuration
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.isSystemInDarkTheme
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.CardContainer
import com.pillyliu.pinballandroid.ui.CompactDropdownFilter
import com.pillyliu.pinballandroid.ui.FixedWidthTableCell
import com.pillyliu.pinballandroid.ui.InsetFilterHeader
import org.json.JSONArray
import java.text.NumberFormat

private const val LIBRARY_URL = "https://pillyliu.com/pinball/data/pinball_library.json"

private data class LPLTarget(val game: String, val great: Long, val main: Long, val floor: Long)
private data class TargetRow(
    val target: LPLTarget,
    val area: String?,
    val bank: Int?,
    val group: Int?,
    val position: Int?,
    val libraryOrder: Int,
    val fallbackOrder: Int,
)
private data class LibraryLookup(
    val index: Int,
    val normalizedName: String,
    val area: String?,
    val bank: Int?,
    val group: Int?,
    val position: Int?,
)

private enum class TargetSortOption(val label: String) {
    LOCATION("Area"),
    BANK("Bank"),
    ALPHABETICAL("A-Z"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TargetsScreen(
    contentPadding: PaddingValues,
    onBack: (() -> Unit)? = null,
) {
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    var rows by remember {
        mutableStateOf(
            lplTargets.mapIndexed { idx, t ->
                TargetRow(t, null, null, null, null, Int.MAX_VALUE, idx)
            },
        )
    }
    var sortOptionName by rememberSaveable { mutableStateOf(TargetSortOption.LOCATION.name) }
    var selectedBank by rememberSaveable { mutableStateOf<Int?>(null) }
    var showFilterSheet by rememberSaveable { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val sortOption = remember(sortOptionName) { TargetSortOption.valueOf(sortOptionName) }
    val bankOptions = remember(rows) { rows.mapNotNull { it.bank }.toSet().sorted() }
    val sortedRows = remember(rows, sortOption) { sortRows(rows, sortOption) }
    val filteredRows = remember(sortedRows, selectedBank) {
        if (selectedBank == null) sortedRows else sortedRows.filter { it.bank == selectedBank }
    }
    val navSummaryText = "Sort: ${sortOption.label}  ${selectedBank?.let { "Bank: $it" } ?: "Bank: All"}"

    LaunchedEffect(Unit) {
        try {
            val cached = PinballDataCache.passthroughOrCachedText(LIBRARY_URL)
            val libraryGames = JSONArray(cached.text.orEmpty())
            val normalizedLibrary = (0 until libraryGames.length()).map { index ->
                val item = libraryGames.getJSONObject(index)
                LibraryLookup(
                    index = index,
                    normalizedName = normalize(item.optString("name")),
                    area = (item.optString("area").takeIf { it.isNotBlank() }
                        ?: item.optString("location").takeIf { it.isNotBlank() })?.trim(),
                    bank = item.optInt("bank").takeIf { it > 0 },
                    group = item.optInt("group").takeIf { it > 0 },
                    position = item.optInt("position").takeIf { it > 0 },
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
                    TargetRow(target, chosen.area, chosen.bank, chosen.group, chosen.position, chosen.index, fallbackIndex)
                } else {
                    TargetRow(target, null, null, null, null, Int.MAX_VALUE, fallbackIndex)
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
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            InsetFilterHeader(
                summaryText = navSummaryText,
                onFilterClick = { showFilterSheet = true },
                onBack = onBack,
            )
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                if (isLandscape) {
                    Row {
                        Text("2nd highest \"great game\"", color = targetAccentColor(TargetColorRole.Great), textAlign = TextAlign.Center, modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                        Text("4th highest main target", color = targetAccentColor(TargetColorRole.Main), textAlign = TextAlign.Center, modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                        Text("8th highest solid floor", color = targetAccentColor(TargetColorRole.Floor), textAlign = TextAlign.Center, modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
                    }
                } else {
                    Row {
                        Text("2nd highest", color = targetAccentColor(TargetColorRole.Great), textAlign = TextAlign.Center, modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text("4th highest", color = targetAccentColor(TargetColorRole.Main), textAlign = TextAlign.Center, modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text("8th highest", color = targetAccentColor(TargetColorRole.Floor), textAlign = TextAlign.Center, modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                    }
                    Row {
                        Text("\"great game\"", color = targetAccentColor(TargetColorRole.Great), textAlign = TextAlign.Center, modifier = Modifier.weight(1f), fontSize = 11.sp)
                        Text("main target", color = targetAccentColor(TargetColorRole.Main), textAlign = TextAlign.Center, modifier = Modifier.weight(1f), fontSize = 11.sp)
                        Text("solid floor", color = targetAccentColor(TargetColorRole.Floor), textAlign = TextAlign.Center, modifier = Modifier.weight(1f), fontSize = 11.sp)
                    }
                }
            }

            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }

            CardContainer(modifier = Modifier.fillMaxWidth().weight(1f, fill = true)) {
                BoxWithConstraints {
                    val baseWidth = 660f
                    val scale = (maxWidth.value / baseWidth).coerceIn(1f, 1.9f)
                    val gameWidth = (210 * scale).toInt()
                    val bankWidth = (44 * scale).toInt()
                    val scoreWidth = (136 * scale).toInt()

                    Row(
                        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                        horizontalArrangement = if (isLandscape) Arrangement.Center else Arrangement.Start,
                    ) {
                        Column {
                            Header(gameWidth, bankWidth, scoreWidth)
                            Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                                filteredRows.forEachIndexed { index, row ->
                                    TargetRowView(index, row, gameWidth, bankWidth, scoreWidth)
                                }
                            }
                        }
                    }
                }
            }

            Text(
                "Benchmarks are based on historical LPL league results across all seasons where each game appeared. For each game, scores are derived from per-bank results using 2nd / 4th / 8th highest averages with sample-size adjustments. These values are then averaged across all bank appearances for that game.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 12.sp,
                lineHeight = 16.sp,
                modifier = Modifier.padding(top = 1.dp, start = 4.dp, end = 4.dp),
            )
        }
    }

    if (showFilterSheet) {
        ModalBottomSheet(onDismissRequest = { showFilterSheet = false }) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text("Targets filters", style = MaterialTheme.typography.titleSmall)
                SortMenu(
                    selected = sortOption,
                    onSelect = { sortOptionName = it.name },
                    modifier = Modifier.fillMaxWidth(),
                )
                BankMenu(
                    selectedBank = selectedBank,
                    bankOptions = bankOptions,
                    onSelect = { selectedBank = it },
                    modifier = Modifier.fillMaxWidth(),
                )
                TextButton(onClick = { showFilterSheet = false }, modifier = Modifier.align(Alignment.End)) {
                    Text("Done")
                }
            }
        }
    }
}

@Composable
private fun SortMenu(
    selected: TargetSortOption,
    onSelect: (TargetSortOption) -> Unit,
    modifier: Modifier = Modifier,
) {
    CompactDropdownFilter(
        selectedText = "Sort: ${selected.label}",
        options = TargetSortOption.entries.map { "Sort: ${it.label}" },
        onSelect = { label ->
            val raw = label.removePrefix("Sort: ").trim()
            val option = TargetSortOption.entries.firstOrNull { it.label == raw } ?: selected
            onSelect(option)
        },
        modifier = modifier,
        minHeight = 34.dp,
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 3.dp),
        textSize = 12.sp,
        itemTextSize = 12.sp,
    )
}

@Composable
private fun BankMenu(
    selectedBank: Int?,
    bankOptions: List<Int>,
    onSelect: (Int?) -> Unit,
    modifier: Modifier = Modifier,
) {
    CompactDropdownFilter(
        selectedText = selectedBank?.let { "Bank $it" } ?: "All banks",
        options = listOf("All banks") + bankOptions.map { "Bank $it" },
        onSelect = { label ->
            if (label == "All banks") {
                onSelect(null)
            } else {
                onSelect(label.removePrefix("Bank ").trim().toIntOrNull())
            }
        },
        modifier = modifier,
        minHeight = 34.dp,
        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 3.dp),
        textSize = 12.sp,
        itemTextSize = 12.sp,
    )
}

private fun sortRows(rows: List<TargetRow>, option: TargetSortOption): List<TargetRow> {
    return when (option) {
        TargetSortOption.LOCATION -> rows.sortedWith(
            compareBy<TargetRow> { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE }
                .thenBy { it.libraryOrder }
                .thenBy { it.fallbackOrder },
        )
        TargetSortOption.BANK -> rows.sortedWith(
            compareBy<TargetRow> { it.bank ?: Int.MAX_VALUE }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE }
                .thenBy { it.target.game.lowercase() }
                .thenBy { it.libraryOrder }
                .thenBy { it.fallbackOrder },
        )
        TargetSortOption.ALPHABETICAL -> rows.sortedWith(
            compareBy<TargetRow> { it.target.game.lowercase() }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.position ?: Int.MAX_VALUE }
                .thenBy { it.libraryOrder }
                .thenBy { it.fallbackOrder },
        )
    }
}

@Composable
private fun Header(gameWidth: Int, bankWidth: Int, scoreWidth: Int) {
    Row {
        FixedWidthTableCell("Game", gameWidth, bold = true, horizontalPadding = 5.dp)
        FixedWidthTableCell("B", bankWidth, bold = true, horizontalPadding = 5.dp)
        FixedWidthTableCell("2nd", scoreWidth, bold = true, horizontalPadding = 5.dp)
        FixedWidthTableCell("4th", scoreWidth, bold = true, horizontalPadding = 5.dp)
        FixedWidthTableCell("8th", scoreWidth, bold = true, horizontalPadding = 5.dp)
    }
}

@Composable
private fun TargetRowView(index: Int, row: TargetRow, gameWidth: Int, bankWidth: Int, scoreWidth: Int) {
    Row(
        modifier = Modifier
            .background(if (index % 2 == 0) MaterialTheme.colorScheme.surface else MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(vertical = 5.dp),
    ) {
        FixedWidthTableCell(
            text = row.target.game,
            width = gameWidth,
            maxLines = 1,
            horizontalPadding = 5.dp,
            overflow = TextOverflow.Ellipsis,
        )
        FixedWidthTableCell(row.bank?.toString() ?: "-", bankWidth, horizontalPadding = 5.dp)
        FixedWidthTableCell(fmt(row.target.great), scoreWidth, color = targetAccentColor(TargetColorRole.Great), horizontalPadding = 5.dp)
        FixedWidthTableCell(fmt(row.target.main), scoreWidth, color = targetAccentColor(TargetColorRole.Main), horizontalPadding = 5.dp)
        FixedWidthTableCell(fmt(row.target.floor), scoreWidth, color = targetAccentColor(TargetColorRole.Floor), horizontalPadding = 5.dp)
    }
}

private enum class TargetColorRole { Great, Main, Floor }

@Composable
private fun targetAccentColor(role: TargetColorRole): Color {
    val darkMode = isSystemInDarkTheme()
    val base = when (role) {
        TargetColorRole.Great -> Color(0xFF34D399)
        TargetColorRole.Main -> Color(0xFF60A5FA)
        TargetColorRole.Floor -> Color(0xFF9CA3AF)
    }
    return if (darkMode) {
        lerp(base, Color.White, 0.16f)
    } else {
        lerp(base, MaterialTheme.colorScheme.onSurface, 0.36f)
    }
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
