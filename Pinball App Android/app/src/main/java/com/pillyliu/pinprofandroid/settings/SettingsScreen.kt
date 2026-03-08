package com.pillyliu.pinprofandroid.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.Image
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Button
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
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
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.layout.ContentScale
import android.text.method.LinkMovementMethod
import android.widget.TextView
import androidx.core.text.HtmlCompat
import com.pillyliu.pinprofandroid.R
import com.pillyliu.pinprofandroid.data.rememberLplFullNameAccessUnlocked
import com.pillyliu.pinprofandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinprofandroid.data.setShowFullLplLastName
import com.pillyliu.pinprofandroid.data.unlockLplFullNameAccess
import com.pillyliu.pinprofandroid.library.CatalogManufacturerOption
import com.pillyliu.pinprofandroid.library.ImportedSourceRecord
import com.pillyliu.pinprofandroid.library.ImportedSourcesStore
import com.pillyliu.pinprofandroid.library.LibrarySource
import com.pillyliu.pinprofandroid.library.LibrarySourceEvents
import com.pillyliu.pinprofandroid.library.LibrarySourceState
import com.pillyliu.pinprofandroid.library.LibrarySourceStateStore
import com.pillyliu.pinprofandroid.library.LibrarySourceType
import com.pillyliu.pinprofandroid.library.LibraryVenueSearchResult
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppInlineActionChip
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPanelEmptyCard
import com.pillyliu.pinprofandroid.ui.AppPanelStatusCard
import com.pillyliu.pinprofandroid.ui.AppScreenHeader
import com.pillyliu.pinprofandroid.ui.AppScreen
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import com.pillyliu.pinprofandroid.ui.EmptyLabel
import com.pillyliu.pinprofandroid.ui.SectionTitle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private sealed interface SettingsRoute {
    data object Home : SettingsRoute
    data object AddManufacturer : SettingsRoute
    data object AddVenue : SettingsRoute
    data object AddTournament : SettingsRoute
}

