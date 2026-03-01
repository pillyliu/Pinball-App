package com.pillyliu.pinballandroid.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.toArgb
import android.text.method.LinkMovementMethod
import android.widget.TextView
import androidx.core.text.HtmlCompat
import com.pillyliu.pinballandroid.data.rememberLplFullNameAccessUnlocked
import com.pillyliu.pinballandroid.data.rememberShowFullLplLastName
import com.pillyliu.pinballandroid.data.setShowFullLplLastName
import com.pillyliu.pinballandroid.data.unlockLplFullNameAccess
import com.pillyliu.pinballandroid.library.CatalogManufacturerOption
import com.pillyliu.pinballandroid.library.ImportedSourceProvider
import com.pillyliu.pinballandroid.library.ImportedSourceRecord
import com.pillyliu.pinballandroid.library.ImportedSourcesStore
import com.pillyliu.pinballandroid.library.LibrarySeedDatabase
import com.pillyliu.pinballandroid.library.LibrarySource
import com.pillyliu.pinballandroid.library.LibrarySourceEvents
import com.pillyliu.pinballandroid.library.LibrarySourceState
import com.pillyliu.pinballandroid.library.LibrarySourceStateStore
import com.pillyliu.pinballandroid.library.LibrarySourceType
import com.pillyliu.pinballandroid.library.LibraryVenueSearchResult
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.CardContainer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private sealed interface SettingsRoute {
    data object Home : SettingsRoute
    data object AddManufacturer : SettingsRoute
    data object AddVenue : SettingsRoute
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

    suspend fun reload() {
        loading = true
        error = null
        runCatching {
            manufacturers = withContext(Dispatchers.IO) { LibrarySeedDatabase.loadManufacturerOptions(context) }
            importedSources = ImportedSourcesStore.load(context)
            sourceState = LibrarySourceStateStore.load(context)
        }.onFailure { error = it.message ?: "Failed to load settings." }
        loading = false
    }

    fun afterSourceMutation() {
        importedSources = ImportedSourcesStore.load(context)
        sourceState = LibrarySourceStateStore.load(context)
        LibrarySourceEvents.notifyChanged()
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
                    val record = ImportedSourceRecord(
                        id = "manufacturer--${manufacturer.id}",
                        name = manufacturer.name,
                        type = LibrarySourceType.MANUFACTURER,
                        provider = ImportedSourceProvider.OPDB,
                        providerSourceId = manufacturer.id,
                        machineIds = emptyList(),
                        lastSyncedAtMs = System.currentTimeMillis(),
                    )
                    ImportedSourcesStore.upsert(context, record)
                    LibrarySourceStateStore.upsertSource(context, record.id, enable = true, pinIfPossible = true)
                    afterSourceMutation()
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
                    val record = ImportedSourceRecord(
                        id = result.id,
                        name = result.name,
                        type = LibrarySourceType.VENUE,
                        provider = ImportedSourceProvider.PINBALL_MAP,
                        providerSourceId = result.id.removePrefix("venue--pm-"),
                        machineIds = machineIds,
                        lastSyncedAtMs = System.currentTimeMillis(),
                        searchQuery = query,
                        distanceMiles = radiusMiles,
                    )
                    ImportedSourcesStore.upsert(context, record)
                    LibrarySourceStateStore.upsertSource(context, record.id, enable = true, pinIfPossible = true)
                    afterSourceMutation()
                    route = SettingsRoute.Home
                },
            )
            return
        }

        SettingsRoute.Home -> Unit
    }

    AppScreen(contentPadding) {
        if (loading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            return@AppScreen
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                CardContainer {
                    Text("Library", fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { route = SettingsRoute.AddManufacturer }) { Text("Add Manufacturer") }
                        Button(onClick = { route = SettingsRoute.AddVenue }) { Text("Add Venue") }
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
                                    runCatching {
                                        val machineIds = PinballMapClient.fetchVenueMachineIds(source.providerSourceId)
                                        ImportedSourcesStore.upsert(
                                            context,
                                            source.copy(machineIds = machineIds, lastSyncedAtMs = System.currentTimeMillis()),
                                        )
                                        afterSourceMutation()
                                    }.onFailure {
                                        error = "Venue refresh failed: ${it.message ?: "Unknown error"}"
                                    }
                                }
                            } else null,
                            onDelete = {
                                ImportedSourcesStore.remove(context, source.id)
                                afterSourceMutation()
                            },
                        )
                    }
                    if (importedSources.isEmpty()) {
                        Text("No additional sources added yet.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }

            item {
                PrivacySection()
            }

            item {
                CardContainer {
                    Text("About", fontWeight = FontWeight.SemiBold)
                    LinkedHtmlText(
                        html = """
                            LPL Pinball App is built on <a href="https://opdb.org/">OPDB</a> (Open Pinball Database) to provide machine and manufacturer data. Venue search is powered by <a href="https://www.pinballmap.com">Pinball Map</a>. Rulesheets are sourced from <a href="https://tiltforums.com/">Tiltforums</a>, <a href="https://rules.silverballmania.com/">Bob's Guide</a>, <a href="https://pinballprimer.github.io/">Pinball Primer</a>, and <a href="https://replayfoundation.org/papa/learning-center/player-guide/rule-sheets/">PAPA</a>. Playfield images were manually sourced or provided by OPDB. Videos are manually sourced as well as curated from <a href="https://matchplay.events/">Matchplay</a>.
                        """.trimIndent(),
                    )
                }
            }

            error?.let { message ->
                item {
                    CardContainer {
                        Text(message, color = MaterialTheme.colorScheme.error)
                    }
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
                onRefresh?.let { Button(onClick = it) { Text("Refresh") } }
                onDelete?.let { Button(onClick = it) { Text("Delete") } }
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
        Text("Privacy", fontWeight = FontWeight.SemiBold)
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
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Button(onClick = onBack) { Text("Back") }
                Text("Add Manufacturer", fontWeight = FontWeight.SemiBold)
            }
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                ManufacturerBucket.entries.forEachIndexed { index, bucket ->
                    SegmentedButton(
                        selected = selectedBucket == bucket,
                        onClick = { selectedBucket = bucket },
                        shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(
                            index = index,
                            count = ManufacturerBucket.entries.size,
                        ),
                    ) {
                        Text(bucket.label)
                    }
                }
            }
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                label = { Text("Search manufacturers") },
                modifier = Modifier.fillMaxWidth(),
            )
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
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Button(onClick = onBack) { Text("Back") }
                Text("Add Venue", fontWeight = FontWeight.SemiBold)
            }
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
            Text("Distance", style = MaterialTheme.typography.labelSmall)
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                listOf(10, 25, 50, 100).forEachIndexed { index, miles ->
                    SegmentedButton(
                        selected = radiusMiles == miles,
                        onClick = { radiusMiles = miles },
                        shape = androidx.compose.material3.SegmentedButtonDefaults.itemShape(index = index, count = 4),
                    ) {
                        Text("$miles mi")
                    }
                }
            }
            OutlinedTextField(
                value = minimumGameCount.toString(),
                onValueChange = { minimumGameCount = it.toIntOrNull()?.coerceAtLeast(0) ?: minimumGameCount },
                label = { Text("Minimum games") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
            )
            LaunchedEffect(minimumGameCount) {
                prefs.edit().putInt("settings-add-venue-min-game-count", minimumGameCount).apply()
            }
            Button(
                onClick = { scope.launch { runSearch() } },
                enabled = !searching && query.isNotBlank(),
            ) {
                Text(if (searching) "Searching..." else "Search Pinball Map")
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            emptyResultsMessage?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (!hasSearched && results.isEmpty() && !searching) {
                Text(
                    "Search Pinball Map by city or ZIP, then import a venue as a Library source.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
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
