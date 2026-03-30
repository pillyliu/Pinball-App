package com.pillyliu.pinprofandroid.standings

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinprofandroid.data.PinballDataCache
import com.pillyliu.pinprofandroid.data.leaguePlayerNamesMatch
import com.pillyliu.pinprofandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinprofandroid.league.LeaguePreviewRefreshEvents
import com.pillyliu.pinprofandroid.practice.rememberPreferredLeaguePlayerName
import com.pillyliu.pinprofandroid.ui.AppFilterSheet
import com.pillyliu.pinprofandroid.ui.AppInlineStatusMessage
import com.pillyliu.pinprofandroid.ui.AppRefreshStatusRow
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.CompactDropdownFilter
import com.pillyliu.pinprofandroid.ui.EmptyLabel
import com.pillyliu.pinprofandroid.ui.InsetFilterHeader
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StandingsScreen(
    contentPadding: PaddingValues,
    onBack: (() -> Unit)? = null,
) {
    val showFullLplLastName = rememberShowFullLplLastName()
    val preferredLeaguePlayerName = rememberPreferredLeaguePlayerName()
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    var rows by remember { mutableStateOf(emptyList<StandingsCsvRow>()) }
    var error by remember { mutableStateOf<String?>(null) }
    var dataUpdatedAtMs by remember { mutableStateOf<Long?>(null) }
    var isRefreshing by remember { mutableStateOf(false) }
    var hasNewerData by remember { mutableStateOf(false) }
    var initialLoadComplete by remember { mutableStateOf(false) }
    var selectedSeason by rememberSaveable { mutableStateOf<Int?>(null) }
    var showFilterSheet by rememberSaveable { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val pulseTransition = rememberInfiniteTransition(label = "standingsRefreshPulse")
    val pulseAlpha by pulseTransition.animateFloat(
        initialValue = 1f,
        targetValue = 0.35f,
        animationSpec = infiniteRepeatable(animation = tween(650), repeatMode = RepeatMode.Reverse),
        label = "standingsRefreshPulseAlpha",
    )

    fun refresh(force: Boolean) {
        if (isRefreshing) return
        scope.launch {
            isRefreshing = true
            try {
                val cached = if (force) {
                    PinballDataCache.forceRefreshText(STANDINGS_CSV_URL)
                } else {
                    PinballDataCache.passthroughOrCachedText(STANDINGS_CSV_URL)
                }
                rows = parseStandings(cached.text.orEmpty())
                dataUpdatedAtMs = cached.updatedAtMs
                val seasonsNow = rows.map { it.season }.toSet().sorted()
                if (selectedSeason == null || selectedSeason !in seasonsNow) {
                    selectedSeason = seasonsNow.maxOrNull()
                }
                error = null
                if (force) {
                    LeaguePreviewRefreshEvents.notifyChanged()
                }
                if (dataUpdatedAtMs != null) {
                    scope.launch {
                        val remoteHasNewer = PinballDataCache.hasRemoteUpdate(STANDINGS_CSV_URL)
                        hasNewerData = remoteHasNewer
                    }
                } else {
                    hasNewerData = false
                }
            } catch (t: Throwable) {
                error = t.message ?: "Failed to load standings"
            } finally {
                isRefreshing = false
                initialLoadComplete = true
            }
        }
    }

    LaunchedEffect(Unit) {
        refresh(false)
    }

    val seasons = rows.map { it.season }.toSet().sorted()
    val standingRows = buildStandings(rows, selectedSeason)
    val seasonLabels = seasons.map { "Season $it" }
    val navSummaryText = "Standings - ${selectedSeason?.let { "Season $it" } ?: "Season"}"

    AppScreen(contentPadding) {
        Column(modifier = Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            InsetFilterHeader(
                summaryText = navSummaryText,
                onFilterClick = { showFilterSheet = true },
                onBack = onBack,
            )

            error?.let { AppInlineStatusMessage(text = it, isError = true) }
            dataUpdatedAtMs?.let { updatedAt ->
                AppRefreshStatusRow(
                    label = formatStandingsUpdatedAt(updatedAt),
                    isRefreshing = isRefreshing,
                    hasNewerData = hasNewerData,
                    pulseAlpha = pulseAlpha,
                    onRefresh = { refresh(true) },
                )
            }

            CardContainer(modifier = Modifier.fillMaxWidth().weight(1f, fill = true)) {
                BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                    val baseTableWidth = 646f
                    val scaled = (maxWidth.value / baseTableWidth).coerceIn(1f, 1.9f)
                    val widths = StandingsWidths(
                        rank = (34 * scaled).toInt(),
                        player = (136 * scaled).toInt(),
                        points = (68 * scaled).toInt(),
                        eligible = (38 * scaled).toInt(),
                        nights = (34 * scaled).toInt(),
                        bank = (42 * scaled).toInt(),
                    )

                    Row(
                        modifier = Modifier.fillMaxSize().horizontalScroll(rememberScrollState()),
                        horizontalArrangement = if (isLandscape) Arrangement.Center else Arrangement.Start,
                    ) {
                        Column(modifier = Modifier.fillMaxHeight()) {
                            StandingsHeaderRow(widths)
                            if (!initialLoadComplete && isRefreshing) {
                                Column(
                                    modifier = Modifier.weight(1f, fill = true),
                                    verticalArrangement = Arrangement.Center,
                                ) {
                                    EmptyLabel("Loading data…")
                                }
                            } else if (standingRows.isEmpty()) {
                                Column(
                                    modifier = Modifier.weight(1f, fill = true),
                                    verticalArrangement = Arrangement.Center,
                                ) {
                                    EmptyLabel("No rows. Check data source or season selection.")
                                }
                            } else {
                                Column(
                                    modifier = Modifier
                                        .weight(1f, fill = true)
                                        .verticalScroll(rememberScrollState()),
                                ) {
                                    standingRows.forEachIndexed { index, standing ->
                                        StandingsRow(
                                            rank = index + 1,
                                            standing = standing,
                                            widths = widths,
                                            showFullLplLastName = showFullLplLastName,
                                            isHighlighted = leaguePlayerNamesMatch(standing.rawPlayer, preferredLeaguePlayerName),
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showFilterSheet) {
        AppFilterSheet(
            title = "Standings filters",
            onDismissRequest = { showFilterSheet = false },
        ) {
            CompactDropdownFilter(
                selectedText = selectedSeason?.let { "Season $it" } ?: "Select",
                options = seasonLabels,
                onSelect = { label ->
                    selectedSeason = label.removePrefix("Season ").trim().toIntOrNull()
                },
                modifier = Modifier.fillMaxWidth(),
                minHeight = 38.dp,
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 10.dp, vertical = 0.dp),
                textSize = 12.sp,
                itemTextSize = 12.sp,
            )
        }
    }
}