private enum class ManufacturerBucket(val label: String) {
    MODERN("Modern"),
    CLASSIC("Classic"),
    OTHER("Other"),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SettingsScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val builtinSources = remember {
        listOf(
            LibrarySource(id = "venue--rlm-amusements", name = "RLM Amusements", type = LibrarySourceType.VENUE),
            LibrarySource(id = "venue--the-avenue-cafe", name = "The Avenue Cafe", type = LibrarySourceType.VENUE),
        )
    }
    var route by remember { mutableStateOf<SettingsRoute>(SettingsRoute.Home) }
    val sourceVersion by LibrarySourceEvents.version.collectAsState()
    var manufacturers by remember { mutableStateOf<List<CatalogManufacturerOption>>(emptyList()) }
    var importedSources by remember { mutableStateOf<List<ImportedSourceRecord>>(emptyList()) }
    var sourceState by remember { mutableStateOf(LibrarySourceState()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var refreshingHostedData by remember { mutableStateOf(false) }
    var hostedDataStatusMessage by remember { mutableStateOf<String?>(null) }
    var hostedDataStatusIsError by remember { mutableStateOf(false) }

    fun applySnapshot(snapshot: SettingsDataSnapshot) {
        manufacturers = snapshot.manufacturers
        importedSources = snapshot.importedSources
        sourceState = snapshot.sourceState
    }

    fun applySourceSnapshot(snapshot: SettingsSourceSnapshot) {
        importedSources = snapshot.importedSources
        sourceState = snapshot.sourceState
    }

    suspend fun reload() {
        loading = true
        error = null
        runCatching { loadSettingsDataSnapshot(context) }
            .onSuccess(::applySnapshot)
            .onFailure { error = it.message ?: "Failed to load settings." }
        loading = false
    }

    fun afterSourceMutation() {
        applySourceSnapshot(
            SettingsSourceSnapshot(
                importedSources = ImportedSourcesStore.load(context),
                sourceState = LibrarySourceStateStore.load(context),
            ),
        )
        LibrarySourceEvents.notifyChanged()
    }

    fun refreshHostedLibraryData() {
        if (refreshingHostedData) return
        scope.launch {
            refreshingHostedData = true
            hostedDataStatusMessage = null
            hostedDataStatusIsError = false
            runCatching { forceRefreshHostedSettingsData(context) }
                .onSuccess { snapshot ->
                applySnapshot(snapshot)
                hostedDataStatusMessage = "Pinball data refreshed from pillyliu.com."
                hostedDataStatusIsError = false
            }.onFailure {
                hostedDataStatusMessage = "Hosted data refresh failed: ${it.message ?: "Unknown error"}"
                hostedDataStatusIsError = true
            }
            refreshingHostedData = false
        }
    }

    LaunchedEffect(Unit) {
        reload()
    }
    LaunchedEffect(sourceVersion) {
        if (sourceVersion != 0L) {
            reload()
        }
    }

    when (route) {
        SettingsRoute.AddManufacturer -> {
            AddManufacturerScreen(
                contentPadding = contentPadding,
                manufacturers = manufacturers,
                onBack = { route = SettingsRoute.Home },
                onAdd = { manufacturer ->
                    applySourceSnapshot(addManufacturerSource(context, manufacturer))
                    route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.AddVenue -> {
            AddVenueScreen(
                contentPadding = contentPadding,
                onBack = { route = SettingsRoute.Home },
                onImport = { result, machineIds, query, radiusMiles ->
                    applySourceSnapshot(addVenueSource(context, result, machineIds, query, radiusMiles))
                    route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.AddTournament -> {
            AddTournamentScreen(
                contentPadding = contentPadding,
                onBack = { route = SettingsRoute.Home },
                onImport = { result ->
                    applySourceSnapshot(addTournamentSource(context, result))
                    route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.Home -> Unit
    }

    AppScreen(contentPadding) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (loading) {
                item {
                    AppPanelStatusCard(
                        text = "Loading settings…",
                        showsProgress = true,
                    )
                }
            }

            item {
                CardContainer {
                    SectionTitle("Library")
                    Text(
                        "Add:",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Button(
                            onClick = { route = SettingsRoute.AddManufacturer },
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                        ) { Text("Manufacturer", maxLines = 1, overflow = TextOverflow.Clip) }
                        Button(
                            onClick = { route = SettingsRoute.AddVenue },
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                        ) { Text("Venue", maxLines = 1, overflow = TextOverflow.Clip) }
                        Button(
                            onClick = { route = SettingsRoute.AddTournament },
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp),
                        ) { Text("Tournament", maxLines = 1, overflow = TextOverflow.Clip) }
                    }
                    Text(
                        "Enabled adds that source's games to Library and Practice. Library adds the source to the Library source filter for quick switching. Up to ${LibrarySourceStateStore.MAX_PINNED_SOURCES} sources can appear in Library at once.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    builtinSources.forEach { source ->
                        ManagedSourceRow(
                            title = source.name,
                            subtitle = "Built-in venue",
                            enabled = true,
                            pinned = sourceState.pinnedSourceIds.contains(source.id),
                            canDisable = false,
                            onEnabledChange = {},
                            onPinnedChange = { isPinned ->
                                if (LibrarySourceStateStore.setPinned(context, source.id, isPinned)) {
                                    afterSourceMutation()
                                } else {
                                    error = "Pinned sources are limited to ${LibrarySourceStateStore.MAX_PINNED_SOURCES}."
                                }
                            },
                            onRefresh = null,
                            onDelete = null,
                        )
                    }
                    importedSources.forEach { source ->
                        ManagedSourceRow(
                            title = source.name,
                            subtitle = when (source.type) {
                                LibrarySourceType.MANUFACTURER -> {
                                    val count = manufacturers.firstOrNull { it.id == source.providerSourceId }?.gameCount ?: 0
                                    "Manufacturer • ${if (count == 1) "1 game" else "$count games"}"
                                }

                                LibrarySourceType.VENUE -> {
                                    val count = source.machineIds.size
                                    "Imported venue • ${if (count == 1) "1 game" else "$count games"}"
                                }

                                LibrarySourceType.TOURNAMENT -> {
                                    val count = source.machineIds.size
                                    "Match Play tournament • ${if (count == 1) "1 game" else "$count games"}"
                                }

                                LibrarySourceType.CATEGORY -> "Category"
                            },
                            enabled = sourceState.enabledSourceIds.contains(source.id),
                            pinned = sourceState.pinnedSourceIds.contains(source.id),
                            canDisable = true,
                            onEnabledChange = {
                                LibrarySourceStateStore.setEnabled(context, source.id, it)
                                afterSourceMutation()
                            },
                            onPinnedChange = { isPinned ->
                                if (LibrarySourceStateStore.setPinned(context, source.id, isPinned)) {
                                    afterSourceMutation()
                                } else {
                                    error = "Pinned sources are limited to ${LibrarySourceStateStore.MAX_PINNED_SOURCES}."
                                }
                            },
                            onRefresh = if (source.type == LibrarySourceType.VENUE) {
                                {
                                    scope.launch {
                                        runCatching { refreshVenueSource(context, source) }
                                            .onSuccess(::applySourceSnapshot)
                                            .onFailure {
                                            error = "Venue refresh failed: ${it.message ?: "Unknown error"}"
                                        }
                                    }
                                }
                            } else if (source.type == LibrarySourceType.TOURNAMENT) {
                                {
                                    scope.launch {
                                        runCatching { refreshTournamentSource(context, source) }
                                            .onSuccess(::applySourceSnapshot)
                                            .onFailure {
                                            error = "Tournament refresh failed: ${it.message ?: "Unknown error"}"
                                        }
                                    }
                                }
                            } else null,
                            onDelete = {
                                applySourceSnapshot(removeSettingsSource(context, source.id))
                            },
                        )
                    }
                    if (importedSources.isEmpty()) {
                        AppPanelEmptyCard(text = "No additional sources added yet.")
                    }
                }
            }

            item {
                CardContainer {
                    SectionTitle("Pinball Data")
                    Text(
                        "Force-refresh the hosted Library and OPDB catalog from pillyliu.com.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Button(
                        onClick = ::refreshHostedLibraryData,
                        enabled = !refreshingHostedData,
                    ) {
                        Text(if (refreshingHostedData) "Refreshing Pinball Data..." else "Refresh Pinball Data")
                    }
                    when {
                        hostedDataStatusMessage != null -> {
                            AppInlineTaskStatus(
                                text = hostedDataStatusMessage.orEmpty(),
                                showsProgress = refreshingHostedData,
                                isError = hostedDataStatusIsError,
                            )
                        }

                        refreshingHostedData -> {
                            AppInlineTaskStatus(
                                text = "Refreshing hosted pinball data…",
                                showsProgress = true,
                            )
                        }
                    }
                }
            }

            item {
                PrivacySection()
            }

            item {
                CardContainer {
                    SectionTitle("About")
                    Box(
                        modifier = Modifier.fillMaxWidth(),
                        contentAlignment = Alignment.Center,
                    ) {
                        Image(
                            painter = painterResource(id = R.drawable.splash_logo),
                            contentDescription = "PinProf logo",
                            modifier = Modifier
                                .fillMaxWidth(0.42f)
                                .heightIn(max = 140.dp),
                            contentScale = ContentScale.Fit,
                        )
                    }
                    LinkedHtmlText(
                        html = """
                            PinProf is built on <a href="https://opdb.org/">OPDB</a> (Open Pinball Database) to provide machine and manufacturer data. Venue search is powered by <a href="https://www.pinballmap.com">Pinball Map</a>. Rulesheets are sourced from <a href="https://tiltforums.com/">Tiltforums</a>, <a href="https://rules.silverballmania.com/">Bob's Guide</a>, <a href="https://pinballprimer.github.io/">Pinball Primer</a>, and <a href="https://replayfoundation.org/papa/learning-center/player-guide/rule-sheets/">PAPA</a>. Playfield images were manually sourced or provided by OPDB. Videos are manually sourced as well as curated from <a href="https://matchplay.events/">Matchplay</a>.
                        """.trimIndent(),
                    )
                }
            }

            error?.let { message ->
                item {
                    AppPanelStatusCard(
                        text = message,
                        isError = true,
                    )
                }
            }
        }
    }
}

@Composable
private fun ManagedSourceRow(
    title: String,
    subtitle: String,
    enabled: Boolean,
    pinned: Boolean,
    canDisable: Boolean,
    onEnabledChange: (Boolean) -> Unit,
    onPinnedChange: (Boolean) -> Unit,
    onRefresh: (() -> Unit)?,
    onDelete: (() -> Unit)?,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                onRefresh?.let { AppInlineActionChip(text = "Refresh", onClick = it) }
                onDelete?.let { AppInlineActionChip(text = "Delete", onClick = it, destructive = true) }
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("Enabled", style = MaterialTheme.typography.labelSmall)
            Switch(
                checked = enabled,
                onCheckedChange = onEnabledChange,
                enabled = canDisable,
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("Pinned", style = MaterialTheme.typography.labelSmall)
            Switch(
                checked = pinned,
                onCheckedChange = onPinnedChange,
            )
        }
    }
}

@Composable
private fun PrivacySection() {
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    val unlocked = rememberLplFullNameAccessUnlocked()
    val showFullLastName = rememberShowFullLplLastName()

    CardContainer {
        SectionTitle("Privacy")
        Text(
            "Lansing Pinball League names are shown as first name plus last initial by default.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (unlocked) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Show full last names for LPL data")
                Switch(
                    checked = showFullLastName,
                    onCheckedChange = { setShowFullLplLastName(context, it) },
                )
            }
        } else {
            var password by remember { mutableStateOf("") }
            var error by remember { mutableStateOf<String?>(null) }
            OutlinedTextField(
                value = password,
                onValueChange = {
                    password = it
                    error = null
                },
                label = { Text("LPL full-name password") },
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(
                    onDone = {
                        focusManager.clearFocus()
                        if (unlockLplFullNameAccess(context, password)) {
                            password = ""
                            error = null
                        } else {
                            error = "Incorrect password."
                        }
                    },
                ),
            )
            Button(
                onClick = {
                    if (unlockLplFullNameAccess(context, password)) {
                        password = ""
                        error = null
                    } else {
                        error = "Incorrect password."
                    }
                },
                enabled = password.isNotBlank(),
            ) {
                Text("Unlock Full Names")
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
    }
}

@Composable
private fun AddManufacturerScreen(
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
                CardContainer {
                    EmptyLabel("No manufacturers found for that search.")
                }
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
                                    Text(manufacturer.name, fontWeight = FontWeight.SemiBold)
                                    if (manufacturer.isModern) {
                                        Text(
                                            "Modern",
                                            style = MaterialTheme.typography.labelSmall,
                                            fontWeight = FontWeight.SemiBold,
                                            modifier = Modifier
                                                .padding(horizontal = 0.dp)
                                                .background(
                                                    MaterialTheme.colorScheme.surfaceContainerHigh,
                                                    shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
                                                )
                                                .padding(horizontal = 8.dp, vertical = 4.dp),
                                        )
                                    }
                                    Text(
                                        "${manufacturer.gameCount} games",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                FilledTonalIconButton(onClick = { onAdd(manufacturer) }) {
                                    Icon(
                                        imageVector = Icons.Filled.Add,
                                        contentDescription = "Add ${manufacturer.name}",
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

private fun List<CatalogManufacturerOption>.filteredForBucket(
    bucket: ManufacturerBucket,
): List<CatalogManufacturerOption> {
    val classicTopIds = filter { !it.isModern }
        .sortedWith(compareByDescending<CatalogManufacturerOption> { it.gameCount }.thenBy { it.name.lowercase() })
        .take(20)
        .map { it.id }
        .toSet()
    return when (bucket) {
        ManufacturerBucket.MODERN -> filter { it.isModern }
        ManufacturerBucket.CLASSIC -> filter { it.id in classicTopIds }
            .sortedWith(compareByDescending<CatalogManufacturerOption> { it.gameCount }.thenBy { it.name.lowercase() })
        ManufacturerBucket.OTHER -> filter { !it.isModern && it.id !in classicTopIds }
    }
}

private fun extractTournamentId(raw: String): String? {
    val trimmed = raw.trim()
    if (trimmed.isBlank()) return null
    if (trimmed.all { it.isDigit() }) return trimmed
    return Regex("""tournaments/(\d+)""")
        .find(trimmed)
        ?.groupValues
        ?.getOrNull(1)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddVenueScreen(
    contentPadding: PaddingValues,
    onBack: () -> Unit,
    onImport: (LibraryVenueSearchResult, List<String>, String, Int) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current
    val prefs = remember(context) { context.getSharedPreferences("settings-v1", android.content.Context.MODE_PRIVATE) }
    var query by remember { mutableStateOf("") }
    var radiusMiles by remember { mutableIntStateOf(50) }
    var minimumGameCount by remember { mutableIntStateOf(prefs.getInt("settings-add-venue-min-game-count", 5)) }
    var results by remember { mutableStateOf<List<LibraryVenueSearchResult>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    var hasSearched by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val filteredResults = remember(results, minimumGameCount) {
        results.filter { it.machineCount >= minimumGameCount }
    }

    suspend fun runSearch() {
        searching = true
        error = null
        hasSearched = true
        runCatching {
            withContext(Dispatchers.IO) { PinballMapClient.searchVenues(query, radiusMiles) }
        }.onSuccess {
            results = it
        }.onFailure {
            error = it.message ?: "Venue search failed."
            results = emptyList()
        }
        searching = false
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
            CardContainer {
                LinkedHtmlText(
                    html = """Search powered by <a href="https://www.pinballmap.com">Pinball Map</a>""",
                )
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    label = { Text("City or ZIP code") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(
                        onSearch = {
                            focusManager.clearFocus()
                            if (!searching && query.isNotBlank()) {
                                scope.launch { runSearch() }
                            }
                        },
                    ),
                )
                AnchoredDropdownFilter(
                    selectedText = "$radiusMiles miles",
                    options = listOf(10, 25, 50, 100).map { miles ->
                        DropdownOption(value = miles.toString(), label = "$miles miles")
                    },
                    onSelect = { value -> radiusMiles = value.toInt() },
                    label = "Distance",
                )
                OutlinedTextField(
                    value = minimumGameCount.toString(),
                    onValueChange = { minimumGameCount = it.toIntOrNull()?.coerceAtLeast(0) ?: minimumGameCount },
                    label = { Text("Minimum games") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
                )
                Button(
                    onClick = { scope.launch { runSearch() } },
                    enabled = !searching && query.isNotBlank(),
                ) {
                    Text(if (searching) "Searching..." else "Search Pinball Map")
                }
                if (searching) {
                    AppInlineTaskStatus(text = "Searching Pinball Map…", showsProgress = true)
                } else if (error != null) {
                    AppInlineTaskStatus(text = error.orEmpty(), isError = true)
                }
            }
            LaunchedEffect(minimumGameCount) {
                prefs.edit().putInt("settings-add-venue-min-game-count", minimumGameCount).apply()
            }
            emptyResultsMessage?.let {
                CardContainer {
                    Text(
                        it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (!hasSearched && results.isEmpty() && !searching) {
                CardContainer {
                    Text(
                        "Search Pinball Map by city or ZIP, then import a venue as a Library source.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxSize()) {
                items(filteredResults) { result ->
                    CardContainer {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(result.name, fontWeight = FontWeight.SemiBold)
                            val locationLine = listOfNotNull(result.city, result.state, result.zip).joinToString(", ")
                            if (locationLine.isNotBlank()) {
                                Text(locationLine, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Text(
                                buildString {
                                    append("${result.machineCount} games")
                                    result.distanceMiles?.let { append(" • ${"%.1f".format(it)} miles") }
                                },
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Button(
                                onClick = {
                                    scope.launch {
                                        searching = true
                                        error = null
                                        runCatching {
                                            withContext(Dispatchers.IO) {
                                                PinballMapClient.fetchVenueMachineIds(result.id.removePrefix("venue--pm-"))
                                            }
                                        }.onSuccess { machineIds ->
                                            onImport(result, machineIds, query.trim(), radiusMiles)
                                        }.onFailure {
                                            error = it.message ?: "Venue import failed."
                                        }
                                        searching = false
                                    }
                                },
                                enabled = !searching,
                            ) {
                                Text("Import Venue")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AddTournamentScreen(
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

    AppScreen(contentPadding) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxSize()) {
            AppScreenHeader(title = "Add Tournament", onBack = onBack)
            CardContainer {
                LinkedHtmlText(
                    html = """Import powered by <a href="https://matchplay.events">Match Play</a>""",
                )
                OutlinedTextField(
                    value = rawTournamentId,
                    onValueChange = { rawTournamentId = it },
                    label = { Text("Tournament ID or URL") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
                )
                Text(
                    "Enter a Match Play tournament ID or URL to import its arena list into Library and Practice.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Button(
                    onClick = {
                        scope.launch {
                            importing = true
                            error = null
                            val resolvedId = tournamentId
                            if (resolvedId == null) {
                                error = "Enter a valid tournament ID."
                                importing = false
                                return@launch
                            }
                            runCatching {
                                withContext(Dispatchers.IO) { MatchPlayClient.fetchTournament(resolvedId) }
                            }.onSuccess { result ->
                                if (result.machineIds.isEmpty()) {
                                    error = "No OPDB-linked arenas were found for that tournament."
                                } else {
                                    onImport(result)
                                }
                            }.onFailure {
                                error = it.message ?: "Tournament import failed."
                            }
                            importing = false
                        }
                    },
                    enabled = !importing && tournamentId != null,
                ) {
                    Text(if (importing) "Importing..." else "Import Tournament")
                }
                if (importing) {
                    AppInlineTaskStatus(text = "Importing tournament…", showsProgress = true)
                } else if (error != null) {
                    AppInlineTaskStatus(text = error.orEmpty(), isError = true)
                }
            }
        }
    }
}

@Composable
private fun LinkedHtmlText(
    html: String,
    modifier: Modifier = Modifier,
) {
    val bodyColor = MaterialTheme.colorScheme.onSurfaceVariant
    val linkColor = MaterialTheme.colorScheme.primary
    AndroidView(
        modifier = modifier.fillMaxWidth(),
        factory = { context ->
            TextView(context).apply {
                movementMethod = LinkMovementMethod.getInstance()
                linksClickable = true
            }
        },
        update = { view ->
            view.textSize = 12f
            view.setTextColor(bodyColor.toArgb())
            view.setLinkTextColor(linkColor.toArgb())
            view.text = HtmlCompat.fromHtml(html, HtmlCompat.FROM_HTML_MODE_LEGACY)
        },
    )
}
