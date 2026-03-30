package com.pillyliu.pinprofandroid.settings

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.pillyliu.pinprofandroid.ui.AppTintedStatusChip
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.LibraryVenueSearchResult
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppCompactIconButton
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
internal fun AddManufacturerScreen(
    contentPadding: PaddingValues,
    manufacturers: List<CatalogManufacturerOption>,
    onBack: () -> Unit,
    onAdd: (CatalogManufacturerOption) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    var selectedBucket by remember { mutableStateOf(ManufacturerBucket.MODERN) }
    val bucketedManufacturers = remember(manufacturers, selectedBucket) {
        manufacturers.filteredForBucket(selectedBucket)
    }
    val filtered = remember(bucketedManufacturers, query) {
        val normalized = query.trim().lowercase()
        if (normalized.isBlank()) {
            bucketedManufacturers
        } else {
            bucketedManufacturers.filter { it.name.lowercase().contains(normalized) }
        }
    }
    AppScreen(contentPadding) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxSize()) {
            AppScreenHeader(title = "Add Manufacturer", onBack = onBack)
            CardContainer {
                AnchoredDropdownFilter(
                    selectedText = selectedBucket.label,
                    options = ManufacturerBucket.entries.map { bucket ->
                        DropdownOption(value = bucket.name, label = bucket.label)
                    },
                    onSelect = { value ->
                        selectedBucket = ManufacturerBucket.valueOf(value)
                    },
                    label = "Bucket",
                )
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    label = { Text("Search manufacturers") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (filtered.isEmpty()) {
                AppPanelEmptyCard(text = "No manufacturers found for that search.")
            } else {
                LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxSize()) {
                    items(filtered) { manufacturer ->
                        CardContainer {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Row(
                                    modifier = Modifier.weight(1f),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    AppCardSubheading(manufacturer.name)
                                    if (manufacturer.isModern) {
                                        AppTintedStatusChip(
                                            text = "Modern",
                                            color = MaterialTheme.colorScheme.primary,
                                            compact = true,
                                        )
                                    }
                                    Text(
                                        "${manufacturer.gameCount} games",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                AppCompactIconButton(
                                    icon = Icons.Filled.Add,
                                    contentDescription = "Add ${manufacturer.name}",
                                    onClick = { onAdd(manufacturer) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AddVenueScreen(
    contentPadding: PaddingValues,
    onBack: () -> Unit,
    onImport: (LibraryVenueSearchResult, List<String>, String, Int) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current
    val prefs = remember(context) { context.getSharedPreferences("settings-v1", Context.MODE_PRIVATE) }
    var query by remember { mutableStateOf("") }
    var radiusMiles by remember { mutableIntStateOf(25) }
    var minimumGameCount by remember { mutableIntStateOf(prefs.getInt("settings-add-venue-min-game-count", 5)) }
    var results by remember { mutableStateOf<List<LibraryVenueSearchResult>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    var locating by remember { mutableStateOf(false) }
    var hasSearched by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var lastSearchContext by remember { mutableStateOf("") }

    val filteredResults = remember(results, minimumGameCount) {
        results.filter { it.machineCount >= minimumGameCount }
    }

    fun effectiveSearchContext(): String = lastSearchContext.ifBlank { query.trim() }

    suspend fun performVenueSearch(
        contextLabel: String,
        search: suspend () -> List<LibraryVenueSearchResult>,
    ) {
        searching = true
        error = null
        hasSearched = true
        lastSearchContext = contextLabel
        runCatching { search() }
            .onSuccess {
                results = it
                error = null
            }.onFailure {
                error = it.message ?: "Venue search failed."
                results = emptyList()
            }
        searching = false
    }

    suspend fun runSearch() {
        val trimmedQuery = query.trim()
        if (trimmedQuery.isBlank()) return
        performVenueSearch(contextLabel = trimmedQuery) {
            withContext(Dispatchers.IO) { PinballMapClient.searchVenues(trimmedQuery, radiusMiles) }
        }
    }

    suspend fun runCurrentLocationSearch() {
        locating = true
        error = null
        val coordinate = runCatching { currentVenueSearchCoordinate(context) }
            .onFailure {
                error = it.message ?: "Current location is unavailable."
            }
            .getOrNull()
        locating = false
        if (coordinate == null) return

        performVenueSearch(contextLabel = "Current location") {
            withContext(Dispatchers.IO) {
                PinballMapClient.searchVenues(
                    latitude = coordinate.latitude,
                    longitude = coordinate.longitude,
                    radiusMiles = radiusMiles,
                )
            }
        }
    }

    fun launchCurrentLocationSearch() {
        if (searching || locating) return
        focusManager.clearFocus()
        scope.launch { runCurrentLocationSearch() }
    }

    val locationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants ->
        val granted = grants[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            grants[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (granted) {
            launchCurrentLocationSearch()
        } else {
            error = "Location permission is required to search near you."
        }
    }

    fun requestCurrentLocationSearch() {
        if (searching || locating) return
        val fineGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (fineGranted || coarseGranted) {
            launchCurrentLocationSearch()
        } else {
            locationPermissionLauncher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                )
            )
        }
    }

    val emptyResultsMessage = remember(hasSearched, results, filteredResults, minimumGameCount) {
        when {
            !hasSearched -> null
            results.isEmpty() -> "No venues found for that search."
            filteredResults.isEmpty() -> {
                if (minimumGameCount == 1) "No venues found with at least 1 game."
                else "No venues found with at least $minimumGameCount games."
            }
            else -> null
        }
    }

    AppScreen(contentPadding) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxSize()) {
            AppScreenHeader(title = "Add Venue", onBack = onBack)
            SettingsVenueSearchCard(
                query = query,
                onQueryChange = { query = it },
                radiusMiles = radiusMiles,
                onRadiusMilesChange = { radiusMiles = it },
                minimumGameCount = minimumGameCount,
                onMinimumGameCountChange = { minimumGameCount = it },
                searching = searching,
                locating = locating,
                error = error,
                onSearch = { scope.launch { runSearch() } },
                onSearchSubmit = {
                    focusManager.clearFocus()
                    if (!searching && !locating && query.isNotBlank()) {
                        scope.launch { runSearch() }
                    }
                },
                onCurrentLocation = { requestCurrentLocationSearch() },
            )
            LaunchedEffect(minimumGameCount) {
                prefs.edit().putInt("settings-add-venue-min-game-count", minimumGameCount).apply()
            }
            emptyResultsMessage?.let {
                AppPanelEmptyCard(text = it)
            }
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxSize()) {
                items(filteredResults) { result ->
                    SettingsVenueResultCard(
                        result = result,
                        searching = searching,
                        onImport = {
                            scope.launch {
                                searching = true
                                error = null
                                runCatching {
                                    withContext(Dispatchers.IO) {
                                        PinballMapClient.fetchVenueMachineIds(result.id.removePrefix("venue--pm-"))
                                    }
                                }.onSuccess { machineIds ->
                                    onImport(
                                        result,
                                        machineIds,
                                        effectiveSearchContext(),
                                        radiusMiles,
                                    )
                                }.onFailure {
                                    error = it.message ?: "Venue import failed."
                                }
                                searching = false
                            }
                        },
                    )
                }
            }
        }
    }
}

@Composable
internal fun AddTournamentScreen(
    contentPadding: PaddingValues,
    onBack: () -> Unit,
    onImport: (MatchPlayTournamentImportResult) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current
    var rawTournamentId by remember { mutableStateOf("") }
    var importing by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val tournamentId = remember(rawTournamentId) { extractTournamentId(rawTournamentId) }
    val canImportTournament = !importing && tournamentId != null

    suspend fun loadTournament(id: String): MatchPlayTournamentImportResult {
        val result = withContext(Dispatchers.IO) { MatchPlayClient.fetchTournament(id) }
        if (result.machineIds.isEmpty()) {
            throw TournamentImportException.NoLinkedArenas
        }
        return result
    }

    fun tournamentImportErrorMessage(error: Throwable): String {
        return when (error) {
            TournamentImportException.NoLinkedArenas -> error.message ?: "Tournament import failed."
            else -> error.message ?: "Tournament import failed."
        }
    }

    suspend fun performTournamentImport() {
        val resolvedId = tournamentId
        if (resolvedId == null) {
            error = "Enter a valid tournament ID."
            return
        }
        importing = true
        error = null
        runCatching { loadTournament(resolvedId) }
            .onSuccess(onImport)
            .onFailure { error = tournamentImportErrorMessage(it) }
        importing = false
    }

    AppScreen(contentPadding) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxSize()) {
            AppScreenHeader(title = "Add Tournament", onBack = onBack)
            SettingsTournamentImportCard(
                rawTournamentId = rawTournamentId,
                onTournamentIdChange = { rawTournamentId = it },
                importing = importing,
                error = error,
                canImportTournament = canImportTournament,
                onImport = { scope.launch { performTournamentImport() } },
                onDone = { focusManager.clearFocus() },
            )
        }
    }
}
