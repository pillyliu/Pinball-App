package com.pillyliu.pinprofandroid.stats

import android.content.res.Configuration
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.pillyliu.pinprofandroid.data.formatLplPlayerNameForDisplay
import com.pillyliu.pinprofandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinprofandroid.league.LeaguePreviewRefreshEvents
import com.pillyliu.pinprofandroid.practice.rememberPreferredLeaguePlayerName
import com.pillyliu.pinprofandroid.ui.AppFilterSheet
import com.pillyliu.pinprofandroid.ui.AppInlineStatusMessage
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.AppRefreshStatusRow
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.InsetFilterHeader
import androidx.compose.ui.platform.LocalConfiguration
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsScreen(
    contentPadding: PaddingValues,
    onBack: (() -> Unit)? = null,
) {
    val showFullLplLastName = rememberShowFullLplLastName()
    val preferredLeaguePlayerName = rememberPreferredLeaguePlayerName()
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE

    var rows by remember { mutableStateOf(emptyList<ScoreRow>()) }
    var error by remember { mutableStateOf<String?>(null) }
    var dataUpdatedAtMs by remember { mutableStateOf<Long?>(null) }
    var isRefreshing by remember { mutableStateOf(false) }
    var hasNewerData by remember { mutableStateOf(false) }
    var initialLoadComplete by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val pulseTransition = rememberInfiniteTransition(label = "statsRefreshPulse")
    val pulseAlpha by pulseTransition.animateFloat(
        initialValue = 1f,
        targetValue = 0.35f,
        animationSpec = infiniteRepeatable(animation = tween(650), repeatMode = RepeatMode.Reverse),
        label = "statsRefreshPulseAlpha",
    )

    var season by rememberSaveable { mutableStateOf("") }
    var player by rememberSaveable { mutableStateOf("") }
    var bankNumber by rememberSaveable { mutableStateOf<Int?>(null) }
    var machine by rememberSaveable { mutableStateOf("") }
    var showFilterSheet by rememberSaveable { mutableStateOf(false) }

    fun hasRows(
        seasonValue: String = season,
        playerValue: String = player,
        bankValue: Int? = bankNumber,
        machineValue: String = machine,
    ): Boolean = rows.any { row ->
        (seasonValue.isEmpty() || row.season == seasonValue) &&
            (playerValue.isEmpty() || row.player == playerValue) &&
            (bankValue == null || row.bankNumber == bankValue) &&
            (machineValue.isEmpty() || row.machine == machineValue)
    }

    fun reconcileBankScopedSelections() {
        val currentBank = bankNumber
        if (currentBank != null && player.isNotEmpty() && !hasRows(bankValue = currentBank, playerValue = player, machineValue = "")) {
            player = ""
        }
        if (machine.isNotEmpty() && !hasRows(playerValue = player, bankValue = currentBank, machineValue = machine)) {
            machine = ""
        }
    }

    fun reconcilePlayerScopedSelections() {
        val currentBank = bankNumber
        if (currentBank != null && !hasRows(playerValue = player, bankValue = currentBank, machineValue = "")) {
            bankNumber = null
        }
        reconcileBankScopedSelections()
    }

    fun reconcileSeasonScopedSelections() {
        if (player.isNotEmpty() && !hasRows(playerValue = player, bankValue = null, machineValue = "")) {
            player = ""
        }
        val currentBank = bankNumber
        if (currentBank != null && !hasRows(playerValue = player, bankValue = currentBank, machineValue = "")) {
            bankNumber = null
        }
        reconcileBankScopedSelections()
    }

    fun selectSeason(newSeason: String) {
        season = newSeason
        reconcileSeasonScopedSelections()
    }

    fun selectPlayer(newPlayer: String) {
        player = newPlayer
        reconcilePlayerScopedSelections()
    }

    fun selectBankNumber(newBankNumber: Int?) {
        bankNumber = newBankNumber
        reconcileBankScopedSelections()
    }

    fun selectMachine(newMachine: String) {
        machine = newMachine
    }

    fun refresh(force: Boolean) {
        if (isRefreshing) return
        scope.launch {
            isRefreshing = true
            try {
                val loaded = withContext(Dispatchers.IO) { loadStatsRows(force) }
                rows = loaded.rows
                dataUpdatedAtMs = loaded.updatedAtMs
                if (rows.isNotEmpty()) {
                    val seasonsNow = rows.map { it.season }.toSet().sortedWith(::compareStatsSeasons)
                    if ((!initialLoadComplete && season.isBlank()) || (season.isNotBlank() && season !in seasonsNow)) {
                        season = seasonsNow.lastOrNull().orEmpty()
                    }
                    reconcileSeasonScopedSelections()
                }
                error = null
                if (force) {
                    LeaguePreviewRefreshEvents.notifyChanged()
                }
                if (dataUpdatedAtMs != null) {
                    scope.launch {
                        val remoteHasNewer = hasRemoteStatsUpdate()
                        hasNewerData = remoteHasNewer
                    }
                } else {
                    hasNewerData = false
                }
            } catch (t: Throwable) {
                error = t.message ?: "Failed to load stats CSV"
            } finally {
                isRefreshing = false
                initialLoadComplete = true
            }
        }
    }

    LaunchedEffect(Unit) {
        refresh(false)
    }

    val seasons = rows.map { it.season }.toSet().sortedWith(::compareStatsSeasons)
    val players = rows.filter { season.isEmpty() || it.season == season }.map { it.player }.toSet().sorted()
    val banks = rows.filter { (season.isEmpty() || it.season == season) && (player.isEmpty() || it.player == player) }
        .map { it.bankNumber }
        .toSet()
        .sorted()
    val machines = rows.filter {
        (season.isEmpty() || it.season == season) &&
            (player.isEmpty() || it.player == player) &&
            (bankNumber == null || it.bankNumber == bankNumber)
    }.map { it.machine }.filter { it.isNotBlank() }.toSet().sorted()

    val filtered = rows.filter {
        (season.isEmpty() || it.season == season) &&
            (player.isEmpty() || it.player == player) &&
            (bankNumber == null || it.bankNumber == bankNumber) &&
            (machine.isEmpty() || it.machine == machine)
    }

    val bankStats = computeStats(
        rows.filter {
            season.isNotEmpty() && it.season == season &&
                bankNumber != null && it.bankNumber == bankNumber &&
                machine.isNotEmpty() && it.machine == machine
        },
        true,
    )
    val historyStats = computeStats(rows.filter { machine.isNotEmpty() && it.machine == machine }, false)
    val navSummaryText = statsNavSummaryText(
        season = season,
        bankNumber = bankNumber,
        player = player,
        machine = machine,
        showFullLplLastName = showFullLplLastName,
    )
    val seasonOptions = listOf(DropdownOption("", "S: All")) + seasons.map { DropdownOption(it, abbreviateStatsSeason(it)) }
    val playerOptions = listOf(DropdownOption("", "Player: All")) +
        players.map { DropdownOption(it, formatLplPlayerNameForDisplay(it, showFullLplLastName)) }
    val bankOptions = listOf(DropdownOption("", "B: All")) + banks.map { DropdownOption(it.toString(), "B$it") }
    val machineOptions = listOf(DropdownOption("", "Machine: All")) + machines.map { DropdownOption(it, it) }

    AppScreen(contentPadding) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            InsetFilterHeader(
                summaryText = navSummaryText,
                onFilterClick = { showFilterSheet = true },
                onBack = onBack,
            )

            error?.let { AppInlineStatusMessage(text = it, isError = true) }
            dataUpdatedAtMs?.let { updatedAt ->
                AppRefreshStatusRow(
                    label = formatStatsUpdatedAt(updatedAt),
                    isRefreshing = isRefreshing,
                    hasNewerData = hasNewerData,
                    pulseAlpha = pulseAlpha,
                    onRefresh = { refresh(true) },
                )
            }

            if (isLandscape) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f, fill = true),
                    verticalAlignment = Alignment.Top,
                ) {
                    CardContainer(modifier = Modifier.weight(0.6f, fill = true)) {
                        StatsTable(
                            filtered = filtered,
                            showFullLplLastName = showFullLplLastName,
                            preferredLeaguePlayerName = preferredLeaguePlayerName,
                            isRefreshing = isRefreshing,
                            initialLoadComplete = initialLoadComplete,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                    CardContainer(modifier = Modifier.weight(0.4f, fill = true)) {
                        MachineStatsPanel(
                            machine = machine,
                            bankNumber = bankNumber,
                            season = season,
                            bankStats = bankStats,
                            historyStats = historyStats,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                }
            } else {
                val machinePanelHeight = if (machine.isBlank()) 72.dp else 212.dp
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f, fill = true),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    CardContainer(modifier = Modifier.fillMaxWidth().weight(1f, fill = true)) {
                        StatsTable(
                            filtered = filtered,
                            showFullLplLastName = showFullLplLastName,
                            preferredLeaguePlayerName = preferredLeaguePlayerName,
                            isRefreshing = isRefreshing,
                            initialLoadComplete = initialLoadComplete,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                    CardContainer(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = machinePanelHeight, max = machinePanelHeight),
                    ) {
                        MachineStatsPanel(
                            machine = machine,
                            bankNumber = bankNumber,
                            season = season,
                            bankStats = bankStats,
                            historyStats = historyStats,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                }
            }
        }
    }

    if (showFilterSheet) {
        AppFilterSheet(
            title = "Stats filters",
            onDismissRequest = { showFilterSheet = false },
        ) {
            AnchoredDropdownFilter(
                selectedText = seasonDisplayText(season),
                options = seasonOptions,
                onSelect = { selectSeason(it) },
            )
            AnchoredDropdownFilter(
                selectedText = bankDisplayText(bankNumber),
                options = bankOptions,
                onSelect = { selectBankNumber(it.toIntOrNull()) },
            )
            AnchoredDropdownFilter(
                selectedText = playerDisplayText(player, showFullLplLastName),
                options = playerOptions,
                onSelect = { selectPlayer(it) },
            )
            AnchoredDropdownFilter(
                selectedText = machineDisplayText(machine),
                options = machineOptions,
                onSelect = { selectMachine(it) },
            )
        }
    }
}
