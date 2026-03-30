package com.pillyliu.pinprofandroid.targets

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.library.hostedResolvedLeagueTargetsPath
import com.pillyliu.pinprofandroid.ui.AppFilterSheet
import com.pillyliu.pinprofandroid.ui.AppInlineStatusMessage
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.AppThreeColumnLegendHeader
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.InsetFilterHeader

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TargetsScreen(
    contentPadding: PaddingValues,
    onBack: (() -> Unit)? = null,
) {
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    var rows by remember {
        mutableStateOf(defaultTargetRows())
    }
    var sortOptionName by rememberSaveable { mutableStateOf(TargetSortOption.LOCATION.name) }
    var selectedBank by rememberSaveable { mutableStateOf<Int?>(null) }
    var showFilterSheet by rememberSaveable { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val sortOption = remember(sortOptionName) { TargetSortOption.valueOf(sortOptionName) }
    val bankOptions = remember(rows) { rows.mapNotNull { it.bank }.toSet().sorted() }
    val sortedRows = remember(rows, sortOption) { sortTargetRows(rows, sortOption) }
    val filteredRows = remember(sortedRows, selectedBank) {
        if (selectedBank == null) sortedRows else sortedRows.filter { it.bank == selectedBank }
    }
    val navSummaryText = "Sort: ${sortOption.label}  ${selectedBank?.let { "Bank: $it" } ?: "Bank: All"}"

    LaunchedEffect(Unit) {
        try {
            val cached = PinballDataCache.loadText(hostedResolvedLeagueTargetsPath, allowMissing = true)
            rows = resolveTargetRows(cached.text)
            error = null
        } catch (t: Throwable) {
            error = "Using bundled target order (resolved targets unavailable: ${t.message ?: t::class.java.simpleName})."
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
                AppThreeColumnLegendHeader(
                    columns = targetLegendColumns(isLandscape),
                    primaryColors = listOf(
                        targetAccentColor(TargetColorRole.Great),
                        targetAccentColor(TargetColorRole.Main),
                        targetAccentColor(TargetColorRole.Floor),
                    ),
                    compact = !isLandscape,
                )
            }

            error?.let { AppInlineStatusMessage(text = it, isError = true) }

            Column(
                modifier = Modifier.weight(1f, fill = true),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                CardContainer(modifier = Modifier.fillMaxWidth().weight(1f, fill = true)) {
                    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                        val baseWidth = 660f
                        val scale = (maxWidth.value / baseWidth).coerceIn(1f, 1.9f)
                        val gameWidth = (210 * scale).toInt()
                        val bankWidth = (44 * scale).toInt()
                        val scoreWidth = (136 * scale).toInt()

                        Row(
                            modifier = Modifier.fillMaxSize().horizontalScroll(rememberScrollState()),
                            horizontalArrangement = if (isLandscape) Arrangement.Center else Arrangement.Start,
                        ) {
                            Column(modifier = Modifier.fillMaxHeight()) {
                                TargetsHeader(gameWidth, bankWidth, scoreWidth)
                                Column(
                                    modifier = Modifier
                                        .weight(1f, fill = true)
                                        .verticalScroll(rememberScrollState()),
                                ) {
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
    }

    if (showFilterSheet) {
        AppFilterSheet(
            title = "Targets filters",
            onDismissRequest = { showFilterSheet = false },
        ) {
            TargetSortMenu(
                selected = sortOption,
                onSelect = { sortOptionName = it.name },
                modifier = Modifier.fillMaxWidth(),
            )
            TargetBankMenu(
                selectedBank = selectedBank,
                bankOptions = bankOptions,
                onSelect = { selectedBank = it },
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
